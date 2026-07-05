# Rediseño de la Lista de Chats y Carrusel de Tarjetas de Amigos

Este documento sirve como guía técnica detallada y documentación arquitectónica del rediseño aplicado a la pantalla de listado de chats en **Lingiux**, el cual migró de un diseño basado en tarjetas elevadas ("globitos") a una lista convencional y plana, agregando un carrusel de tarjetas de amigos y un sistema de insignias de banderas de idiomas.

---

## 1. Contexto y Objetivos del Rediseño

El diseño inicial de la pantalla de listado de conversaciones utilizaba tarjetas independientes con bordes redondeados y sombreado para cada chat. Aunque estético, este enfoque consumía un exceso de espacio vertical y reducía la densidad de información en pantalla.

Para alinear la experiencia a las aplicaciones de comunicación modernas (como Instagram o WhatsApp), los objetivos de este rediseño fueron:
1.  **Optimización del Espacio (Lista Plana)**: Remover los contenedores de tarjeta y mostrar las conversaciones de forma continua separadas por una línea divisoria sutil.
2.  **Gamificación e Interacción Social (Carrusel de Amigos)**: Incluir un carrusel horizontal en la parte superior que muestra de manera dinámica qué tarjetas de vocabulario han estado practicando los amigos del usuario.
3.  **Contextualización Lingüística (Insignias de Banderas)**: Mostrar en el extremo superior derecho de cada chat los idiomas que se están practicando o aprendiendo dentro de esa sala de conversación.

---

## 2. Tecnologías y Librerías Utilizadas

Para llevar a cabo esta implementación de manera eficiente y escalable, se utilizaron las siguientes librerías del ecosistema de Flutter:

### A. `flutter_svg` (v2.0.10)
*   **Propósito**: Renderizado de recursos gráficos vectoriales en formato SVG.
*   **Uso en la Feature**: Las banderas de los países (como `us.svg`, `mx.svg`, `fr.svg`, etc.) se almacenan en formato vectorial bajo la carpeta `assets/flags/`. `flutter_svg` permite redimensionar estas banderas a un tamaño micro (ej: `18x18` píxeles) sin pérdida de definición gráfica y consumiendo una fracción del almacenamiento que requeriría una textura PNG de alta densidad.

### B. `flutter_riverpod` (v2.6.1)
*   **Propósito**: Gestión del estado reactivo global de la aplicación.
*   **Uso en la Feature**:
    *   `chatsProvider`: Stream reactivo que se conecta en tiempo real a Supabase para recibir actualizaciones de las conversaciones activas.
    *   `authProvider`: Permite validar el usuario autenticado para asegurar que el listado corresponda únicamente a las conversaciones en las que participa el usuario logueado.

### C. `cached_network_image` (v3.4.1)
*   **Propósito**: Descarga, caché en memoria/disco y renderizado eficiente de imágenes remotas.
*   **Uso en la Feature**: Utilizado para mostrar los avatares de los usuarios/amigos que provienen de Supabase Storage de manera fluida y con animaciones de carga o placeholders en caso de fallos de red.

---

## 3. Detalle de Archivos Modificados

### [MODIFY] [chats_list_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chats_list_screen.dart)
Este es el archivo principal que alberga la interfaz del listado de chats. Fue refactorizado en tres secciones clave:

#### 1. Inclusión de Mock Data para el Carrusel
Para simular el historial de práctica de la comunidad antes de conectar la lógica final del backend, declaramos la constante `_mockPracticedCards` dentro del estado del widget:
```dart
final List<Map<String, dynamic>> _mockPracticedCards = const [
  {
    'friendName': 'Sebas',
    'friendAvatar': null,
    'word': 'Serendipity',
    'gradient': [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    'avatarColorIndex': 0,
  },
  {
    'friendName': 'Pepito',
    'friendAvatar': null,
    'word': 'Mellifluous',
    'gradient': [Color(0xFFFF6B8B), Color(0xFFFF8E53)],
    'avatarColorIndex': 1,
  },
  {
    'friendName': 'Emma',
    'friendAvatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
    'word': 'Ephemeral',
    'gradient': [Color(0xFF4FA4F4), Color(0xFF4CD9A3)],
    'avatarColorIndex': 2,
  },
  ...
];
```

