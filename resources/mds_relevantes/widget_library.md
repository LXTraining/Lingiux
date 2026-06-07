# Biblioteca de Widgets Nativos de Flutter en Lingiux

Este catálogo recopila los **widgets nativos de Flutter** que componen la interfaz de la aplicación. Está diseñado como una guía de referencia para comprender el propósito de cada widget oficial de Flutter, sus propiedades clave y cómo se aplican en la práctica en nuestro código.

---

## 1. Contenedores Estructurales y Diseño de Pantalla

### Scaffold
- **¿Qué es?:** Es el widget estructural básico de Material Design. Proporciona espacios predefinidos para elementos como la barra superior (`appBar`), la barra inferior (`bottomNavigationBar`), cajones de navegación (`drawer`) y el cuerpo principal (`body`).
- **Propiedades clave:** `appBar`, `body`, `bottomNavigationBar`, `backgroundColor`, `resizeToAvoidBottomInset`.
- **Cómo se usa en Lingiux:** Se usa como raíz en casi todas las vistas (`HomeScreen`, `ChatsListScreen`, `ChatDetailScreen` y `WordDetailScreen`) para definir la barra de navegación o el cuerpo con colores oscuros uniformes (`AppColors.background`).

### Stack y Positioned
- **¿Qué es?:** `Stack` permite apilar múltiples widgets hijos uno encima de otro (como capas). `Positioned` se utiliza únicamente dentro de un `Stack` para colocar y dimensionar sus elementos respecto a los bordes superior, inferior, izquierdo o derecho del contenedor.
- **Propiedades clave:**
  - `Stack`: `alignment`, `clipBehavior`.
  - `Positioned`: `top`, `bottom`, `left`, `right`, `width`, `height`.
  - `Positioned.fill`: Expande el widget hijo para rellenar todo el espacio disponible del `Stack`.
- **Cómo se usa en Lingiux:** 
  - En `_WordCard` para colocar círculos decorativos difusos detrás de los textos.
  - En `_WordMiniCard` para colocar la imagen de fondo con `Positioned.fill` y pintar encima las letras de la palabra y el botón.
  - En `_ChatListTile` para posicionar la insignia verde (`isOnline`) sobre la esquina inferior derecha del avatar circular.

### Container
- **¿Qué es?:** Widget de conveniencia que combina funciones comunes de pintura, posicionamiento y dimensionamiento. Permite definir márgenes, espaciado interno (*padding*), colores de fondo, bordes, esquinas redondeadas y transformaciones.
- **Propiedades clave:** `padding`, `margin`, `width`, `height`, `decoration` (`BoxDecoration`), `alignment`, `shape`.
- **Cómo se usa en Lingiux:** Se usa para crear los avatares circulares (`BoxShape.circle`), las cajas de texto de los botones inferiores, y los globos de mensajes en los chats aplicando degradados de color (`LinearGradient`) y bordes específicos en `BoxDecoration`.

### Padding
- **¿Qué es?:** Un widget que agrega espacio vacío alrededor de su hijo según los valores definidos por `EdgeInsets`.
- **Propiedades clave:** `padding`.
- **Cómo se usa en Lingiux:** Se usa de forma recurrente para separar textos de los bordes del teléfono y establecer márgenes consistentes sin necesidad de sobrecargar propiedades de `Container`.

### SizedBox
- **¿Qué es?:** Una caja de tamaño fijo. Se utiliza para forzar dimensiones específicas en un widget hijo o para crear espacios en blanco (separaciones horizontales o verticales) dentro de un `Column` o `Row`.
- **Propiedades clave:** `width`, `height`.
- **Cómo se usa en Lingiux:** Para insertar espacios constantes entre textos o elementos (ej. `const SizedBox(height: 12)`).

---

## 2. Listas y Desplazamientos (Scrolls)

### PageView
- **¿Qué es?:** Una lista deslizable donde cada elemento (página) ocupa toda la pantalla o el área asignada. Permite desplazarse de forma horizontal o vertical, comúnmente usado en carruseles o tutoriales.
- **Propiedades clave:** `scrollDirection` (`Axis.horizontal` o `Axis.vertical`), `controller` (`PageController`), `onPageChanged`, `physics`.
- **Cómo se usa en Lingiux:** En [word_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/screens/word_detail_screen.dart) configurado con `scrollDirection: Axis.vertical` para permitir al usuario navegar entre tarjetas de vocabulario deslizando el dedo hacia arriba o hacia abajo.

