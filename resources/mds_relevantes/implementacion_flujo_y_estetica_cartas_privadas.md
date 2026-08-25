# Arquitectura y Diseño: Flujo Contextual y Estética Clash Royale para Cartas Privadas

Este documento detalla la planeación, implementación técnica, dependencias y procedimientos de reversión de la funcionalidad de cartas privadas y locales en los chats de **Lingiux**, incluyendo su integración directa en el creador de cartas y la remodelación estética inspirada en el videojuego *Clash Royale*.

---

## 1. Objetivos del Cambio

El desarrollo se enfocó en resolver dos grandes problemas identificados en la experiencia del usuario (UX) y el diseño visual (UI):

1. **Aislamiento y Contexto Local:** 
   * Evitar el uso de Bottom Sheets redundantes.
   * Hacer que al hacer clic en el icono de cartas en un chat (`chat_detail_screen`) o grupo (`group_detail_screen`), el usuario sea redirigido de forma directa a la pestaña de creación (**CreateCardScreen**).
   * Al estar dentro del editor, la interfaz se adapta dinámicamente: oculta controles genéricos y muestra un carrusel interactivo con las cartas privadas que ya pertenecen a esa conversación.
   * Cambiar dinámicamente el título del formulario de "Palabra Clave" a "Crear Palabra Local".

2. **Remodelación Estética de la Mini-Carta (Estilo Clash Royale):**
   * **Limpieza Visual:** Quitar el icono del libro y el botón "Open" del centro de la carta, los cuales obstruían la visualización de la ilustración/imagen de fondo.
   * **Banner Inferior Pegado a los Bordes:** Crear una franja negra semi-transparente en el extremo inferior de la carta que abarque el ancho total de borde a borde.
   * **Opacidad Optimizada:** Configurar la opacidad del fondo de esta franja al **`20%`** (más translúcido) y remover cualquier filtro o reducción de opacidad sobre la imagen de fondo de la carta para que se muestre a opacidad completa (**`1.0`**).
   * **Tipografía Exclusiva Georgia:** Utilizar la fuente serif **`Georgia`** en mayúsculas y en negrita extra, alineada geométricamente al centro, logrando un aspecto editorial y de videojuego premium.
   * **Fondo de Pantalla Más Oscuro (Backdrop Dimming):** Incrementar la opacidad de atenuación de la pantalla detrás del pop-up flotante de la carta de `0.15` a **`0.35`** para hacer resaltar el pop-up dramáticamente.

---

## 2. Estructura de Archivos Modificados

La funcionalidad abarca múltiples capas del proyecto (presentación, navegación y widgets compartidos). A continuación se muestra su posición en la estructura del proyecto completo:

```
lingiux_app/
├── lib/
│   ├── features/
│   │   ├── chat/
│   │   │   └── presentation/
│   │   │       └── screens/
│   │   │           ├── chat_detail_screen.dart   <-- Acción AppBar, MiniCardFront/Back, OverlayEntrance
│   │   │           └── group_detail_screen.dart  <-- Acción AppBar
│   │   └── create_card/
│   │       └── presentation/
│   │           ├── screens/
│   │           │   └── create_card_screen.dart   <-- Paso 0 Contextual, Carrusel Horizontal, Botón Atrás
│   │           └── widgets/
│   │               └── step_word_identity.dart   <-- Título dinámico "Crear Palabra Local"
```

---

## 3. Detalle Técnico de la Implementación

### A. Redirección Directa desde Chats y Grupos
* **Archivos:** [`chat_detail_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart) y [`group_detail_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/group_detail_screen.dart).
* **Mecanismo:** Reemplazamos la llamada a `_showLocalCardsBottomSheet(context)` por una inyección de estado en Riverpod:
  ```dart
  ref.read(pendingConversationIdProvider.notifier).state = conversationId;
  ref.read(activeTabProvider.notifier).state = 2; // Pestaña del creador
  Navigator.popUntil(context, (route) => route.isFirst);
  ```
  Esto vacía la pila de navegación del chat actual y transiciona al usuario directamente al editor con el contexto de la conversación inicializado.

### B. Encabezado Dinámico y Carrusel de Cartas en el Creador
* **Archivo:** [`create_card_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_screen.dart).
* **Mecanismo:** Evaluamos `conversationId != null`. Si es verdadero:
  1. Omitimos el renderizado del stepper de pasos ("Paso 1 de 2") y el banner informativo verde.
  2. Insertamos un botón de retroceso personalizado que llama a `_prevStep()`. Si venía de una conversación, limpia `pendingConversationIdProvider = null` y redirige el flujo de la pestaña a la pestaña 0 (Chats).
  3. Renderizamos un carrusel horizontal con un `SizedBox` de altura `100` y tarjetas de ancho `68` (`clipBehavior: Clip.antiAlias` para respetar los bordes redondeados). Cada miniatura utiliza la misma estética que la carta del chat (imagen completa a opacidad 1.0, banner inferior translúcido al 20% y fuente Georgia centrada).

### C. Modificación del Título de Entrada
* **Archivo:** [`step_word_identity.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/step_word_identity.dart).
* **Mecanismo:** Agregamos el parámetro opcional `String? conversationId` al constructor del widget. En el método `build`, evaluamos:
  ```dart
  widget.conversationId != null ? 'Crear Palabra Local' : 'Palabra Clave'
  ```

