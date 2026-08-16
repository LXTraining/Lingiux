# Especificación Técnica: Panel de Detalles de Lección de Tres Secciones y Redirección Eco Interactiva 📑

Este documento detalla la implementación y arquitectura de la interfaz de pestañas segmentadas en el panel de detalles de lecciones (**BottomSheet**), así como la lógica de redirección directa al tocar las opiniones flotantes ("eco") en el feed principal.

---

## 🌿 1. Introducción y Requerimiento

El objetivo de esta mejora es enriquecer la interacción del mapa de aprendizaje (caminito ondulado) al unificar y categorizar el contenido de cada lección al momento de seleccionarla:
1.  **Panel de Detalles Multisección:** En lugar de mostrar una lista estática y extensa de información, el BottomSheet ahora organiza el contenido en tres pestañas interactivas: **General** (datos de autoría y objetivos), **Opiniones** (bandeja de comentarios de la comunidad) y **Ranking** (tabla de líderes con puntuaciones y tiempos).
2.  **Redirección Eco Táctil:** Los globos de comentarios flotantes ("comentarios eco") en el mapa ahora son botones interactivos. Al hacer tap en ellos, se despliega automáticamente el BottomSheet con la pestaña de **Opiniones** preseleccionada.

---

## 📂 2. Estructura de Archivos y Dependencias

Las modificaciones se concentran principalmente en la capa de presentación de la sección de inicio (feed):

```text
lib/
└── features/
    └── feed/
        └── presentation/
            └── screens/
                └── feed_screen.dart      <--- Contiene la vista FeedScreen, el método de 
                                               BottomSheet y los widgets del caminito.
```

### Librerías Utilizadas
*   **`flutter/material.dart`:** Utilizada para la estructura tridimensional del panel, segmentación de tabs, ScrollViews y listas con `CircleAvatar` y `ListTile`.
*   **`flutter/services.dart`:** Invoca `HapticFeedback.lightImpact()` y `HapticFeedback.mediumImpact()` para brindar respuestas físicas al cambiar de pestaña o abrir el panel.

---

## ⚙️ 3. Detalle de la Implementación Técnica

### A. Estructura Reactiva del BottomSheet con `StatefulBuilder`
Debido a que `showModalBottomSheet` se renderiza sobre un contexto flotante de `Navigator` independiente del estado directo de `FeedScreen`, se implementó un **`StatefulBuilder`** para permitir la reactividad y la alternancia de pestañas dentro del diálogo sin necesidad de reconstruir la pantalla entera:

```dart
showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (context) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        // Control de estado interno 'activeTab'
        // ...
      },
    );
  },
);
```

### B. Segmentación del Tab Bar (Pill Bar)
Diseñamos un tab bar con aspecto ovalado tipo pastilla (Pill):
*   **Contenedor Principal:** Con esquinas redondeadas (`BorderRadius.circular(16)`) y fondo gris translúcido suave (`AppColors.surfaceVariant.withValues(alpha: 0.45)`).
*   **Botones Segmentados:** Cada botón utiliza un `AnimatedContainer` con una duración de **180ms**. Cuando la pestaña está activa, el fondo cambia a blanco puro y proyecta una sombra paralela tenue (`BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: Offset(0, 2))`), simulando un botón tridimensional flotante.
*   **Alineación y Texto:** Cada botón incluye un icono representativo y texto descriptivo en fuente de tamaño 10 con peso seminegrita para conservar la jerarquía.

### C. Secciones Dinámicas del Panel
El panel cuenta con un `SizedBox` de altura fija de **180 píxeles** con física de rebote (`BouncingScrollPhysics`) para evitar que el BottomSheet crezca demasiado y tapar toda la pantalla, permitiendo un scroll limpio dentro de las pestañas:

1.  **Tab 0: General (`buildGeneralTab`)**
    *   Muestra el avatar del creador verificado y la caja `"¿Qué aprenderás?"` con descripción y bordes suavizados.
2.  **Tab 1: Opiniones (`buildCommentsTab`)**
    *   Carga la lista `lesson.comments`. Muestra la foto de perfil del usuario, su nombre, fecha simulada (`"hace 2 horas"`) y el texto de su comentario en cursiva suave.
    *   **Control de Seguridad:** Si la lección está bloqueada (`lesson.isLocked == true`), bloquea el acceso de los comentarios, desplegando un candado indicando que debe desbloquearse primero.
    *   **Control de Vacío:** Si la lección no tiene comentarios, despliega un placeholder limpio `"No hay comentarios aún"`.
3.  **Tab 2: Ranking (`buildRankingsTab`)**
    *   Muestra una tabla de líderes (Sophia Martinez, Liam Anderson, Emma Watson) simulada con medallas (🥇, 🥈, 🥉), fotos de perfil y estadísticas de rapidez (porcentaje de acierto y tiempo en segundos).
    *   **Control de Seguridad:** Si la lección está bloqueada, despliega un candado informativo de ranking restringido.

### D. Flujo de Redirección Directa desde el Globo Eco
1.  **Firma del BottomSheet Modificada:**
    Se añadió el parámetro opcional `initialTab` al método de apertura de detalles:
    ```dart
    void _showLessonDetailsBottomSheet(BuildContext context, Lesson lesson, {int initialTab = 0})
    ```
2.  **Detector de Gestos en la Feed:**
    El contenedor de la opinión de comentarios flotante (`EchoCommentsWidget`) en el caminito se envolvió en un widget `GestureDetector`:
    ```dart
    child: GestureDetector(
      onTap: () {
        _showLessonDetailsBottomSheet(context, lesson, initialTab: 1);
      },
      child: Container(
        // Contenido de opiniones eco
      ),
    )
    ```
    *   Esto permite que al tocar la píldora flotante se lance el BottomSheet pre-seleccionando la pestaña **1 (Opiniones)** de forma inmediata y automática.

---

## 🔄 4. Protocolo de Reversión (Desinstalación Completa)

Si se desea remover este sistema de pestañas y la redirección eco para volver al panel anterior con diseño estático, ejecute los siguientes pasos:

### Paso A: Revertir Firma en `feed_screen.dart`
1.  Abra [`feed_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/feed/presentation/screens/feed_screen.dart).
2.  Localice la declaración de `_showLessonDetailsBottomSheet` (línea ~649) y remueva el parámetro `{int initialTab = 0}` dejándola con la firma original:
    ```dart
    void _showLessonDetailsBottomSheet(BuildContext context, Lesson lesson) {
    ```
3.  Elimine las variables internas de pestañas y las funciones `buildTabButton`, `buildGeneralTab`, `buildCommentsTab`, y `buildRankingsTab`.

### Paso B: Revertir Cuerpo del BottomSheet
1.  Restaurar el contenido del builder de `showModalBottomSheet` eliminando `StatefulBuilder` y devolviendo el `Container` original con la estructura lineal (avatar, "¿Qué aprenderás?" e inicio de lección), tal como se describe en la documentación de reversión del MD de opiniones eco.

### Paso C: Remover GestureDetector del Globo Eco
1.  Busque el `GestureDetector` que envuelve el `Container` de `EchoCommentsWidget` (línea ~360).
2.  Remueva el widget `GestureDetector` y el callback `onTap` manteniendo el `Container` como el hijo directo del widget `Positioned`.
3.  Elimine el archivo de documentación [`implementacion_panel_pestanas_detalles_leccion_y_redireccion_eco.md`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/resources/mds_relevantes/implementacion_panel_pestanas_detalles_leccion_y_redireccion_eco.md).
