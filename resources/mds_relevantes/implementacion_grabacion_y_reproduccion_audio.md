# Implementación de Grabación y Reproducción de Audio en Cartas

Este documento técnico detalla la arquitectura, herramientas, base de datos y cambios en el código realizados para implementar la grabación de notas de voz personalizadas de hasta 15 segundos al crear cartas de vocabulario, y su posterior reproducción en el carrusel de la aplicación **Lingiux**.

---

## 🎙️ 1. Objetivo y Requerimientos

El objetivo principal es permitir a los usuarios agregar notas de voz personalizadas (ej. pronunciando el significado o la frase de ejemplo) a las cartas que crean en la aplicación:
1.  **Límite de Tiempo:** La grabación debe tener un límite estricto de **15 segundos**, deteniéndose por software automáticamente al llegar a ese umbral.
2.  **Previsualización Local:** El usuario puede escuchar la nota de voz grabada (Play/Pausa) o descartarla y volver a grabar antes de subir la tarjeta.
3.  **Almacenamiento en Supabase:** El archivo de audio se sube como binario a Supabase Storage y el enlace (URL pública) se asocia al registro de la carta en la base de datos PostgreSQL.
4.  **Reproducción Remota (Streaming):** Al visualizar el carrusel de cartas de vocabulario, las cartas con audio muestran un botón de reproducción. Al tocarlo, el audio se reproduce vía streaming y se detiene automáticamente si el usuario desliza la pantalla hacia otra tarjeta.

---

## 📦 2. Librerías y Dependencias Utilizadas

Se añadieron y configuraron tres paquetes esenciales del ecosistema Flutter en [pubspec.yaml](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/pubspec.yaml):

| Librería | Versión | Propósito |
| :--- | :--- | :--- |
| **`record`** | `^6.2.1` | Interactuar con el micrófono del dispositivo, solicitar permisos y generar el archivo codificado en AAC (M4A) de forma nativa. |
| **`path_provider`** | `^2.1.6` | Obtener rutas seguras del almacenamiento del sistema operativo (directorio temporal de caché) para guardar el archivo de audio local antes de subirlo. |
| **`audioplayers`** | `^6.7.1` | Reproducir el audio tanto localmente (para la previsualización usando `DeviceFileSource`) como de forma remota en streaming (mediante `UrlSource`). |

---

## ☁️ 3. Configuración en el Servidor (Supabase)

### Base de Datos (PostgreSQL)
Se ejecutó una instrucción DDL para agregar la columna de soporte de audio a la tabla existente:
```sql
ALTER TABLE public.word_cards ADD COLUMN IF NOT EXISTS audio_url text NULL;
```

### Almacenamiento (Storage Bucket)
Para simplificar el acceso a los archivos y reutilizar las políticas de seguridad públicas ya configuradas en el proyecto, los audios se suben al bucket público `word-images` bajo el prefijo de carpeta `audios/` (ejemplo de ruta final: `audios/audio_1700000000.m4a`).

---

## 🛠️ 4. Archivos Modificados y Detalles del Código

### A. Modelo de Datos
*   **Archivo:** [word_card_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/domain/models/word_card_model.dart)
*   **Cambio:** Se agregó la propiedad `audioUrl` (String, nullable) al constructor de `WordCardModel`, configurando su mapeo en las funciones `fromJson` y `toJson` para leer y escribir el campo `audio_url` de la base de datos.

### B. Formulario de Creación de Tarjetas
*   **Archivo:** [create_card_form_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_form_screen.dart)
*   **Cambios Clave:**
    *   **Inicialización y Ciclo de Vida:** Se instanciaron `AudioRecorder` y `AudioPlayer` locales, liberando sus recursos adecuadamente mediante sus respectivos métodos `.dispose()` y cancelando los temporizadores en el método `dispose()` del State.
    *   **Lógica de Grabación:**
        *   `_startRecording()`: Solicita permisos del micrófono. Si se conceden, inicia la grabación en formato AAC (`AudioEncoder.aacLc`) en la ruta temporal del celular y arranca un `Timer.periodic` de un segundo. Si el temporizador llega a `15`, invoca automáticamente a `_stopRecording()`.
        *   `_stopRecording()`: Detiene el grabador y almacena la ruta del archivo local `.m4a` en el estado.
        *   `_deleteRecording()`: Elimina el archivo físico de audio temporal y limpia el estado para permitir una nueva grabación.
        *   `_togglePlayPreview()`: Reproduce o detiene la previsualización local usando `DeviceFileSource`.
    *   **Interfaz de Usuario (UI):** Se creó el componente dinámico `_buildAudioRecorderSection()` que se adapta visualmente al estado:
        *   *Listo para grabar:* Botón de "Iniciar Grabación" con icono de micrófono.
        *   *Grabando:* Indicador circular de progreso parpadeante con el formato de tiempo `0:SS / 0:15` y botón de detener (Stop).
        *   *Grabado:* Botón de reproducción circular (Play/Pause) para escuchar el audio guardado y botón de papelera para descartar el audio.
    *   **Proceso de Subida (`_saveCard`):** Si hay un audio local grabado, lee el archivo como bytes (`readAsBytes()`), lo sube a Supabase Storage con `uploadBinary` especificando el Content-Type `audio/m4a`, y guarda la URL pública en el campo `audio_url` de la base de datos al insertar la carta.

### C. Visualización de Cartas en el Carrusel (Scrolling)
*   **Archivo:** [word_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/screens/word_detail_screen.dart)
*   **Cambios Clave:**
    *   **Reproductor Centralizado:** Se integró una instancia de `AudioPlayer` (`_networkPlayer`) dentro de `_WordDetailScreenState` para manejar el streaming remoto de los audios.
    *   **Control del Scroll:** En el `PageView.builder`, al cambiar de página (`onPageChanged`), se llama a `_networkPlayer.stop()` y se resetea el estado para silenciar inmediatamente el audio de la tarjeta anterior.
    *   **Botón de Volumen Interactivo:** En la vista individual `_WordCard`, el icono de volumen (`volume_up_rounded`) ahora es interactivo:
        *   Solo aparece si `wordCard.audioUrl` tiene contenido.
        *   Muestra un icono de "Pausa" (`pause_rounded`) si el audio de esa carta específica está sonando, y un altavoz (`volume_up_rounded`) en caso contrario.
        *   Al hacer tap, se delega al método `_toggleAudio()` de la pantalla para reproducir el streaming de internet (`UrlSource`).

### D. Pruebas y Limpieza del Analizador
*   **Archivo:** [widget_test.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/test/widget_test.dart)
*   **Cambio:** Se eliminaron imports redundantes de Flutter Material para limpiar los warnings estáticos del compilador.

---

## 🔄 5. Flujo Completo del Audio (Esquema)

```text
[Formulario de Creación]
  └── Grabar audio (Máx. 15s) ──> Guarda temp.m4a en caché local
  └── Subir Tarjeta ──> Sube temp.m4a a Supabase Storage (word-images/audios/)
                      └── Inserta 'audio_url' en base de datos PostgreSQL

[Carrusel de Vocabulario]
  └── Lee 'audio_url' de Supabase
  └── Si existe ──> Renderiza botón de Play
                      └── Tap en botón ──> Streaming de audio remoto vía AudioPlayer (URL)
                      └── Swipe Vertical ──> Detiene el audio
```
