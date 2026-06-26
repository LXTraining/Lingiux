# Navegación por Gestos de Deslizamiento (PageView) en Chats

Este documento detalla la conceptualización, arquitectura e implementación de la navegación mediante gestos de deslizamiento lateral en la pantalla de chat de Lingiux, permitiendo al usuario navegar hacia una vista individual de información del chat al deslizar su dedo hacia la derecha.

---

## 1. Conceptos de Deslizamiento (Swiping) en Dispositivos Móviles

Al diseñar interacciones basadas en gestos de deslizamiento en Flutter, es crucial diferenciar entre dos flujos principales:

### Caso A: Deslizar una Fila de la Lista (Swipe-to-Action)
* **¿Qué es?:** El usuario desliza un elemento de lista individual (como una celda de chat) para revelar acciones contextuales rápidas (borrar, archivar, silenciar).
* **Componente Flutter:** Usualmente implementado mediante el widget nativo **`Dismissible`** o la librería `flutter_slidable`.
* **Uso recomendado:** Acciones de gestión rápida que no requieren cambiar el contexto completo de la pantalla.

### Caso B: Deslizar la Pantalla Completa (PageView / Pestañas)
* **¿Qué es?:** El usuario desliza el dedo en cualquier punto de la pantalla para transicionar fluidamente a otra página completa.
* **Componente Flutter:** Implementado mediante el widget **`PageView`** o **`TabBarView`** controlados por un `PageController`.
* **Uso recomendado:** Flujos premium e inmersivos (como transiciones entre la cámara, chats y perfiles en Snapchat o Tinder).

> [!NOTE]
> Para la pantalla del chat individual en Lingiux, implementamos el **Caso B (PageView)**, permitiendo que la conversación principal tenga un panel de detalles accesible al deslizar la pantalla hacia la derecha.

---

## 2. Decisiones de Diseño (Soft UI & Premium Style)

Conforme a las directrices de `DESIGN_SYSTEM.md`, la página de información del chat implementa los siguientes estándares visuales:

* **Esquinas Ultra Redondeadas:** La tarjeta de características de la página de detalles utiliza un radio de borde de `28px` con una sombra muy sutil y difusa (`Color(0x080F172A)`).
* **Color Base:** Fondo limpio en tono claro (`AppColors.background` -> `#F8F9FD`).
* **Degradados:** El contenedor del icono superior utiliza el gradiente de marca (`#815BF5` a `#5A45FF`) con un efecto de brillo suave.
* **Iconografía Outline:** Íconos finos de estilo lineal con un grosor constante.
* **Microinteracciones y Animación:**
  * Uso de `Hero` para realizar una transición fluida y de alta fidelidad del avatar del usuario entre las pantallas.
  * Física de rebote (`BouncingScrollPhysics`) para que el deslizamiento lateral se sienta natural e inmersivo.

---

## 3. Detalles de Implementación

La integración se realizó modificando directamente el archivo [chat_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart). 

### Inicialización y Disposición del Controlador
Se declaró un `PageController` para gestionar el estado de la página actual y permitir animaciones de navegación programáticas:

```dart
late final PageController _pageController;

@override
void initState() {
  super.initState();
  _pageController = PageController();
}

@override
void dispose() {
  _pageController.dispose();
  super.dispose();
}
```

### Estructura de Vistas en `build`
El widget principal ahora retorna un `PageView` envuelto en un `GestureDetector` (para cerrar los overlays flotantes de vocabulario):

```dart
@override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: _dismissOverlay,
    child: PageView(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      children: [
        _buildConversationPage(context),
        _buildInfoPage(context),
      ],
    ),
  );
}
```

---

## 4. Desglose de Pantallas

### Página 0: Conversación Principal (`_buildConversationPage`)
Es la pantalla de chat estándar donde se muestran los mensajes y la barra de entrada de texto.
* **Acceso Programático:** Añadimos un botón de detalles (`Icons.info_outline_rounded`) en las acciones del AppBar. Al pulsarse, ejecuta una animación suave hacia la página de detalles:
  ```dart
  _pageController.animateToPage(
    1,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );
  ```

### Página 1: Detalles del Chat (`_buildInfoPage`)
La nueva pantalla que se revela al deslizar el dedo hacia la izquierda (transición hacia la derecha). Actúa como un marcador de posición de alta fidelidad para el futuro contenido.
* **Avatar Dinámico:** Muestra las iniciales y color correspondientes al chat actual en tamaño grande (`96px`), conectado a la vista previa mediante un tag `Hero`.
* **Identificación del Estado:** Una etiqueta redondeada tipo píldora que refleja si el usuario está en línea (`AppColors.online`) o desconectado.
* **Tarjeta de Marcador de Posición:** Un contenedor Soft UI blanco que describe las funcionalidades a futuro (estadísticas, vocabulario compartido y configuraciones).
* **Guías de Interacción:** Un texto animado con iconos que indica cómo interactuar: `"Desliza a la derecha para volver al chat"`.

---

## 5. Control de Calidad y Pruebas

Para validar los cambios, se ejecutaron las siguientes verificaciones:

1. **Análisis Estático (`flutter analyze`):** Confirmación de que no existen problemas de compilación ni de sintaxis en [chat_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart).
2. **Pruebas de Widgets (`flutter test`):** Comprobación de que la prueba de humo base (`App boot smoke test`) y los flujos de inicialización siguen pasando con éxito sin romper dependencias.