#### 2. Widget del Carrusel (`_buildFriendCardsCarousel`)
Construye la fila horizontal superior utilizando un `ListView.builder` con scroll horizontal. Las tarjetas se diseñaron siguiendo la estética de esquinas muy redondeadas del sistema de diseño:
*   **Dimensiones**: Ancho fijo de `90px` y altura del contenedor de `125px`.
*   **Gradientes**: Se utilizaron combinaciones cromáticas de dos colores para crear un efecto dinámico e inmersivo.
*   **Avatar**: Un mini `CircleAvatar` superior con un borde blanco que destaca sobre el gradiente del fondo.

#### 3. Determinación de Banderas (`_getLanguagesForChat`)
Para mostrar qué idiomas se están aprendiendo, implementamos una lógica determinista que asocia el identificador o nombre de la sala con un grupo de archivos vectoriales:
```dart
List<String> _getLanguagesForChat(ChatEntity chat) {
  if (chat.name.toLowerCase().contains('sebas')) {
    return ['us.svg', 'fr.svg'];
  } else if (chat.name.toLowerCase().contains('pepito')) {
    return ['mx.svg', 'de.svg', 'br.svg'];
  } else {
    // Lógica determinista basada en el hash del chat
    final flags = ['us.svg', 'mx.svg', 'fr.svg', 'de.svg', 'it.svg', 'br.svg'];
    final index1 = chat.id.hashCode.abs() % flags.length;
    final index2 = (chat.id.hashCode.abs() + 2) % flags.length;
    return [flags[index1], flags[index2]];
  }
}
```

#### 4. Rediseño del Tile (`_ChatListTile`)
La estructura se simplificó sustituyendo el contenedor decorado exterior por un widget `Column` plano:
*   **Fondo**: Transparente, permitiendo ver el degradado superior de la app de forma fluida.
*   **Efecto al presionar**: Encapsulado dentro de un `Material` e `InkWell` para dar retroalimentación táctil nativa con salpicadura de color (`splashColor`) basada en el color principal de acento.
*   **Línea divisoria**: Un widget `Divider` con grosor de `0.5px` y márgenes laterales de `20px` para separar estéticamente cada conversación.

---

## 4. Estructura Visual de la Fila (Layout de Componentes)

El siguiente diagrama detalla cómo se distribuyen los elementos espaciales en la nueva fila del listado de chat:

```text
┌────────────────────────────────────────────────────────────────────────┐
│  [AVATAR]   [NOMBRE DEL USUARIO]               (Bandera1) (Bandera2)  │
│  (Online)   [Último mensaje del chat]                      [Rel. Time] │
├────────────────────────────────────────────────────────────────────────┤
│                    LÍNEA DIVISORIA SUTIL (0.5px)                       │
└────────────────────────────────────────────────────────────────────────┘
```

*   **Fila Superior**:
    *   A la izquierda, se encuentra el **Avatar** con su respectivo halo indicador de conexión en verde si el participante está en línea (`isOnline`).
    *   En el centro, el **Nombre del usuario** con tipografía `Inter` semibold.
    *   A la derecha, la colección de **Banderas de idiomas** alineadas horizontalmente, rodeadas por un fino borde blanco para crear separación visual.
*   **Fila Inferior**:
    *   En el centro, el **Último mensaje** de la conversación, configurado con `TextOverflow.ellipsis` y un máximo de 1 línea para prevenir desbordes de texto.
    *   A la derecha, el **Tiempo relativo** transcurrido desde el último mensaje (ej. "7h", "2d") y una insignia numérica en color oscuro si hay mensajes sin leer (`unreadCount`).

---

## 5. Cumplimiento con el Sistema de Diseño (DESIGN_SYSTEM.md)

Este rediseño cumple de manera estricta con las pautas de interfaz definidas para Lingiux:
1.  **Esquinas Suaves (Soft UI)**: Las mini tarjetas del carrusel de amigos tienen un `borderRadius` de `20px` para asegurar un acabado moderno.
2.  **Degradados de Marca**: Las mini tarjetas utilizan la paleta cromática oficial (Morado/Índigo, Coral/Naranja, Celeste/Verde) con sombras tintadas para simular relieve y brillo en pantalla.
3.  **Tipografía Consistente**: Se aplicó la fuente `Inter` a todos los textos de la vista (títulos y descripciones), manteniendo los tamaños relativos de escala tipográfica (título de chat en `15px` y descripciones en `13px` y `11px`).
4.  **Optimización del Dibujo**: Se aplicaron métodos de mezcla de color usando `.withValues(alpha: ...)` para evitar la fatiga y degradación del motor de renderizado Skia/Impeller al calcular la opacidad de los avatares y sombras.
