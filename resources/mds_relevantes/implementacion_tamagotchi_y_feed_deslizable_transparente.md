# Documentación Técnica: FeedScreen Unificado con Tamagotchi Interactivo y Panel Deslizable Transparente

Este documento proporciona una guía de referencia exhaustiva sobre la arquitectura, el diseño visual, las físicas de gestos y las micro-animaciones implementadas en la pantalla de inicio (**FeedScreen**) de **Lingiux**. Detalla cómo se eliminó el panel divisorio tradicional para unificar la pantalla en un lienzo continuo y cómo se orquestó la interacción reactiva entre la mascota virtual y el caminito de lecciones.

---

## 1. Introducción y Concepto de Diseño

En la experiencia de usuario (UX) móvil moderna, las divisiones abruptas mediante tarjetas físicas o divisores restan fluidez y ensucian la interfaz. El objetivo de este desarrollo fue integrar dos secciones principales en un único lienzo transparente:
1. **La Sección de la Mascota (TamagotchiWidget):** Situada en la mitad superior de la pantalla. Es el elemento de juego interactivo que acompaña y motiva al usuario en su aprendizaje.
2. **La Sección del Camino de Aprendizaje (Lesson Path):** El caminito ondulado tradicional que se despliega desde la parte inferior.

En lugar de separar estas secciones mediante una tarjeta blanca tradicional, ambas flotan sobre el mismo fondo degradado premium de la aplicación. Al arrastrar hacia arriba el camino para ver más lecciones, este se expande suavemente para ocupar la pantalla completa. Durante este movimiento, la mascota realiza una transición fluida en tres dimensiones (opacidad, escala y posición) para desaparecer de la vista del usuario de manera natural.

---

## 2. Estructura y Arquitectura del Proyecto

El desarrollo está integrado bajo el módulo de **Feed** (pantalla de inicio) y respeta las directrices de Clean Architecture implementadas en **Lingiux**:

```text
lingiux_app/
├── lib/
│   ├── core/
│   │   └── constants/
│   │       ├── app_colors.dart            <-- Definición de colores de marca y degradados premium
│   │       └── app_strings.dart           <-- Textos de localización y navegación
│   └── features/
│       ├── feed/
│       │   └── presentation/
│       │       └── screens/
│       │           └── feed_screen.dart   <-- [Pantalla Modificada] Contiene la lógica del gesto y Tamagotchi
│       ├── vocabulary/
│       │   └── presentation/
│       │       └── screens/
│       │           └── word_detail_screen.dart
│       ├── home/
│       │   └── presentation/
│       │       └── screens/
│       │           └── home_screen.dart   <-- Controla el scaffold principal y el BottomNavigationBar
│       └── profile/
│           └── presentation/
│               ├── providers/
│               │   └── profile_provider.dart
│               └── screens/
│                   └── profile_screen.dart   <-- [Pantalla Modificada] Pestaña de lecciones con caminito punteado
└── resources/
    └── mds_relevantes/
        └── implementacion_tamagotchi_y_feed_deslizable_transparente.md <-- Este documento
```

---

## 3. Físicas y Gestos de Deslizamiento (Snapping y Transparencia)

Para implementar el deslizamiento de pantalla dividida sin recurrir a librerías externas pesadas, se utilizó el widget nativo de Flutter **`DraggableScrollableSheet`**.

### Físicas de Snapping
* **`initialChildSize: 0.55`:** El camino de lecciones ocupa exactamente el 55% de la altura disponible de la pantalla en reposo, dejando el 45% superior visible para el Tamagotchi.
* **`minChildSize: 0.55`:** Restringe el colapso del panel a un mínimo del 55%, impidiendo que se oculte por completo.
* **`maxChildSize: 1.0`:** Permite que el camino se expanda hasta cubrir el 100% de la altura de la pantalla (pantalla completa).
* **`snap: true` con `snapSizes: const [0.55, 1.0]`:** Fuerza que el panel salte automáticamente de forma amortiguada hacia una de las dos posiciones objetivo al soltar el dedo, evitando estados intermedios.