### D. Rediseño del Pop-Up e Inspección de Cartas (Estilo Clash Royale)
* **Archivo:** [`chat_detail_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart).
* **Backdrop (Pantalla más oscura):** En `_OverlayEntranceState`, aumentamos el valor final de la animación de atenuación:
  ```dart
  _backdropOpacityAnimation = Tween<double>(
    begin: 0.0,
    end: 0.35, // Aumentado de 0.15 para oscurecer más el fondo
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  ```
* **Opacidad de Imagen:** En `WordMiniCardFront` (tanto en la evaluación de la carta directa como en la carga asíncrona de fallback), eliminamos el filtro oscuro y establecimos la opacidad del `ClipRRect` a `1.0`:
  ```dart
  Positioned.fill(
    child: Opacity(
      opacity: 1.0, // Cambiado de 0.70 a 1.0 para colores sólidos y brillantes
      child: ClipRRect( ... )
    )
  )
  ```
* **Remoción de Padding de la Base:** Para permitir que el banner toque los bordes físicos de la carta sin márgenes vacíos, eliminamos la propiedad `padding: const EdgeInsets.all(12)` en `MiniCardBase`. Para las demás vistas que sí requieren padding (como el reverso `WordMiniCardBack` o placeholders), envolvimos sus columnas internas con un widget `Padding` individual.
* **Banner de Borde a Borde:** Rediseñamos el banner para situarse en la parte inferior de la carta con un posicionamiento absoluto (`bottom: 0, left: 0, right: 0`), altura `28` y bordes circulares adaptados únicamente al extremo inferior:
  ```dart
  Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.20), // 20% de opacidad para alta transparencia
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.12),
            width: 0.5,
          ),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            matchingCard.word.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              fontFamily: 'Georgia', // Serif premium para estilo videojuego
            ),
          ),
        ),
      ),
    ),
  )
  ```

---

## 4. Librerías y Dependencias Utilizadas

* **`flutter_riverpod`**: Administra los estados globales de navegación y contexto local (`pendingConversationIdProvider`, `activeTabProvider`, `wordCardsProvider`).
* **`cached_network_image`**: Encargada de renderizar la ilustración de fondo de la carta de forma resiliente desde los servidores de Supabase Storage con caching automático en disco.
* **`flutter` (Material Design & Services)**: Utiliza `OverlayEntry` para pintar el pop-up por encima de la vista de chats, `HapticFeedback` para vibración UX, y el motor de dibujo `BoxDecoration` para la translucidez y bordes curvos.

---

## 5. Guía de Reversión

En caso de que en el futuro se decida revertir esta funcionalidad o modificarla a su estado original (Bottom Sheets flotantes y diseño original de la mini-carta), sigue estos pasos:

### Opción A: Mediante Control de Versiones (Git)
Si la reversión es inmediata, puedes deshacer el commit ejecutando en tu terminal:
```bash
# Revierte el commit donde se realizaron estas modificaciones
git revert 18cea3d
```

### Opción B: Reversión Manual del Código
1. **Restaurar el Bottom Sheet:** En `chat_detail_screen.dart` y `group_detail_screen.dart`, restaura el método `_showLocalCardsBottomSheet(...)` que existía en el historial y vuelve a asignarlo al parámetro `onPressed` de los botones de la AppBar correspondientes.
2. **Restaurar el Stepper en el Creador:** En `create_card_screen.dart`, remueve el condicional `if (conversationId == null) ... else ...` y deja únicamente la barra de progreso y el banner informativo verde originales.
3. **Restaurar Título "Palabra Clave":** En `step_word_identity.dart`, elimina la propiedad `conversationId` y el condicional del título para volver a mostrar de forma estática `'Palabra Clave'`.
4. **Restaurar Estética Centrada de la Carta:**
   * En `MiniCardBase` en `chat_detail_screen.dart`, vuelve a agregar `padding: const EdgeInsets.all(12)` en el contenedor principal.
   * En `WordMiniCardFront`, remueve la estructura de `Stack` con `Positioned` inferior y restaura la `Column` centrada (`mainAxisAlignment: MainAxisAlignment.center`) que renderiza el icono `Icons.auto_stories_outlined` y el botón ovalado `"Open"`.
   * Restablece la opacidad de la imagen de fondo a `0.70` en lugar de `1.0`.
   * Cambia la atenuación del backdrop de `0.35` de vuelta a `0.15` en `_OverlayEntranceState`.
