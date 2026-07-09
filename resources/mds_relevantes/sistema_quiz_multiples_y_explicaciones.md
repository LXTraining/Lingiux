# Sistema de Auto-Quiz Múltiple y Explicaciones de Tarjetas (Lingiux)

Este documento detalla a nivel de diseño, arquitectura y código la implementación del sistema interactivo de **Auto-Quiz de 3 ejercicios** (Pregunta, Acomodar Palabras y Completar la Palabra) junto con el módulo de **Descripción/Explicación de Carta** y su transición animada.

---

## 📖 1. Descripción General del Sistema

El sistema permite que cada tarjeta mental de vocabulario contenga un mini-ejercicio interactivo configurable por el creador. Cuando el estudiante repasa las tarjetas en su mazo de exploración, se le presenta el ejercicio correspondiente. Al interactuar con los botones de respuesta, la tarjeta reacciona visualmente y auditivamente, revelando una explicación detallada sobre por qué la respuesta es correcta.

---

## 🎛️ 2. Los Tres Tipos de Ejercicio

### A. Pregunta (True / False)
*   **Funcionamiento**: Diseñado para que la frase de contexto sea una interrogación. El estudiante debe responder si la afirmación con respecto al vocabulario/imagen es correcta o no.
*   **Editor**: 
    *   Valida que la frase de ejemplo termine en `?`. De lo contrario, se muestra una advertencia.
    *   Permite seleccionar si la respuesta correcta es **Sí** o **No**.
*   **Resolución**: Muestra los botones Sí y No en la base de la tarjeta.

### B. Acomodar Palabras (Duolingo Style)
*   **Funcionamiento**: La frase de contexto se oculta de la tarjeta en su estado inicial, mostrándose únicamente el botón de reproducir audio. El estudiante debe escuchar la pronunciación y ordenar los chips de palabras en la base de la tarjeta en la posición correcta.
*   **Editor**:
    *   **Bloqueo**: Solo se habilita si existe una grabación de audio asociada a la carta.
    *   **Distractores**: Permite agregar de 1 a 3 palabras incorrectas para mezclarse con las palabras reales de la frase.
*   **Resolución**:
    *   Oculta el texto frontal y coloca el área de ensamblado (una caja punteada) **arriba** del botón de audio.
    *   Muestra un pool de chips (palabras reales + distractores mezclados de forma aleatoria) al fondo de la tarjeta.
    *   Tocar un chip del pool lo sube al área de ensamblado con un deslizamiento suave (`AnimatedSize`). Tocarlo en el área de ensamblado lo regresa al pool inferior.
    *   Al completar el orden, si es correcto se revela la frase original; si es incorrecto, muestra la retroalimentación y se reinicia después de 1.6 segundos.

### C. Completa la Palabra Faltante
*   **Funcionamiento**: En la frase de ejemplo se esconde una de las palabras (se sustituye por una línea continua `_____`). El estudiante debe seleccionar de una botonera de tres opciones cuál es la palabra faltante.
*   **Editor**:
    *   **Identificación Automática**: El sistema parsea la frase de ejemplo y extrae las palabras candidatas a ser ocultadas, excluyendo de forma obligatoria la palabra clave principal de la tarjeta (para evitar resolver el ejercicio de manera obvia).
    *   **Selector**: Ofrece un menú desplegable para elegir la palabra a ocultar.
    *   **Distractores**: Requiere agregar al menos 2 palabras incorrectas.
*   **Resolución**:
    *   Muestra la frase de ejemplo con la línea `_____` en lugar de la palabra elegida.
    *   Renderiza 3 opciones horizontales en la base (la palabra correcta + 2 distractores mezclados aleatoriamente).

---

## 📝 3. Descripción / Explicación de la Carta
*   **Objetivo**: Ofrecer una justificación gramatical o contextual de por qué la respuesta era correcta (ej: *"Los perros nunca son de pelaje azul, normalmente son cafés..."*).
*   **Editor**: Campo de texto multilínea opcional bajo la pestaña "Contenido".
*   **Almacenamiento**: Se guarda dentro del objeto JSON `canvas_design` bajo la propiedad `description` en la tabla `word_cards` de Supabase. Esto evita tener que alterar la base de datos SQL del servidor, manteniendo total compatibilidad hacia atrás.
*   **Animación de Revelado**: 
    *   Para evitar un corte brusco, la desaparición de los botones y la revelación de la explicación se realizan con un widget `AnimatedSwitcher` acoplado con transiciones `FadeTransition` (opacidad) y `SizeTransition` (altura).
    *   Toda la transición toma exactamente **350 milisegundos**.
    *   Si el usuario falla, la explicación se muestra durante **1.6 segundos** y luego los botones de respuesta regresan automáticamente mediante la misma animación para permitirle otro intento. Si acierta, la explicación queda fija en la tarjeta.

