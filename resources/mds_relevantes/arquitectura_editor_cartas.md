# Arquitectura de Diseño de Editores de Cartas Personalizables

Este documento detalla la estructura arquitectónica, patrones de diseño de sistemas y mejores prácticas recomendadas por profesionales para la implementación de un **Editor de Cartas Personalizable** en la aplicación **Lingiux**, permitiendo al usuario un nivel elevado de libertad creativa (estilo Canva, Figma o el editor de historias de Instagram).

---

## 1. El Concepto Fundamental: Separación de Estado y Representación

El pilar principal de un editor visual profesional es la **separación absoluta** entre los datos del lienzo y cómo se dibujan en la pantalla.

### 1.1. El Estado del Lienzo (Canvas JSON Document)
Una carta personalizada no se guarda en la base de datos como una imagen rígida mientras se edita; se almacena como un documento de configuración estructurado en formato JSON. Esto permite que los textos sigan siendo editables, que los elementos puedan moverse después de guardarse y que el consumo de almacenamiento sea mínimo.

#### Ejemplo conceptual del esquema de datos:
```json
{
  "canvas": {
    "width": 1080,
    "height": 1620,
    "background": {
      "type": "gradient",
      "colors": ["#1e293b", "#0f172a"],
      "angle": 45
    }
  },
  "layers": [
    {
      "id": "layer_img_001",
      "type": "image",
      "source_url": "https://supabase-storage.../dog.jpg",
      "transform": {
        "x": 240.0,
        "y": 450.0,
        "scale": 1.1,
        "rotation": 0.0,
        "z_index": 1
      }
    },
    {
      "id": "layer_txt_001",
      "type": "text",
      "content": "Dog",
      "style": {
        "font_family": "Inter",
        "font_size": 48.0,
        "color": "#ffffff",
        "alignment": "center"
      },
      "transform": {
        "x": 240.0,
        "y": 800.0,
        "scale": 1.0,
        "rotation": 0.0,
        "z_index": 2
      }
    }
  ]
}
```

---

## 2. La Arquitectura de Tres Capas del Editor

Para mantener un código limpio, modular y fácil de escalar, la estructura del editor se divide en tres capas de responsabilidad bien delimitadas.

```
┌────────────────────────────────────────────────────────┐
│                    CAPA DEL MODELO                     │
│  - Documento JSON (Estado en memoria con Riverpod)     │
│  - Comando de Pila (Historial de Deshacer / Rehacer)   │
└──────────────────────────┬─────────────────────────────┘
                           │ Flujo Unidireccional
                           ▼
┌────────────────────────────────────────────────────────┐
│                  CAPA DE INTERACCIÓN                   │
│  - Lienzo Interactivo (Viewport de Edición)             │
│  - Bounding Box (Marco de Selección con manejadores)   │
│  - Detección de Gestos (Hit Testing sobre coordenadas) │
└──────────────────────────┬─────────────────────────────┘
                           │ Al presionar "Guardar"
                           ▼
┌────────────────────────────────────────────────────────┐
│                   CAPA DE EXPORTACIÓN                  │
│  - Rasterización (Renderizado Off-Screen de Alta Res)  │
│  - Generación de Archivo Final (PNG / WebP)            │
│  - Subida a Supabase Storage y Base de Datos (jsonb)   │
└────────────────────────────────────────────────────────┘
```

### 2.1. Capa del Modelo (State & Command Engine)
Esta capa gestiona los datos en memoria. Para implementar funcionalidades esenciales como **Deshacer (Undo)** y **Rehacer (Redo)**, se utiliza el **Patrón Command**.

* **Pila de Estados:** En lugar de mutar el JSON en caliente, cada cambio (mover elemento, cambiar color, escribir texto) se encapsula en una clase "Action/Command".
* **Historial:** Se mantienen dos listas en memoria (`undoStack` y `redoStack`). Al realizar una acción, se inserta en `undoStack` y se limpia `redoStack`. Al presionar el botón "Deshacer", se revierte el último cambio y se pasa a la pila de rehacer.

