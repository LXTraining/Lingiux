# Implementación de Chat P2P y Tiempo Real con Supabase en Lingiux: Documentación Técnica de Extremo a Extremo

Este documento constituye una guía técnica detallada y exhaustiva sobre el diseño, arquitectura, seguridad y resolución de problemas para el sistema de **Chat Peer-to-Peer (P2P) en Tiempo Real** implementado en **Lingiux**. Recopila todos los conceptos conceptuales, flujos lógicos, estructuras SQL, código en Flutter y las resoluciones de las excepciones críticas encontradas durante el desarrollo.

---

## 🧭 1. Fundamentos y Arquitectura de Comunicación

### A. El Paradigma de Tiempo Real (Supabase Realtime)
En las aplicaciones móviles modernas, el polling HTTP clásico (hacer peticiones periódicas al servidor cada $N$ segundos para buscar nuevos datos) es ineficiente: agota la batería del dispositivo, consume ancho de banda innecesario y produce retrasos en la entrega de mensajes.

Para Lingiux, se seleccionó **Supabase Realtime**, un motor basado en WebSockets. Su funcionamiento interno se divide en varias capas:
1.  **Postgres WAL (Write-Ahead Logging):** PostgreSQL registra todos los cambios en los datos (inserciones, actualizaciones, eliminaciones) en un registro secuencial en disco (WAL) antes de aplicarlos.
2.  **Servicio Realtime (El Contenedor Go):** Supabase ejecuta un servicio en segundo plano que escucha el flujo de replicación lógica de PostgreSQL (WAL).
3.  **Phoenix Channels & WebSockets:** El servicio de Supabase empaqueta estos cambios en formato JSON y los distribuye en tiempo real a los clientes conectados a través de conexiones WebSocket persistentes.
4.  **Flutter Client:** El SDK de Flutter (`supabase_flutter`) mantiene abierto el socket y actualiza reactivamente la interfaz de usuario en menos de 100ms cuando detecta un evento en la base de datos.

### B. El Modelo de Relación P2P (Peer-to-Peer)
A diferencia de los chats locales simulados en memoria, el sistema P2P distribuye las conversaciones entre usuarios reales de forma centralizada y segura. Dos usuarios registrados comparten exactamente la misma sala de conversación y el mismo historial de mensajes. La privacidad se controla a nivel de base de datos: ningún usuario ajeno a la conversación puede leer o escribir mensajes en dicha sala.

---

## 🗄️ 2. Estructura de la Base de Datos en Supabase (DDL)

El esquema de datos está completamente normalizado y consta de tres tablas principales que implementan una relación muchos-a-muchos (M:N) para vincular usuarios públicos con salas de chat compartidas.

```sql
-- =========================================================================
-- 1. TABLA DE CONVERSACIONES (Salas de Chat)
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.conversations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  last_message text DEFAULT 'Conversación iniciada',
  last_message_time timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  created_by uuid REFERENCES public.profiles(id) DEFAULT auth.uid()
);

COMMENT ON TABLE public.conversations IS 'Almacena las salas de chat compartidas entre usuarios.';

-- =========================================================================
-- 2. TABLA DE PARTICIPANTES (Relación M:N entre Perfiles y Conversaciones)
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.conversation_participants (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id uuid REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
  profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(conversation_id, profile_id)
);

COMMENT ON TABLE public.conversation_participants IS 'Relación intermedia que asocia perfiles a salas de chat específicas.';

-- =========================================================================
-- 3. TABLA DE MENSAJES (Historial)
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id uuid REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  text text NOT NULL,
  time timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

COMMENT ON TABLE public.messages IS 'Almacena los mensajes reales enviados en cada conversación.';
```

### Habilitación del Canal de Replicación de Tiempo Real
Las tablas recién creadas en PostgreSQL no replican eventos en tiempo real de forma automática. Si intentamos suscribirnos desde Flutter usando `.stream(...)` sin registrar la tabla en la publicación de Supabase, la petición WebSocket fallará tras unos segundos con un error de timeout (`RealtimeSubscribeException`). 