### Unificación de Fondo Transparente
Para lograr un lienzo unificado, se removieron todas las decoraciones del contenedor que envuelve a la hoja deslizable:
```dart
// Eliminación de color de fondo, bordes redondeados físicos y sombras divisoras
decoration: const BoxDecoration(
  color: Colors.transparent,
),
```
Esto permite que el `CustomPaint` de la línea del camino y los nodos de las lecciones se dibujen y desplacen directamente sobre el fondo del Scaffold de la pantalla.

### Resolución de Conflictos de Gestos (Gesto Integrado)
El mayor problema al anidar listas desplazables dentro de hojas deslizantes es el conflicto de scroll (hacer scroll en la lista vs. arrastrar la hoja). Esto se resolvió enlazando el **`ScrollController`** provisto por el builder del `DraggableScrollableSheet` al widget **`SingleChildScrollView`** que renderiza el caminito:
```dart
return SingleChildScrollView(
  controller: scrollController, // Enlace crucial
  physics: const ClampingScrollPhysics(), // Evita rebotes excesivos que interrumpan el arrastre
  padding: const EdgeInsets.only(top: 16, bottom: 40),
  child: Stack( ... ),
);
```
Cuando el panel está en `0.55`, cualquier scroll ascendente arrastra toda la hoja hacia arriba hasta alcanzar el tamaño `1.0`. Una vez que la hoja ocupa el `1.0` (pantalla completa), el mismo gesto pasa a desplazar el contenido del caminito de lecciones de forma continua y natural. Al regresar al tope superior del caminito (offset 0), el scroll descendente vuelve a arrastrar la hoja hacia abajo para colapsarla al `0.55`.

---

## 4. Mecánica de Desvanecimiento e Interpolación Reactiva

Dado que el fondo del caminito de lecciones es transparente, si el usuario desliza la hoja hacia arriba, las tarjetas de las lecciones flotarían sobre el Tamagotchi, generando un choque visual inaceptable. Para solucionarlo, implementamos una interpolación reactiva basada en la posición de la hoja.

### El Desafío de Rendimiento
Reconstruir toda la pantalla en cada frame del deslizamiento (para calcular la opacidad del Tamagotchi) causaría problemas de rendimiento y caídas de FPS, ya que la ruta de lecciones ejecuta operaciones pesadas de CustomPaint (`PathPainter`) y renderiza múltiples avatares y tarjetas.
Para optimizar esto, se aplicó el patrón de **Reconstrucción Selectiva**:
1. Convertimos `FeedScreen` en un **`ConsumerStatefulWidget`** y declaramos un `ValueNotifier<double>` para almacenar la extensión de la hoja.
2. Envolvemos el `DraggableScrollableSheet` en un **`NotificationListener<DraggableScrollableNotification>`** que actualiza el notificador en silencio sin disparar un `setState` completo en la pantalla:
   ```dart
   NotificationListener<DraggableScrollableNotification>(
     onNotification: (notification) {
       _sheetExtentNotifier.value = notification.extent;
       return true;
     },
     child: DraggableScrollableSheet( ... )
   )
   ```
3. Envolvemos únicamente al `TamagotchiWidget` en un **`ValueListenableBuilder<double>`**. De este modo, al deslizar, solo se reconstruye el sub-árbol de la mascota superior (unas pocas decenas de widgets simples), manteniendo el caminito de lecciones intacto.

### Fórmulas Matemáticas de la Interpolación
Definimos el rango de escala y traslación en base a la extensión actual de la hoja ($x$, donde $0.55 \le x \le 1.0$):

1. **Opacidad del Tamagotchi ($O$):**
   Debe ser $1.0$ cuando $x = 0.55$ y $0.0$ cuando $x = 1.0$.
   $$O(x) = \left( \frac{1.0 - x}{1.0 - 0.55} \right) = \frac{1.0 - x}{0.45}$$
   Asegurando los límites mediante clamp:
   $$O(x) = \text{clamp}\left(0.0, 1.0, \frac{1.0 - x}{0.45}\right)$$

2. **Escala del Tamagotchi ($S$):**
   Debe encogerse sutilmente de $1.0$ (visible) a $0.8$ (desvanecido) para simular profundidad 3D.
   $$S(x) = 0.8 + 0.2 \cdot O(x)$$

