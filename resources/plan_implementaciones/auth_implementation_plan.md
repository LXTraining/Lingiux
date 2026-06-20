# Plan de Implementación: Sistema de Autenticación de Usuarios (Auth)

Este plan detalla los pasos para diseñar y programar el sistema de autenticación de usuarios en **Lingiux**, conectándolo a Supabase Auth, sincronizando perfiles de usuario, protegiendo rutas y diseñando interfaces de inicio de sesión y registro con estética premium.

## User Review Required

> [!IMPORTANT]
> **Refactorización de Rutas:** Se propone cambiar la configuración estática actual de `AppRouter.router` para que sea expuesta mediante un provider de Riverpod (`routerProvider`). Esto es necesario para que GoRouter pueda escuchar de forma reactiva el estado de sesión del usuario y redirigirlo automáticamente sin recargar la app de forma forzada.

## Proposed Changes

### 1. Base de Datos (Supabase Schema)
Se propone ejecutar el siguiente bloque de SQL para crear la tabla de perfiles, vincularla al Auth central y automatizar la sincronización:

```sql
-- A. Crear la tabla de perfiles de usuario
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  updated_at timestamp with time zone,
  username text UNIQUE,
  full_name text,
  avatar_url text,
  target_language text DEFAULT 'English',
  streak_count integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

-- B. Habilitar Seguridad a Nivel de Fila (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- C. Definir Políticas de RLS
CREATE POLICY "Permitir lectura pública de perfiles" 
ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Permitir actualización individual de perfil propio" 
ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- D. Función Trigger para crear el perfil automáticamente tras registro en auth.users
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

-- E. Vincular el trigger a la tabla auth.users
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
```

---

### 2. Capa de Lógica y Estado (Flutter & Riverpod)

#### [NEW] [auth_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/auth/presentation/providers/auth_provider.dart)
*   Crear un `StateNotifierProvider` (o notifier de clase anotada) llamado `authProvider` que maneje el estado de autenticación de Supabase.
*   Inicializar escuchando el Stream `Supabase.instance.client.auth.onAuthStateChange`.
*   Exponer métodos asíncronos para:
    *   `signUp(String email, String password, String name)`
    *   `signIn(String email, String password)`
    *   `signOut()`
*   Mapear el estado a una clase `AuthState` que contenga el estado de carga (`isLoading`), datos del usuario actual (`Session?` o `User?`), y posibles errores.

---

### 3. Redirección de Rutas (GoRouter & Guards)

#### [MODIFY] [app.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/app.dart)
*   Convertir `LingiuxApp` de un `StatelessWidget` a un `ConsumerWidget`.
*   Consumir `routerProvider` para pasar la configuración en `MaterialApp.router(routerConfig: ...)`.

#### [MODIFY] [app_router.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/core/router/app_router.dart)
*   Refactorizar para convertir la clase en un provider de Riverpod (`routerProvider`).
*   Configurar el método `redirect` en GoRouter:
    *   Si el usuario no está autenticado (no hay sesión en `authProvider`) y trata de acceder a rutas internas (como la ruta raíz `/`), redirigirlo a `/login`.
    *   Si el usuario ya está autenticado e intenta abrir la pantalla de `/login` o `/signup`, redirigirlo automáticamente a la pantalla raíz `/`.
*   Registrar las nuevas rutas `/login` y `/signup`.

---

### 4. Capa de Presentación (UI Premium)

#### [NEW] [login_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/auth/presentation/screens/login_screen.dart)
*   Pantalla premium con degradado de fondo en concordancia con `DESIGN_SYSTEM.md`.
*   Formulario para ingresar correo y contraseña con validaciones.
*   Enlace de navegación hacia `/signup` (Crear cuenta).
*   Efectos hápticos táctiles en botones y animaciones fluidas al procesar el estado de carga.

#### [NEW] [signup_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/auth/presentation/screens/signup_screen.dart)
*   Pantalla para crear cuenta solicitando nombre completo, correo electrónico y contraseña.
*   Una vez registrado exitosamente, Supabase creará el perfil automáticamente en base de datos.
*   Redirección automática al `/home`.

---

## Verification Plan

### Automated Tests
*   Ejecutar `flutter analyze` para asegurar la correcta declaración de tipos y resolución de dependencias.
*   Ejecutar `flutter test` para validar que el router e interfaces compilen sin romper el árbol de widgets existente.

### Manual Verification
*   **Base de datos:** Verificar en la interfaz de Supabase que al registrarse un usuario, se agregue instantáneamente su registro correspondiente en `public.profiles` mediante el Trigger.
*   **Guards:** Cerrar la aplicación logueado y validar el auto-login directo al `HomeScreen`.
*   **Cierre de sesión:** Pulsar el botón de logout en el perfil de la app y verificar que GoRouter reenvíe al usuario instantáneamente a `/login`.
