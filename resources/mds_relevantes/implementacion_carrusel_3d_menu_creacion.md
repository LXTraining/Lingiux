# Implementación de Carrusel Circular 3D en Menú de Creación

Este documento detalla la arquitectura, el modelo matemático, la lógica de ordenamiento de profundidad (Z-Sorting) y el diseño estético aplicados en el nuevo componente del menú de creación en la aplicación Lingiux.

---

## 📂 Ubicación en el Proyecto y Archivos Modificados

La funcionalidad está integrada en el módulo de creación de tarjetas (`create_card`) en las siguientes rutas:

1. **Nuevo Componente Visual:**
   * [`lib/features/create_card/presentation/widgets/three_d_horizontal_carousel.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/three_d_horizontal_carousel.dart)
   * *Descripción:* Centraliza la captura de gestos del carrusel, el cálculo trigonométrico de coordenadas en 3D, el ordenamiento en pila y la animación de alineación (snapping).

2. **Integración en la Vista Principal:**
   * [`lib/features/create_card/presentation/screens/create_card_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_screen.dart)
   * *Descripción:* Reemplaza el menú estático original por el carrusel horizontal e invoca los callbacks para abrir cada flujo de creación.

3. **Limpieza de Recursos Obsoletos:**
   * *Archivo Eliminado:* `three_d_vertical_carousel.dart`
   * *Descripción:* Se depuró para evitar código duplicado o innecesario en la rama del proyecto.

---

## 🧮 Arquitectura Técnica y Modelo Matemático

Para replicar con total fidelidad el carrusel en 3D de la referencia, implementamos un motor gráfico tridimensional simplificado utilizando la API nativa de Flutter, prescindiendo de librerías externas de terceros para garantizar el máximo rendimiento (60/120 FPS constantes) y evitar dependencias innecesarias.

El carrusel utiliza una **órbita circular tridimensional** definida en los ejes $X$ (horizontal) y $Z$ (profundidad).

### 1. Cálculo de Posiciones (Trigonometría)
El ángulo general de la rueda se controla en radianes mediante la variable continua `_angle`. Para $N=3$ elementos, la posición angular individual de cada tarjeta $i$ se calcula como:

$$\text{itemAngle}_i = \text{\_angle} + i \times \frac{2\pi}{3}$$

A partir de este ángulo, determinamos las coordenadas unitarias en la órbita circular:
* **$x = \sin(\text{itemAngle}_i)$:** Define el desplazamiento en el eje horizontal de la pantalla. Un valor de $-1.0$ representa el extremo izquierdo y $1.0$ el extremo derecho.
* **$z = \cos(\text{itemAngle}_i)$:** Define la profundidad del objeto respecto a la pantalla. Un valor de $1.0$ representa el punto más cercano al usuario (frente/centro) y $-1.0$ el punto más alejado (fondo/atrás).

### 2. Transformaciones Proyectivas (Matriz 3D)
Con los valores de $x$ y $z$, aplicamos transformaciones visuales personalizadas en el widget `Transform` de cada tarjeta:
* **Perspectiva Real:** Modificamos el valor de proyección de perspectiva en la matriz de transformación con `setEntry(3, 2, 0.0016)` (el parámetro $M_{32}$ que deforma los bordes simulando una lente tridimensional).
* **Torsión Lateral (Eje Y):** Rotamos el elemento en el eje Y proporcional al desplazamiento horizontal para darle el efecto de inclinación sobre el cilindro: `rotateY(x * -0.42)`.
* **Escala por Profundidad:** La tarjeta se encoge a medida que viaja hacia atrás:
  $$\text{scale} = 0.80 + \frac{z + 1.0}{2.0} \times 0.20$$
  *(Varía proporcionalmente entre $0.80$ en el fondo y $1.0$ en el frente).*
* **Opacidad por Profundidad:** Los elementos traseros se desvanecen suavemente para no restar atención al elemento enfocado:
  $$\text{opacity} = 0.35 + \frac{z + 1.0}{2.0} \times 0.65$$
  *(Varía proporcionalmente entre $0.35$ en el fondo y $1.0$ en el frente).*
* **Inclinación de la Órbita:** Elevamos ligeramente los elementos del fondo en el eje vertical para dar el efecto de que el cilindro está visto desde una perspectiva cenital inclinada hacia abajo: `translateY = (1.0 - z) * -16.0`.

### 3. Z-Sorting (Ordenamiento de Profundidad en Stack)
El renderizado por defecto de un `Stack` en Flutter sigue el orden secuencial de la lista de hijos (el primer elemento en la lista se pinta primero y el último se dibuja encima de todos).

Para hacer que las tarjetas pasen **físicamente por detrás** de la tarjeta frontal al girar:
* Creamos una estructura helper `_SortedCard` que vincula el widget final con su profundidad calculada `z`.
* Antes de entregar la lista al `Stack`, ordenamos los elementos de menor a mayor `z`:
  ```dart
  sortedCards.sort((a, b) => a.z.compareTo(b.z));
  ```
