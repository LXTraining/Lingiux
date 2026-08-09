# Evolución del Diseño de Nodos en el Cerebro Digital (Efecto Canica/Burbuja)

Este documento detalla la investigación de diseño, los conceptos gráficos, la lógica matemática y los fragmentos de código de las tres iteraciones creadas para los nodos del vocabulario (Cerebro Digital) en la pantalla de **Comunidad**. Proporciona el código de cada variante descartada para facilitar su recuperación en el futuro.

---

## 🌿 1. Introducción y Concepto General

Los nodos de la constelación mental eran originalmente círculos planos de color sólido. Para dotar a la aplicación de un aspecto más premium e interactivo, se planteó diseñar nodos que asemejen canicas físicas. Todas las implementaciones se programaron dentro del lienzo vectorial (`CustomPainter`) utilizando operaciones aceleradas por hardware en la GPU para mantener una tasa de refresco fluida de **60/120 Hz** sin sobrecargar la CPU.

---

## 🎨 2. Las Tres Iteraciones de Diseño (Conceptos y Código)

A continuación se presenta el código y la teoría de cada versión para su fácil intercambio o restauración futura.

### Iteración 1: Canica 3D Realista Clásica (Aspecto Windows Vista/Mac Aqua)
*   **Concepto:** Simula una esfera sólida tridimensional clásica. Utiliza un gradiente radial con el punto focal de iluminación desplazado hacia arriba y a la izquierda. El lado opuesto se degrada a un color oscuro para simular sombra volumétrica.
*   **Código en `paint`:**
    ```dart
    if (node.type == 'word') {
      // 1. Calcular punto focal desplazado arriba a la izquierda para el reflejo
      final focalPoint = node.position - Offset(radius * 0.28, radius * 0.28);
      final darkenedColor = Color.lerp(node.color, Colors.black, 0.38)!;
      
      // 2. Crear gradiente radial tridimensional
      final marblePaint = Paint()
        ..shader = ui.Gradient.radial(
          node.position,
          radius,
          [
            Colors.white.withValues(alpha: 0.95),  // Destello de luz caliente
            node.color.withValues(alpha: 0.90),    // Color de base
            darkenedColor.withValues(alpha: 0.95),  // Sombra tridimensional opuesta
          ],
          [0.0, 0.45, 1.0],
          ui.TileMode.clamp,
          null,
          focalPoint,
          0.0,
        );
      canvas.drawCircle(node.position, radius, marblePaint);

      // 3. Borde blanco translúcido
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(node.position, radius, borderPaint);

      // 4. Pintar reflejo especular
      final specularPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(focalPoint, radius * 0.18, specularPaint);
    }
    ```

---

### Iteración 2: Canica de Vidrio Glossy/Líquida (Refracción Inferior)
*   **Concepto:** Se enfoca en la refracción de luz interna del cristal (efecto líquido). El punto focal del gradiente se posiciona en la **parte inferior** del nodo, simulando que la luz sale por abajo. En la parte superior se dibuja un óvalo blanco difuminado con un gradiente vertical lineal, emulando el reflejo curvo del cristal.
*   **Código en `paint`:**
    ```dart
    if (node.type == 'word') {
      // 1. Gradiente radial con punto focal en la parte inferior para simular refracción de luz interna
      final bottomFocalPoint = node.position + Offset(0, radius * 0.40);
      final lightColor = Color.lerp(node.color, Colors.white, 0.50)!;
      final shadowColor = Color.lerp(node.color, Colors.black, 0.32)!;

      final basePaint = Paint()
        ..shader = ui.Gradient.radial(
          node.position,
          radius,
          [
            lightColor.withValues(alpha: 0.95),  // Refracción brillante interna abajo
            node.color.withValues(alpha: 0.90),  // Color medio
            shadowColor.withValues(alpha: 0.95), // Sombra en el borde superior
          ],
          [0.0, 0.55, 1.0],
          ui.TileMode.clamp,
          null,
          bottomFocalPoint,
          0.0,
        );
      canvas.drawCircle(node.position, radius, basePaint);

      // 2. Borde del contorno de cristal
      final rimPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(node.position, radius, rimPaint);

      // 3. Destello especular brillante y curvado en la parte superior (Glossy Highlight)
      final glossRect = Rect.fromCenter(
        center: node.position - Offset(0, radius * 0.35),
        width: radius * 0.95,
        height: radius * 0.48,
      );
      final glossPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(glossRect.left, glossRect.top),
          Offset(glossRect.left, glossRect.bottom),
          [
            Colors.white.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0.05),
          ],
        )
        ..style = PaintingStyle.fill;
      canvas.drawOval(glossRect, glossPaint);
    }
    ```

