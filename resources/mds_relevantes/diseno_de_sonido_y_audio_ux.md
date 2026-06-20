# Diseño de Sonido y Audio UX (UI Sound SFX)

Este documento sirve como guía técnica y de buenas prácticas para la implementación de efectos de sonido (Audio UX) y retroalimentación háptica (vibraciones) en la interfaz de usuario de **Lingiux**.

---

## 1. Fundamentos del Audio UX en Dispositivos Móviles

El diseño de sonido para interfaces móviles no busca entretener, sino **confirmar una acción**. Su propósito principal es dar retroalimentación física al usuario tras interactuar con un elemento virtual (como tocar una palabra).

### 1.1 El factor latencia
Para sonidos de interfaz de usuario (UI SFX), el retraso entre la pulsación y la reproducción de audio debe ser menor a **50 milisegundos**. Si el retraso supera este umbral, el usuario percibe que la aplicación es lenta o pesada.

### 1.2 Comparativa de Formatos

| Formato | Compresión | Latencia de Decodificación | Uso Recomendado |
| :--- | :--- | :--- | :--- |
| **`.wav` (PCM 16-bit)** | Ninguna | **Cero (Instantánea)** | Sonidos muy cortos de UI de < 1 seg (clicks, pops, taps). |
| **`.mp3` / `.aac`** | Con pérdida | Muy baja (en archivos muy cortos) | Sonidos cortos de UI y música de fondo o audios de pronunciaciones. |
| **`.ogg`** | Con pérdida | Muy baja | Sonidos interactivos intermedios y efectos de videojuegos. |

---

## 2. Almacenamiento y Registro de Sonidos en Flutter

Los archivos de audio locales se agregan como recursos estáticos del proyecto en la carpeta de assets dedicada al sonido:

```text
lingiux_app/
  └── assets/
      └── sounds/
          ├── tap_pop.wav
          ├── tap_pop.mp3
          └── card_flip.mp3
```

### 2.1 Registro dinámico por Directorio (Mejor Práctica)
Para evitar editar el archivo `pubspec.yaml` cada vez que agregamos o cambiamos un sonido, registramos la carpeta entera de sonidos con una barra diagonal al final. Esto hace que Flutter registre automáticamente cualquier archivo (`.mp3`, `.wav`, etc.) que coloquemos ahí:

```yaml
flutter:
  assets:
    - .env
    - assets/sounds/
```

> [!WARNING]
> Si agregas un archivo nuevo a la carpeta `assets/sounds/` o modificas `pubspec.yaml`, **debes detener la app por completo y volver a iniciarla** (`flutter run`). Un *Hot Reload* o *Hot Restart* no compilará los nuevos assets en el instalador.

---

## 3. Implementación de Audio: De Soundpool a un Pool de AudioPlayers

### 3.1 ¿Por qué no usamos `soundpool`?
Originalmente se consideró el paquete `soundpool` debido a su latencia ultra-baja. Sin embargo, en compilaciones modernas de Flutter y Gradle, este paquete causa errores graves de compilación en Android:
`Unresolved reference 'Registrar'`
Esto sucede porque `soundpool` quedó obsoleto y utiliza las APIs antiguas de *Flutter Android Embeddings v1*, lo cual bloquea la construcción de la app en versiones modernas de Flutter.

### 3.2 Migración y Solución: Pool de `AudioPlayer`
Como reemplazo, utilizamos la librería oficial y mantenida **`audioplayers`** (v6.7.1). 

Para lograr la misma respuesta instantánea y resolver dos grandes problemas típicos de la reproducción de audio, implementamos un **Pool de Reproductores**:

1. **El problema de la reproducción única ("Play-Once"):** Si se usa un único objeto `AudioPlayer`, cuando el sonido termina de reproducirse, el reproductor se queda apuntando al final del archivo. Para volver a reproducirlo es necesario reiniciar el reproductor, pero apagarlo (`stop()`) o mover el cabezal (`seek()`) asíncronamente en cada tap suele generar fallos de sincronía e impedir que el sonido se escuche en taps consecutivos rápidos.
2. **El problema de la Recolección de Basura (Garbage Collection):** Si creamos un `AudioPlayer` local dentro de la función de click y no guardamos una referencia a él, el recolector de basura de Dart lo borra de la memoria RAM a los pocos microsegundos antes de que el celular envíe la señal nativa de reproducir el audio. Esto hace que el sonido falle silenciosamente y no suene nada.
3. **Soporte de sonidos superpuestos (Overlap):** Si el usuario toca varias palabras en ráfaga rápida, necesitamos que los sonidos suenen uno encima del otro de manera natural, en vez de cortarse entre sí.

#### Arquitectura del Pool en `AudioService`:
Inicializamos un pool de tamaño fijo (`4` reproductores) al iniciar el servicio. Guardamos las referencias de estos 4 reproductores en una lista de la clase singleton para evitar que Dart los borre de la memoria. Cada vez que el usuario hace tap, rotamos al siguiente reproductor de la lista y llamamos a `play()`.