### ListView
- **¿Qué es?:** El widget de scroll lineal más utilizado. Renderiza una lista de widgets hijos uno tras otro. 
- **Variantes y propiedades clave:**
  - `ListView.builder`: Crea elementos dinámicamente solo cuando son visibles en pantalla, ahorrando RAM.
  - `ListView.separated`: Igual al builder, pero permite insertar un widget separador (línea divisoria, espacio) entre cada elemento.
  - Propiedades: `itemCount`, `itemBuilder`, `controller` (`ScrollController`), `physics`.
- **Cómo se usa en Lingiux:**
  - En `ChatsListScreen` mediante `ListView.separated` para añadir una línea tenue (`Divider`) entre chats.
  - En `ChatDetailScreen` mediante `ListView.builder` para renderizar de forma fluida el historial de burbujas de mensajes.

### SingleChildScrollView
- **¿Qué es?:** Una caja que permite scroll para un único widget hijo. Es muy útil cuando tenemos un diseño vertical que puede exceder el tamaño de la pantalla (como formularios o descripciones largas) evitando errores de desborde (*overflow*).
- **Propiedades clave:** `scrollDirection`, `physics`, `child`.
- **Cómo se usa en Lingiux:** En `_WordCard` envolviendo el texto de la definición de la palabra, permitiendo que definiciones muy largas puedan leerse completas haciendo scroll dentro del cuerpo de la tarjeta sin dañar el resto del diseño.

---

## 3. Interactividad y Gestos

### GestureDetector
- **¿Qué es?:** Widget que no tiene representación visual propia, pero detecta una gran variedad de gestos táctiles del usuario en la pantalla.
- **Propiedades clave:** `onTap`, `onDoubleTap`, `onLongPress`, `onTapDown`, `onTapUp`, `onTapCancel`.
- **Cómo se usa en Lingiux:**
  - En `_TappableWord` en el chat, usando `onTapDown` y `onTapUp` para rastrear las coordenadas de la palabra pulsada y lanzar el pop-up en la posición correcta del plano.
  - En `ChatDetailScreen` envolviendo toda la pantalla para quitar el pop-up de la palabra al hacer tap en cualquier área vacía.

### InkWell
- **¿Qué es?:** Similar a `GestureDetector`, pero añade un efecto visual interactivo propio de Material Design: una animación de propagación de ondas (*splash ripple effect*) en el punto de contacto. Requiere estar dentro de un widget `Material` para dibujar el efecto.
- **Propiedades clave:** `onTap`, `splashColor`, `borderRadius`.
- **Cómo se usa en Lingiux:** En `_ChatListTile` para dar una retroalimentación premium de ondas de color morado translúcido al presionar sobre cualquier conversación.

---

## 4. Estilos y Efectos Visuales

### ClipRRect
- **¿Qué es?:** Recorta a su widget hijo utilizando un rectángulo de bordes redondeados. Es la forma estándar en Flutter de redondear esquinas de imágenes u otros elementos rectangulares.
- **Propiedades clave:** `borderRadius`.
- **Cómo se usa en Lingiux:**
  - En la imagen central de las tarjetas en `_WordCard`.
  - En el fondo de imagen del pop-up en `_WordMiniCard` para asegurar que la imagen de Unsplash adopte esquinas de 16px o 20px sin salirse del contenedor principal.

### Wrap
- **¿Qué es?:** Un flujo que acomoda widgets hijos horizontal o verticalmente. A diferencia de `Row`, si los widgets exceden el ancho de la pantalla, `Wrap` automáticamente crea una nueva línea abajo, evitando el error de desbordamiento horizontal.
- **Propiedades clave:** `spacing` (espacio entre hijos), `runSpacing` (espacio entre filas), `alignment`.
- **Cómo se usa en Lingiux:** En `MessageBubble` para unir y pintar todas las palabras cliqueables (`_TappableWord`) en secuencia, garantizando que el texto del globo del chat se comporte como un párrafo continuo que fluye y se adapta al ancho de la pantalla.

### Opacity
- **¿Qué es?:** Un widget que hace que su hijo sea parcial o totalmente transparente.
- **Propiedades clave:** `opacity` (valores entre `0.0` para invisible y `1.0` para opaco).
- **Cómo se usa en Lingiux:** En `_WordMiniCard` con `opacity: 0.70` sobre la imagen para mezclarla de fondo con el degradado morado de la caja.

---

## 5. Entrada de Datos y Carga

