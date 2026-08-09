# Implementación de Tarjeta Flotante con Carrusel y Aura de Selección en el Cerebro Digital

Este documento detalla exhaustivamente el diseño, la lógica matemática, las transiciones de animación y la estructura de archivos de la tarjeta flotante de previsualización de vocabulario con soporte para gestos (Swipe) y el sistema de auras brillantes interconectadas en la pestaña **Comunidad** (Cerebro Digital).

---

## 🌿 1. Introducción y Requerimientos de Diseño

Para mejorar la interacción educativa y visual del Cerebro Digital de Lingiux, se desarrollaron dos funcionalidades integradas de alto impacto:

1.  **Aura Resplandeciente Dinámica:** El nodo de vocabulario seleccionado actualmente debe destacar visualmente del resto de la constelación mediante un aura brillante del color de su propia categoría y un anillo concéntrico blanco de foco. Al cambiar de nodo, esta luz debe apagarse en el nodo anterior y encenderse en el nuevo mediante una transición progresiva y suave (sin cortes instantáneos).
2.  **Tarjeta Flotante Glassmorphic Estática con Carrusel Interno:** Un popup inferior con desenfoque de cristal esmerilado que muestre la ayuda visual y textual de la palabra. Al deslizar el dedo (Swipe) horizontalmente sobre la tarjeta, se debe navegar cíclicamente a la siguiente o anterior palabra de la misma agrupación (familia/categoría), actualizando los textos y la imagen interna con una transición de empuje lateral y actualizando la iluminación en el lienzo. La tarjeta debe conservar una altura fija y no sufrir saltos de diseño.

---

## 🎨 2. Especificación Técnica de la Implementación

### A. Aura de Selección Transicional en el CustomPainter

Para lograr la transición suave de "apagado/encendido" del aura de luz entre nodos en movimiento:

1.  **Doble Ticker de Animación (`TickerProviderStateMixin`):**
    Originalmente, la pantalla usaba `SingleTickerProviderStateMixin` para el motor de físicas elásticas de los resortes. Al agregar un `AnimationController` para la transición de selección, Flutter arrojaba error de múltiples tickers. Se modificó el mixin del estado del widget a `TickerProviderStateMixin` para posibilitar múltiples controladores simultáneos.
2.  **Controlador de Transición de Selección (`_selectionAnimationController`):**
    Se agregó en `initState` un controlador con una duración de `220 milisegundos` y un escucha que gatilla el repintado del lienzo en cada frame:
    ```dart
    _selectionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        _repaintNotifier.requestRepaint();
      });
    ```
3.  **Matemática de Desvanecimiento Cruzado (Cross-fade):**
    Al seleccionar una nueva palabra, se almacena el ID del nodo actual en `_previousSelectedWordNodeId`, se actualiza `_selectedWordNode` con el nuevo nodo y se inicia la animación hacia adelante (`forward(from: 0.0)`).
    En el método `paint` del CustomPainter:
    *   **Nodo Seleccionado Activo:** El brillo y anillo blanco aumentan de opacidad proporcionalmente a `selectionAnimationValue` (de `0.0` a `1.0`).
    *   **Nodo Seleccionado Anterior:** Se desvanecen proporcionalmente a `1.0 - selectionAnimationValue` (de `1.0` a `0.0`).
4.  **Efecto de Neón Bloom en Canvas:**
    Se crearon dos capas de sombreado para simular luz real:
    *   *Capa Externa:* Un círculo de radio `radius + 12` con máscara de desenfoque de `12` y opacidad máxima de `35%`.
    *   *Capa Interna:* Un círculo central de radio `radius + 6` con máscara de desenfoque de `6` y opacidad máxima de `75%`.
    *   *Anillo Concéntrico:* Un círculo de radio `radius + 3` con un pincel blanco de grosor `2.2` que resalta los bordes.

### B. Tarjeta Flotante Glassmorphic de Altura Fija

1.  **Estructura Base en Stack:**
    Para lograr que la tarjeta permanezca estable e inmóvil mientras su contenido realiza transiciones internas, la tarjeta se estructuró de la siguiente forma:
    *   `Positioned` inferior con márgenes seguros.
    *   `ClipRRect` y `BackdropFilter` con `sigmaX: 20, sigmaY: 20` para simular cristal esmerilado translúcido premium sobre el fondo espacial de la app.
    *   `Stack` interno para posicionar el botón de cerrar (`x`) en la esquina superior derecha (`Positioned(top: 12, right: 12)`). Esto elimina el botón del flujo vertical y previene overflow de textos.
    *   `Container` con una altura estrictamente fija de `128px` y color de fondo blanco de baja opacidad (`Colors.white.withOpacity(0.30)`).
