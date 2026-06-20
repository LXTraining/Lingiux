# Implementación del Sistema de Autenticación y Perfil con Supabase

Este documento detalla paso a paso cómo se implementó el sistema de autenticación de usuarios y el perfil interactivo en **Lingiux**, conectando la aplicación de Flutter con Supabase Auth y Database.

---

## 🏛️ 1. Configuración del Backend en Supabase

Para mantener sincronizados los usuarios del módulo de autenticación con nuestra base de datos relacional y habilitar la seguridad, realizamos las siguientes modificaciones:

### A. Tabla de Perfiles Públicos (`public.profiles`)
Se creó una tabla para almacenar los datos públicos de los usuarios, vinculada mediante una clave foránea en cascada a la tabla de usuarios del sistema de Supabase (`auth.users`).

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

### B. Seguridad a Nivel de Fila (RLS)
Se habilitaron políticas de RLS para proteger los perfiles:
*   **Lectura:** Permitida de manera pública para todos los usuarios autenticados.
*   **Escritura/Actualización:** Únicamente permitida al propietario del perfil (`auth.uid() = id`).

```sql
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir lectura pública de perfiles" 
ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Permitir actualización individual de perfil propio" 
ON public.profiles FOR UPDATE USING (auth.uid() = id);
```

### C. Automatización de Perfiles (Trigger)
Creamos una función y un trigger en Supabase para que cada vez que un usuario nuevo se registre a través del formulario de la aplicación, se cree inmediatamente su fila correspondiente en la tabla `profiles` con los datos proporcionados (como el nombre completo).

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

---

## ⚙️ 2. Ajustes Clave en el Consola de Supabase (Evitar Errores Comunes)

Durante las pruebas iniciales surgieron dos bloqueos comunes de seguridad de Supabase Auth: la verificación obligatoria por correo y el límite de envíos de correo.

### A. Desactivación de Confirmación por Correo ("Confirm Email")
Por defecto, Supabase requiere que los usuarios verifiquen su correo antes de poder iniciar sesión. En entornos de desarrollo, esto bloquea los logins de prueba rápidos.
*   **Solución:** En el Panel de Supabase, ve a **Authentication 🔑 > Providers > Email** y desactiva la opción **Confirm email**. De este modo, los usuarios se registran y quedan marcados como confirmados inmediatamente.

### B. Límite de Velocidad de Emails ("Email Rate Limit Exceeded")
Supabase restringe el envío masivo de correos de confirmación/registro a aproximadamente 3 por hora por IP para mitigar el spam de bots.
*   **Solución:** En **Authentication 🔑 > Rate Limits**, se pueden incrementar los límites de envíos por hora durante la fase de desarrollo para evitar bloqueos del servicio al registrar múltiples cuentas de prueba consecutivas.

---

## 💻 3. Arquitectura y Código en Flutter

El flujo de autenticación en la app se divide en proveedores de estado, controladores de rutas dinámicas y componentes visuales premium.

### A. Proveedores de Estado y Lógica (Riverpod)

1.  **Módulo de Autenticación:** [auth_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/auth/presentation/providers/auth_provider.dart)
    *   `AuthState` gestiona el estado reactivo (`isLoading`, `user`, `session`, `errorMessage`).
    *   `AuthNotifier` se conecta al cliente de Supabase y escucha en tiempo real el Stream `onAuthStateChange`. Asigna este flujo a `_authSubscription` y lo cancela en `dispose()` para prevenir fugas de memoria.
    *   Expone las funciones `signIn(email, password)`, `signUp(email, password, fullName)` y `signOut()`.

2.  **Módulo del Perfil:** [profile_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/providers/profile_provider.dart)
    *   Expone un `FutureProvider` que lee la fila del usuario en la tabla `profiles` mediante consulta asíncrona.
    *   Escucha al `authProvider`. Si hay un cambio de sesión (login/logout), invalida los datos antiguos y recarga el perfil correspondiente de manera automática.

### B. Enrutamiento Protegido (GoRouter & Guards)
*   **Archivo:** [app_router.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/core/router/app_router.dart)
*   Se refactorizó el enrutamiento para ser un provider de Riverpod (`routerProvider`).
*   Implementamos **Guards** reactivos en la propiedad `redirect` de GoRouter:
    ```dart
    redirect: (context, state) {
      final isLoggedIn = authState.user != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSigningUp = state.matchedLocation == '/signup';

      if (!isLoggedIn && !isLoggingIn && !isSigningUp) return '/login'; // Forzar login
      if (isLoggedIn && (isLoggingIn || isSigningUp)) return '/';       // Forzar Home
      return null;
    }
    ```
*   **Archivo:** [app.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/app.dart)
    *   `LingiuxApp` pasa a ser un `ConsumerWidget` que inyecta la configuración del `routerProvider`.

### C. Interfaces de Usuario Premium

1.  **Inicio de Sesión y Registro:**
    *   **Archivos:** [login_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/auth/presentation/screens/login_screen.dart) y [signup_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/auth/presentation/screens/signup_screen.dart)
    *   **Diseño:** Fondos degradados violeta/índigo, círculos de brillo de fondo, tarjetas estilo Glassmorphism sutil para los formularios, soporte de respuesta táctil (`HapticFeedback`) y validación instantánea de campos con visualización de errores mediante `SnackBar` reactivos.

2.  **Sección de Perfil:**
    *   **Archivo:** [profile_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/screens/profile_screen.dart)
    *   **Fallback Seguro:** Si la base de datos se demora en responder, muestra inmediatamente el correo y nombre desde el estado local de inicio de sesión (`userMetadata`) evitando pantallas en blanco.
    *   **Avatar:** Carga la URL de imagen o autogenera las iniciales del nombre con colores degradados y un indicador de estado online activo.
    *   **Estadísticas e Idioma:** Renderiza tarjetas para la Racha de Días (Streak 🔥) y el Idioma Objetivo (🗣️) junto con una barra de progreso.
    *   **Menu de Ajustes:** Un botón engranaje en el AppBar que despliega un `ModalBottomSheet` premium para gestionar opciones y ejecutar el Cierre de Sesión (`signOut`).

---

## 🧪 4. Pruebas y Robustez de la Suite

*   **Archivo modificado:** [widget_test.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/test/widget_test.dart)
*   **Mocking:** Usamos la librería `mocktail` para crear implementaciones falsas de `SupabaseClient` y `GoTrueClient`.
*   **Aislamiento:** Reemplazamos `supabaseClientProvider` en el `ProviderScope` del test. Esto nos permite ejecutar `flutter test` de forma local y automatizada en pipelines sin requerir conexión a internet ni que el servicio de Supabase real esté inicializado en `main.dart`.
*   **Comprobación:** El test de humo simula el arranque y verifica exitosamente que la aplicación se monta y redirige correctamente a `LoginScreen`.

---

## 🎯 5. Siguientes Pasos

1.  **Asociar Cartas de Vocabulario por Usuario:**
    Agregar la columna `user_id` en `word_cards` para que al crear o consultar cartas, cada usuario visualice únicamente sus tarjetas y notas de voz personalizadas en lugar de compartir una base de datos global.
2.  **Asociar Historial de Chats:**
    Ajustar la colección de chats para que cada usuario tenga su propio historial de conversaciones persistente e individualizado en Supabase.
