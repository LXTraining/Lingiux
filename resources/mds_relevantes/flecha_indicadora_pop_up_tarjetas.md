# 📐 Flecha Indicadora en Pop-up de Tarjetas: Centrado de Precisión y Animación Rotacional 3D

Este documento detalla la reingeniería y el diseño matemático implementados en el Pop-up de las tarjetas flippables dentro de los chats de **Lingiux**, añadiendo un indicador visual (flechita) en perspectiva 3D que apunta con exactitud al centro de la palabra seleccionada, acompañando el giro tridimensional del contenido sin perder la alineación.

---

## 📌 1. Contexto y Objetivos Visuales

En la pantalla de detalles de conversación (`ChatDetailScreen`), al hacer tap sobre cualquier palabra de un globo de mensaje, se despliega una tarjeta flotante (`FlippableCard`) mediante un `OverlayEntry`. Originalmente:
1.  **Falta de Enlace Visual**: La tarjeta aparecía suspendida sin ningún indicador o "cola" de diálogo, dificultando saber qué palabra exacta la había detonado.
2.  **Desalineación Inicial**: El pop-up no quedaba completamente centrado con respecto al eje de la palabra.
3.  **Incompatibilidad con Rotación 3D**: Si se ponía una flecha externa al contenedor giratorio, al voltear la tarjeta en 3D (para ver la traducción o definición trasera), la flecha no seguía el movimiento, rompiendo la sensación de que la carta es un objeto tridimensional sólido.

El objetivo fue diseñar un indicador triangular integrado que girara con la carta, apuntara siempre a la palabra y mantuviera una distancia geométrica simétrica.

---

## 🔍 2. Desafíos Técnicos y Resoluciones Matemáticas

La implementación requirió resolver cuatro desafíos complejos de alineación, maquetación y transformaciones espaciales:

### A. Corrección del Bug de Doble Centrado
En la primera aproximación, el Pop-up se mostraba desplazado significativamente hacia la derecha de la palabra. Al auditar el flujo de coordenadas entre la vista de burbujas y el manejador del pop-up, descubrimos lo siguiente:

1.  **Detección en la Burbuja (`message_bubble.dart`)**:
    Al presionar la palabra, el widget `_TappableWordState` ya calcula el punto medio de la palabra y lo envía en `globalPosition`:
    ```dart
    final Offset centerPosition = Offset(
      globalPosition.dx + box.size.width / 2, // Ya está centrado horizontalmente
      globalPosition.dy,
    );
    widget.onTap(widget.word, centerPosition, box.size);
    ```
2.  **Cálculo en la Tarjeta (`chat_detail_screen.dart`)**:
    En `_showWordCard`, volvíamos a sumar la mitad del ancho de la palabra (`wordSize.width / 2`), lo cual duplicaba el desplazamiento:
    ```dart
    // BUG ANTERIOR:
    final wordCenterX = globalPosition.dx + wordSize.width / 2; // Desfase acumulado a la derecha
    ```
*   **Solución**: Eliminamos la suma redundante y tomamos directamente `globalPosition.dx` como el centro real de la palabra (`wordCenterX = globalPosition.dx`), logrando que la tarjeta y la flecha se posicionen perfectamente sobre el eje central del texto.

---

### B. Cálculo Dinámico de la Flecha bajo Clamping
Cuando el usuario presiona una palabra en los extremos izquierdo o derecho de la pantalla, la tarjeta de 96px de ancho podría desbordarse. Para evitarlo, aplicamos un límite de seguridad (`clamp`) al inicio horizontal de la carta (`left`):
```dart
left = left.clamp(8.0, screenSize.width - cardWidth - 8);
```
Si la carta se bloquea en los márgenes de la pantalla, el centro de la palabra (`wordCenterX`) y el centro de la carta dejan de coincidir.

*   **Solución**: Calculamos la posición relativa de la flecha en la carta restando la coordenada `left` de la tarjeta del centro de la palabra (`wordCenterX`), aplicando un clamp interno para que la flecha nunca se dibuje encima de los bordes redondeados (radio de 20px) de las esquinas:
    ```dart
    final arrowLeft = (wordCenterX - left).clamp(16.0, cardWidth - 16.0);
    ```
