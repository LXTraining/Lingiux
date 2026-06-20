# Guía de Autenticación (Auth) con Supabase en Flutter

Este documento sirve como introducción teórica, arquitectónica y de mejores prácticas para la implementación del sistema de autenticación de usuarios en **Lingiux**, utilizando el servicio de autenticación de **Supabase** y gestión de estado reactiva en **Flutter**.

---

## 🔑 1. Fundamentos de la Autenticación (Auth)

La autenticación es el mecanismo de seguridad que valida la identidad del usuario, mientras que la autorización determina qué acciones tiene permitido realizar una vez validada su identidad.

### A. GoTrue (El Servidor de Auth)
Supabase incluye un servidor integrado de autenticación basado en API REST llamado **GoTrue** (escrito en Go). Este servidor administra el registro, inicio de sesión, recuperación de contraseña, confirmaciones por email y autenticación con terceros (Google, Apple, etc.).

### B. Gestión de Sesión mediante Tokens
Para mantener al usuario conectado de forma segura y eficiente, Supabase utiliza un estándar de la industria compuesto por dos tokens cifrados:
1.  **Access Token (Token de Acceso - JWT):** 
    *   **Duración:** Corta (usualmente 1 hora).
    *   **Propósito:** Contiene la firma digital del usuario cifrada. Se envía automáticamente en la cabecera de cada petición a la base de datos o almacenamiento para autorizar transacciones.
2.  **Refresh Token (Token de Refresco):**
    *   **Duración:** Larga (semanas o meses).
    *   **Propósito:** Se almacena de forma persistente y encriptada en el almacenamiento local del teléfono del usuario. Cuando el token de acceso expira, el SDK de Supabase utiliza el Refresh Token en segundo plano para obtener un nuevo Access Token de forma transparente, evitando obligar al usuario a iniciar sesión repetidamente.

---

## 🚪 2. El Ciclo de Vida del Usuario (UX)

Un sistema de autenticación profesional debe contemplar los siguientes estados de interacción:

*   **Registro (Sign Up):** Creación de una cuenta con email/contraseña o proveedor externo. Supabase puede configurarse para enviar un correo de confirmación con un código de verificación de un solo uso (OTP).
*   **Inicio de Sesión (Sign In):** Validación de credenciales. Al completarse, el SDK guarda los tokens locales en el dispositivo.
*   **Persistencia de Sesión (Auto-Login):** Al arrancar la aplicación, el SDK busca si existe un Refresh Token válido en el almacenamiento persistente del dispositivo. De hallarse, inicia sesión automáticamente sin pasar por la interfaz de login.
*   **Cierre de Sesión (Sign Out):** Elimina los tokens locales de forma segura e invalida la sesión activa en el servidor de Supabase.

---

## 🏗️ 3. Arquitectura del Sistema de Auth en Flutter

En proyectos profesionales, la autenticación se implementa siguiendo un flujo reactivo dividido en tres capas principales:

```text
[Supabase Auth (Servidor)]
           │
  (onAuthStateChange Stream)
           │
           ▼
[Auth State Provider (Riverpod)] ──(Notifica cambios)──> [GoRouter (Rutas)]
           │                                                    │
           ▼                                                    ▼
Reconstruye árbol de Widgets                             Redirige /login o /home
```

### Pilar A: El Escuchador de Estado (`Auth State Listener`)
Supabase expone un Stream reactivo llamado `onAuthStateChange`. Este Stream emite eventos cada vez que el estado de autenticación muta (ej: `signedIn`, `signedOut`, `tokenRefreshed`, `userUpdated`).
*   **Estrategia:** Se crea un provider de Riverpod que escuche este Stream globalmente durante el arranque del aplicativo.

### Pilar B: Redirección Dinámica de Rutas (`Guards`)
El Router declarativo de la aplicación (en nuestro caso, **GoRouter**) lee el estado expuesto por el provider de autenticación:
*   **Rutas Protegidas:** Si el usuario intenta entrar a `/home` o `/chat` sin sesión activa, GoRouter intercepta la petición y redirige a la pantalla de `/login`.
*   **Rutas de Invitado:** Si el usuario está autenticado e intenta navegar hacia `/login` o `/signup`, GoRouter lo redirige automáticamente a la pantalla de inicio `/home`.

### Pilar C: La Tabla Pública de Perfiles (`public.profiles`)
Por motivos de seguridad y cumplimiento de normativas de datos, Supabase guarda los datos de registro (email, password hashes, tokens) en una tabla interna oculta y protegida llamada `auth.users`. Esta tabla no es accesible de forma directa para consultas comunes del cliente móvil.

**La Solución Profesional:**
1.  Se crea una tabla en el esquema público de PostgreSQL llamada **`profiles`**.
2.  Esta tabla tiene un campo `id` de tipo UUID que actúa como clave primaria y está enlazada mediante una llave foránea (`Foreign Key`) al `id` de `auth.users`, configurada con borrado en cascada (`ON DELETE CASCADE`).
3.  Se programa una función Trigger en PostgreSQL que detecta la creación de cualquier usuario en `auth.users` y añade automáticamente una fila correspondiente en `public.profiles`.

---

## 🛡️ 4. Seguridad de Datos: Row Level Security (RLS)

Con Supabase Auth implementado, la seguridad de las lecturas y escrituras en la base de datos se desplaza hacia el servidor mediante políticas de RLS.

### Ejemplo de Política RLS
Para asegurar que los usuarios no puedan ver ni editar las cartas de vocabulario creadas por otros usuarios, se activa RLS en la tabla `word_cards` y se define la siguiente política:
```sql
-- Habilitar RLS en la tabla
ALTER TABLE public.word_cards ENABLE ROW LEVEL SECURITY;

-- Crear regla para permitir leer y escribir solo datos propios
CREATE POLICY "Permitir acceso individual por id de usuario"
ON public.word_cards
FOR ALL -- Aplica para SELECT, INSERT, UPDATE, DELETE
USING (auth.uid() = user_id); -- Compara el ID del JWT con el de la fila
```

---

## 🗺️ 5. Plan de Implementación para Lingiux

Los próximos pasos técnicos a seguir para dotar a **Lingiux** de un sistema de login y registro premium son:

### Paso 1: Configurar la Base de Datos en Supabase
*   Crear la tabla `public.profiles` con campos adicionales (nombre, idioma_objetivo, avatar_url, racha, etc.).
*   Implementar la función Trigger en Postgres para crear el perfil automáticamente tras el registro en `auth.users`.

### Paso 2: Crear el Notificador de Estado (`AuthNotifier`)
*   Escribir un StateNotifier o Provider en Riverpod que administre las funciones de `signInWithEmail`, `signUpWithEmail` y `signOut`.
*   Conectar el listener de sesión global de Supabase al provider.

### Paso 3: Configurar Guards en `app_router.dart`
*   Actualizar `GoRouter` para leer el estado del `AuthNotifier`.
*   Proteger las rutas de la aplicación de tal manera que requieran sesión activa obligatoriamente.

### Paso 4: Diseñar Interfaces de Login y Registro
*   Diseñar pantallas de Login y Sign Up alineadas con el sistema de diseño visual de la app (`DESIGN_SYSTEM.md`), utilizando transiciones elegantes, degradados premium y retroalimentación háptica.
