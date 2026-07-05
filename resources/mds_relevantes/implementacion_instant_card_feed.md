# Implementación de Instant Card en Feed: Atajo Rápido e Interactivo

Este documento recopila la arquitectura de diseño visual, la evolución de UI/UX y la lógica técnica aplicada para la creación del widget **Instant Card** en la pantalla de inicio de **Lingiux**, el cual funciona como un atajo estético y discreto hacia la baraja global de tarjetas de vocabulario.

---

## 1. Introducción y Concepto del Requerimiento

El objetivo era introducir un atajo visual flotante que simulara el comportamiento de las "Notas" o "Instants" de Instagram en la sección de chats directos, con las siguientes particularidades:
* **Ubicación:** Asomándose en el lateral derecho de la pantalla, discretamente integrado con la interfaz general.
* **Comportamiento:** En lugar de abrir visualizadores de fotos temporales, su función exclusiva es enviar al usuario directamente al carrusel de tarjetas de vocabulario de la comunidad (`WordDetailScreen`).
* **Estilo Visual:** Debía sentirse como parte de la identidad de marca de la app (una tarjeta mnemotécnica de vocabulario).

---

## 2. Evolución del Diseño y Decisiones de UI/UX

Para llegar al resultado final, se implementaron dos iteraciones de diseño basadas en el feedback del usuario sobre la limpieza y la consistencia de la interfaz:

### Iteración 1: El Estilo Polaroid (Descartado)
* **Diseño:** Un contenedor blanco que simulaba una fotografía física Polaroid con un margen inferior más ancho y una burbuja de nota flotante arriba que decía "Repasar". Cargaba imágenes dinámicas de las palabras de la base de datos de forma aleatoria.
* **Problema:** Lucía como un "post de blog o red social genérico" en lugar de un elemento educativo. Además, la carga dinámica de imágenes de Supabase competía visualmente con el contenido de la pantalla de inicio y sobrecargaba la UI.

### Iteración 2: La Mini Card Estática y Discreta (Implementado)
* **Diseño:** Se reemplazó el estilo Polaroid por una réplica en miniatura abstracta de las tarjetas mnemotécnicas oficiales de la aplicación.
* **Color y Gradiente:** Utiliza el degradado estático morado/índigo (`Color(0xFF7C3AED)` y `Color(0xFF4F46E5)`) con bordes redondeados (`BorderRadius.circular(14)`) y sombra difuminada a juego.
* **Abstracción:** Se eliminó cualquier tipo de texto de palabras dinámicas (como "ambiguos" o placeholders) e imágenes cargadas de internet, eliminando la distracción visual. Se incorporó únicamente un icono central de destellos translúcido (`Icons.auto_awesome_outlined`).
* **Opacidad y Dimensiones:** Se redujo su escala a unas dimensiones compactas de **`75` de ancho y `120` de alto**. Todo el widget cuenta con una opacidad del **90% (`0.90`)** y se asoma discretamente a la derecha (`right: -42`) y en la parte superior (`top: 140`) de la pantalla para no entorpecer el scroll o el uso de los menús principales.

---

## 3. Lógica de Redirección Inteligente

Aunque el diseño visual del widget es estático y limpio, su comportamiento por dentro es **dinámico e inteligente**.

Cuando el usuario hace clic sobre el Instant, el widget consulta de forma interna la lista global de tarjetas descargadas por el proveedor:

```dart
final wordCardsAsync = ref.watch(wordCardsProvider);
final cards = wordCardsAsync.value ?? [];
final targetWord = cards.isNotEmpty ? cards.first.word : 'lingiux';
```

### Flujo de Navegación:
1. **Lectura asíncrona:** Riverpod lee en segundo plano las tarjetas disponibles en `wordCardsProvider`.
2. **Evaluación de existencias:** 
   * Si la base de datos tiene tarjetas creadas (ya sea del propio usuario o globales de la comunidad), se selecciona la palabra de la **primera tarjeta real existente** (`cards.first.word`).
   * Si por alguna razón la lista está completamente vacía (un usuario nuevo en una base de datos virgen), se utiliza el valor por defecto `'lingiux'` como resguardo (*fallback*).
3. **Navegación directa:** Se navega a la pantalla del carrusel (`WordDetailScreen`) pasando dicha palabra real como argumento. De esta forma, el carrusel se inicializa cargando una tarjeta completa ya terminada y lista para estudiar, en lugar de una tarjeta vacía que mande al usuario al editor.

---

## 4. Archivos Modificados

* **[feed_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/feed/presentation/screens/feed_screen.dart) [MODIFY]:**
  * Modificado el widget completo para heredar de `ConsumerWidget`.
  * Diseñado el layout flotante dentro del `Stack` con su posicionamiento, rotación, dimensiones, opacidad y el icono central.
  * Inyectada la lectura asíncrona del proveedor para redireccionar a la primera tarjeta válida en la base de datos.
  * Actualizado el mensaje central del dashboard de inicio eliminando la etiqueta de "Próximamente" e incorporando una descripción interactiva y premium de las funciones de la aplicación.

---

## 5. Librerías y Recursos Utilizados

* **`flutter_riverpod`:** Utilizado para acceder de forma limpia y reactiva al proveedor de estado `wordCardsProvider` dentro de un `ConsumerWidget`.
* **`flutter/services.dart`:** Utilizado para ejecutar efectos hápticos (`HapticFeedback.mediumImpact()`) en el momento en que el usuario presiona la tarjeta flotante, dándole una sensación de respuesta táctil premium.
