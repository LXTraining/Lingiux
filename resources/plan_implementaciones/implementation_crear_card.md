# Plan de Implementación: Creación Dinámica de Word Cards con Supabase y Galería

Este plan detalla los pasos para implementar el flujo de creación de tarjetas de vocabulario desde la aplicación. Los usuarios podrán seleccionar una imagen de su galería, completar un formulario dinámico con toda la metadata y subirla directamente a Supabase (Storage y Base de Datos), integrándose automáticamente en la lista de tarjetas y en el reconocedor de palabras de los chats.

---

## Proposed Changes

### 1. Modelo de Datos y Visualización (Domain & Presentation)

#### [MODIFY] [word_card_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/domain/models/word_card_model.dart)
* Añadir campos opcionales en el modelo `WordCardModel`:
  * `exampleSentence` (`String?` mapeado a `example_sentence` en JSON).
  * `category` (`String?` mapeado a `category` en JSON).
  * `language` (`String?` mapeado a `language` en JSON).
* Actualizar el constructor, el método `factory WordCardModel.fromJson` y `Map<String, dynamic> toJson` para soportar estos nuevos campos.

#### [MODIFY] [word_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/screens/word_detail_screen.dart)
* Modificar el widget `_WordCard`:
  * En la sección de **Tags**, reemplazar la lista estática hardcodeada por una fila dinámica que renderice el tag del idioma (`wordCard.language`) y de la categoría (`wordCard.category`) si están presentes. Dejar un tag por defecto ("Vocabulario") si ambos están vacíos.
  * En la sección de **Definición**, envolver el texto de la descripción en un `Column` y agregar abajo la frase de ejemplo (`wordCard.exampleSentence`) entre comillas y en estilo itálico con opacidad reducida (`withValues(alpha: 0.75)`), manteniendo la propiedad scrollable en caso de textos largos.

---

### 2. Flujo de Captura y Formulario de Creación

#### [MODIFY] [create_card_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_screen.dart)
* Convertir el widget de `StatelessWidget` a `StatefulWidget` o usar una estructura interactiva.
* Integrar `image_picker` para permitir seleccionar una imagen de la galería.
* Lógica del flujo:
  * Al ingresar a la sección de "Crear" (pestaña del signo "+"), se disparará automáticamente el selector de imágenes de la galería (`ImagePicker.pickImage(source: ImageSource.gallery)`) mediante un callback post-frame en la inicialización.
  * Si el usuario **selecciona una imagen**, navegamos inmediatamente a `CreateCardFormScreen` pasándole la ruta del archivo local.
  * Si el usuario **cancela**, se le mostrará una pantalla de bienvenida sumamente estética y premium con:
    * Un fondo con el degradado superior de marca.
    * Un contenedor circular con el icono de agregar imágenes.
    * Título y descripción explicativa ("Diseña tus propias Word Cards").
    * Un botón grande de degradado violeta a índigo: **"Seleccionar Imagen de Galería"** para volver a intentar la selección en cualquier momento.

#### [NEW] [create_card_form_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_form_screen.dart)
* Crear la pantalla del formulario con el siguiente diseño y funcionalidad:
  * **AppBar**: Botón de retroceso, fondo transparente y título "Crear Tarjeta".
  * **Vista Previa de Imagen**: Un contenedor rectangular con la imagen local seleccionada (esquinas redondeadas de `16px` y sombra).
  * **Formulario**:
    * Campo de Palabra clave (`word`) - Requerido.
    * Campo de Pronunciación fonética (`phonetic`) - Requerido, ej: `/ˈɛpl/`.
    * Campo de Categoría (`category`) - Opcional, ej: `Sustantivo`, `B2 Level`.
    * Campo de Idioma (`language`) - Opcional, ej: `Inglés`.
    * Campo de Definición (`definition`) - Requerido, con soporte multilínea (altura de 3-4 líneas).
    * Campo de Frase de Ejemplo / Oración (`example_sentence`) - Opcional.
  * **Estilos del Formulario**: Inputs consistentes con `AppTheme` (relleno gris claro, esquinas redondeadas de `16px`).
  * **Lógica de Envío**:
    * Validar que los campos obligatorios estén completos.
    * Mostrar un estado de carga inmersivo en el botón (deshabilitando los campos y mostrando un spinner).
    * **Paso 1: Subir imagen a Supabase Storage**: Subir el archivo local al bucket público `word-images` con un nombre único basado en timestamp. Obtener su URL pública.
    * **Paso 2: Guardar Metadata en Supabase Database**: Insertar la fila en la tabla `word_cards` incluyendo el URL público de la foto, palabra, definición, fonética, categoría, frase e idioma.
    * **Paso 3: Actualizar Estado**: Invalidar el proveedor de Riverpod `wordCardsProvider` para que la app se actualice reactivamente en segundo plano.
    * **Paso 4: Feedback**: Mostrar un mensaje de éxito (Snackbar) y retornar a la pantalla principal.

---

## Verification Plan

### Automated Tests
* Ejecutar `flutter analyze` para garantizar que la importación de `image_picker` y las nuevas llamadas de Supabase estén libres de errores de compilación y lints.

### Manual Verification
1. Ir a la pestaña **Crear** (+): verificar que se abra el selector de imágenes de la galería automáticamente.
2. Cancelar la selección de galería: comprobar que la pantalla muestre el estado de bienvenida con el botón de "Seleccionar Imagen".
3. Elegir una imagen de la galería: verificar que se realice la transición limpia a la pantalla del formulario con la imagen seleccionada visible en el encabezado.
4. Llenar los campos obligatorios y opcionales (Palabra: "Flutter", Fonética: "/flʌtər/", Idioma: "Inglés", Categoría: "Framework", Definición: "Un SDK de Google para desarrollo multiplataforma", Frase: "I love coding apps with Flutter").
5. Presionar el botón "Subir Tarjeta": verificar el indicador de carga.
6. Confirmar en el listado de tarjetas (`WordDetailScreen`) que la nueva tarjeta aparezca, mostrando la foto subida a Supabase, los tags dinámicos de "Framework" y "Inglés", y la frase de ejemplo abajo de la definición.
7. Ir a una conversación de chat, escribir "flutter" (o una palabra que use esa palabra), y verificar que al dar tap sobre ella, el pop-up rápido de chat muestre la imagen cargada y el botón "Open" nos dirija a la tarjeta creada en el scrolling.
