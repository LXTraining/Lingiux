# Plan de Implementación: Stepper de Creación de Cartas de Vocabulario (Wizard Editor)

Este plan describe la reestructuración completa de la pantalla de creación de Word Cards en **Lingiux**. Pasaremos de un flujo rígido e invasivo (que abre la galería al instante de presionar el botón `+`) a un **asistente progresivo (Wizard/Stepper) de 4 pasos** que valida el contenido semántico primero, permite subir imágenes directamente dentro de una maqueta de tarjeta, ofrece personalización estética en caliente y finaliza con una previsualización 3D interactiva antes de persistir los datos en Supabase.

---

## User Review Required

> [!IMPORTANT]
> **Cambios de Flujo Críticos:**
> * El botón central `+` de la barra de navegación ya no abrirá la galería del teléfono de forma automática. Ahora navegará directamente a la pantalla del Asistente de Creación, mostrando el **Paso 1**.
> * La grabación de audio y la selección de categoría gramatical se mantendrán dentro del Paso 1 (identidad de la palabra), ya que forman parte de su estructura sonora y semántica.
> * La selección de imagen se desplaza al **Paso 2** y se integra visualmente dentro de un lienzo interactivo de tarjeta (*Dashed Border Image Picker*).
> * Los commits en Git se dejarán listos para que los ejecutes manualmente según tus preferencias.

---

## Proposed Changes

La reestructuración se realizará de forma modular en la capa de presentación de la característica `create_card`.

### Componente de Creación de Cartas (`lib/features/create_card`)

#### [MODIFY] [create_card_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_screen.dart)
* Rediseñar este archivo para que actúe como el Scaffold principal del Asistente.
* Implementar:
  * `PageController` con scroll bloqueado (`NeverScrollableScrollPhysics`).
  * Una barra de progreso superior animada (`AnimatedContainer` o `LinearProgressIndicator` personalizado).
  * Un indicador de texto de pasos (ej: "Paso 1 de 4: Palabra").
  * Panel inferior de control con botones Soft UI ("Atrás" y "Continuar / Crear").
* Integrar los 4 pasos dentro del cuerpo del `PageView`.

#### [NEW] [step_word_identity.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/step_word_identity.dart)
* **Paso 1: Identidad:** Contendrá los campos para la Palabra, Idioma, Categoría Gramatical (Sustantivo, Verbo, etc.), Fonética y la grabadora de audio (`AudioRecorder` preexistente).
* Implementará la lógica de validación rápida.

#### [NEW] [step_word_mnemonics.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/step_word_mnemonics.dart)
* **Paso 2: Nemotecnia:** Mostrará la silueta de la tarjeta vacía con un contenedor punteado (*dashed border*) y un botón de `+` en el centro.
* Al pulsar sobre la tarjeta vacía se disparará el selector de imágenes (`image_picker`). Al seleccionar la imagen, se mostrará como fondo de la carta en tiempo real.
* Añadirá los campos inferiores para la definición de la palabra y la frase de ejemplo.

#### [NEW] [step_card_aesthetics.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/step_card_aesthetics.dart)
* **Paso 3: Personalización:** Permitirá seleccionar el fondo (carrusel de combinaciones de gradientes premium) y el marco decorativo (Normal, Bronce, Plata, Oro, Neón) mediante un carrusel interactivo debajo del lienzo de la carta.

#### [NEW] [step_card_preview.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/step_card_preview.dart)
* **Paso 4: Previsualización 3D:** Integrará el widget de volteo de cartas en 3D que diseñamos.
* Permitirá dar tap para voltear y ver el reverso (definición) antes de publicar.
* Se conectará con la función de subida de imagen/audio a Supabase Storage e inserción del registro en `word_cards`.

---

## Verification Plan

### Manual Verification
1. **Paso 1 (Validación):** Intentar avanzar al paso 2 sin introducir una palabra. Comprobar que el asistente bloquea el progreso y muestra un mensaje de error.
2. **Paso 2 (Imagen en Canvas):** Tocar el botón `+` en el centro del lienzo de la tarjeta vacía, seleccionar una imagen de la galería y comprobar que se visualiza como fondo de la tarjeta en tiempo real sin salir de la pantalla del stepper.
3. **Paso 3 (Personalización):** Seleccionar diferentes gradientes y marcos en el carrusel y confirmar que la carta actualiza su estilo estético al instante.
4. **Paso 4 (Previsualización 3D y Guardar):** Probar el volteo 3D de la carta (frente y reverso), pulsar el botón de crear y comprobar que se suban los datos correctamente a Supabase y se retorne al feed refrescando la base de datos de las Word Cards.