3. **Traslación Vertical ($T$):**
   Debe desplazarse hacia arriba hasta $50$ píxeles negativos para dar el efecto de ser empujado.
   $$T(x) = -50.0 \cdot (1.0 - O(x))$$

Código Dart implementado:
```dart
ValueListenableBuilder<double>(
  valueListenable: _sheetExtentNotifier,
  builder: (context, extent, child) {
    final tamagotchiOpacity = ((1.0 - extent) / (1.0 - 0.55)).clamp(0.0, 1.0);
    final scale = 0.8 + 0.2 * tamagotchiOpacity;
    final offset = -50.0 * (1.0 - tamagotchiOpacity);

    return Opacity(
      opacity: tamagotchiOpacity,
      child: Transform.translate(
        offset: Offset(0, offset),
        child: Transform.scale(
          scale: scale,
          child: const TamagotchiWidget(),
        ),
      ),
    );
  },
)
```

---

## 5. Construcción y Animaciones de la Mascota (TamagotchiWidget)

El `TamagotchiWidget` está diseñado para sentirse vivo y dinámico. Implementa múltiples capas y animaciones concurrentes de Flutter:

### 1. Sistema de Partículas y Brillo Ambiental
Utiliza círculos posicionados en un `Stack` con diferentes opacidades y tamaños, simulando motas de polvo mágico o burbujas que flotan alrededor de la mascota:
* Partícula izquierda: 16px de ancho, color `gradientBgStart` con opacidad del 20%.
* Partícula derecha: 24px de ancho, color `gradientBgEnd` con opacidad del 15%.
* Partícula superior: 12px de ancho, color blanco con opacidad del 30%.

### 2. Pedestal Metálico/Vidrio (Glassmorphism)
Una elipse horizontal que simula una superficie física en perspectiva tridimensional sobre la cual levita la mascota:
```dart
Container(
  width: 150,
  height: 20,
  decoration: BoxDecoration(
    borderRadius: const BorderRadius.all(Radius.elliptical(150, 20)),
    gradient: LinearGradient(
      colors: [
        Colors.white.withOpacity(0.4),
        Colors.white.withOpacity(0.1),
      ],
      ...
    ),
    border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withOpacity(0.15),
        blurRadius: 10,
        offset: const Offset(0, 6),
      ),
    ],
  ),
)
```

### 3. Animaciones Concurrentes de la Mascota
El estado `_TamagotchiWidgetState` utiliza un único `AnimationController` de 3 segundos en modo repetitivo con reversa continua (`repeat(reverse: true)`). A partir de él, se derivan tres animaciones usando curvas suaves (`Curves.easeInOut`):

* **Flotación (Levitación):**
  Un desplazamiento vertical armónico simple de 0 a -8 píxeles.
  ```dart
  _floatAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );
  ```
* **Respiración (Pulsación):**
  Una variación sutil en la escala del cuerpo de la mascota de 1.0 a 1.05.
  ```dart
  _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );
  ```
* **Órbita Futurista Rotativa:**
  Un anillo orbital elíptico inclinado de líneas punteadas que rota en 360 grados continuamente.
  ```dart
  _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
    CurvedAnimation(parent: _controller, curve: Curves.linear),
  );
  ```
  El anillo es dibujado en el lienzo usando un CustomPainter personalizado (`OrbitalRingPainter`) que inclina la matriz de transformación del canvas y calcula la trayectoria discontinua:
  ```dart
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(-0.25); // Inclinación en perspectiva 3D
  canvas.translate(-center.dx, -center.dy);
  // Cálculo de guiones usando path.computeMetrics()
  ```

### 4. Cuerpo de la Mascota (Huevo de Aprendizaje)
El cuerpo principal de la mascota se definió con un contenedor con esquinas redondeadas asimétricas para darle una silueta de huevo de caricatura:
```dart
borderRadius: const BorderRadius.only(
  topLeft: Radius.circular(45),
  topRight: Radius.circular(45),
  bottomLeft: Radius.circular(35),
  bottomRight: Radius.circular(35),
),
```
Se aplicó un degradado premium de tres colores (Morado, Rosa, Celeste) junto con un reflejo elíptico traslúcido en la parte superior izquierda (`white.withOpacity(0.35)`) para simular volumen y refracción de luz de vidrio brillante.

