# Guía de Rendimiento y Optimización en Flutter

Este documento explica en detalle el funcionamiento del motor de renderizado de Flutter, los factores que provocan ralentizaciones (*lag* o *jank*), y las mejores prácticas para asegurar que **Lingiux** funcione a 60 FPS o 120 FPS constantes.

---

## 🎞️ 1. ¿Cómo funciona la pantalla y qué es el "Lag" (Jank)?

El sistema operativo de los dispositivos móviles funciona como un proyector: dibuja imágenes sucesivas de la interfaz para simular fluidez y movimiento.
*   **Pantallas de 60Hz:** Se actualizan 60 veces por segundo, lo que otorga exactamente **16.6 ms** para procesar y dibujar cada fotograma.
*   **Pantallas de 120Hz:** Se actualizan 120 veces por segundo, dando únicamente **8.3 ms** por fotograma.

Si la preparación de un fotograma tarda más de este tiempo, el sistema operativo se salta ese fotograma. Esto se percibe visualmente como un tirón, retraso o salto brusco de animación, conocido técnicamente como **Jank** (o coloquialmente como *lag*).

---

## 🧵 2. Hilos de Ejecución en Flutter

Flutter distribuye el trabajo en múltiples hilos de procesamiento de forma asíncrona:

1.  **UI Thread (Hilo de Dart/Lógica):** Ejecuta el código de Dart de la app (providers de Riverpod, peticiones de red, parseo de JSON, reconstrucciones del árbol de widgets).
2.  **Raster Thread (Hilo Gráfico/GPU):** Ejecuta el motor gráfico nativo de Flutter (**Impeller** o **Skia**). Toma las instrucciones del UI Thread y las convierte en píxeles reales.
3.  **Platform Thread (Hilo Nativo):** Administra la integración nativa con el sistema operativo (sensores, plugins, canales de plataforma, etc.).

> [!IMPORTANT]
> Si bloqueas el **UI Thread** con operaciones pesadas por más de 8 o 16 ms, se retrasará la entrega de comandos al Raster Thread y la aplicación tendrá *jank*.

---

## 🚫 3. Las 6 Causas Comunes de Lag y sus Soluciones

### 1. Bloqueo del Hilo Principal con Tareas Pesadas
*   **Causa:** Criptografía, parseo de grandes cadenas JSON, manipulación de imágenes locales o cálculos matemáticos complejos ejecutados directamente en la UI.
*   **Solución:** Mover estas tareas a un hilo secundario (**Isolates**).
    ```dart
    // Ejecuta la función pesada de manera aislada sin trabar el hilo de UI
    final resultado = await Isolate.run(() => procesarDatosPesados(datos));
    ```

### 2. Reconstrucciones de Widgets Excesivas e Innecesarias
*   **Causa:** Llamar a `setState()` en un widget raíz de nivel superior, forzando a Flutter a recalcular todo el árbol cuando solo cambió un campo de texto o botón pequeño.
*   **Solución:**
    *   Usa constructores `const` siempre que sea posible. Esto previene que Flutter vuelva a procesar esos widgets estáticos.
    *   Divide tus pantallas en widgets atómicos y modulares.
    *   En Riverpod, suscríbete a cambios específicos con `.select()` para evitar reconstruir widgets completos al mutar propiedades no relacionadas:
        ```dart
        final nombre = ref.watch(perfilProvider.select((user) => user.name));
        ```

### 3. Cargar Listados Largos sin Reciclaje de Widgets
*   **Causa:** Usar `SingleChildScrollView` combinada con `Column` para listados grandes o infinitos. Forzará la renderización simultánea de cientos de elementos invisibles en memoria.
*   **Solución:** Usar siempre los constructores dinámicos del framework:
    *   `ListView.builder()` o `GridView.builder()`.
    *   `CustomScrollView` con componentes `Slivers` para estructurar la UI de forma eficiente.
    *   Esto asegura que solo se procesen los widgets visibles en pantalla en cada momento.

### 4. Imágenes Gigantes sin Caché ni Redimensionamiento
*   **Causa:** Descargar y decodificar imágenes de alta resolución (ej. fotos de cámara de 5MB) para mostrarlas en vistas en miniatura (miniaturas o avatares de 60x60).
*   **Solución:**
    *   Usa el widget `CachedNetworkImage` para cachear recursos descargados en el disco del celular.
    *   Usa las propiedades `cacheWidth` y `cacheHeight` al cargar imágenes locales para optimizar el tamaño en memoria RAM al decodificar.

### 5. Operaciones Gráficas Costosas para la GPU
*   **Causa:** Aplicar efectos visuales complejos que requieren procesar los píxeles de la pantalla por capas, como `BackdropFilter` (desenfoque/blur), `Opacity` en jerarquías profundas de widgets, o esquinas redondeadas excesivas con `ClipRRect`.
*   **Solución:**
    *   Evita usar el widget `Opacity` para cambiar simplemente colores. En su lugar, usa un color con canal alfa (`color.withAlpha()` o `.withValues()`).
    *   Utiliza bordes redondeados dentro de la propiedad `decoration` de un `Container` antes que envolver elementos en un `ClipRRect` si no hay desborde.

### 6. Fugas de Memoria (Memory Leaks)
*   **Causa:** No liberar los controladores del sistema cuando se destruye una vista o pantalla, impidiendo que el recolector de basura libere memoria RAM.
*   **Solución:** Llama de forma obligatoria al método `dispose()` de los controladores creados en tus `StatefulWidgets`:
    ```dart
    @override
    void dispose() {
      _miTextController.dispose();
      _miScrollController.dispose();
      _miAnimationController.dispose();
      super.dispose();
    }
    ```

---

## 🚀 4. Impeller: La Nueva Era Gráfica de Flutter

En versiones anteriores de Flutter, el primer renderizado de animaciones complejas solía sufrir de tirones breves debido al **Shader Compilation Jank** del motor Skia (que compila los shaders de la GPU sobre la marcha).

**Impeller** (habilitado de forma predeterminada en iOS y en dispositivos Android compatibles):
*   Reemplaza a Skia para resolver este problema.
*   Pre-compila todos los shaders necesarios de la interfaz de usuario en el momento de construir la aplicación (compilación AOT).
*   Proporciona transiciones y animaciones fluidas desde el primer arranque del usuario.

---

## 🛠️ 5. Cómo Medir y Diagnosticar Rendimiento de Forma Real

> [!WARNING]
> **Nunca evalúes el rendimiento o lag en modo Debug.**
> El modo Debug agrega código pesado de diagnóstico para permitir el *Hot Reload* y la depuración del código, haciendo que la app vaya lenta.

### Pasos para realizar perfiles de rendimiento reales:
1.  **Ejecutar en modo Profile:** Compila la aplicación optimizada pero con soporte para instrumentación y diagnóstico en un dispositivo físico real:
    ```bash
    flutter run --profile
    ```
2.  **Flutter DevTools:** Abre las herramientas web del DevTools y dirígete a la pestaña **Performance**. Allí verás un análisis en vivo de los hilos de UI y Raster, identificando con precisión qué funciones superan los 8.3ms/16.6ms de ejecución.