---

### Iteración 3 (Actual): Burbuja/Gema 2D Cartoon Juguetona
*   **Concepto:** Diseño plano-ilusionista (flat game art) alegre y amigable. Utiliza una base de color sólida y vibrante combinada con dos destellos blancos geométricos y nítidos: un óvalo blanco muy marcado arriba a la izquierda y otro micro-reflejo abajo a la derecha. Evita gradientes suaves para lograr el aspecto nítido de la ilustración vectorial.
*   **Código en `paint`:**
    ```dart
    if (node.type == 'word') {
      // 1. Cuerpo de color sólido y vibrante (Estilo 2D)
      final bodyPaint = Paint()
        ..color = node.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, radius, bodyPaint);

      // 2. Contorno blanco sutil
      final rimPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(node.position, radius, rimPaint);

      // 3. Destello especular principal muy blanco y marcado en la parte superior izquierda
      final glossPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85) // Resplandor blanco sólido para estilo caricatura
        ..style = PaintingStyle.fill;
      final glossCenter = node.position - Offset(radius * 0.30, radius * 0.30);
      canvas.drawCircle(glossCenter, radius * 0.26, glossPaint);

      // 4. Micro reflejo secundario en la parte inferior derecha para dar sensación de volumen 2D
      final minorGlossPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.40)
        ..style = PaintingStyle.fill;
      final minorGlossCenter = node.position + Offset(radius * 0.36, radius * 0.36);
      canvas.drawCircle(minorGlossCenter, radius * 0.12, minorGlossPaint);
    }
    ```

---

## 📂 3. Estructura de Archivos

*   **Archivo Modificado:** [community_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/community/presentation/screens/community_screen.dart)
*   **Estructura del Directorio:**
    ```text
    lib/
    └── features/
        └── community/
            └── presentation/
                └── screens/
                    └── community_screen.dart  <-- (Contiene la clase VocabularyGraphPainter y el método paint)
    ```

---

## 🛠 4. Librerías y Dependencias Utilizadas

El dibujado de canicas se resolvió de forma puramente nativa a nivel de framework, previniendo sobrecargas de rendimiento de paquetes de terceros:
1.  **`flutter/material.dart`:** Proveedor de las clases `Paint`, `Canvas` y los constructores de color.
2.  **`dart:ui`:** Importado asíncronamente como `ui` para resolver gradientes lineales y radiales nativos en los shaders de Flutter.

---

## 🔄 5. Instrucciones para Revertir o Cambiar de Estilo

### A. Para regresar a los Nodos Planos Originales
Si deseas descartar las burbujas o canicas y volver a los círculos completamente planos y uniformes, reemplaza el bloque `if (node.type == 'word')` dentro del bucle de dibujo de nodos del método `paint` en [community_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/community/presentation/screens/community_screen.dart) por el renderizado por defecto:

```dart
      // Relleno sólido plano original para todos los nodos
      final fillPaint = Paint()
        ..color = isCategory ? node.color : node.color.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, radius, fillPaint);

      // Borde del nodo plano original
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: isCategory ? 0.90 : 0.50)
        ..strokeWidth = isCategory ? 2.5 : 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(node.position, radius, borderPaint);
```

### B. Para alternar entre las Iteraciones 1, 2 o 3
Para cambiar el estilo visual de los nodos del vocabulario, localiza el condicional `if (node.type == 'word')` y copia íntegramente el bloque de código de la iteración que desees restaurar (especificados en la Sección 2 de este documento) reemplazando la lógica actual.