### 5. Interactividad Física y Retroalimentación Háptica
* **Gesto de Toque:** Envuelto en un `GestureDetector`. Al presionarse, activa una vibración física mediante la API del sistema: `HapticFeedback.mediumImpact()`.
* **Animación de Rebote:** Activa temporalmente un estado booleano `_isPressed`. Esto desencadena una reducción rápida de escala (`0.85`) manejada a través del widget nativo `AnimatedScale` con curvas elásticas, devolviendo una sensación táctil altamente interactiva y responsiva.
* **Mensajes Aleatorios:** El globo de diálogo actualiza su texto eligiendo de forma aleatoria un comentario divertido de una lista predefinida:
  ```dart
  final List<String> _speeches = [
    '¡Zzz... Lingui está soñando con verbos en inglés!',
    '¡Hola! Cada lección que completas me da energía.',
    '¡Mmm... creo que hoy es un gran día para practicar modismos!',
    '¡Brr! Siento que mi cascarón se agrieta con tu conocimiento.',
    '¡Hii! ¿Sabías que hablar un idioma nuevo abre un cerebro extra?',
    '¡Pst! Si completas tu racha de hoy, tendré un regalo para ti.',
  ];
  ```

---

## 6. Buenas Prácticas de Desarrollo de Software Aplicadas

1. **Reconstrucción Selectiva (Performance):** Uso de `ValueNotifier` y `ValueListenableBuilder` en lugar de `setState` general en `FeedScreen`. Esto evita el recalculo del `PathPainter` y la re-creación de los nodos del camino en cada pixel del desplazamiento.
2. **Uso de Widgets Nativos Amortiguados:** Se priorizó el uso de `AnimatedScale` y `TweenAnimationBuilder` sobre controladores complejos de animación donde era posible para mantener el código limpio y libre de memory leaks.
3. **Optimización Háptica y Animaciones No Bloqueantes:** El temporizador de retroalimentación de escala de rebote y el cambio de textos se ejecutan de manera asíncrona no bloqueante usando `Future.delayed` y respetando el estado de montaje del widget (`mounted`).
4. **Perspectiva con Operaciones de Canvas Limpias:** La perspectiva 3D del anillo orbital se logra mediante transformaciones matriciales locales encapsuladas (`canvas.save()` y `canvas.restore()`), lo que no interfiere con el pintado de otros elementos gráficos de la pantalla.
5. **Cero Dependencias Externas Adicionales:** Se implementaron gestos, físicas y animaciones complejas usando componentes 100% nativos del framework SDK de Flutter, previniendo problemas de compatibilidad y tamaño del bundle.
6. **Optimización Gráfica en Líneas Punteadas (PathPainter):** Para renderizar la línea discontinua del camino, en lugar de invocar `canvas.drawPath` en cada paso del bucle (lo cual multiplicaría los draw calls y degradaría el rendimiento de renderizado en pantallas de alta densidad), subdividimos la curva Bezier continua original del camino utilizando `PathMetrics` y agregamos todos los segmentos individuales en un solo objeto `Path` consolidado (`dashedPath`). Esto permite pintar el camino y su sombra en tan solo dos draw calls totales sobre el canvas, manteniendo al mismo tiempo un degradado lineal que fluye de forma continua entre cada guion.

---

## 7. Librerías y APIs Utilizadas

El desarrollo hace uso de las siguientes APIs estándar de Flutter y Dart:
* **`dart:math` (math):** Utilizado para el número `pi`, funciones trigonométricas en el dibujo de arcos orbitales, y la clase `Random` para la selección de diálogos aleatorios de la mascota.
* **`dart:async` (Timer):** Soporte para control de temporizadores en caso de necesitar loops adicionales de texto o retrasos controlados.
* **`package:flutter/services.dart` (HapticFeedback):** Acceso a los motores de vibración háptica físicos del dispositivo móvil (iOS / Android) para otorgar retroalimentación física a las pulsaciones táctiles.
* **`package:flutter_riverpod/flutter_riverpod.dart`:** Control de estado reactivo y escucha de los proveedores de datos de cartas y perfiles de usuario.

---

## 8. Guía de Reversión (Cómo desinstalar esta funcionalidad)