2.  **Gesto de Deslizamiento (Horizontal Swipe):**
    Se utiliza `GestureDetector(onHorizontalDragEnd: ...)` sobre la tarjeta para capturar el sentido de deslizamiento:
    *   `primaryVelocity! < 0` (Swipe izquierda): Llama a `_navigateToSiblingWord(true)` (siguiente palabra).
    *   `primaryVelocity! > 0` (Swipe derecha): Llama a `_navigateToSiblingWord(false)` (palabra anterior).
3.  **Transición de Carrusel Interno (`AnimatedSwitcher`):**
    Para simular el cambio de página interno, el contenido de la tarjeta se extrajo a `_buildPreviewCardContent(node)` y se envolvió en un `AnimatedSwitcher` con un `transitionBuilder` de tipo `SlideTransition` y `FadeTransition`:
    ```dart
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.08, 0.0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _buildPreviewCardContent(node),
    )
    ```
    *Nota:* El widget devuelto por `_buildPreviewCardContent` tiene asignada una clave única `ValueKey<String>(node.id)` para obligar a `AnimatedSwitcher` a correr la animación de deslizamiento cada vez que cambia la palabra seleccionada.

### C. Alineación y Formato del Contenido

*   **Alineación Centrada:** La tarjeta alinea verticalmente la imagen redondeada de la palabra (`86x86`) y la columna de texto al centro mediante `crossAxisAlignment: CrossAxisAlignment.center` y `mainAxisAlignment: MainAxisAlignment.center`.
*   **Letra Capital Automática:** En el renderizado de la palabra, la primera letra se capitaliza a mayúscula inline:
    ```dart
    card.word.isNotEmpty ? (card.word[0].toUpperCase() + card.word.substring(1)) : ''
    ```
*   **Gestión de Altura:** Si existe la categoría de la palabra, se dibuja su respectiva insignia (Badge) con su color y espaciado. Si no existe, no ocupa espacio vertical, manteniendo el título centrado.

---

## 📂 3. Estructura de Archivos

*   **Archivo Modificado:** [community_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/community/presentation/screens/community_screen.dart)
*   **Ubicación en el Proyecto:**
    ```text
    lib/
    └── features/
        └── community/
            └── presentation/
                └── screens/
                    └── community_screen.dart  <-- (Contiene la lógica de animación, gestos y dibujado del Canvas)
    ```

---

## 🛠 4. Librerías y Dependencias Utilizadas

Se mantuvieron las dependencias nativas para evitar inflar el tamaño de la aplicación y mantener el rendimiento gráfico puro:
1.  **`flutter/material.dart`:** Para el uso de `AnimatedSwitcher`, `BackdropFilter`, `GestureDetector`, `Stack`, y transiciones integradas.
2.  **`dart:ui`:** Para la aplicación del filtro de desenfoque de imagen (`ImageFilter.blur`).

---

## 🔄 5. Instrucciones para Revertir o Quitar la Funcionalidad

Si por requisitos técnicos o de diseño se desea revertir esta previsualización con carrusel y regresar a la navegación directa o desactivar el aura de selección:

### Paso 1: Revertir la declaración y dibujado del CustomPainter
En [community_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/community/presentation/screens/community_screen.dart), remueve los campos `previousSelectedWordNodeId` y `selectionAnimationValue` de la clase `VocabularyGraphPainter` y sus constructores, y en el método `paint` elimina la sección de dibujado de `isSelectedWord` y `isPreviousSelectedWord`.

### Paso 2: Revertir la acción de Tap en el nodo
Dentro del método `_handleNodeTap(GraphNode node)` (alrededor de la línea 670), restaura la navegación directa del nodo de palabra:
```dart
    } else if (node.type == 'word' && node.wordCard != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WordDetailScreen(selectedWord: node.wordCard!.word),
        ),
      );
    }
```

### Paso 3: Limpiar variables de animación y métodos helper
Elimina los métodos `_getSiblingWordNodes`, `_navigateToSiblingWord`, y `_selectWordNode`, deshazte del `_selectionAnimationController` en `initState`/`dispose`, y regresa el mixin de `_CommunityScreenState` a `SingleTickerProviderStateMixin`.