---

## 📁 4. Archivos Modificados

### 1. [create_card_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_screen.dart)
*   **Rol**: Pantalla contenedora de pasos para crear una tarjeta mental.
*   **Modificaciones**:
    *   Declaramos `_descriptionController` para controlar el campo de explicación de la carta y lo liberamos adecuadamente en el método `dispose()`.
    *   Pasamos este controlador en el constructor de `CardEditorWidget`.

### 2. [card_editor_widget.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/card_editor_widget.dart)
*   **Rol**: Interfaz interactiva de edición en tiempo real.
*   **Modificaciones**:
    *   **Botonera Cuadrada con Iconos**: Implementamos el método `_buildSquareTypeButton(...)` para cambiar las pestañas por botones cuadrados con iconos dinámicos y estados interactivos de bloqueo (con candado en la esquina superior derecha).
    *   **Lógica de Bloqueo**: Se desactivan los botones de ejercicio si no se ha ingresado la frase de ejemplo o si no se ha grabado el audio de voz.
    *   **Editor de Distractores**: Creamos el panel `_buildDistractorPanel()` que maneja una lista interactiva de chips (`Chip`) con botones de eliminación `(x)`. Añade distractores uno por uno a través de un `TextField` compacto validando duplicados y un límite máximo de 3.
    *   **Guardado**: Incorpora la explicación `'description'` al objeto JSON `quizConfig` transmitido al callback `onSave()`.

### 3. [word_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/screens/word_detail_screen.dart)
*   **Rol**: Tarjeta de exploración e interacción en el mazo de vocabulario.
*   **Modificaciones**:
    *   Convertido a `ConsumerStatefulWidget` para encapsular la lógica del ejercicio de cada tarjeta individualmente.
    *   **Chips de Palabras Propios (`_buildWordChip`)**: Reemplazamos `ActionChip` por contenedores personalizados para evitar que heredaran el texto/fondo blanco en algunos temas del celular.
    *   **Efecto Deslizar (`AnimatedSize`)**: Envuelve los Wraps de Acomodar Palabras para que las posiciones de los chips se muevan suavemente al cambiar de pool, simulando el comportamiento fluido de Duolingo.
    *   **AnimatedSwitcher + Explicación**: Implementamos `_buildDescriptionView(...)` y la lógica de transición animada al cambiar el estado `_isAnswered` para mostrar la descripción y reaparecer los botones tras 1.6 segundos en caso de error.

---

## 📦 5. Librerías y Dependencias Utilizadas

| Dependencia | Propósito en Lingiux |
| :--- | :--- |
| **`audioplayers`** | Usada para reproducir los sonidos de éxito (`correct.mp3`) y error (`incorrect.wav`). Se implementó un ciclo de vida dinámico llamando a `AudioPlayer()..play()` y liberando los recursos de memoria con `.dispose()` una vez que finaliza la reproducción para evitar fugas (*memory leaks*). |
| **`record`** | Utilizada en el editor para grabar las pistas de audio de voz en formato `.m4a` a través del micrófono del celular, con un tope automático de 15 segundos. |
| **`supabase_flutter`** | Cliente SDK de Supabase que permite subir los archivos de imagen/audio a los buckets de almacenamiento y realizar la inserción de las tarjetas mediante inserts SQL remotos. |
| **`flutter_riverpod`** | Gestor de estado que nos permite invalidar proveedores de datos (`wordCardsProvider`) tras guardar la tarjeta para que el feed se actualice al instante con la nueva información. |

---

## 💡 6. Buenas Prácticas de Rendimiento e Interfaz (UI/UX)

1.  **Protección de Memoria**: La instancia local de `AudioPlayer` creada al calificar una respuesta se auto-destruye en su callback `onPlayerComplete` evitando consumo innecesario de RAM en listas con múltiples tarjetas.
2.  **Prevención de Errores de Guardado**: Al validar los tipos de ejercicios en tiempo real en los botones de selección, impedimos que el usuario guarde una tarjeta con datos inconsistentes (ej: un ejercicio "Acomodar" sin audio o "Pregunta" sin frase).
3.  **Transición de Alturas**: Usar `SizeTransition` con `axisAlignment: -1.0` dentro del `AnimatedSwitcher` permite que el contenedor superior no dé un salto de altura brusco, acomodando el resto de elementos visuales de la tarjeta con extrema fluidez.