De esta forma, cuando la carta queda estática contra el borde de la pantalla, la flecha se desliza de forma dinámica por su base superior/inferior para seguir apuntando exactamente a la palabra.

---

### C. Aislamiento de la Rotación 3D para Evitar Desalineación
La tarjeta flippable gira en el eje Y a 180 grados utilizando una matriz de perspectiva de Flutter:
```dart
final Matrix4 transform = Matrix4.identity()
  ..setEntry(3, 2, 0.002) // Perspectiva 3D
  ..rotateY(angle);
```
*   **El Problema**: Si envolvíamos toda la columna (Flecha + Carta) en la transformación 3D, al girar la carta 180 grados, la flecha (que estaba en una posición descentrada, ej: `arrowLeft = 20.0`) orbitaba en un círculo 3D alrededor del centro de la columna (`x = 48.0`), acabando en el extremo opuesto (`x = 76.0`) y desalineándose de la palabra en pantalla.
*   **La Solución (Rotación Separada)**:
    1. Dejamos el contenedor `Column` principal sin rotación (estático), manteniendo a la flecha y a la carta en sus respectivas posiciones horizontales correctas.
    2. Aplicamos la matriz de transformación `transform` por separado a la carta y al triángulo de la flecha.
    3. Para la flecha, definimos un punto de pivote **`Alignment.center`**. Al hacer esto, la flecha gira tridimensionalmente **sobre su propio eje de simetría vertical**, adelgazándose y girando sobre su base sin desplazarse un solo píxel hacia la izquierda o derecha en la pantalla.

---

### D. Corrección de la Asimetría del Espaciado Vertical
Cuando la tarjeta se dibujaba en la parte inferior de la palabra (debido a falta de espacio en la parte superior), se notaba visualmente más alejada de la palabra.

*   **Causa**: Al calcular la posición superior (`top`), sumábamos un margen de separación (`spacing = 8.0`). Dado que el primer widget de la columna en este modo es el propio triángulo indicador (altura de 8.0px), la flecha empezaba 8px más abajo del texto, creando una brecha vacía de 8px entre la palabra y la punta del triángulo.
*   **Solución**: Quitamos la separación extra cuando la carta se abre por debajo (`isBelow = true`), definiendo el inicio del pop-up directamente en el borde inferior de la palabra:
    ```dart
    top = globalPosition.dy + wordSize.height;
    ```
De este modo, el triángulo de 8px llena exactamente la distancia y la punta toca el contorno inferior del texto con total simetría.

---

## 💻 3. Código Fuente Detallado de la Implementación

Los cambios fueron concentrados en el archivo [chat_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart).

### A. Captura de Tap y Parámetros en `_showWordCard`
```dart
  void _showWordCard(String word, Offset globalPosition, Size wordSize) {
    _dismissOverlay();

    final cleanWord = word.replaceAll(RegExp(r"[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ']"), '');
    if (cleanWord.length < 2) return;

    final wordList = ref.read(wordCardsProvider).value ?? [];
    final hasCard = wordList.any((w) => w.word.toLowerCase() == cleanWord.toLowerCase());

    ref.read(audioServiceProvider).playTap();
    HapticFeedback.lightImpact();

    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 96.0;
    const cardHeight = 136.0;
    const spacing = 8.0;
    final safeAreaTop = MediaQuery.of(context).padding.top + kToolbarHeight;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    // globalPosition.dx ya es el centro calculado por la burbuja
    final wordCenterX = globalPosition.dx;
    double left = wordCenterX - cardWidth / 2;
    double top = globalPosition.dy - cardHeight - spacing;

    // Si no hay suficiente espacio arriba, mostrar debajo de la palabra
    bool isBelow = false;
    if (top < safeAreaTop + 8.0) {
      top = globalPosition.dy + wordSize.height; // Pegado al borde inferior del texto
      isBelow = true;
    }

    left = left.clamp(8.0, screenSize.width - cardWidth - 8);
    top = top.clamp(
      safeAreaTop + 8.0,
      screenSize.height - cardHeight - safeAreaBottom - 16.0,
    );

    // Calcular posición horizontal de la flecha con respecto al inicio de la carta
    final arrowLeft = (wordCenterX - left).clamp(16.0, cardWidth - 16.0);

    final cardController = FlippableCardController();

    _overlayEntry = OverlayEntry(
      builder: (_) => _OverlayEntrance(
        isBelow: isBelow,
        left: left,
        top: top,
        onDismiss: _dismissOverlay,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity!.abs() > 200) {
            final swipeRight = details.primaryVelocity! > 0;
            cardController.flip(swipeRight: swipeRight);
            HapticFeedback.selectionClick();
          }
        },
        child: FlippableCard(
          controller: cardController,
          isBelow: isBelow,
          arrowLeft: arrowLeft,
          front: _WordMiniCardFront(
            word: cleanWord,
            onTap: () {
              _dismissOverlay();
              // Navegar al detalle...
            },
          ),
          back: _WordMiniCardBack(
            word: cleanWord,
            onTap: () {
              _dismissOverlay();
              // Navegar al detalle...
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }
```

