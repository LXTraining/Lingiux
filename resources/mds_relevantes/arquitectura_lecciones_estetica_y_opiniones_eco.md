# Arquitectura de Estética de Lecciones, Imágenes de Fondo y Opiniones Eco

Este documento detalla la especificación técnica de las mejoras visuales implementadas en la pantalla de inicio (**FeedScreen**) de Lingiux. El rediseño optimiza el mapa de aprendizaje (caminito ondulado) mediante la integración de texturas de fondo en los botones, cápsulas de aislamiento para evitar el cruce de líneas, y opiniones dinámicas ("comentarios eco") en tiempo real con fotos de perfil de los usuarios.

---

## 1. Estructura del Proyecto y Archivos Afectados

Las modificaciones se concentran en la capa de presentación del feed principal, manteniendo una alta cohesión al encapsular los modelos de datos de pruebas locales dentro del mismo archivo para simplificar el flujo.

```text
lingiux_app/
├── lib/
│   └── features/
│       └── feed/
│           └── presentation/
│               └── screens/
│                   └── feed_screen.dart      <--- [MODIFICADO] Lógica del camino, píldoras visuales,
│                                                   LessonNode y EchoCommentsWidget
└── resources/
    └── mds_relevantes/
        └── arquitectura_lecciones_estetica_y_opiniones_eco.md <--- [NUEVO] Este documento técnico
```

---

## 2. Librerías y Dependencias Utilizadas

Para implementar estas características de manera reactiva, fluida y con rendimiento premium, se aprovecharon los siguientes módulos:

* **`flutter/material.dart`**: Provee el motor de renderizado y widgets fundamentales como `AnimatedSwitcher`, `SlideTransition`, `FadeTransition`, `ClipRRect`, `DecoratedBox` y `CircleAvatar`.
* **`dart:async`**: Utilizado para la clase `Timer`, la cual se encarga de disparar la transición periódica de las opiniones cada 4 segundos.
* **`flutter/services.dart`**: Permite el acceso a la API del sistema operativo para detonar vibraciones de retroalimentación física mediante `HapticFeedback.lightImpact()` y `HapticFeedback.mediumImpact()`.
* **`dart:math`**: Requerido por el pintor de curvas de Bezier (`PathPainter`) para los cálculos de inclinación de la línea discontinua y el cálculo trigonométrico de rotaciones.

---

## 3. Detalle de la Implementación Técnica

### A. Imagen de Fondo en `LessonNode`
Cada lección cuenta con un botón circular tridimensional (`LessonNode`). Para asociarle una imagen representativa sin opacar el gradiente temático que identifica la categoría:

1. **Campos del Modelo:** Se añadieron los campos opcionales `imageUrl` a la clase local `Lesson`.
2. **Fusión en `BoxDecoration`:** En el estado `_LessonNodeState`, se integró una `DecorationImage` dentro de la decoración de fondo del botón.
3. **Opacidad Controlada:** Se configuró el parámetro `opacity` en **`0.35`** y el ajuste `fit: BoxFit.cover`. Al estar la imagen por encima del degradado pero con baja opacidad, las dos capas se funden: el color del gradiente brilla desde atrás y la imagen aporta textura temática de fondo.
4. **Conservación de Estados:**
   * Si la lección está bloqueada (`isLocked: true`), la propiedad `image` es nula y el botón se renderiza con una paleta de grises planos y un icono de candado.
   * Si la lección está desbloqueada, el icono característico (ej. comida, viajes) se dibuja en el centro en color blanco con sombras para maximizar el contraste sobre la imagen.

---

### B. Comentarios "Eco" Dinámicos con Avatares
La característica de opiniones emula la interactividad social de los "comentarios eco" de las historias de Instagram:

1. **Clase `LessonComment`:** Define la estructura de cada opinión:
   ```dart
   class LessonComment {
     final String text;      // Contenido del comentario
     final String userName;  // Nombre del usuario
     final String? avatarUrl;// Foto de perfil del usuario
     
     const LessonComment({
       required this.text,
       required this.userName,
       this.avatarUrl,
     });
   }
   ```
2. **Ciclo Periódico:** El widget `EchoCommentsWidget` utiliza un `Timer.periodic(const Duration(seconds: 4), ...)` para alternar de forma cíclica entre los comentarios de la lección modificando un índice reactivo.
3. **Transición Elástica (Curves.easeOutBack):** Para dar la sensación de que el comentario sube con un rebote de muelle/resorte elástico, se combinó `AnimatedSwitcher` con un constructor de transiciones personalizado:
   * **Desplazamiento:** Un `SlideTransition` desplaza el comentario verticalmente desde abajo (`Offset(0.0, 1.2)`) hacia su posición neutral (`Offset.zero`) usando una curva `Curves.easeOutBack`.
   * **Desvanecimiento:** Un `FadeTransition` altera la opacidad de `0.0` a `1.0` de forma simultánea.