* De esta manera, Flutter dibuja primero las tarjetas que se encuentran al fondo (con `z` negativo) y pinta al final la tarjeta que está al frente (con `z` cercano a `1.0`), logrando una superposición y solapamiento tridimensional realista.

---

## 🕹️ Captura de Gestos y Animación de Alineación (Snapping)

El carrusel es interactivo a través de un `GestureDetector` que cubre todo el contenedor:

* **Arrastre Libre:** Al detectar un gesto horizontal en `onHorizontalDragUpdate`, incrementamos o decrementamos el ángulo `_angle` en función de los píxeles desplazados (`details.primaryDelta`), escalados por el ancho de pantalla para ajustar la sensibilidad.
* **Alineación Automática (Snapping):** Al soltar el dedo (`onHorizontalDragEnd`), calculamos qué elemento está más cerca del frente (su ángulo `itemAngle` se aproxima a un múltiplo de $2\pi$).
  * Encontramos el índice entero más cercano:
    ```dart
    double segment = 2 * pi / 3;
    int closestIndex = (-_angle / segment).round();
    double targetAngle = -closestIndex * segment;
    ```
  * Disparamos un `AnimationController` con una curva de desaceleración (`Curves.easeOutCubic`) para transicionar el ángulo actual de la rueda hacia el `targetAngle`.
* **Navegación por Toque:** 
  * Si el usuario pulsa en una tarjeta que está en el fondo, calculamos la distancia angular más corta en la línea de enteros (`targetIndex++` o `targetIndex--`) y rotamos el carrusel suavemente para traerla al frente.
  * Si el usuario pulsa en la tarjeta que ya está centrada en el frente, se ejecuta su callback correspondiente para abrir la creación de la Carta, Lección o Relato.

---

## 🎨 Diseño Visual y Detalles de la Tarjeta

Las tarjetas imitan fielmente el estilo de tickets o tarjetas de selección premium mostradas en el video:

* **Desbordamiento Superior (3D Overflow):** 
  * La tarjeta principal se renderiza dentro de un `Stack` con `clipBehavior: Clip.none`.
  * Colocamos la ilustración/icono de forma absoluta `Positioned(top: 2)` sobresaliendo de los límites físicos de la tarjeta por arriba.
* **Características Internas:**
  * Cabecera con título principal en negrita y un badge en la parte inferior que denota la categoría de vocabulario o lectura con fondo traslúcido estilizado.
  * Dos filas descriptivas con iconos minimalistas para explicar el formato y objetivo de la opción.
  * Botón de acción estilo ticket plano en la base con bordes curvos de radio `14` y color de acento según el gradiente de la tarjeta.

---

## 🔄 Cómo Revertir los Cambios (Desinstalación)

En caso de que en el futuro se requiera volver a la fila de botones horizontales estándar, sigue estos pasos:

1. **Restaurar el layout original en `create_card_screen.dart`:**
   * Abre [`create_card_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_screen.dart).
   * Elimina el import del carrusel:
     ```dart
     import '../widgets/three_d_horizontal_carousel.dart';
     ```
   * En el método `build`, localiza el componente `ThreeDHorizontalCarousel(...)` y reemplázalo por el código original del `Row`:
     ```dart
     Row(
       children: [
         Expanded(
           child: _buildSelectionCard(
             context: context,
             title: 'Carta',
             subtitle: 'VOCABULARIO',
             icon: Icons.auto_awesome_motion_rounded,
             gradient: const [Color(0xFF815BF5), Color(0xFF5A45FF)],
             onTap: () {
               setState(() {
                 _currentStep = 0;
               });
             },
           ),
         ),
         const SizedBox(width: 12),
         Expanded(
           child: _buildSelectionCard(
             context: context,
             title: 'Lección',
             subtitle: 'CAMINOS',
             icon: Icons.map_rounded,
             gradient: const [Color(0xFFFF6B8B), Color(0xFFFF8E53)],
             onTap: () {
               Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (_) => const CreateLessonWizardScreen(),
                 ),
               );
             },
           ),
         ),
         const SizedBox(width: 12),
         Expanded(
           child: _buildSelectionCard(
             context: context,
             title: 'Relato',
             subtitle: 'LECTURAS',
             icon: Icons.auto_stories_rounded,
             gradient: const [Color(0xFF4FA4F4), Color(0xFF4CD9A3)],
             onTap: () {
               Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (_) => const StoryEditorScreen(),
                 ),
               );
             },
           ),
         ),
       ],
     ),
     ```

2. **Eliminar el archivo del widget:**
   * Borra permanentemente el archivo [`three_d_horizontal_carousel.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/three_d_horizontal_carousel.dart) del disco.
