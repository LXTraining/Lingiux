# Corrección de Distorsión de Avatares en el Cerebro Digital y Optimización de Rendimiento

Este documento detalla el diagnóstico, la solución matemática y el análisis de rendimiento de la optimización realizada en la pestaña **Comunidad** (Cerebro Digital / Constelación de Personas) de la aplicación Lingiux para evitar la distorsión visual de las fotos de perfil de los usuarios.

---

## 🌿 1. Introducción y Contexto

En el modo de visualización de **Personas** de la pantalla de Comunidad, los usuarios se muestran como nodos hijos interconectados con su respectiva bandera de nacionalidad (nodo padre) mediante una simulación de física de resortes elásticos. 

### El Problema Detectado
Las fotos de perfil de los contactos (los avatares de los nodos circulares) se mostraban ligeramente distorsionadas (estiradas horizontalmente o aplastadas verticalmente). Esto ocurría porque la imagen origen (que rara vez es un cuadrado perfecto) era pintada directamente sobre un área de destino circular (que es un cuadrado perfecto a nivel geométrico), forzando una deformación en su relación de aspecto original.

---

## 🎨 2. Especificación Técnica de la Solución (BoxFit.cover en Canvas)

Para lograr un comportamiento análogo al de `BoxFit.cover` dentro de un pintor personalizado (`CustomPainter`), tuvimos que modificar cómo se calcula la sección de la imagen origen que se lee y se dibuja sobre el lienzo (`Canvas`).

### Lógica Anterior (Con Distorsión)
Originalmente, el código definía la lectura de la imagen de la siguiente manera:
```dart
final src = Rect.fromLTWH(0, 0, loadedImage.width.toDouble(), loadedImage.height.toDouble());
final dst = Rect.fromCircle(center: node.position, radius: radius - 0.5);
canvas.drawImageRect(loadedImage, src, dst, Paint());
```
*   **src:** Rectángulo completo de la imagen original (por ejemplo, `300 x 400` en formato vertical).
*   **dst:** Cuadrado perfecto circunscrito al círculo de radio `radius` (por ejemplo, `24 x 24`).
*   **Resultado:** El renderizador estira los 300px a 24px en el eje X y los 400px a 24px en el eje Y, alterando las proporciones faciales.

### Lógica Nueva (Sin Distorsión)
Calculamos dinámicamente un cuadrado perfecto de recorte extraído del **exacto centro** de la foto:
1.  **Obtener el lado menor:** Identificamos la dimensión más pequeña de la imagen (`minSide = math.min(width, height)`). Si la imagen es de `300 x 400`, el lado menor es `300`.
2.  **Calcular desfases de centrado (Offsets):**
    *   `srcX = (width - minSide) / 2`
    *   `srcY = (height - minSide) / 2`
    *   Para la imagen de `300 x 400`, `srcX = 0` y `srcY = 50`.
3.  **Definir el rectángulo origen (`src`):** Generamos un cuadrado de `300 x 300` píxeles centrado en las coordenadas `(0, 50)`.
4.  **Dibujar:** Al mapear un cuadrado origen a un cuadrado de destino (`dst`), la proporción se mantiene en escala 1:1, logrando un recorte de tipo "cover" donde no hay distorsiones de caras.

```dart
final double srcWidth = loadedImage.width.toDouble();
final double srcHeight = loadedImage.height.toDouble();
final double minSide = math.min(srcWidth, srcHeight);
final double srcX = (srcWidth - minSide) / 2;
final double srcY = (srcHeight - minSide) / 2;

final src = Rect.fromLTWH(srcX, srcY, minSide, minSide);
final dst = Rect.fromCircle(center: node.position, radius: radius - 0.5);
```

---

## ⚡ 3. Análisis de Rendimiento: ¿Por qué no da lag?

La renderización fluida a 60 FPS o 120 FPS en dispositivos móviles exige que la función `paint` del `CustomPainter` se complete en menos de 8 milisegundos por fotograma. Esta optimización cumple con esa regla estricta debido a los siguientes factores de arquitectura:

1.  **Procesamiento Acelerado por GPU:**
    El recorte y escalado de la textura se realiza directamente en el procesador gráfico (GPU) utilizando el motor de renderizado de Flutter (Skia o Impeller). La GPU no duplica píxeles en la memoria RAM ni genera imágenes temporales; simplemente lee un subconjunto de coordenadas de textura en un solo paso de rasterización.
2.  **Cero Operaciones Pesadas en CPU:**
    Las operaciones aritméticas añadidas (`math.min`, restas y divisiones entre dos) se ejecutan en la CPU en pocos ciclos de reloj (menos de 1 nanosegundo).
3.  **Evitación de Decodificación Frame a Frame (Caché Activa):**
    La descarga y descompresión de las imágenes PNG o JPG es la tarea que genera caídas de rendimiento (lag). En nuestro sistema, la decodificación se ejecuta **una sola vez** asíncronamente mediante `ImageStreamListener` y se almacena en la caché en memoria `_profileImagesCache` como un objeto crudo de tipo `ui.Image`. El pintor gráfico solo lee esta caché, por lo que no hay consumo de red ni de disco durante el scroll.
4.  **Calidad de Filtrado Inteligente (`FilterQuality`):**
    Utilizamos `FilterQuality.high` (que aplica interpolación bicúbica al redimensionar) para que las fotos de tamaño grande se vean nítidas en los círculos pequeños. En teléfonos modernos, esta interpolación se realiza por hardware. 
    *   *Nota de rendimiento:* Si alguna vez se detecta ralentización en dispositivos de muy bajo rendimiento de hace más de una década, se puede cambiar a `FilterQuality.medium` o `FilterQuality.low` (filtrado bilineal) sin alterar las matemáticas del recorte.

---

## 📂 4. Estructura de Archivos y Código Modificado

*   **Ruta del Archivo Modificado:** [community_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/community/presentation/screens/community_screen.dart)
*   **Posición en el Proyecto:**
    ```text
    lib/
    └── features/
        └── community/
            └── presentation/
                └── screens/
                    └── community_screen.dart  <-- (Contiene la clase VocabularyGraphPainter y el CustomPainter)
    ```

---

## 🛠 5. Dependencias y Librerías Utilizadas

La solución no utiliza ninguna biblioteca externa adicional, protegiendo al proyecto de dependencias muertas o incrementos en el tamaño del APK/IPA:
1.  **`dart:math`:** Proveedor de la biblioteca nativa `math.min`.
2.  **`dart:ui`:** Acceso directo a `ui.Image` y `ui.FilterQuality` para pintar gráficos de bajo nivel de forma nativa.
3.  **`flutter/material.dart`:** Motor del framework de renderizado y el widget `CustomPainter`.

---

## 🔄 6. Instrucciones para Revertir o Quitar la Funcionalidad

Si por algún requerimiento de diseño o depuración necesitas revertir este cambio y regresar al dibujado completo distorsionado original, puedes hacerlo mediante dos vías:

### Vía Código (Manual)
En [community_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/community/presentation/screens/community_screen.dart), localiza el método `paint` dentro de `VocabularyGraphPainter` (alrededor de la línea 1380) y reemplaza la sección de `node.type == 'person'` con el siguiente código simplificado:

```dart
      } else if (node.type == 'person') {
        final avatarUrl = node.userProfile?['avatar_url'] as String? ?? '';
        final loadedImage = profileImages[avatarUrl];

        if (loadedImage != null) {
          canvas.save();
          final Path clipPath = Path()
            ..addOval(Rect.fromCircle(center: node.position, radius: radius - 0.5));
          canvas.clipPath(clipPath);

          // Código original sin recorte centrado
          final src = Rect.fromLTWH(0, 0, loadedImage.width.toDouble(), loadedImage.height.toDouble());
          final dst = Rect.fromCircle(center: node.position, radius: radius - 0.5);
          canvas.drawImageRect(loadedImage, src, dst, Paint());
          canvas.restore();
        }
```

### Vía Git (Terminal)
Si no has realizado más cambios y deseas descartar la corrección del archivo:
```bash
git checkout lib/features/community/presentation/screens/community_screen.dart
```