Si en el futuro se requiere deshacer esta funcionalidad y regresar al caminito de lecciones tradicional de pantalla completa con degradado simple (sin Tamagotchi ni físicas deslizantes), sigue estos pasos:

### Paso 1: Modificar las importaciones
Abre el archivo [feed_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/feed/presentation/screens/feed_screen.dart) y retira las importaciones de `dart:math` y `dart:async`:
```diff
-import 'dart:async';
-import 'dart:math' as math;
 import 'package:flutter/material.dart';
```

### Paso 2: Revertir la clase FeedScreen a ConsumerWidget
Cambia la clase `FeedScreen` y su cuerpo del Scaffold para restablecer la versión sin estado ni notificador:

```dart
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const gradientColors = [Color(0xFF7C3AED), Color(0xFF4F46E5)];

    final wordCardsAsync = ref.watch(wordCardsProvider);
    final cards = wordCardsAsync.value ?? [];
    final targetWord = cards.isNotEmpty ? cards.first.word : 'lingiux';

    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
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
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              leading: Builder(
                builder: (context) {
                  final profile = ref.watch(profileProvider).value;
                  final avatarUrl = profile?['avatar_url'] as String?;
                  final streakCount = profile?['streak_count'] as int? ?? 0;
                  final fullName = profile?['full_name'] ?? '';
                  final initials = fullName.isNotEmpty
                      ? fullName.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                      : 'LX';

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(homeScaffoldKeyProvider).currentState?.openDrawer();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12.0, top: 10.0, bottom: 10.0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          if (streakCount > 0)
                            Positioned(
                              right: -6,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B8B),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF6B8B).withOpacity(0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🔥', style: TextStyle(fontSize: 8)),
                                    const SizedBox(width: 1),
                                    Text(
                                      '$streakCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              title: const Text(AppStrings.navInicio),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                const double rowHeight = 150.0;
                const double nodeSize = 80.0;
                const double cardHeight = 76.0;
                final totalHeight = mockLessons.length * rowHeight + 40.0;

                final xFractions = [0.25, 0.65, 0.35, 0.70, 0.40, 0.65];

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 16, bottom: 40),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          size: Size(width, totalHeight),
                          painter: PathPainter(
                            xFractions: xFractions,
                            rowHeight: rowHeight,
                            itemCount: mockLessons.length,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        height: totalHeight,
                        child: Stack(
                          children: [
                            for (int index = 0; index < mockLessons.length; index++) ...[
                              Positioned(
                                top: (index * rowHeight + rowHeight / 2) - cardHeight / 2,
                                left: (xFractions[index % xFractions.length] < 0.5)
                                    ? (width * xFractions[index % xFractions.length]) + nodeSize / 2 + 10
                                    : 20,
                                right: (xFractions[index % xFractions.length] < 0.5)
                                    ? 20
                                    : (width - (width * xFractions[index % xFractions.length])) + nodeSize / 2 + 10,
                                child: _buildLessonCard(context, mockLessons[index], (xFractions[index % xFractions.length] < 0.5), cardHeight),
                              ),
                              Positioned(
                                left: (width * xFractions[index % xFractions.length]) - nodeSize / 2,
                                top: (index * rowHeight + rowHeight / 2) - nodeSize / 2,
                                child: LessonNode(
                                  lesson: mockLessons[index],
                                  size: nodeSize,
                                  onTap: () => _showLessonDetailsBottomSheet(context, mockLessons[index]),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Acceso Directo Flotante
          Positioned(
            right: -42,
            top: 140,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WordDetailScreen(selectedWord: targetWord),
                  ),
                );
              },
              child: Transform.rotate(
                angle: -0.06,
                child: Opacity(
                  opacity: 0.90,
                  child: Container(
                    width: 75,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.30),
                          blurRadius: 12,
                          offset: const Offset(-3, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 14,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Icon(
                              Icons.auto_awesome_outlined,
                              size: 24,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Paso 3: Borrar el código de soporte al final del archivo
Elimina por completo las clases `TamagotchiWidget`, `_TamagotchiWidgetState` y `OrbitalRingPainter` que se encuentran situadas al final del archivo [feed_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/feed/presentation/screens/feed_screen.dart).
