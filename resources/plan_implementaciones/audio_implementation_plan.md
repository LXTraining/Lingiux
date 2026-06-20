# Plan de Implementación: Grabación y Reproducción de Audio en Cartas

Este plan detalla los pasos técnicos para implementar la grabación de audio de hasta 15 segundos al crear una carta, guardarla en Supabase Storage, y poder reproducirla en el scroll de las tarjetas de vocabulario.

## User Review Required

> [!NOTE]
> **Base de Datos Configurada:** Ya he ejecutado la migración SQL en Supabase para agregar la columna `audio_url` a la tabla `word_cards`.
> 
> **Bucket de Supabase:** Para simplificar la configuración de políticas públicas de lectura y subida, se guardarán los audios dentro del bucket existente `word-images` bajo la ruta `audios/` (ejemplo: `audios/1700000000.m4a`). Esto garantiza que los audios sean públicos e inmediatamente reproducibles por streaming sin configurar políticas adicionales.

## Proposed Changes

### Dependencias

#### [MODIFY] [pubspec.yaml](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/pubspec.yaml)
*   Agregar el paquete `record: ^5.1.2` para capturar audio desde el micrófono.
*   Agregar el paquete `path_provider: ^2.1.3` para obtener acceso al directorio temporal del celular y guardar el archivo temporal de audio antes de subirlo.

---

### Modelo de Datos

#### [MODIFY] [word_card_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/domain/models/word_card_model.dart)
*   Añadir la propiedad `final String? audioUrl` al modelo `WordCardModel`.
*   Actualizar `fromJson` para mapear el campo `audio_url`.
*   Actualizar `toJson` para incluir el campo `audio_url`.

---

### Creación de Cartas

#### [MODIFY] [create_card_form_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_form_screen.dart)
*   Importar las dependencias `record` y `path_provider`.
*   Añadir un componente visual interactivo para la grabación de audio antes del botón de guardar:
    *   **Estado inactivo:** Muestra un botón con icono de micrófono y etiqueta "Grabar nota de voz (Máx. 15s)".
    *   **Estado grabando:** Muestra un indicador rojo parpadeante, un temporizador dinámico (ej: `0:05 / 0:15`) y un botón de parar. Se detiene automáticamente al llegar a los 15 segundos.
    *   **Estado grabado:** Muestra controles de reproducción para previsualizar el audio (Play/Pausa) y un botón de borrar para volver a grabar.
*   En la función `_saveCard()`:
    *   Si hay un audio grabado, leer el archivo como bytes.
    *   Subir el archivo de audio a Supabase Storage en el bucket `word-images` bajo la ruta `audios/${timestamp}.m4a`.
    *   Obtener la URL pública del audio y guardarla en la columna `audio_url` de la tabla `word_cards`.

---

### Visualización y Reproducción

#### [MODIFY] [word_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/screens/word_detail_screen.dart)
*   Modificar la visualización de la tarjeta en `_WordCard`.
*   En el botón de volumen (`volume_up_rounded`):
    *   Solo mostrarlo o activarlo si la propiedad `wordCard.audioUrl` no está vacía.
    *   Al tocar el botón de volumen, reproducir el audio del usuario vía streaming a través de una instancia local o compartida de `AudioPlayer`.
    *   Mapear estados de reproducción (cargando, sonando, pausado) para animar el icono correspondientemente si el usuario reproduce el audio.

---

## Verification Plan

### Automated Tests
*   Ejecutar `flutter test` para validar que los modelos y widgets continúen compilando y pasando las pruebas de humo.
*   Ejecutar `flutter analyze` para verificar la sanidad del código.

### Manual Verification
*   Validar la UI del formulario: iniciar grabación, confirmar que el temporizador incrementa, detenerla antes de 15 segundos, y escuchar la previsualización.
*   Validar el límite automático de 15 segundos: iniciar grabación y esperar a que se detenga sola al llegar a 15 segundos.
*   Subir carta de prueba: rellenar datos, grabar audio, y confirmar que se sube exitosamente a Supabase.
*   Visualización: abrir la carta creada en el carrusel de vocabulario y pulsar el icono de audio para validar la reproducción fluida mediante streaming.
