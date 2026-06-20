# Documentación Completa: Autenticación, Perfil de Usuario y Aislamiento de Datos con Supabase

Este documento recopila de manera detallada todos los pasos, configuraciones, estructuras de base de datos, código de Flutter y resolución de errores aplicados durante la implementación del sistema de **Autenticación (Paso 1)** y el **Aislamiento de Vocabulario y Chats por Usuario (Paso 2)** en **Lingiux**.

---

## 🔐 PASO 1: Autenticación de Usuarios, Perfil y Cierre de Sesión

El primer paso consistió en asegurar el acceso a la aplicación, crear perfiles para los nuevos usuarios de manera automática y diseñar una sección premium de perfil donde se pudiera cerrar la sesión.

### A. Base de Datos en Supabase
Para enlazar los usuarios registrados de Supabase Auth con los datos de nuestra base de datos, se realizaron los siguientes cambios a través del editor SQL:

1.  **Tabla de Perfiles (`public.profiles`):**
    ```sql
    CREATE TABLE IF NOT EXISTS public.profiles (
      id uuid REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
      updated_at timestamp with time zone,
      username text UNIQUE,
      full_name text,
      avatar_url text,
      target_language text DEFAULT 'Inglés',
      streak_count integer DEFAULT 0,
      created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
    );
    ```
2.  **Sincronización Automática (Trigger):**
    Se creó una función trigger `handle_new_user()` que escucha inserciones en `auth.users` (gestionadas por Supabase Auth) y crea en cascada una fila en `public.profiles` con el correo y los metadatos del usuario:
    ```sql
    CREATE OR REPLACE FUNCTION public.handle_new_user()
    RETURNS trigger AS $$
    BEGIN
      INSERT INTO public.profiles (id, full_name, avatar_url, target_language)
      VALUES (
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name', ''),
        coalesce(new.raw_user_meta_data->>'avatar_url', ''),
        'Inglés'
      );
      RETURN new;
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    CREATE OR REPLACE TRIGGER on_auth_user_created
      AFTER INSERT ON auth.users
      FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
    ```
3.  **Seguridad RLS (Row Level Security):**
    ```sql
    ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "Permitir lectura pública de perfiles" ON public.profiles FOR SELECT USING (true);
    CREATE POLICY "Permitir actualización de perfil propio" ON public.profiles FOR UPDATE USING (auth.uid() = id);
    ```

### B. Configuraciones Críticas del Dashboard de Supabase
Durante el desarrollo, detectamos y resolvimos dos restricciones predeterminadas de Supabase Auth:
*   **Confirmación de Email obligatoria:** Por defecto, Supabase no deja iniciar sesión a cuentas nuevas hasta que abran un enlace de confirmación por correo. **Solución:** Desactivar **Confirm email** en *Authentication > Providers > Email* de la consola.
*   **Límites de registros por hora (Rate Limits):** Supabase bloquea peticiones consecutivas con el error `email rate limit exceeded`. **Solución:** Aumentar los límites temporales en la pestaña *Authentication > Rate Limits* del Dashboard.

### C. Refactorización en Flutter
*   **Control del Estado (`auth_provider.dart`):** Creamos `AuthState` y `AuthNotifier` bajo Riverpod, escuchando en tiempo real cambios de sesión con `onAuthStateChange`. Se implementó el método `dispose()` para limpiar `_authSubscription` y evitar fugas de memoria.
*   **Rutas Dinámicas (`app_router.dart`):** Refactorizamos el router en un Riverpod `routerProvider`. Añadimos guards en la propiedad `redirect` de GoRouter:
    *   Si no estás logueado e intentas ir al Home, te envía a `/login`.
    *   Si ya estás logueado e intentas entrar a login/registro, te redirige al Home `/`.
*   **Vistas de Entrada (`LoginScreen` / `SignUpScreen`):** Desarrolladas con fondos degradados modernos, haptic feedback al interactuar y SnackBars flotantes en caso de error.
*   **Pestaña de Perfil (`ProfileScreen`):** Rediseñada como `ConsumerWidget`. Muestra la racha de días, el idioma objetivo, progreso y un engranaje en el AppBar que abre un `ModalBottomSheet` con el botón de **Cerrar sesión** (`signOut`).

---

## 🛡️ PASO 2: Aislamiento y Persistencia de Vocabulario y Chats por Usuario

El segundo paso se centró en independizar los datos de cada usuario para que solo visualicen sus propias tarjetas y conversaciones privadas de chat, sustituyendo los datos en memoria por base de datos real en Supabase.

### A. Estructuración SQL para Aislamiento de Datos
Se ejecutaron comandos SQL para modificar `word_cards` y crear las tablas de chats y mensajería en tiempo real:

```sql
-- 1. Tarjetas de vocabulario (word_cards)
ALTER TABLE public.word_cards 
ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.word_cards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir lectura de tarjetas propias o del sistema"
ON public.word_cards FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Permitir inserción de tarjetas propias"
ON public.word_cards FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Permitir actualización/eliminación de tarjetas propias"
ON public.word_cards FOR UPDATE USING (auth.uid() = user_id);

-- 2. Tabla de Chats (chats)
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

ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
-- Políticas RLS para chats propios
CREATE POLICY "Permitir lectura de chats propios" ON public.chats FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Permitir inserción/edición de chats propios" ON public.chats FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Permitir actualización de chats propios" ON public.chats FOR UPDATE USING (auth.uid() = user_id);

-- 3. Tabla de Mensajes (messages)
CREATE TABLE IF NOT EXISTS public.messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id uuid REFERENCES public.chats(id) ON DELETE CASCADE NOT NULL,
  text text NOT NULL,
  is_me boolean NOT NULL,
  time timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
-- Políticas RLS cruzadas (valida que el chat_id pertenezca al usuario autenticado)
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

### B. ⚠️ Solución al Error de Realtime (`RealtimeSubscribeException`)
*   **El Problema:** Al ingresar a la pestaña de chats por primera vez, el flujo WebSocket tiraba el error `RealtimeSubscribeException(status: RealtimeSubscribeStatus.timeOut, details: null)`. Esto sucede porque en Supabase, las tablas recién creadas **no retransmiten cambios por Realtime por defecto** y las suscripciones de la app mediante `.stream(...)` fallan por timeout.
*   **La Solución:** Publicar explícitamente las tablas en la publicación de tiempo real de Supabase (`supabase_realtime`) ejecutando este query SQL:
    ```sql
    alter publication supabase_realtime add table public.chats;
    alter publication supabase_realtime add table public.messages;
    ```

### C. Proveedores Reactivos y Siembras en Flutter
*   **Modelos de Datos:** Creamos [chat_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/data/models/chat_model.dart) con `ChatModel` y `MessageModel` heredando de las entidades de dominio originales para evitar tener que refactorizar los componentes de la interfaz de usuario.
*   **Query de Vocabulario:** [vocabulary_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/providers/vocabulary_provider.dart) filtra las tarjetas usando `.or('user_id.eq.${user.id},user_id.is.null')`, permitiendo ver las tarjetas creadas por el usuario autenticado Y las tarjetas compartidas del sistema (donde `user_id` es null).
*   **Lógica de Flujo de Chats (`chat_provider.dart`):**
    *   `chatsProvider` (StreamProvider) escucha a la tabla `chats` en tiempo real filtrando por el `user_id` de la sesión activa.
    *   **Siembra Inicial (Emma Watson):** Si la lista de chats devuelta por la base de datos está vacía, se ejecuta una función asíncrona interna en segundo plano (`_seedIfEmpty`) que inserta **únicamente 1 contacto inicial (Emma Watson)** y su conversación introductoria en la base de datos para ese usuario.
    *   `messagesProvider(chatId)` (StreamProvider) escucha el historial de mensajes ordenado cronológicamente.
    *   `ChatService` expone la función `sendMessage` que inserta un mensaje e inmediatamente actualiza la metadata del último mensaje y fecha en el chat padre.
*   **UI Dinámica:** Convertimos [chats_list_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chats_list_screen.dart) y [chat_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart) a widgets de Riverpod, consumiendo los nuevos StreamProviders y despachando mensajes directamente a Supabase de manera persistente en lugar de guardarlos en estados en memoria temporales.

---

## 📂 4. Resumen de Archivos Modificados y Creados

| Tipo | Archivo / Enlace | Descripción |
| :--- | :--- | :--- |
| **Creado** | [auth_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/auth/presentation/providers/auth_provider.dart) | Gestor de la sesión de Supabase Auth con listeners reactivos. |
| **Creado** | [login_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/auth/presentation/screens/login_screen.dart) | Pantalla de inicio de sesión premium con diseño Glassmorphism. |
| **Creado** | [signup_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/auth/presentation/screens/signup_screen.dart) | Pantalla de registro de usuario enlazada con metadatos. |
| **Creado** | [profile_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/providers/profile_provider.dart) | Proveedor reactivo de perfil asíncrono con fallback a metadatos locales. |
| **Modificado** | [profile_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/screens/profile_screen.dart) | Diseño premium del perfil, estadísticas del estudiante y ModalBottomSheet de cierre de sesión. |
| **Creado** | [chat_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/data/models/chat_model.dart) | Mapeadores JSON de Supabase para chats y mensajes. |
| **Creado** | [chat_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/providers/chat_provider.dart) | StreamProviders de chats y mensajes en tiempo real, con lógica de siembra para 1 contacto. |
| **Modificado** | [vocabulary_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/providers/vocabulary_provider.dart) | Filtrado reactivo de tarjetas por ID de usuario. |
| **Modificado** | [create_card_form_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_form_screen.dart) | Inserción automática del ID de usuario al crear tarjetas. |
| **Modificado** | [chats_list_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chats_list_screen.dart) | Lista de chats adaptada a Riverpod y Supabase. |
| **Modificado** | [chat_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart) | Historial de mensajes conectado a streams en tiempo real de la base de datos. |
| **Modificado** | [widget_test.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/test/widget_test.dart) | Pruebas aisladas con mocktail sobreescribiendo el cliente de Supabase para tests locales. |

---

## 🧪 5. Pruebas de Calidad Realizadas
*   **Flutter Analyze:** Código libre de advertencias y errores en los nuevos módulos creados.
*   **Flutter Test:** Suite de pruebas del widget de humo ejecutado localmente de forma exitosa (`All tests passed!`).