### B. Pintor del Indicador Triangular (`_ArrowPainter`)
Utilizamos un `CustomPainter` simple para dibujar una forma triangular sólida rellenando un `Path` cerrado. Los colores se toman de los extremos superior o inferior del degradado de la tarjeta para simular una sola pieza continua:
```dart
class _ArrowPainter extends CustomPainter {
  final Color color;
  final bool isBelow;

  _ArrowPainter({required this.color, required this.isBelow});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isBelow) {
      // Triángulo apuntando hacia ARRIBA (Card abajo de la palabra)
      path.moveTo(size.width / 2, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      // Triángulo apuntando hacia ABAJO (Card arriba de la palabra)
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

### C. Rotación Integrada en `FlippableCard`
Actualizamos el método `build` de `_FlippableCardState` para inyectar la columna del cuerpo y las flechas de forma que se aplique la misma matriz de rotación `transform` tanto a la tarjeta como a su flecha correspondiente:
```dart
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double angle = _animation.value * math.pi * _directionMultiplier;
        final bool showFront = angle.abs() < math.pi / 2;

        final Matrix4 transform = Matrix4.identity()
          ..setEntry(3, 2, 0.002) // 3D perspective
          ..rotateY(angle);

        final cardWidget = showFront
            ? widget.front
            : Transform(
                transform: Matrix4.identity()..rotateY(math.pi),
                alignment: Alignment.center,
                child: widget.back,
              );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isBelow) ...[
              // Flecha apuntando hacia arriba rotando sobre su propio centro
              Padding(
                padding: EdgeInsets.only(left: widget.arrowLeft - 6.0),
                child: Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: CustomPaint(
                    size: const Size(12, 8),
                    painter: _ArrowPainter(
                      color: const Color(0xFF7C3AED),
                      isBelow: true,
                    ),
                  ),
                ),
              ),
            ],
            // La tarjeta flippable rotando sobre su propio centro geométrico
            Transform(
              transform: transform,
              alignment: Alignment.center,
              child: cardWidget,
            ),
            if (!widget.isBelow) ...[
              // Flecha apuntando hacia abajo rotando sobre su propio centro
              Padding(
                padding: EdgeInsets.only(left: widget.arrowLeft - 6.0),
                child: Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: CustomPaint(
                    size: const Size(12, 8),
                    painter: _ArrowPainter(
                      color: const Color(0xFF5B21B6),
                      isBelow: false,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
```

---

## 🛠️ 4. Archivos Modificados e Impacto en la Aplicación

*   **`lib/features/chat/presentation/screens/chat_detail_screen.dart`**:
    *   Reescribimos la lógica de centrado en `_showWordCard`.
    *   Actualizamos la firma del widget de estado `FlippableCard` para aceptar `isBelow` y `arrowLeft`.
    *   Rediseñamos `_FlippableCardState.build` para acoplar la columna estática y aplicar rotación Y independiente al cuerpo de la tarjeta y a la flecha.
    *   Añadimos la clase auxiliar `_ArrowPainter` para pintar el triángulo vectorial con precisión milimétrica.

Este cambio tiene un **impacto nulo en el rendimiento** del chat. El cálculo de coordenadas y la representación de `CustomPaint` se resuelven de forma nativa e instantánea a nivel de GPU, manteniendo la experiencia de navegación suave en las conversaciones.
