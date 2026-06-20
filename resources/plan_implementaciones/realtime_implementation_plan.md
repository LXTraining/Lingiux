# Plan de Implementación: Chat P2P en Tiempo Real entre Usuarios Reales

Este plan detalla los pasos para transformar el módulo de chat de una simulación de un solo lado (mock) a un sistema de chat **Peer-to-Peer (P2P) real** en la base de datos de Supabase, permitiendo que múltiples usuarios reales registrados chateen entre sí en tiempo real.

---

## User Review Required

> [!IMPORTANT]
> **Cambio Arquitectónico en la Base de Datos:**
> Reemplazaremos la tabla simple de `chats` por una estructura relacional normalizada y profesional:
> 1. `conversations` (Salas de conversación compartidas).
> 2. `conversation_participants` (Tabla intermedia que une usuarios a las salas).
> 3. `messages` (Mensajes asociados a la sala y con la autoría de un remitente `sender_id`).
>
> **Buscador de Usuarios para Chatear:**
> Para poder iniciar un chat entre los dos usuarios reales que tienes registrados, habilitaremos el botón de redactar (icono de lápiz/editar `Icons.edit_outlined` arriba a la derecha de la lista de chats) para que abra un modal de búsqueda de usuarios. Desde ahí se listarán los demás perfiles registrados y al hacer clic sobre uno se creará o abrirá la conversación común.

---

## Proposed Changes

### 1. Base de Datos (Supabase SQL)
Ejecutaremos el siguiente script para limpiar las tablas temporales del Paso 2 e implementar el modelo de chat P2P:

```sql
-- A. Eliminar tablas previas de chat unidireccional
DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.chats CASCADE;

-- B. Crear tabla de conversaciones (salas)
CREATE TABLE public.conversations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  last_message text DEFAULT '',
  last_message_time timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- C. Crear tabla de participantes de conversación
CREATE TABLE public.conversation_participants (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id uuid REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
  profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(conversation_id, profile_id)
);

-- D. Crear tabla de mensajes vinculada a la conversación y remitente
CREATE TABLE public.messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id uuid REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  text text NOT NULL,
  time timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- E. Habilitar RLS en todas las tablas
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- F. Definir Políticas de RLS
-- Conversaciones: Lectura y actualización solo para participantes
CREATE POLICY "Lectura de conversaciones participantes" ON public.conversations
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.conversation_participants
    WHERE conversation_participants.conversation_id = conversations.id
    AND conversation_participants.profile_id = auth.uid()
  )
);

CREATE POLICY "Creación de conversaciones libre" ON public.conversations
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Actualización de conversaciones participantes" ON public.conversations
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.conversation_participants
    WHERE conversation_participants.conversation_id = conversations.id
    AND conversation_participants.profile_id = auth.uid()
  )
);

-- Participantes: Lectura solo si eres miembro de la misma conversación; Inserción libre para autenticados
CREATE POLICY "Lectura de participantes compartidos" ON public.conversation_participants
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.conversation_participants cp
    WHERE cp.conversation_id = conversation_participants.conversation_id
    AND cp.profile_id = auth.uid()
  )
);

CREATE POLICY "Inserción de participantes libre" ON public.conversation_participants
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Mensajes: Lectura e Inserción solo si eres participante de la conversación
CREATE POLICY "Lectura de mensajes miembros" ON public.messages
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.conversation_participants
    WHERE conversation_participants.conversation_id = messages.conversation_id
    AND conversation_participants.profile_id = auth.uid()
  )
);

CREATE POLICY "Inserción de mensajes miembros" ON public.messages
FOR INSERT WITH CHECK (
  auth.uid() = sender_id
  AND EXISTS (
    SELECT 1 FROM public.conversation_participants
    WHERE conversation_participants.conversation_id = messages.conversation_id
    AND conversation_participants.profile_id = auth.uid()
  )
);

-- G. Habilitar Replicación Realtime
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.conversation_participants;
alter publication supabase_realtime add table public.messages;
```

---

### 2. Modelos en Flutter

#### [MODIFY] [chat_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/data/models/chat_model.dart)
*   Actualizar `ChatModel` para parsear la respuesta relacional de Supabase:
    *   Extraerá el ID de la conversación, el último mensaje y fecha.
    *   Buscará entre los participantes de la conversación a la persona que **no** es el usuario actual, y mapeará su nombre, iniciales y foto para construir el `ChatEntity` que requiere la UI.
*   Actualizar `MessageModel` para incluir el campo `senderId` y mapear `isMe` dinámicamente comparando `senderId == auth.uid`.

---

### 3. Capa de Lógica (Riverpod Providers)

#### [MODIFY] [chat_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/providers/chat_provider.dart)
*   **`chatsProvider`**: Escuchará en tiempo real (mediante Stream) las conversaciones del usuario actual haciendo una consulta relacional con inner joins para filtrar solo donde participe.
*   **`messagesProvider(conversationId)`**: Escuchará en tiempo real la tabla `messages` filtrada por `conversation_id`.
*   **`ChatService`**:
    *   `sendMessage(conversationId, text)`: Insertará el mensaje con `sender_id = auth.uid` y actualizará el campo `last_message` en la conversación.
    *   `createConversation(otherUserId)`: Creará una nueva sala, insertará a ambos usuarios como participantes y retornará el ID de la conversación.
    *   `searchProfiles(query)`: Método para buscar otros usuarios en la tabla `profiles` para iniciar chats.

---

### 4. Interfaces de Usuario (UI)

#### [MODIFY] [chats_list_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chats_list_screen.dart)
*   Configurar el `IconButton` de edición (`Icons.edit_outlined`) para abrir un Modal Bottom Sheet de búsqueda.
*   Diseñar el Modal de Búsqueda que liste los perfiles disponibles de Supabase y permita iniciar/abrir la conversación al seleccionarlos.

#### [MODIFY] [chat_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart)
*   Conectar el envío de mensajes al `ChatService` pasando el `sender_id` correcto.

---

## Verification Plan

### Automated Tests
*   Ejecutar `flutter analyze` y `flutter test` para validar la compilación y correcto funcionamiento general.

### Manual Verification
1.  **Iniciar Conversación:** Iniciar sesión con el **Usuario A**, presionar el botón de redactar chat, buscar al **Usuario B** en la lista y enviarle un mensaje.
2.  **Recepción Realtime:** Iniciar sesión con el **Usuario B** en otro dispositivo o simulador y comprobar que el chat aparece en la lista con el último mensaje al instante, y que al abrirlo recibe los mensajes en tiempo real.