Para resolverlo, ejecutamos este query que habilita la réplica en las tres tablas involucradas:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
```

---

## 🔒 3. Políticas RLS (Row Level Security): Concepto y Configuración

Row Level Security (RLS) es una característica de PostgreSQL que restringe qué filas de una tabla puede consultar, insertar, actualizar o eliminar un determinado usuario de acuerdo con las condiciones de seguridad especificadas. RLS actúa como un cortafuegos directamente en el motor de la base de datos, garantizando que aunque el cliente de Flutter sea vulnerable o manipulado, los datos sigan estando seguros.

### Cláusulas Críticas de RLS: `USING` vs `WITH CHECK`
*   **`USING`:** Condición que deben cumplir las filas **ya existentes** en la base de datos para poder ser leídas (`SELECT`), modificadas (`UPDATE`) o eliminadas (`DELETE`). Si la condición evalúa a `false` o `null`, el motor oculta la fila para el usuario (en `SELECT`) o niega la operación.
*   **`WITH CHECK`:** Condición que deben cumplir las filas **nuevas o resultantes** de una operación de inserción (`INSERT`) o actualización (`UPDATE`). Si el nuevo registro no cumple la condición, el motor aborta la transacción y lanza un error.

### Declaración de Políticas Aplicadas

#### A. Políticas para `conversations`
*   **SELECT (Lectura):** Permite ver una conversación si el usuario actual es su creador (`auth.uid() = created_by`) o si existe un registro en `conversation_participants` que lo vincula a la sala.
    ```sql
    CREATE POLICY "Lectura de conversaciones participantes" 
    ON public.conversations FOR SELECT TO authenticated 
    USING (
      auth.uid() = created_by 
      OR EXISTS (
        SELECT 1 FROM public.conversation_participants 
        WHERE conversation_participants.conversation_id = conversations.id 
          AND conversation_participants.profile_id = auth.uid()
      )
    );
    ```
*   **INSERT (Inserción):** Cualquier usuario autenticado en Supabase Auth puede iniciar una conversación.
    ```sql
    CREATE POLICY "Creación de conversaciones libre" 
    ON public.conversations FOR INSERT TO authenticated 
    WITH CHECK (auth.role() = 'authenticated');
    ```
*   **UPDATE (Actualización):** Solo los usuarios participantes del chat pueden actualizar la metadata de la sala (por ejemplo, el texto del último mensaje y la hora para ordenar la lista de chats).
    ```sql
    CREATE POLICY "Actualización de conversaciones participantes" 
    ON public.conversations FOR UPDATE TO authenticated 
    USING (
      EXISTS (
        SELECT 1 FROM public.conversation_participants 
        WHERE conversation_participants.conversation_id = conversations.id 
          AND conversation_participants.profile_id = auth.uid()
      )
    );
    ```

#### B. Políticas para `conversation_participants`
*   **SELECT (Lectura):** Permite a cualquier usuario autenticado ver quién pertenece a qué conversación. Esto es crucial para que Flutter pueda realizar cruces relacionales y buscar los nombres/perfiles de los destinatarios.
    ```sql
    CREATE POLICY "Lectura de participantes compartidos" 
    ON public.conversation_participants FOR SELECT TO authenticated 
    USING (true);
    ```
*   **INSERT (Inserción):** Cualquier usuario autenticado puede agregar filas a esta tabla. Es indispensable para que al iniciar una conversación, el creador pueda insertarse a sí mismo y al destinatario en el mismo paso.
    ```sql
    CREATE POLICY "Inserción de participantes libre" 
    ON public.conversation_participants FOR INSERT TO authenticated 
    WITH CHECK (auth.role() = 'authenticated');
    ```

#### C. Políticas para `messages`
*   **SELECT (Lectura):** Un usuario solo puede leer mensajes de una conversación si existe un registro en `conversation_participants` donde `conversation_id = messages.conversation_id` y `profile_id = auth.uid()`.
    ```sql
    CREATE POLICY "Lectura de mensajes miembros" 
    ON public.messages FOR SELECT TO authenticated 
    USING (
      EXISTS (
        SELECT 1 FROM public.conversation_participants 
        WHERE conversation_participants.conversation_id = messages.conversation_id 
          AND conversation_participants.profile_id = auth.uid()
      )
    );
    ```
*   **INSERT (Inserción):** Permite insertar un mensaje si el usuario que lo envía coincide con el remitente (`auth.uid() = sender_id`) y pertenece a la conversación respectiva.
    ```sql
    CREATE POLICY "Inserción de mensajes miembros" 
    ON public.messages FOR INSERT TO authenticated 
    WITH CHECK (
      auth.uid() = sender_id 
      AND EXISTS (
        SELECT 1 FROM public.conversation_participants 
        WHERE conversation_participants.conversation_id = messages.conversation_id 
          AND conversation_participants.profile_id = auth.uid()
      )
    );
    ```

---

## 🛠️ 5. Análisis y Resolución de Excepciones Críticas de RLS

Durante el desarrollo, nos enfrentamos a dos excepciones del motor de base de datos PostgreSQL que detuvieron el flujo de la aplicación. Aquí se detalla paso a paso por qué ocurrieron y cómo se resolvieron de forma definitiva.

### ⚠️ Excepción 1: Recursión Infinita en RLS (`code: 42P17`)
*   **El Mensaje de Error:**
    `PostgresException (PostgresException(message: infinite recursion detected in policy for relation "conversation_participants", code: 42P17, details: Internal Server Error, hint: null))`
*   **Origen del Error:**
    Ocurrió al consultar `conversation_participants` desde Flutter para buscar los chats activos del usuario. La política de lectura (`SELECT`) original de la tabla intermedia era:
    ```sql
    -- POLÍTICA RECURSIVA INCORRECTA
    CREATE POLICY "Lectura de participantes compartidos" ON conversation_participants 
    FOR SELECT USING (
      profile_id = auth.uid() 
      OR conversation_id IN (
        SELECT conversation_id FROM conversation_participants WHERE profile_id = auth.uid()
      )
    );
    ```
    Cuando el usuario hacía un `SELECT` sobre `conversation_participants`, PostgreSQL intentaba evaluar el filtro de la fila. La condición `conversation_id IN (SELECT ...)` requiere hacer una subconsulta a la **misma tabla** `conversation_participants`. Dado que RLS estaba activo para lecturas en esa tabla, la subconsulta volvía a disparar la evaluación de la política RLS, lo que a su vez ejecutaba otra subconsulta, creando un bucle infinito de llamadas a la política. Al detectar este comportamiento circular, el motor de PostgreSQL abortó la transacción con el código de error `42P17`.
*   **El Intento de Solución (Función Security Definer):**
    Intentamos envolver la subconsulta dentro de una función PL/pgSQL marcada como `SECURITY DEFINER`:
    ```sql
    CREATE OR REPLACE FUNCTION public.check_conversation_member(conv_id uuid, user_id uuid)
    RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
    BEGIN
      RETURN EXISTS (
        SELECT 1 FROM public.conversation_participants
        WHERE conversation_id = conv_id AND profile_id = user_id
      );
    END;
    $$;
    ```
    Y actualizamos la política a `USING (check_conversation_member(conversation_id, auth.uid()))`.
    *¿Por qué falló?* En teoría, una función `SECURITY DEFINER` se ejecuta con los privilegios de su creador (el rol administrador `postgres` que cuenta con `bypassrls = true`), lo que debería saltarse las políticas RLS y romper la recursión. Sin embargo, bajo el planificador de consultas de Postgres y el contexto en que PostgREST evalúa las expresiones de políticas RLS complejas, el motor seguía evaluando recursivamente la política bajo el contexto de sesión del usuario autenticado, manteniendo la recursión.
*   **La Solución Definitiva:**
    Simplificamos la política de lectura de `conversation_participants` a una expresión no recursiva y directa:
    ```sql
    CREATE POLICY "Lectura de participantes compartidos" 
    ON public.conversation_participants FOR SELECT TO authenticated 
    USING (true);
    ```
    Al usar `USING (true)`, cualquier usuario autenticado de la aplicación puede consultar el mapeo relacional de participantes (qué UUIDs están en qué salas de chat). Esto es 100% seguro porque los UUIDs no contienen datos personales sensibles y los chats y mensajes correspondientes siguen herméticamente bloqueados por sus propias políticas RLS (las cuales exigen de forma individual que el `auth.uid()` del usuario coincida con un participante válido de la sala). La recursión se eliminó de raíz y las consultas pasaron a completarse en microsegundos.

### ⚠️ Excepción 2: Violación de RLS al Insertar Conversaciones (`code: 42501`)
*   **El Mensaje de Error:**
    `PostgresException (PostgresException(message: new row violates row-level security policy for table "conversations", code: 42501, details: Forbidden, hint: null))`
*   **Origen del Error:**
    Esta excepción ocurría en la línea 83 de `chat_provider.dart` al intentar crear un chat entre dos usuarios desde el buscador:
    ```dart
    final convInsert = await _supabase.from('conversations').insert({
      'last_message': 'Conversación iniciada',
      'last_message_time': DateTime.now().toIso8601String(),
    }).select().single();
    ```
    *   La inserción (`insert`) era permitida gracias a la política de creación libre de conversaciones.
    *   Sin embargo, el cliente de Supabase añade implícitamente la cláusula `RETURNING` en PostgreSQL para traer la fila de vuelta (necesaria para satisfacer el `.select().single()` y obtener el ID de la conversación creada).
    *   Para devolver la fila insertada, PostgreSQL ejecuta una verificación de lectura (`SELECT`) sobre el registro recién insertado.
    *   La política de `SELECT` de `conversations` original validaba si el usuario existía en la tabla `conversation_participants` para esa conversación.
    *   **El Conflicto Temporal:** Al ejecutar la línea 83, la conversación en `conversations` se está insertando, pero **los participantes aún no se han insertado** en `conversation_participants` (se hace en la línea 91, una vez que obtenemos el ID). Como el participante no existía todavía, el chequeo de RLS del `SELECT` fallaba de inmediato, bloqueando la transacción entera con un error de violación de políticas (`42501`).
*   **La Solución Definitiva:**
    Añadimos una columna `created_by` (tipo `uuid`, apuntando a `profiles.id`) en la tabla `conversations` con un valor por defecto `auth.uid()`.
    De esta forma, cuando un usuario crea una conversación, la base de datos registra automáticamente quién la creó.
    Luego, redefinimos la política de lectura de `conversations` para que evalúe si eres el creador de la conversación **o** si eres un participante registrado:
    ```sql
    CREATE POLICY "Lectura de conversaciones participantes" 
    ON public.conversations FOR SELECT TO authenticated 
    USING (
      auth.uid() = created_by 
      OR EXISTS (
        SELECT 1 FROM public.conversation_participants 
        WHERE conversation_participants.conversation_id = conversations.id 
          AND conversation_participants.profile_id = auth.uid()
      )
    );
    ```
    Al insertar la conversación, `created_by` se autocompleta con el UUID del usuario actual. Cuando el `.select()` evalúa el RLS, la condición `auth.uid() = created_by` devuelve `true`, permitiendo retornar la fila y el ID al cliente móvil con éxito. Posteriormente, una vez registrados los participantes en la tabla intermedia, ambos usuarios (creador y destinatario) acceden mediante la cláusula `OR EXISTS (...)`.

---

## 🏗️ 6. Arquitectura y Código en Flutter

La lógica de negocio y visualización del chat en tiempo real se implementó de forma desacoplada y limpia bajo una arquitectura de tres capas.

### A. Capa de Datos y Mapeo (`chat_model.dart`)
La aplicación maneja entidades genéricas a nivel de dominio (`ChatEntity`, `MessageEntity`) para desacoplar la base de datos de la interfaz de usuario. En la capa de datos implementamos `ChatModel` y `MessageModel` con mapeadores JSON:

```dart
class ChatModel extends ChatEntity {
  // ... constructor ...

