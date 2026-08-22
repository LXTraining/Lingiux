# Resumen Técnico: Implementación de Cartas de Vocabulario Privadas/Locales en Chats 🎴💬

Este documento describe la arquitectura, el diseño de la base de datos y la implementación técnica de la funcionalidad que permite a los usuarios crear y visualizar **Cartas de Vocabulario Privadas** que pertenecen única y exclusivamente al contexto de un chat o grupo de estudio específico en Lingiux.

---

## 1. Contexto e Historia de Usuario
Originalmente, todas las cartas de vocabulario creadas en la aplicación eran de carácter **Global**, lo que significaba que cualquier palabra registrada era visible en el cerebro digital principal, en el perfil del usuario, y se asociaba con taps de palabras en cualquier chat indistintamente.

### El Requerimiento:
*   **Creación Local:** Permitir a los usuarios crear cartas rápidas directamente desde un chat o grupo a través de un botón dedicado en el AppBar.
*   **Privacidad Absoluta:** Estas cartas deben estar aisladas herméticamente. No deben aparecer en otros chats al pulsar sobre las palabras, ni en el Cerebro Digital del perfil general, ni en el listado general del usuario.
*   **Visibilidad contextual:** El usuario puede listar cuántas cartas locales se han creado en ese chat abriendo la sección de detalles/miembros del chat o grupo (pestaña dedicada o sección en el panel lateral).

---

## 2. Estructura y Arquitectura en la Base de Datos (Supabase)

Para persistir el contexto conversacional de las tarjetas de vocabulario sin romper el esquema relacional ni duplicar datos, extendimos la tabla de Supabase `word_cards`.

### A. Modificación del Esquema (DDL)
Se añadió una columna nullable `conversation_id` con llave foránea referenciando a la tabla de conversaciones, y se creó un índice para agilizar búsquedas.

```sql
-- 1. Agregar columna de relación conversacional (nullable)
-- Si es NULL, la carta es GLOBAL. Si tiene un UUID, es PRIVADA.
ALTER TABLE word_cards 
ADD COLUMN conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE;

-- 2. Crear índice B-Tree para búsquedas eficientes por conversación
-- Optimiza consultas frecuentes al cargar chats o detalles del grupo.
CREATE INDEX idx_word_cards_conversation 
ON word_cards(conversation_id);
```

### B. Decisiones de Diseño en Base de Datos:
1.  **Eliminación en Cascada (`ON DELETE CASCADE`):** Si un chat, canal o grupo de estudio se elimina, todas las cartas de vocabulario privadas asociadas se purgan de la base de datos automáticamente. Esto previene fugas de datos y registros huérfanos.
2.  **Opcionalidad mediante Nulos:** Mantener `conversation_id` como nullable permite que el 100% de la lógica anterior de tarjetas globales siga funcionando perfectamente sin alterar el código existente.
3.  **Seguridad de RLS (Row Level Security):** Las políticas de RLS de Supabase en `word_cards` continúan aplicando el aislamiento por usuario (`user_id = auth.uid()`), lo que asegura que solo el autor de la carta tenga acceso a leerla o modificarla.

---

## 3. Arquitectura del Estado en Flutter (Riverpod)

Para comunicar el estado contextual del chat con el asistente de creación de cartas, creamos un flujo de navegación reactivo utilizando **Riverpod**:

### A. Proveedores de Estado (`navigation_provider.dart`):
*   **`pendingConversationIdProvider`:** Un `StateProvider<String?>` que actúa como canal de comunicación efímero. Al hacer clic en "Crear carta local" en un chat, el ID del chat se escribe en este proveedor. Al completarse o cancelarse la creación, se restablece a `null`.

### B. Proveedores de Vocabulario (`vocabulary_provider.dart`):
*   **`wordCardsProvider` (Caché centralizada):** Mantiene la descarga total de tarjetas del usuario. Almacena tanto globales como locales. Esto minimiza el consumo de red en Supabase.
*   **`userWordCardsProvider` y `correctWordCardsProvider` (Vistas Globales):** Se modificaron agregando un filtro estricto por código para excluir cualquier tarjeta que tenga un `conversationId` asignado.
    ```dart
    // Excluir locales del Cerebro Digital general
    final cards = (response as List<dynamic>)
        .map((json) => WordCardModel.fromJson(json as Map<String, dynamic>))
        .where((card) => card.conversationId == null || card.conversationId!.isEmpty)
        .toList();
    ```

---

## 4. Archivos Modificados y Lógica de Aislamiento

La funcionalidad se implementó modificando los siguientes componentes del proyecto:

### A. Dominio: [`word_card_model.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/domain/models/word_card_model.dart)
Se expandieron las propiedades del modelo agregando el campo `conversationId` con soporte de serialización y deserialización JSON:
```dart
final String? conversationId;
// ...
conversationId: json['conversation_id'] as String?,
// ...
'conversation_id': conversationId,
```

### B. Proveedores: [`vocabulary_provider.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/providers/vocabulary_provider.dart)
Filtrado estricto en los listados del Cerebro Digital principal para evitar que las tarjetas locales se muestren globalmente.

### C. Navegación: [`navigation_provider.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/home/presentation/providers/navigation_provider.dart)
Se declaró `pendingConversationIdProvider` para guardar temporalmente el ID de la conversación de origen.