4. **Renderizado del Globo de Comentarios:**
   * Cada comentario se renderiza como una fila (`Row`) alineada al centro.
   * **Avatar Mini:** Un `CircleAvatar` con un diámetro estricto de **14 píxeles** (borde blanco de 0.8px y sombra tenue) que carga la foto del usuario desde Unsplash.
   * **Texto Enriquecido (`Text.rich`):** Muestra el nombre del usuario en negrita y fuente color oscuro (`AppColors.onSurface`), seguido de la opinión en cursiva con un tono grisáceo para darle jerarquía.
   * **Sistema de Bloqueo:** Si la lección está bloqueada, en lugar del avatar del usuario se renderiza un candado de seguridad (`Icons.lock_rounded`) dentro de un círculo gris, y el texto muestra "Opiniones bloqueadas 🔒".

---

### C. Distribución Vertical Centrada y Cápsulas de Aislamiento
En lugar de ubicar un cuadro flotante grande al costado del botón, los datos se dispusieron de manera vertical para mantener la ligereza en pantalla. Sin embargo, esto causaba que la línea punteada del camino pasara justo por encima de los textos, haciéndolos ilegibles.

Para solucionarlo, se implementaron **Cápsulas de Aislamiento Visual**:

1. **Cápsula Superior:**
   * Situada arriba del botón circular.
   * Contiene la bandera del idioma, la categoría (ej. `🇺🇸 BÁSICO 1`) y el título de la lección en negrita de 12px.
2. **Cápsula Inferior:**
   * Situada abajo del botón circular.
   * Contiene únicamente el widget dinámico `EchoCommentsWidget`.
3. **Bloqueo del Fondo:** Ambas cápsulas están envueltas en un `Container` con fondo blanco de alta opacidad (`Colors.white.withOpacity(0.95)`), bordes sutiles y sombra paralela. Esto genera un "backplate" o máscara opaca física: la línea del camino se dibuja en el fondo, pero desaparece visualmente al pasar por debajo de la cápsula y vuelve a salir desde el extremo opuesto.
4. **Algoritmo de Límites Horizontales (`clamp`):**
   Debido a que el camino serpentea, algunos nodos quedan muy pegados a los bordes de la pantalla. Para evitar que las cápsulas anchas se corten, la coordenada horizontal se calcula dinámicamente:
   ```dart
   final double boxLeft = (centerX - boxWidth / 2).clamp(12.0, width - boxWidth - 12.0);
   ```
   Este asegura que, sin importar qué tan a la izquierda o derecha esté la curva del camino, las cápsulas se desplazarán automáticamente hacia adentro para mantenerse a 12px del borde del dispositivo.

---

### D. Centrado e Incremento de Espaciado (rowHeight)
1. **Centrado del Origen:** Se modificaron las alineaciones horizontales del array `xFractions`. La primera lección (índice 0) se configuró en **`0.50`**, centrándola perfectamente en la pantalla justo debajo del Tamagotchi.
2. **Prevención de Choques (rowHeight = 200.0):** Al añadir las cápsulas arriba y abajo del botón, el alto de fila original de `150.0` resultaba insuficiente, haciendo que la cápsula inferior del nivel superior colisionara con la cápsula superior del nivel inferior.
   * Se incrementó el alto de fila `rowHeight` a **`200.0`** píxeles.
   * Esto separa los nodos y garantiza un espacio libre de aproximadamente **`45 píxeles`** entre cápsulas de lecciones consecutivas, dando un aspecto amplio y limpio.

---

## 4. Protocolo de Reversión (Desinstalación Completa)

Si en el futuro se desea regresar al diseño de tarjeta lateral tradicional o eliminar las imágenes de los botones y el eco de comentarios, siga estos pasos:

### Paso A: Revertir las Propiedades del Modelo `Lesson`
1. Abra `feed_screen.dart`.
2. Diríjase a la declaración de `class Lesson` (línea ~1100).
3. Elimine los campos `final String? imageUrl;` y `final List<LessonComment> comments;`.
4. En el constructor de `Lesson`, remueva `this.imageUrl` y `this.comments = const [],`.
5. Elimine la clase `class LessonComment` por completo.

