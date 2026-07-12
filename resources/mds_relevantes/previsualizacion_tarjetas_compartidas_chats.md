# Previsualización de Tarjetas Compartidas en la Bandeja de Chats

Este documento detalla la especificación técnica, la base de datos en Supabase, los proveedores en Riverpod y las modificaciones de UI implementadas para limpiar y formatear la miniatura del último mensaje en la bandeja exterior de chats cuando se comparte una tarjeta de vocabulario.

---

## 🧐 1. ¿Por qué se veía un texto crudo y cómo lo solucionamos?

### El problema:
Cuando compartías una tarjeta dentro de una conversación, el sistema enviaba un mensaje especial formateado como `[CARD]:palabra:cardId`. 

Al salir a la bandeja exterior de chats, la miniatura mostraba el texto crudo directamente desde la base de datos (por ejemplo, `[CARD]:thhthhht`), lo cual resultaba confuso y estropeaba la estética premium de la interfaz de usuario.

### La solución profesional:
Implementamos un formateador dinámico a nivel de cliente en la bandeja de chats. Para saber quién envió la tarjeta y personalizar el mensaje, agregamos una columna en la base de datos que registra el ID del remitente del último mensaje y adaptamos el tile del chat en Flutter.

---

## 🗄️ 2. Modificaciones en la Base de Datos (Supabase)

Para persistir la identidad del autor del último mensaje enviado, agregamos la columna `last_message_sender_id` a la tabla `conversations` de Supabase ejecutando la siguiente consulta SQL:

```sql
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS last_message_sender_id UUID REFERENCES public.profiles(id);
```

---

## 📦 3. Sincronización de Entidades, Modelos y Servicios

### A. [chat_entity.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/domain/entities/chat_entity.dart)
Añadimos la propiedad opcional `lastMessageSenderId` de tipo `String?` al constructor y a los campos de la clase `ChatEntity`.

### B. [chat_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/data/models/chat_model.dart)
Actualizamos el factory `ChatModel.fromJson` para mapear la nueva columna de base de datos desde la respuesta JSON:
```dart
final lastMessageSenderId = json['last_message_sender_id'] as String?;
```

### C. [chat_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/providers/chat_provider.dart)
*   **Consulta Select**: Modificamos `chatsProvider` para añadir `last_message_sender_id` dentro del select del stream.
*   **Servicio de Chat**: Modificamos el método `sendMessage` en la clase `ChatService` para actualizar de forma concurrente el ID del remitente al enviar un mensaje:
    ```dart
    await _supabase.from('conversations').update({
      'last_message': text.trim(),
      'last_message_time': now.toIso8601String(),
      'last_message_sender_id': senderId, // <-- Registra el autor del mensaje
    }).eq('id', conversationId);
    ```

---

## 📺 4. Formateador Dinámico en la Interfaz de Usuario

Para formatear dinámicamente el último mensaje en la celda del chat de [chats_list_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chats_list_screen.dart):

1.  **Conversión a ConsumerWidget**:
    Convertimos la clase privada `_ChatListTile` de `StatelessWidget` a `ConsumerWidget` para poder acceder al estado del usuario logueado (`authProvider`).
2.  **Método Formateador (`_formatLastMessage`)**:
    Añadimos la función que evalúa el formato del mensaje:
    ```dart
    String _formatLastMessage(ChatEntity chat, String currentUserId) {
      if (chat.lastMessage.startsWith('[CARD]:')) {
        final isMe = chat.lastMessageSenderId == currentUserId;
        return isMe 
            ? 'Has compartido una tarjeta' 
            : '${chat.name} ha compartido una tarjeta';
      }
      return chat.lastMessage;
    }
    ```
    Si el último mensaje es del usuario actual, el sistema muestra `"Has compartido una tarjeta"`. Si fue enviado por el compañero de chat, muestra `"[Nombre] ha compartido una tarjeta"` (por ejemplo: `"Pepito ha compartido una tarjeta"`).

---

## 📂 5. Archivos Modificados

### [NUEVO] [previsualizacion_tarjetas_compartidas_chats.md](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/resources/mds_relevantes/previsualizacion_tarjetas_compartidas_chats.md)
*   Documentación técnica de la funcionalidad.

### [MODIFY] [chat_entity.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/domain/entities/chat_entity.dart)
*   Añadido el campo `lastMessageSenderId`.

### [MODIFY] [chat_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/data/models/chat_model.dart)
*   Mapeo de la columna `last_message_sender_id` desde JSON.

### [MODIFY] [chat_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/providers/chat_provider.dart)
*   Actualización de la consulta select y actualización de la columna del remitente al guardar mensajes.

### [MODIFY] [chats_list_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chats_list_screen.dart)
*   Refactorización a `ConsumerWidget` y adición del formateador dinámico de texto para tarjetas compartidas.
