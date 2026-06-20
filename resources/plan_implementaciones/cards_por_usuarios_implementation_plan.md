# Plan de Implementación: Asociación y Aislamiento de Vocabulario y Chats por Usuario

Este plan detalla los pasos para modificar la base de datos de Supabase y refactorizar la aplicación en Flutter para que cada usuario tenga su propio conjunto aislado de tarjetas de vocabulario y su historial único de chats.

---

## User Review Required

> [!IMPORTANT]
> **Creación de Tablas para Chats en Supabase:**
> Actualmente, los chats y mensajes en la app se manejan 100% en memoria con datos locales simulados (`mockChats`). Para poder asociar los chats a cada usuario en la base de datos, **crearemos dos nuevas tablas en Supabase:** `public.chats` y `public.messages`, y reescribiremos la lógica en Flutter para que consuma estos datos en tiempo real de Supabase en lugar del archivo estático.
>
> **Migración de Datos Existentes:**
> Al agregar `user_id` como obligatorio o habilitar RLS en `word_cards`, las tarjetas existentes en la base de datos que no tengan asociado un usuario podrían no ser visibles para nadie. Se propone asociar todas las tarjetas existentes al primer usuario administrador o dejarlas como "tarjetas del sistema" visibles para todos, mientras que las nuevas tarjetas creadas por los usuarios serán estrictamente privadas.

---

## Open Questions

> [!IMPORTANT]
> **Inicialización de Chats para Nuevos Usuarios (Seeding):**
> ¿Deseas que al registrarse o iniciar sesión por primera vez un usuario se inicialicen automáticamente los 5 chats de prueba (Emma Watson, Carlos Mendez, etc.) en su base de datos para que tenga conversaciones con las que interactuar?
> * **Opción A (Recomendada):** Sí, crear automáticamente los 5 contactos simulados en la base de datos `chats` específicos para ese usuario al iniciar sesión por primera vez, permitiéndole chatear de forma persistente.
> * **Opción B:** No, iniciar con la pantalla de chats completamente vacía y requerir una acción futura para agregar contactos.

---

## Proposed Changes

### 1. Base de Datos (Supabase SQL)

Proponemos ejecutar el siguiente bloque de SQL en Supabase para reestructurar las tablas y configurar la seguridad de fila (RLS):

```sql
-- A. Modificar la tabla word_cards para asociarla al usuario
ALTER TABLE public.word_cards 
ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Habilitar RLS en word_cards
ALTER TABLE public.word_cards ENABLE ROW LEVEL SECURITY;

-- Crear políticas RLS para word_cards
CREATE POLICY "Permitir lectura de tarjetas propias"
ON public.word_cards FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Permitir inserción de tarjetas propias"
ON public.word_cards FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Permitir actualización de tarjetas propias"
ON public.word_cards FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Permitir eliminación de tarjetas propias"
ON public.word_cards FOR DELETE USING (auth.uid() = user_id);


-- B. Crear la tabla de chats en la base de datos
CREATE TABLE IF NOT EXISTS public.chats (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  initials text NOT NULL,
  avatar_color_index integer DEFAULT 0 NOT NULL,
  last_message text DEFAULT '',
  last_message_time timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  unread_count integer DEFAULT 0 NOT NULL,
  is_online boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar RLS en chats
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para chats
CREATE POLICY "Permitir lectura de chats propios"
ON public.chats FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Permitir inserción de chats propios"
ON public.chats FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Permitir actualización de chats propios"
ON public.chats FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Permitir eliminación de chats propios"
ON public.chats FOR DELETE USING (auth.uid() = user_id);


-- C. Crear la tabla de mensajes en la base de datos
CREATE TABLE IF NOT EXISTS public.messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id uuid REFERENCES public.chats(id) ON DELETE CASCADE NOT NULL,
  text text NOT NULL,
  is_me boolean NOT NULL,
  time timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar RLS en mensajes
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para mensajes
CREATE POLICY "Permitir lectura de mensajes del chat propio"
ON public.messages FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.chats 
    WHERE chats.id = messages.chat_id AND chats.user_id = auth.uid()
  )
);

CREATE POLICY "Permitir inserción de mensajes en chat propio"
ON public.messages FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.chats 
    WHERE chats.id = messages.chat_id AND chats.user_id = auth.uid()
  )
);
```

