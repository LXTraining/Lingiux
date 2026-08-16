# Arquitectura e Implementación: Módulo de Relatos, Lectura Interactiva y Karaoke Premium 📖

Este documento detalla a fondo la arquitectura, el diseño de la base de datos, el flujo de estado, el motor de reproducción, la sincronización de karaoke y la interfaz visual del **Módulo de Relatos (Lecturas)** en la aplicación Lingiux.

---

## 🌿 1. Introducción y Propósito

El módulo de **Relatos** expande la experiencia de aprendizaje contextual de Lingiux al permitir que los usuarios redacten o lean textos extensos a pantalla completa.

Este módulo vincula de forma sinérgica la lectura pasiva con herramientas activas de gamificación:
1.  **Lectura Táctil (Click-to-Card):** Permite hacer tap sobre cualquier palabra del texto para abrir al instante una tarjeta interactiva flotante (`FlippableCard` montada sobre un `OverlayEntry`) que expone su significado, pronunciación o imagen ilustrativa, reproduciendo un audio de tap y feedback háctico idéntico al chat.
2.  **Resaltado Gramatical (Syntax Highlighting):** Colorea dinámicamente las palabras según su categoría morfológica (sustantivo, verbo, adjetivo, adverbio).
3.  **Voz e Iluminación Activa (Karaoke Sync):** Utiliza síntesis de voz para leer el relato mientras se resalta con un fondo encapsulado violeta y texto en negrita morada la palabra activa, atenuando a un 35% las palabras ya leídas y realizando scroll automático para mantener la lectura centrada.

---

## 📂 2. Estructura de Archivos y Dependencias

La funcionalidad está integrada de manera modular en las siguientes capas del proyecto:

```text
lib/
├── core/
│   └── services/
│       └── audio_service.dart        <-- Servicio de audio para efectos de clic (tap)
├── features/
│   ├── create_card/
│   │   └── presentation/
│   │       └── screens/
│   │           └── create_card_screen.dart <-- Habilitación de "Relato" y Dashboard inferior
│   └── lessons/
│       ├── domain/
│       │   └── models/
│       │       └── story_model.dart  <-- Modelo de datos de los relatos
│       └── presentation/
│           ├── providers/
│           │   └── stories_provider.dart <-- Servicio y Providers de Riverpod para Supabase
│           └── screens/
│               ├── story_editor_screen.dart <-- Editor/Creador de relatos
│               └── story_reader_screen.dart <-- Lector interactivo, motor TTS y Karaoke
android/
└── app/
    └── src/
        └── main/
            └── AndroidManifest.xml   <-- Declaración de visibilidad para TTS en Android 11+
pubspec.yaml                          <-- Dependencia flutter_tts
```

### Librerías Externas
*   **`flutter_tts` (`^4.1.0`):** Utilizada para la síntesis de voz nativa. Proporciona callbacks de inicio y progreso.
*   **`supabase_flutter` (`^2.9.1`):** Base de datos e inserciones asíncronas.
*   **`flutter_riverpod` (`^2.6.1`):** Inyección y reactividad del estado.

---

## ⚙️ 3. Especificaciones Técnicas e Implementación

### A. Base de Datos (Supabase)
Esquema de la tabla `public.stories` con **RLS (Row Level Security)** habilitado:

```sql
CREATE TABLE public.stories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    language TEXT NOT NULL DEFAULT 'EN',
    difficulty TEXT NOT NULL DEFAULT 'A1',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access" ON public.stories FOR SELECT USING (true);
CREATE POLICY "Allow auth insert" ON public.stories FOR INSERT WITH CHECK (auth.uid() = creator_id);
```

