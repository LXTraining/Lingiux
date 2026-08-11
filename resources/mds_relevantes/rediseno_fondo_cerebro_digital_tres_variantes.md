# Rediseño del Fondo de "Cerebro Digital" (Tres Variantes de Diseño)

Este documento detalla el proceso creativo, la fundamentación estética, la implementación de código y los detalles de reversión para las tres variantes de diseño del fondo y etiquetado explorados en la pantalla de **Comunidad (Cerebro Digital)** en **Lingiux**.

---

## 1. Contexto e Identificación del Problema

La pantalla de **Cerebro Digital** es una visualización interactiva basada en nodos elásticos de categorías, palabras, personas y nacionalidades. 

### El Diseño Original (Espacial/Oscuro)
Originalmente, esta pantalla fue concebida como un espacio estelar oscuro. Su fondo consistía en un degradado diagonal que nacía en la parte superior izquierda con colores vivos y descendía hasta una esquina inferior derecha pintada completamente en **`AppColors.darkBackground` (negro/violeta oscuro)**. 

**Problemas del Diseño Original:**
1. **Falta de consistencia:** El resto de la aplicación utiliza una interfaz de modo claro (fondos mayormente blancos/claros). Entrar a esta sección provocaba un salto de contraste incómodo para el usuario.
2. **La Mancha Negra:** El gradiente hacia negro en la esquina inferior derecha se sentía "sucio" y "pesado", rompiendo la armonía cromática y ocultando la legibilidad en esa zona.

Para resolver esto, exploramos e implementamos consecutivamente **tres soluciones de diseño de alto nivel**.

---

## 2. Las Tres Variantes de Diseño Desarrolladas

### Variante 1: Gradiente Diagonal Suave de Esquina a Esquina (Opción B)
* **Objetivo:** Conservar el aspecto colorido en todo el fondo pero eliminando la mancha oscura de la esquina inferior derecha.
* **Fórmula de Color:** Se eliminó la variable `AppColors.darkBackground`. El degradado pasó a transicionar limpiamente de forma diagonal desde Verde-Teal (`gradientBgStart`) con `0.45` de opacidad hasta Azul-Celeste (`gradientBgEnd`) con `0.45` de opacidad.
* **Diseño del Filtro:** Las cápsulas del carrusel de filtros se actualizaron a un estilo de "vidrio esmerilado claro" (Glassmorphism) con texto oscuro (`AppColors.onSurface`) para garantizar visibilidad sobre el degradado.
* **Código de Fondo Utilizado:**
  ```dart
  Positioned.fill(
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gradientBgStart.withValues(alpha: 0.45),
            AppColors.gradientBgEnd.withValues(alpha: 0.45),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ),
  ),
  ```

---

### Variante 2: Fondo Claro Consistente con Nodos de Alto Contraste (Opción A - Puro)
* **Objetivo:** Lograr una consistencia absoluta del 100% con las demás pestañas de la aplicación (como Inicio o Perfil).
* **Fórmula de Color:** El fondo se definió en color claro sólido (`AppColors.background`). En la cabecera se colocó el degradado sutil de `320px` de altura que va de Verde-Teal a Azul-Celeste y se desvanece por completo a transparente (`alpha: 0.0`), fundiéndose con el blanco de la pantalla.
* **Diseño de los Nodos:** Las etiquetas de texto de los nodos, al pasar a un fondo blanco, requirieron un rediseño radical:
  * El texto se cambió a oscuro (`AppColors.onSurface`).
  * En lugar de una caja negra, cada etiqueta se envolvió en un **badge blanco semi-translúcido redondeado** (`white.withValues(alpha: 0.90)`) con un **borde gris muy fino** (`AppColors.border`). Esto emula el estilo visual minimalista de herramientas líderes como Obsidian, Figma o Miro.
* **Código de Fondo Utilizado:**
  ```dart
  Positioned(
    top: 0,
    left: 0,
    right: 0,
    height: 320,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gradientBgStart.withValues(alpha: 0.45),
            AppColors.gradientBgEnd.withValues(alpha: 0.45),
            AppColors.gradientBgEnd.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    ),
  ),
  ```

---

