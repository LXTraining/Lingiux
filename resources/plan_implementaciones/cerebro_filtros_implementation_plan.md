# Plan de Implementación: Carrusel de Filtros en Cerebro Digital (Comunidad)

Este plan detalla el rediseño superior de la pantalla **Cerebro Digital** (`community_screen.dart`), removiendo el texto instructivo estático y sustituyéndolo por un carrusel interactivo de filtros capsule (categorías, idiomas y niveles/marcos).

---

## 🎨 1. Rediseño de la Cabecera (Filtros en Carrusel)
Removeremos el texto `"Usa pellizco para zoom. Toca o arrastra los nodos."` y crearemos un carrusel horizontal (`ListView.horizontal`) de botones capsule con selectores integrados de tipo Dropdown:

```
+-------------------------------------------------------------------+
|  [🔍 Categoría: Todos v]   [🌐 Idioma: Inglés v]   [🏆 Nivel: Todos v]  |
+-------------------------------------------------------------------+
```

*   **Estilo Visual**: Contenedores premium con bordes redondeados (`20px`), fondo translúcido (`surfaceVariant`), iconos representativos e interactividad háptica en cada selección.
*   **Opciones de Filtrado**:
    1.  **Categoría**: Todos, Verbos, Sustantivos, Adjetivos, Frases.
    2.  **Idioma**: Todos, Inglés, Alemán, Francés, Italiano, Portugués.
    3.  **Nivel / Marco**: Todos, Normal, Bronce, Plata, Oro, Neón.

---

## 🧬 2. Filtrado Físico y Visual de Nodos en la Red
Los filtros interactuarán directamente con el motor de físicas y renderizado del grafo de la constelación:

1.  **Control de Visibilidad**:
    *   Un nodo palabra (`word`) es visible si su categoría no está colapsada **Y** coincide con todos los filtros activos (Categoría, Idioma, Nivel).
    *   Un nodo categoría (`category`) es visible si no hay filtro de categoría activo, o si coincide con la categoría seleccionada en el filtro.
2.  **Líneas de Conexión (Edges)**:
    *   Las conexiones elásticas solo se dibujarán y computarán si ambos nodos conectados (la categoría y la palabra) están marcados como visibles por los filtros.
3.  **Contador Dinámico**:
    *   El indicador superior actualizará su número en vivo mostrando únicamente la cantidad de palabras visibles según los filtros activos.

---

## 📁 3. Archivos a Modificar
*   [community_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/community/presentation/screens/community_screen.dart)
    *   Declarar variables de filtro en `_CommunityScreenState`.
    *   Implementar métodos de validación de filtros (`_doesNodeMatchFilters`, `_getCategoryFilterKey`).
    *   Actualizar `_isNodeVisible` y `_rebuildEdges`.
    *   Reemplazar la leyenda estática por el carrusel de dropdowns capsule.