---

### 2. Modelos de Datos en Flutter

#### [MODIFY] [word_card_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/domain/models/word_card_model.dart)
*   Añadir la propiedad `userId` (String?, nullable) al modelo y sus métodos `fromJson` y `toJson`.

#### [NEW] [chat_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/data/models/chat_model.dart)
*   Crear la clase `ChatModel` y `MessageModel` con métodos `fromJson` y `toJson` para mapear los datos de Supabase a las entidades de UI (`ChatEntity` y `MessageEntity`).

---

### 3. Capa de Lógica y Proveedores (Riverpod)

#### [MODIFY] [vocabulary_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/providers/vocabulary_provider.dart)
*   Modificar `wordCardsProvider` para que escuche a `authProvider`.
*   Filtrar las tarjetas en la consulta de Supabase para traer solo las pertenecientes al usuario actual o las compartidas (`user_id.eq(currentUser.id)`).

#### [NEW] [chat_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/providers/chat_provider.dart)
*   Crear `chatsProvider` (StreamProvider) que escuche en tiempo real a la tabla `chats` de Supabase filtrando por el `user_id` del usuario logueado.
*   Crear una función/provider para inicializar los 5 chats simulados en la base de datos si la consulta de chats retorna vacía (seeding automático).
*   Crear `messagesProvider(chatId)` (StreamProvider) que escuche los mensajes de un chat específico en tiempo real ordenados por fecha.
*   Exponer un método `sendMessage(String chatId, String text)` para insertar un nuevo mensaje en la tabla `messages` y actualizar el campo `last_message` en la tabla `chats`.

---

### 4. Capa de UI y Presentación

#### [MODIFY] [create_card_form_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_form_screen.dart)
*   Al insertar una tarjeta en `word_cards`, incluir el campo `'user_id': supabase.auth.currentUser?.id`.

#### [MODIFY] [chats_list_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chats_list_screen.dart)
*   Convertir a `ConsumerStatefulWidget`.
*   Reemplazar la lectura de `mockChats` por el consumo del `chatsProvider` de forma reactiva, mostrando un indicador de carga mientras se obtienen de Supabase.

#### [MODIFY] [chat_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart)
*   Consumir los mensajes en tiempo real desde `messagesProvider(chatId)` a través de un widget tipo `StreamBuilder` o `ref.watch(messagesProvider)`.
*   Refactorizar el método `_sendMessage()` para guardar el mensaje directamente en Supabase a través del provider, en lugar de mutar un estado local temporal.

---

## Verification Plan

### Automated Tests
*   Ejecutar `flutter analyze` para verificar la coherencia estática del código.
*   Ejecutar `flutter test` para validar que las refactorizaciones no hayan roto las pruebas unitarias y de humo de widgets.

### Manual Verification
1.  **Aislamiento de Cartas:** Iniciar sesión con el **Usuario A**, crear una tarjeta "Serendipity" con audio. Cerrar sesión e iniciar con el **Usuario B**; verificar que el listado de tarjetas del Usuario B esté vacío o no muestre las del Usuario A.
2.  **Aislamiento de Chats:** Enviar un mensaje de chat con el **Usuario A**, cerrar sesión y validar que el **Usuario B** tenga una conversación completamente limpia e independiente en su base de datos.
3.  **Persistencia:** Cerrar completamente la app y reabrirla para asegurar que los mensajes enviados sigan mostrándose (confirmando el correcto flujo desde base de datos).