### TextField
- **¿Qué es?:** Campo de texto para que el usuario escriba información utilizando el teclado del dispositivo.
- **Propiedades clave:** `controller` (`TextEditingController`), `maxLines`, `style`, `decoration` (`InputDecoration`), `onChanged`.
- **Cómo se usa en Lingiux:** En la barra inferior del chat (`_InputBar`) para capturar los mensajes escritos por el usuario, configurado con `maxLines: null` para permitir que el campo crezca verticalmente de forma dinámica si el usuario escribe un mensaje largo.

### CircularProgressIndicator
- **¿Qué es?:** Un indicador de progreso circular que gira de manera indeterminada para denotar que hay un proceso de carga en curso.
- **Propiedades clave:** `color`, `strokeWidth`.
- **Cómo se usa en Lingiux:** Como marcador de carga (*placeholder*) mientras se descargan las imágenes de red en `_WordCard`.

---

## 6. Animaciones

### AnimatedContainer
- **¿Qué es?:** Una versión del widget `Container` que anima gradualmente todos sus cambios de propiedades (color de fondo, tamaño, margen, bordes) a lo largo del tiempo sin necesidad de utilizar controladores de animación complejos.
- **Propiedades clave:** `duration`, `curve`, `decoration`.
- **Cómo se usa en Lingiux:** En `_TappableWord` para animar la aparición y desaparición suave del fondo coloreado cuando el usuario hace tap en una palabra del chat.

### AnimatedBuilder
- **¿Qué es?:** Un widget útil para crear animaciones personalizadas más complejas. Re-construye solo la porción de código necesaria de su árbol interno cuando se dispara el temporizador de una animación.
- **Propiedades clave:** `animation`, `builder`.
- **Cómo se usa en Lingiux:** En `_WordCardsSkeleton` para generar el efecto de pulso (reduciendo y aumentando la opacidad de los bloques de carga de `0.4` a `0.8` de forma cíclica y fluida).

---

## 7. Tabla Comparativa de Widgets Nativos

A continuación se resume dónde y para qué se usa cada widget nativo dentro de la arquitectura de la app:

| Widget Nativo | Categoría | Uso Principal en Lingiux | Propiedades más utilizadas |
| :--- | :--- | :--- | :--- |
| **Scaffold** | Estructural | Base del layout visual en pantallas principales. | `appBar`, `body`, `bottomNavigationBar` |
| **IndexedStack** | Navegación | Administrar pestañas principales en `HomeScreen`. | `index`, `children` |
| **Stack** | Layout | Superponer imágenes de fondo, degradados y badges. | `children`, `alignment` |
| **Positioned** | Layout | Ubicar insignias y capas flotantes en coordenadas. | `top`, `bottom`, `left`, `right` |
| **Container** | Layout / Estilo | Diseñar tarjetas con bordes, gradientes y sombras. | `decoration`, `padding`, `margin` |
| **Padding** | Layout | Generar espaciados consistentes entre textos. | `padding` |
| **SizedBox** | Layout | Insertar espacios fijos de separación horizontal/vertical. | `height`, `width` |
| **PageView** | Desplazamiento | Carrusel vertical táctil para deslizar las Word Cards. | `scrollDirection`, `controller`, `onPageChanged` |
| **ListView** | Desplazamiento | Listas optimizadas de chats e historial de burbujas. | `itemBuilder`, `itemCount`, `separatorBuilder` |
| **SingleChildScrollView** | Desplazamiento | Permitir el desplazamiento de definiciones extensas. | `child`, `physics` |
| **GestureDetector** | Interactividad | Capturar clics y coordenadas sobre palabras del chat. | `onTap`, `onTapDown`, `onTapUp` |
| **InkWell** | Interactividad | Efecto de rebote/ondas de Material en celdas de chat. | `onTap`, `splashColor` |
| **ClipRRect** | Estilo | Redondear las esquinas de imágenes cargadas de red. | `borderRadius` |
| **Wrap** | Layout | Flow para concatenar palabras en el globo de chat. | `spacing`, `runSpacing` |
| **Opacity** | Estilo | Modificar la transparencia de imágenes de fondo. | `opacity` |
| **TextField** | Entrada | Campo de escritura de mensajes con teclado móvil. | `controller`, `maxLines`, `decoration` |
| **AnimatedContainer** | Animación | Transición visual de color al pulsar palabras. | `duration`, `decoration` |
| **AnimatedBuilder** | Animación | Bucle continuo de opacidad para el skeleton loading. | `animation`, `builder` |