### 2.2. Capa de Interacción (Viewport & Gestures)
Es la cara visible del editor, encargada de renderizar la previsualización interactiva.
* **Marco de Selección (Bounding Box):** Cuando el usuario toca un elemento, el sistema dibuja una caja con manejadores de control en las esquinas y bordes. Tocar estos manejadores permite redimensionar o rotar el elemento.
* **Matrices de Transformación:** Para permitir el arrastre libre, pellizco para escalar y rotación con dos dedos, los elementos visuales se transforman aplicando matrices matemáticas bidimensionales (afines), garantizando que las animaciones y el arrastre corran a 60-120 FPS asistidos por la GPU.
* **Hit Testing:** Al tocar la pantalla, el lienzo calcula mediante geometría matemática qué caja delimitadora de elemento colisiona con el punto de contacto $(x, y)$, seleccionando el elemento con mayor `z_index`.

### 2.3. Capa de Exportación (Export Engine)
Una vez que el diseño es definitivo, esta capa se encarga del procesamiento final:
1. **Conversión a Imagen Fiel:** Se crea una escena fuera de pantalla (*off-screen canvas*) con la misma estructura del JSON pero a una resolución mucho mayor (ej. $1080 \times 1620$ píxeles para pantallas retina). Se renderizan todas las capas y se exporta como un flujo de bytes (PNG o WebP).
2. **Subida a Servidor:** La imagen final rasterizada se sube al storage de Supabase para que pueda ser mostrada rápidamente en feeds o listas sin necesidad de reconstruir el grafo de capas en tiempo real en los dispositivos de otros usuarios.
3. **Persistencia del Diseño:** El JSON de diseño se guarda en la base de datos para permitir que el creador de la carta pueda abrirla de nuevo en el editor y modificarla.

---

## 3. Integración con Supabase

La base de datos de Supabase ofrece el tipo de columna **`jsonb`** (JSON binario indexado), idónea para este tipo de arquitecturas, ya que permite almacenar estructuras de datos flexibles y realizar búsquedas rápidas.

### Estructura de la Tabla `word_cards` adaptada al Editor:
* `id` (UUID - Clave Primaria)
* `user_id` (UUID - Relación con el Perfil)
* `word` (text - Palabra clave)
* `definition` (text - Definición textual)
* `card_image_url` (text - Enlace a la imagen rasterizada PNG final en Supabase Storage)
* `canvas_design` (jsonb - Estructura completa de capas, coordenadas y personalización estética)

---

## 4. Niveles de Complejidad en la Implementación

| Nivel | Funcionalidades | Complejidad Técnica | Tiempo Estimado |
| :--- | :--- | :--- | :--- |
| **Nivel 1: Plantillas Rígidas** | Fondos y colores fijos seleccionables. Imágenes y textos en posiciones predefinidas. Sin gestos libres. | Baja | Corto (1-2 días) |
| **Nivel 2: Arrastre y Escala** | Movimiento libre de elementos en la pantalla. Cambio de tamaño mediante caja de selección táctil. | Alta | Medio (1-2 semanas) |
| **Nivel 3: Editor Avanzado** | Rotación con dos dedos, imantación con guías inteligentes de alineación, historial ilimitado de deshacer/rehacer. | Muy Alta | Largo (3-4 semanas) |

---

## 5. Estrategia y Recomendaciones para Lingiux

Para Lingiux, se recomienda una estrategia equilibrada de **Nivel 2**, ofreciendo gran libertad de diseño sin sobrecomplicar la experiencia técnica:
1. **Lienzo Proporcionado Fijo:** Mantener una relación de aspecto consistente de 2:3 para asegurar que todos los diseños encajen perfectamente en las miniaturas del perfil y en el feed.
2. **Paleta Curada de Degradados:** En lugar de un selector de color infinito de 24 bits que pueda arruinar la estética general de la app, ofrecer un conjunto de combinaciones y texturas espaciales premium preseleccionadas.
3. **Filtro de Exportación Limpio:** Usar los mecanismos de captura de renderizado nativos de Flutter (como `RepaintBoundary`) para fotografiar el widget del lienzo a alta resolución en un solo frame y subir el resultado a Supabase.