### D. Interfaz del Asistente: [`create_card_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_screen.dart)
*   **Detección de Origen en `build`:** Escucha si `pendingConversationIdProvider` tiene un valor activo; de ser así, salta automáticamente el selector inicial (`_currentStep = -1`) y lleva al usuario directamente al formulario de la tarjeta (`_currentStep = 0`).
*   **Banner Informativo:** Muestra un cintillo visual premium informando al usuario que está creando una tarjeta local que solo será visible en el chat de origen.
*   **Guardado y Limpieza:** El método `_saveCard` lee el ID de la conversación, realiza la inserción de `'conversation_id': conversationId` en Supabase, invalida `wordCardsProvider` para refrescar los datos y limpia el estado del proveedor.
*   **Limpieza al Volver:** Si el usuario decide regresar al selector inicial, el proveedor se limpia (`null`) para evitar fugas de contexto.

### E. Componentes Visuales del Chat: [`chat_detail_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart)
*   **Botón en AppBar:** Se integró un icono de cartas (`Icons.style_outlined`) en el AppBar que guarda el ID de la conversación en el proveedor y redirige al creador.
*   **Filtro del Pop-up (`_showWordCard`):** El método que captura los taps en las palabras filtra la caché de cartas locales y descarta cualquiera que pertenezca a otros chats:
    ```dart
    final matches = wordList.where((w) => 
      w.word.toLowerCase() == cleanWord.toLowerCase() &&
      (w.conversationId == null || w.conversationId!.isEmpty || w.conversationId == widget.chat.id)
    ).toList();
    ```
*   **Componentes `WordMiniCardFront` and `WordMiniCardBack`:** Se les añadió el parámetro `conversationId`. Tanto la imagen como la validación de texto `hasCard` realizan un filtro cruzado en base a este parámetro para que en chats ajenos no se cargue información privada y muestre el botón genérico de `+ Crear`.
*   **Inventario Local en Info Drawer:** El método `_buildLocalCardsSection` carga y muestra en un carrusel horizontal solo las cartas locales pertenecientes a este chat.

### F. Componentes Visuales del Grupo: [`group_detail_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/group_detail_screen.dart)
*   **Botón en AppBar:** Reemplaza la funcionalidad en grupos con la redirección directa al creador.
*   **Pestaña dedicada "Cartas":** Incrementa el TabController de 3 a 4 y añade la pestaña **"Cartas"**, la cual lista todas las tarjetas del grupo en un Grid de 3 columnas (`_buildLocalCardsTab`).
*   **Filtro del Pop-up:** Filtro análogo al chat directo utilizando `widget.group.conversationId` para descartar cartas de otros chats o grupos.

### G. Detalle Completo: [`word_detail_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/screens/word_detail_screen.dart)
*   **Filtro de Seguridad en Constructor:** Se añadió la propiedad `conversationId`. Al cargar los datos del swiper de tarjetas, se eliminan todas las tarjetas privadas de otros chats para evitar que el usuario pueda visualizarlas al deslizar horizontalmente:
    ```dart
    final wordCards = rawWordCards.where((w) =>
      w.conversationId == null ||
      w.conversationId!.isEmpty ||
      w.conversationId == widget.conversationId
    ).toList();
    ```

---

## 5. Librerías y Dependencias Involucradas

*   **`flutter_riverpod` (v2.x):** Utilizado para el manejo de estado reactivo global, invalidación de cachés (`ref.invalidate`) y el canal de comunicación temporal (`pendingConversationIdProvider`).
*   **`supabase_flutter` (v2.x):** Utilizado para realizar operaciones CRUD directas en la base de datos de PostgreSQL e insertar/recuperar la propiedad `conversation_id`.
*   **`cached_network_image`:** Optimiza la renderización de las portadas de las tarjetas locales en los listados e inventarios de chats y grupos con almacenamiento en memoria caché.
*   **`audioplayers`:** Administra la reproducción de pronunciaciones de voz grabadas en las tarjetas del chat de forma asíncrona.

---

## 6. Guía de Reversión (Rollback)

Si en el futuro se decide eliminar la funcionalidad de cartas privadas y volver a un esquema 100% global, sigue estos pasos:

### Paso A: Base de Datos (Supabase)
Ejecuta la siguiente consulta SQL en tu editor SQL de Supabase para borrar la columna de relación:
```sql
-- Eliminar el índice de rendimiento
DROP INDEX IF EXISTS idx_word_cards_conversation;

-- Eliminar la columna de la tabla (borrará la restricción de llave foránea automáticamente)
ALTER TABLE word_cards DROP COLUMN IF EXISTS conversation_id;
```

### Paso B: Revertir Cambios en Código
1.  **`word_card_model.dart`:**
    *   Elimina la variable `conversationId` del constructor y las propiedades de la clase.
    *   Remueve la lectura de `conversation_id` en `fromJson` y `toJson`.
2.  **`navigation_provider.dart`:**
    *   Elimina el proveedor `pendingConversationIdProvider`.
3.  **`vocabulary_provider.dart`:**
    *   Elimina el filtro `.where((card) => card.conversationId == null || card.conversationId!.isEmpty)` en `userWordCardsFamilyProvider` y `correctWordCardsProvider`.
4.  **`create_card_screen.dart`:**
    *   Quita la lógica de `pendingConversationIdProvider` de los métodos `_prevStep`, `_saveCard` y del escuchador reactivo en `build`.
    *   Elimina el banner informativo verde del widget tree.
5.  **`chat_detail_screen.dart` y `group_detail_screen.dart`:**
    *   Quita el botón de cartas del AppBar de ambos archivos.
    *   Restaura los filtros de `matches` en `_showWordCard` para que solo comparen `w.word.toLowerCase() == cleanWord.toLowerCase()`.
    *   Elimina la sección visual del listado de cartas locales y la pestaña de cartas del grupo.
6.  **`word_detail_screen.dart`:**
    *   Remueve el parámetro `conversationId` y el filtro inicial sobre la colección `rawWordCards` en `data`.