### Variante 3: Aura Celeste Pastel a Pantalla Completa (Opción A Mejorada - SELECCIÓN FINAL)
* **Objetivo:** Evitar que el lienzo del cerebro digital se vea "completamente blanco y vacío" en la mitad inferior, pero sin llegar a saturar de color ni meter sombras oscuras.
* **Fórmula de Color:** Se extendió el contenedor del degradado a pantalla completa (`Positioned.fill`). Al final del degradado en el fondo, en lugar de desvanecer a transparente puro (blanco), se mantuvo un residuo de **azul celeste con 8% de opacidad (`alpha: 0.08`)**.
* **El Efecto Visual:** El fondo se percibe como una superficie con iluminación atmosférica. El 8% de celeste es casi imperceptible al ojo, eliminando la frialdad del blanco crudo, pero conservando la luminosidad y permitiendo que los badges claros y los nodos de colores destaquen de forma espectacular.
* **Código de Fondo Utilizado (Actual):**
  ```dart
  Positioned.fill(
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gradientBgStart.withValues(alpha: 0.45),
            AppColors.gradientBgEnd.withValues(alpha: 0.35),
            AppColors.gradientBgEnd.withValues(alpha: 0.08), // Aura celeste tenue
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    ),
  ),
  ```

---

## 3. Estructura y Archivos Afectados

El trabajo de rediseño del Cerebro Digital se concentró principalmente en una sola pantalla del módulo de comunidad.

```text
lingiux_app/
└── lib/
    └── features/
        └── community/
            └── presentation/
                └── screens/
                    └── community_screen.dart   <-- [MODIFICADO] Contiene la interfaz del lienzo y el CustomPainter del grafo.
```

---

## 4. Guía de Reversión y Configuración Manual de Variantes

Si en el futuro deseas cambiar entre cualquiera de las tres variantes descritas o volver al diseño estelar original, sigue las instrucciones correspondientes:

### Opción 1: Revertir al Diseño Original Espacial/Oscuro
1. Abre [community_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/community/presentation/screens/community_screen.dart).
2. Reemplaza el bloque del degradado del fondo (alrededor de la línea 708) por:
   ```dart
   Positioned.fill(
     child: Container(
       decoration: BoxDecoration(
         gradient: LinearGradient(
           colors: [
             AppColors.gradientBgStart.withValues(alpha: 0.55),
             AppColors.gradientBgEnd.withValues(alpha: 0.55),
             AppColors.darkBackground,
           ],
           begin: Alignment.topLeft,
           end: Alignment.bottomRight,
         ),
       ),
     ),
   ),
   ```
3. Reemplaza el dibujado de etiquetas del `VocabularyGraphPainter` (alrededor de la línea 1808) para volver al texto blanco con caja negra:
   ```dart
   final textSpan = TextSpan(
     text: node.label,
     style: TextStyle(
       color: Colors.white,
       fontSize: isCategory ? 11.0 : 8.5,
       fontWeight: isCategory ? FontWeight.bold : FontWeight.w600,
       fontFamily: 'Inter',
       shadows: const [
         Shadow(color: Colors.black87, offset: Offset(0, 1), blurRadius: 2.0),
       ],
     ),
   );
   // ...
   final bgRect = Rect.fromLTWH(textOffset.dx - 5, textOffset.dy - 1, textPainter.width + 10, textPainter.height + 2);
   canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(5)), Paint()..color = Colors.black.withValues(alpha: 0.45));
   ```

---

### Opción 2: Cambiar a la Variante 1 (Gradiente Diagonal Opción B)
Reemplaza el degradado de fondo en `community_screen.dart` por:
```dart
Positioned.fill(
  child: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.gradientBgStart.withValues(alpha: 0.45),
          AppColors.gradientBgEnd.withValues(alpha: 0.45),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
);
```

---

### Opción 3: Cambiar a la Variante 2 (Fondo Blanco Puro con Cabecera Acotada de 320px)
Reemplaza el degradado de fondo en `community_screen.dart` por:
```dart
Positioned(
  top: 0,
  left: 0,
  right: 0,
  height: 320,
  child: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.gradientBgStart.withValues(alpha: 0.45),
          AppColors.gradientBgEnd.withValues(alpha: 0.45),
          AppColors.gradientBgEnd.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
  ),
);
```