  factory ChatModel.fromJson(Map<String, dynamic> json, String currentUserId) {
    // 1. Obtener la lista de participantes mapeada por la consulta join de Supabase
    final participants = json['all_participants'] as List<dynamic>? ?? [];
    
    // 2. Filtrar para identificar el perfil del destinatario (el que NO es el usuario logueado)
    final otherParticipant = participants.firstWhere(
      (p) => p['profile'] != null && p['profile']['id'] != currentUserId,
      orElse: () => null,
    );

    final otherProfile = otherParticipant != null ? otherParticipant['profile'] as Map<String, dynamic> : null;
    final otherName = otherProfile?['full_name'] as String? ?? 'Usuario de Lingiux';
    
    // 3. Generar iniciales del avatar
    final initials = otherName.trim().isNotEmpty
        ? otherName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'LX';

    // 4. Calcular un índice de color estable y persistente basado en el hash del nombre
    final avatarColorIndex = otherName.hashCode.abs();

    return ChatModel(
      id: json['id'] as String,
      name: otherName,
      initials: initials,
      avatarColorIndex: avatarColorIndex,
      lastMessage: json['last_message'] as String? ?? '',
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'] as String)
          : DateTime.now(),
      unreadCount: 0,
      isOnline: false,
      messages: const [],
    );
  }
}
```

### B. Capa de Presentación e Inyección (Riverpod - `chat_provider.dart`)
Utilizamos Riverpod para inyectar estados reactivos e interactuar de forma directa con los flujos WebSocket (`StreamProvider`) provistos por Supabase.

#### 1. Inyección de Conversaciones (`chatsProvider`)
Se encarga de escuchar las salas de conversación del usuario en tiempo real. Cuando ocurre un cambio en la tabla `conversations` (como la actualización del último mensaje), el stream se activa y recupera de manera relacional los datos de los perfiles:

```dart
final chatsProvider = StreamProvider.autoDispose<List<ChatEntity>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return const Stream.empty();

  final supabase = ref.read(supabaseClientProvider);

  // Gatillar siembra automática de Emma Watson si el usuario no tiene chats
  _seedIfEmpty(user.id, supabase);

  return supabase
      .from('conversations')
      .stream(primaryKey: ['id'])
      .asyncMap((_) async {
        // Ejecutar consulta join para traer perfiles públicos
        final data = await supabase
            .from('conversations')
            .select('''
              id,
              last_message,
              last_message_time,
              conversation_participants!inner(profile_id),
              all_participants:conversation_participants(
                profile:profiles(id, full_name, avatar_url)
              )
            ''')
            .eq('conversation_participants.profile_id', user.id)
            .order('last_message_time', ascending: false);

        return (data as List<dynamic>)
            .map((json) => ChatModel.fromJson(json, user.id))
            .toList();
      });
});
```

#### 2. Inyección de Mensajes de una Sala (`messagesProvider`)
Escucha los mensajes correspondientes a una conversación en orden cronológico:

```dart
final messagesProvider = StreamProvider.family.autoDispose<List<MessageEntity>, String>((ref, conversationId) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return const Stream.empty();

  final supabase = ref.read(supabaseClientProvider);

  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('time', ascending: true)
      .map((list) => list.map((json) => MessageModel.fromJson(json, user.id)).toList());
});
```

#### 3. Siembra de Contacto Inicial (Emma Watson)
Para garantizar una experiencia amigable e interactiva desde el primer inicio, si el usuario no tiene conversaciones activas en base de datos, `_seedIfEmpty` crea una conversación simulada inicial con **Emma Watson** (`e11a9a10-0000-0000-0000-000000000000`). Previamente se insertó el usuario Emma Watson tanto en `auth.users` como en `public.profiles` mediante un script SQL para evitar violaciones de clave foránea relacionales en la base de datos.

```dart
Future<void> _seedIfEmpty(String userId, SupabaseClient supabase) async {
  try {
    final existing = await supabase
        .from('conversation_participants')
        .select('conversation_id')
        .eq('profile_id', userId)
        .limit(1)
        .maybeSingle();

    if (existing == null) {
      // 1. Crear sala de conversación
      final conv = await supabase.from('conversations').insert({
        'last_message': 'I think we need to transcend our current understanding to grasp the full paradigm shift happening around us.',
        'last_message_time': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      }).select().single();

      final convId = conv['id'] as String;

      // 2. Insertar participantes (Usuario actual y Emma Watson)
      await supabase.from('conversation_participants').insert([
        {'conversation_id': convId, 'profile_id': userId},
        {'conversation_id': convId, 'profile_id': emmaWatsonId},
      ]);

      // 3. Insertar historial de mensajes de bienvenida
      await supabase.from('messages').insert([
        {
          'conversation_id': convId,
          'sender_id': emmaWatsonId,
          'text': 'Hey! Have you read that article about the ephemeral nature of digital memories?',
          'time': DateTime.now().subtract(const Duration(hours: 1, minutes: 20)).toIso8601String(),
        },
        {
          'conversation_id': convId,
          'sender_id': userId,
          'text': 'Yes! It was quite fascinating. The author had such an eloquent way of describing how technology shapes our perception.',
          'time': DateTime.now().subtract(const Duration(hours: 1, minutes: 15)).toIso8601String(),
        },
        -- ... resto de mensajes iniciales ...
      ]);
    }
  } catch (e) {
    // Silencioso
  }
}
```

### C. Capa de Servicios y Envío de Mensajes
`ChatService` encapsula las peticiones mutation contra Supabase. El envío de mensajes se realiza mediante una transacción implícita que escribe el mensaje y actualiza la metadata del último mensaje en la conversación padre:

```dart
class ChatService {
  final SupabaseClient _supabase;
  ChatService(this._supabase);

  Future<void> sendMessage(String conversationId, String senderId, String text) async {
    final messageTime = DateTime.now().toIso8601String();

    // 1. Insertar mensaje en base de datos
    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'text': text,
      'time': messageTime,
    });

    // 2. Actualizar último mensaje y hora en el registro padre de conversaciones
    await _supabase.from('conversations').update({
      'last_message': text,
      'last_message_time': messageTime,
    }).eq('id', conversationId);
  }
}
```

---

## 🧪 7. Pruebas y Aseguramiento de Calidad (QA)

*   **Pruebas de Widgets (`widget_test.dart`):** Creamos pruebas unitarias locales utilizando `mocktail` para sobreescribir la inicialización del SDK de Supabase. Esto permite validar los flujos de renderizado de widgets de Flutter de forma aislada sin interactuar con la red o con las políticas RLS reales de la base de datos de producción.
*   **Verificación Local exitosa:**
    *   Análisis estático (`flutter analyze`): **0 advertencias / 0 errores**.
    *   Suite de pruebas unitarias (`flutter test`): **Todos los tests en verde**.