---

## 4. Código de Implementación: `AudioService`

El servicio (`lib/core/services/audio_service.dart`) realiza una detección dinámica inteligente en el arranque para elegir el mejor formato disponible:

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioService {
  bool _initialized = false;
  late Source _tapSource;
  final List<AudioPlayer> _pool = [];
  int _nextPlayerIndex = 0;
  static const int _poolSize = 4;

  Future<void> init() async {
    if (_initialized) return;
    try {
      // Configurar el contexto global para mezclar audio con otras apps (sin pausar Spotify, etc.)
      final audioContext = AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build();
      await AudioPlayer.global.setAudioContext(audioContext);

      // 1. Detectar si existe tap_pop.mp3 en assets
      try {
        await rootBundle.load('assets/sounds/tap_pop.mp3');
        _tapSource = AssetSource('sounds/tap_pop.mp3');
        debugPrint('AudioService: detectado tap_pop.mp3 en assets');
      } catch (_) {
        // Fallback al sonido sintetizado por defecto
        _tapSource = AssetSource('sounds/tap_pop.wav');
        debugPrint('AudioService: usando tap_pop.wav de fallback');
      }

      // 2. Inicializar el pool de reproductores con el audio pre-cargado
      for (int i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        await player.setSource(_tapSource);
        _pool.add(player);
      }
      
      _initialized = true;
      debugPrint('AudioService: Inicializado pool de $_poolSize reproductores');
    } catch (e) {
      debugPrint('Error inicializando AudioService: $e');
    }
  }

  void playTap() {
    if (!_initialized || _pool.isEmpty) return;
    try {
      // Rotar entre los reproductores para permitir clicks rápidos superpuestos
      final player = _pool[_nextPlayerIndex];
      player.play(_tapSource);
      _nextPlayerIndex = (_nextPlayerIndex + 1) % _poolSize;
    } catch (e) {
      debugPrint('Error al reproducir tap: $e');
    }
  }

  void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
    _pool.clear();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  service.init();
  return service;
});
```

---

## 5. Retroalimentación Háptica (Vibraciones Táctiles)

Para complementar la confirmación acústica, los sonidos de tap se sincronizan con un estímulo táctil físico discreto:

```dart
import 'package:flutter/services.dart';

// Genera un micro-toque en el motor vibratorio del celular
HapticFeedback.lightImpact();
```

*Nota: Se prefiere `HapticFeedback.lightImpact()` para botones comunes y gestos de lectura, ya que imita la pulsación de una tecla física sin ser intrusivo.*

---

## 6. Proceso Paso a Paso para Agregar/Cambiar Sonidos en el Futuro

Si deseas cambiar el sonido del tap o agregar un sonido de éxito/error en otra pantalla, sigue este procedimiento estructurado:

### Paso 1: Obtener el archivo de sonido
*   Busca o edita tu sonido preferido. (Páginas recomendadas: **Freesound.org**, **Mixkit.co**, **Sonniss**).
*   Formatos recomendados: `.wav` (PCM 16-bit) para clicks/taps cortos (máxima velocidad), o `.mp3` para efectos melódicos cortos de interfaz.

### Paso 2: Guardar el archivo en el proyecto
*   Mueve el archivo descargado a la ruta: `lingiux_app/assets/sounds/`.
*   Nómbralo en minúsculas y usando guiones bajos (snake_case), por ejemplo: `assets/sounds/success_chime.mp3`.

### Paso 3: Configurar en `pubspec.yaml`
*   Si agregas el archivo en la carpeta `assets/sounds/`, **no** necesitas editar `pubspec.yaml` si la carpeta completa ya está registrada como `- assets/sounds/`.
*   Si creas una subcarpeta nueva (ej. `assets/sounds/interface/`), agrégala al listado de assets:
    ```yaml
    flutter:
      assets:
        - assets/sounds/interface/
    ```

### Paso 4: Detener y reconstruir la aplicación (Obligatorio)
*   **Detén la app por completo** en tu editor/terminal.
*   Ejecuta `flutter clean` (opcional, para borrar caché vieja de assets).
*   Inicia la app de nuevo (`flutter run`).

### Paso 5: Cargar y reproducir en el Código
*   Si vas a crear un nuevo sonido (ejemplo: sonido de éxito), agrégalo a `AudioService`:
    ```dart
    late Source _successSource;
    // En init():
    _successSource = AssetSource('sounds/success_chime.mp3');
    
    // Método para reproducir:
    void playSuccess() {
      // Puedes usar un reproductor del pool o uno temporal para sonidos poco frecuentes
      final player = AudioPlayer();
      player.play(_successSource);
    }
    ```
*   Invócalo desde tus pantallas mediante Riverpod:
    ```dart
    ref.read(audioServiceProvider).playSuccess();
    ```