### B. Parser de Palabras y Formato de Marcado
Para evitar llamadas externas de NLP, implementamos un parseador basado en **Expresiones Regulares** en [`story_reader_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/lessons/presentation/screens/story_reader_screen.dart).

1.  **Limpieza del Texto:** Elimina etiquetas gramaticales (como `[v:understand]`) para generar un `cleanedText` en texto plano apto para el sintetizador de voz.
2.  **Identificación de Tokens y Posicionamiento:**
    ```dart
    final regExp = RegExp(
      r'\[(v|n|adj|adv):([^\]]+)\]|([a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ]+)|([^a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ\s]+)|(\s+)',
      multiLine: true,
    );
    ```
    Guarda los índices `startOffset` y `endOffset` de cada palabra en relación con el texto limpio para la sincronización temporal del audio.

### C. Motor de Karaoke Avanzado y Sincronización (State-Synchronized Prediction)
Para evitar el desfase (lag) característico de los motores TTS en dispositivos móviles, se diseñó un algoritmo híbrido predictivo de doble vía:

1.  **Inicio Milimétrico con `setStartHandler`:**
    El resaltado y el movimiento de la pantalla no inician al pulsar Play (lo que causaría desfase debido al tiempo de carga del motor TTS de 300ms), sino que se disparan exactamente cuando el sistema operativo confirma el inicio físico del audio:
    ```dart
    _flutterTts.setStartHandler(() {
      setState(() {
        _isPlaying = true;
        _currentWordIndex = firstWordIdx;
      });
      _startFallbackTimer();
    });
    ```
2.  **Temporizador Predictor Inteligente:**
    Se calcula dinámicamente el tiempo de lectura de cada palabra basándose en la longitud de las letras y la velocidad seleccionada (`_speechRate`):
    ```dart
    final wordDurationMs = ((currentWordText.length * 95) / (_speechRate / 0.5)).clamp(220.0, 1600.0).toInt();
    ```
3.  **Estabilización en Tiempo Real por Hardware:**
    Si el dispositivo es compatible con callbacks de rango de caracteres, la función `setProgressHandler` intercepta el progreso real del audio del hardware y **sobreescribe** de forma automática la predicción del temporizador, corrigiendo cualquier drift (desviación) acumulado y re-programando la siguiente palabra:
    ```dart
    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      // Búsqueda del token por coincidencia de offset de caracteres
      // ...
      if (activeIndex != -1 && activeIndex != _currentWordIndex) {
        setState(() => _currentWordIndex = activeIndex);
        _scheduleNextWordFallback(); // Sincroniza y reinicia predicción
      }
    });
    ```

### D. Interfaz Visual y Animaciones del Lector sepia
1.  **Fondo Sepia/Pergamino:** El widget principal está envuelto en un gradiente que va de un cálido crema papel (`Color(0xFFFDFBF7)`) a un sepia suave (`Color(0xFFF5EDE0)`).
2.  **Blobs Decorativos de Fondo:** Dos círculos fijos y translúcidos se posicionan en las esquinas (Melón translúcido arriba a la derecha y Lavanda morado de la marca abajo a la izquierda) para darle una estética moderna de libro digital.
3.  **Atenuación Activa (Fading):** Las palabras que ya han sido leídas (`index < _currentWordIndex`) reducen su opacidad a un **35%** mediante un widget `AnimatedOpacity(duration: 200ms)`.
4.  **Resaltado Encapsulado (Pill Highlight):** La palabra activa se encierra en una cápsula violeta con bordes muy redondeados (`BorderRadius.circular(8)`) y color `Color(0xFF7C3AED).withValues(alpha: 0.12)`, aplicando además una animación que incrementa su padding interno. El color del texto activo cambia a violeta profundo.
5.  **Desplazamiento Automático (Auto-Scroll):** La palabra activa detecta su iluminación y llama de forma autocontenida a `Scrollable.ensureVisible` centrando la pantalla con una curva suave de **280ms**.

### E. Unificación de FlippableCard Pop-ups
Al hacer tap sobre una palabra:
1.  Se reproduce un sonido de clic mediante `audioServiceProvider.playTap()` y se activa la vibración nativa (`HapticFeedback.lightImpact()`).
2.  Se carga la tarjeta flotante de la palabra. Si esta palabra no existe en la colección, se levanta igualmente el componente `FlippableCard` con el reverso configurado como un atajo de creación rápida ("+ Crear").
3.  **Resolución de Desbordamiento:** Se aumentó la altura del `SizedBox` contenedor en el overlay a **`cardHeight + 8.0`** (144.0 píxeles) para dar cabida al cuerpo de la tarjeta de 136.0 píxeles más los 8.0 píxeles que ocupa el indicador de flecha (ArrowPainter), eliminando las alertas rojas de desbordamiento de pantalla.

---

## 🔄 5. Instrucciones para Revertir la Funcionalidad

Si decides revertir y remover por completo este módulo de la aplicación, debes ejecutar las siguientes acciones paso a paso:

1.  **Bloquear la opción "Relato" en el selector:** En [`create_card_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_screen.dart), remueve el enlace de la tarjeta de relatos a la navegación del editor, restaura `isFuture: true` y borra la sección inferior de lecturas públicas.
2.  **Revertir AndroidManifest.xml:** En `android/app/src/main/AndroidManifest.xml`, remueve la línea `<action android:name="android.intent.action.TTS_SERVICE" />` dentro de `<queries>`.
3.  **Eliminar Archivos Creados:** Borra del disco los siguientes archivos:
    *   `lib/features/lessons/domain/models/story_model.dart`
    *   `lib/features/lessons/presentation/providers/stories_provider.dart`
    *   `lib/features/lessons/presentation/screens/story_editor_screen.dart`
    *   `lib/features/lessons/presentation/screens/story_reader_screen.dart`
    *   `resources/mds_relevantes/implementacion_modulo_relatos_y_lectura_interactiva.md`
4.  **Remover la Dependencia TTS:** Elimina `flutter_tts: ^4.1.0` de `pubspec.yaml` y ejecuta `flutter pub get`.
5.  **Eliminar Tabla:** Ejecuta `DROP TABLE public.stories CASCADE;` en Supabase.