### Paso B: Revertir los Datos de Prueba `mockLessons`
1. Vaya a la definición del array `mockLessons`.
2. En cada una de las instancias de `Lesson`, elimine los parámetros `imageUrl` y `comments` para que vuelvan a tener solo la configuración original:
   ```dart
   const Lesson(
     id: '1',
     title: 'Frases de Supervivencia',
     category: 'Básico 1',
     flag: '🇺🇸',
     creatorName: 'Ana Smith',
     progress: 1.0,
     isLocked: false,
     icon: Icons.chat_bubble_rounded,
     gradient: [Color(0xFF815BF5), Color(0xFF5A45FF)],
   ),
   ```

### Paso C: Quitar la Imagen del Botón `LessonNode`
1. Vaya al widget `LessonNode` (en `_LessonNodeState` línea ~770).
2. Localice la propiedad `image` dentro de `BoxDecoration` del `Container` del botón.
3. Elimine por completo la línea del parámetro `image`:
   ```dart
   // Elimine esto:
   image: !isLocked && lesson.imageUrl != null && lesson.imageUrl!.isNotEmpty
       ? DecorationImage(
           image: NetworkImage(lesson.imageUrl!),
           fit: BoxFit.cover,
           opacity: 0.35,
         )
       : null,
   ```

### Paso D: Reconstruir la Tarjeta Lateral `_buildLessonCard`
1. Vuelva a agregar el widget de tarjeta lateral que eliminamos, situándolo arriba de `class EchoCommentsWidget`:
   ```dart
   Widget _buildLessonCard(BuildContext context, Lesson lesson, bool isLeft, double cardHeight) {
     final isLocked = lesson.isLocked;
     return Container(
       height: cardHeight,
       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
       decoration: BoxDecoration(
         color: isLocked ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.85),
         borderRadius: BorderRadius.circular(20),
         border: Border.all(
           color: isLocked ? AppColors.border.withOpacity(0.4) : AppColors.border.withOpacity(0.8),
           width: 1,
         ),
         boxShadow: [
           BoxShadow(
             color: Colors.black.withOpacity(0.015),
             blurRadius: 6,
             offset: const Offset(0, 3),
           ),
         ],
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text(lesson.flag, style: const TextStyle(fontSize: 12)),
               const SizedBox(width: 4),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                 decoration: BoxDecoration(
                   color: isLocked ? Colors.grey.shade200 : lesson.gradient[0].withOpacity(0.12),
                   borderRadius: BorderRadius.circular(6),
                 ),
                 child: Text(
                   lesson.category.toUpperCase(),
                   style: TextStyle(
                     color: isLocked ? Colors.grey.shade600 : lesson.gradient[0],
                     fontSize: 8,
                     fontWeight: FontWeight.bold,
                     letterSpacing: 0.5,
                     fontFamily: 'Inter',
                   ),
                 ),
               ),
             ],
           ),
           const SizedBox(height: 4),
           Text(
             lesson.title,
             maxLines: 1,
             overflow: TextOverflow.ellipsis,
             style: TextStyle(
               color: isLocked ? Colors.grey.shade600 : AppColors.onSurface,
               fontSize: 13,
               fontWeight: FontWeight.bold,
               fontFamily: 'Inter',
             ),
           ),
           const SizedBox(height: 2),
           Text(
             'Por ${lesson.creatorName}',
             style: TextStyle(
               color: isLocked ? Colors.grey.shade500 : AppColors.onSurfaceMuted,
               fontSize: 10,
               fontWeight: FontWeight.w500,
               fontFamily: 'Inter',
             ),
           ),
         ],
       ),
     );
   }
   ```
2. Elimine la clase `EchoCommentsWidget` completa.

### Paso E: Reestablecer el Alto de Fila, Alineación de Inicio y Posicionados en la Hoja
1. En la parte superior de la hoja de scroll (línea ~227), cambie el alto de fila y el tamaño de tarjeta de vuelta a su valor original:
   ```dart
   const double rowHeight = 150.0;
   const double cardHeight = 76.0;
   ```
2. Reestablezca la fracción de la primera lección en `xFractions` (línea ~233):
   ```dart
   final xFractions = [0.25, 0.65, 0.35, 0.70, 0.40, 0.65];
   ```
3. En el `Stack` del listado de lecciones (línea ~260), reemplace las tres Positioned por el bucle original que colocaba la tarjeta al lado del nodo:
   ```dart
   for (int index = 0; index < mockLessons.length; index++) ...[
     // Tarjeta informativa de la lección
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
     // Nodo interactivo de la lección
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
   ```
