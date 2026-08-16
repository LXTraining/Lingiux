# Especificación Técnica: Configuración y Catálogo de Fondos en el Creador de Relatos 🎨📖

Este documento detalla la arquitectura, el diseño estético, la estructura del código y el proceso de reversión para la selección persistente de fondos/patrones dentro del creador de relatos (`StoryEditorScreen`) y su renderizado automático en el lector (`StoryReaderScreen`).

---

## 🌿 1. Introducción y Concepto de Diseño

En lugar de que el lector tenga un botón flotante para cambiar el fondo temporalmente, ahora la selección del diseño de fondo es parte de la **creación/edición del relato** (`StoryEditorScreen`). 

Cuando un usuario escribe un relato:
1.  Puede seleccionar el fondo predefinido o patrón que mejor acompañe la temática de su historia en un selector horizontal de vistas previas.
2.  El ID del tema se guarda en el registro de Supabase dentro de la columna `metadata` bajo la clave `theme_id`.
3.  Al abrir dicho relato para leerlo (`StoryReaderScreen`), la aplicación carga automáticamente el fondo guardado en la base de datos para ofrecer una experiencia temática de lectura.

### Catálogo Ampliado de Diseños:
*   **Pergamino (Clásico):** Gradiente crema con blobs melón y lavanda.
*   **Atardecer:** Gradiente romántico rosa/naranja con blobs rosa y naranja claro.
*   **Bosque Zen:** Gradiente relajante verde menta/esmeralda con blobs esmeralda y verde translúcido.
*   **Medianoche:** Modo oscuro premium pizarra profundo con blobs morado y cian.
*   **Cuadrícula Educativa 📐 [NUEVO]:** Patrón de cuadrícula de libreta escolar dibujado mediante un CustomPainter.
*   **Líneas de Libreta 📝 [NUEVO]:** Patrón de líneas horizontales rayadas con margen vertical rojo a la izquierda, simulando una libreta de notas tradicional.
*   **Constelación Estelar 🌌 [NUEVO]:** Modo oscuro profundo con 40 estrellas brillantes distribuidas uniformemente en base a una semilla matemática fija para evitar parpadeos en pantalla.

---

## 📂 2. Archivos Afectados en la Estructura

```text
lib/
└── features/
    └── lessons/
        └── presentation/
            ├── screens/
            │   ├── story_editor_screen.dart <--- [MODIFICADO] Agregado selector de tema y paso en metadata.
            │   └── story_reader_screen.dart <--- [MODIFICADO] Eliminada lógica local de temas, carga directa de metadata.
            └── widgets/
                └── story_background_widget.dart <--- [NUEVO] Contiene el modelo de datos, la lista global de temas, 
                                                       los CustomPainters y el widget contenedor.
resources/
└── mds_relevantes/
    └── implementacion_catalogo_fondos_relatos.md <--- [MODIFICADO] Documentación de la especificación técnica.
```

---

## ⚙️ 3. Detalles de la Implementación del Código

### A. Widget Modular de Fondo (`story_background_widget.dart`)

Centralizamos los temas y pintores en un archivo dedicado para evitar duplicidad de código.

```dart
class StoryBackgroundWidget extends StatelessWidget {
  final String themeId;
  final Widget child;

  const StoryBackgroundWidget({super.key, required this.themeId, required this.child});

  static const List<StoryTheme> themes = [ ... ];

  @override
  Widget build(BuildContext context) {
    final theme = themes.firstWhere((t) => t.id == themeId, orElse: () => themes.first);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: theme.gradientColors),
      ),
      child: Stack(
        children: [
          if (theme.patternType == PatternType.blobs) ...[ /* Blobs */ ],
          if (theme.patternType == PatternType.grid) Positioned.fill(child: GridPatternPainterWidget(...)),
          if (theme.patternType == PatternType.lines) Positioned.fill(child: LinesPatternPainterWidget(...)),
          if (theme.patternType == PatternType.stars) Positioned.fill(child: StarsPatternPainterWidget()),
          child,
        ],
      ),
    );
  }
}
```

---

### B. Selector en el Creador (`story_editor_screen.dart`)

Añadimos un listado horizontal táctil (`ListView.builder`) para que el creador del relato escoja visualmente el diseño antes de guardar el documento:

```dart
// Guardado en la base de datos
await storiesService.saveStory(
  creatorId: user.id,
  title: _titleController.text.trim(),
  content: _contentController.text.trim(),
  language: _selectedLanguage,
  difficulty: _selectedDifficulty,
  metadata: {
    'theme_id': _selectedThemeId,
  },
);
```

---

### C. Carga Automática en el Lector (`story_reader_screen.dart`)

En el `build` del lector, leemos la propiedad de la base de datos y envolvemos el `Scaffold` en el widget de fondo modular:

```dart
  @override
  Widget build(BuildContext context) {
    final activeThemeId = widget.story.metadata['theme_id'] as String? ?? 'parchment';
    final activeTheme = StoryBackgroundWidget.themes.firstWhere(
      (t) => t.id == activeThemeId,
      orElse: () => StoryBackgroundWidget.themes.first,
    );

    return StoryBackgroundWidget(
      themeId: activeThemeId,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar( ... ),
        body: ...
      ),
    );
  }
```

---

## 🔄 4. Protocolo de Reversión (Regresar a Diseño Fijo Único)

Si deseas eliminar la selección personalizada de fondo:

1.  **En el Creador (`story_editor_screen.dart`):**
    *   Elimine el `String _selectedThemeId = 'parchment'` del estado.
    *   Remueva la sección de código del `ListView.builder` etiquetada como `// Selector de Fondo`.
    *   Elimine el campo `'theme_id': _selectedThemeId` en la llamada a `storiesService.saveStory(...)`.
2.  **En el Lector (`story_reader_screen.dart`):**
    *   Remueva el envoltorio `StoryBackgroundWidget`.
    *   Pinte directamente el fondo de pergamino con el gradiente crema clásico y los blobs correspondientes directamente en el `Scaffold`.
3.  **En la estructura del proyecto:**
    *   Elimine el archivo [`story_background_widget.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/lessons/presentation/widgets/story_background_widget.dart).
