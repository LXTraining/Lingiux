# Walkthrough: Autenticación, Perfil de Usuario, Audio y Aislamiento de Datos

Este documento detalla todas las modificaciones y mejoras de backend y frontend realizadas en **Lingiux**, cubriendo el flujo de autenticación, el aislamiento de datos por usuario, la persistencia de chats en tiempo real y la lógica de audio.

---

## 🛡️ 1. Aislamiento y Persistencia de Vocabulario y Chats por Usuario

Se ha implementado el aislamiento de datos a nivel de base de datos y UI para que cada usuario autenticado tenga su propio conjunto privado de tarjetas de vocabulario y conversaciones de chat.

### A. Estructura de Base de Datos y Seguridad (Supabase DDL)
*   **Tarjetas de Vocabulario:** Se agregó la columna `user_id` en `word_cards` vinculada a `profiles(id)`. Se habilitó RLS para permitir que cada usuario lea únicamente sus propias tarjetas o tarjetas compartidas del sistema (`user_id IS NULL`), e inserte/modifique únicamente tarjetas asociadas a su `uid`.
*   **Tabla de Chats (`public.chats`):** Se creó para almacenar los contactos e información general del chat (nombre del destinatario, iniciales, color, último mensaje y marca de tiempo). Habilitada con RLS para aislamiento completo.
*   **Tabla de Mensajes (`public.messages`):** Se creó para almacenar el historial de mensajes de cada conversación. Se implementaron políticas de RLS cruzadas para garantizar que los usuarios solo puedan leer o insertar mensajes de chats que les pertenezcan.

### B. Refactorización de Vocabulario en Flutter
*   **Modelo de Datos:** Se actualizó [word_card_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/domain/models/word_card_model.dart) para incluir y serializar `userId`.
*   **Filtro Reactivo:** Se reestructuró [vocabulary_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/providers/vocabulary_provider.dart) para observar la sesión activa del usuario y realizar una consulta condicional condicionados al `user_id` del usuario activo.
*   **Formulario de Creación:** [create_card_form_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_form_screen.dart) ahora incluye automáticamente el `user_id` del usuario logueado al insertar nuevas tarjetas en Supabase.

### C. Proveedores de Mensajería en Tiempo Real (`chat_provider.dart`)
*   **Archivo creado:** [chat_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/providers/chat_provider.dart)
*   `chatsProvider` (StreamProvider) se conecta a la tabla `chats` en Supabase y escucha actualizaciones en tiempo real usando `.stream(primaryKey: ['id'])` filtrado por el `user_id` del usuario actual.
*   **Siembra Inicial Controlada (Emma Watson):** Al abrir la pestaña de chats por primera vez, el proveedor detecta si la lista de chats está vacía y siembra automáticamente en la base de datos **1 solo contacto simulado (Emma Watson)** junto con su respectivo historial inicial de conversación. Esto evita pantallas vacías de bienvenida.
*   `messagesProvider(chatId)` (StreamProvider) escucha de forma dedicada y en tiempo real el flujo de mensajes para una conversación activa.
*   `ChatService` gestiona el envío de mensajes insertando el registro en `messages` y actualizando en paralelo los metadatos de último mensaje de la conversación en la tabla `chats`.

### D. Conexión Reactiva de la UI de Chats
*   **Lista de Chats:** [chats_list_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chats_list_screen.dart) se convirtió en `ConsumerStatefulWidget` para suscribirse reactivamente a `chatsProvider` mostrando estados de carga, listas vacías y datos del servidor.
*   **Detalle de Conversación:** [chat_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart) lee los mensajes usando `messagesProvider` y realiza auto-scroll al final cuando se añaden nuevos mensajes. El botón enviar despacha los datos directamente a Supabase a través del `chatServiceProvider`.

---

## 👤 2. Perfil de Usuario y Ajustes (Cierre de Sesión)

Se completó el diseño de la sección de perfil de usuario y la lógica de cierre de sesión en la aplicación.

*   **Archivo creado:** [profile_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/providers/profile_provider.dart)
    *   Obtiene de manera reactiva el perfil del usuario autenticado en Supabase consultando la tabla `public.profiles`.
*   **Archivo modificado:** [profile_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/screens/profile_screen.dart)
    *   Diseñado con estadísticas del estudiante (Racha 🔥, Idioma Objetivo 🗣️), barra de progreso y avatar dinámico.
    *   El engranaje del AppBar despliega un `ModalBottomSheet` de Ajustes de Cuenta donde pulsar "Cerrar sesión" dispara `signOut()` e inmediatamente GoRouter redirige al login `/login`.

---

## 🔐 3. Autenticación con Supabase Auth

Se implementó el ciclo completo de autenticación de usuarios, desde la estructura de base de datos hasta la navegación protegida y las vistas premium.

*   **Trigger automático:** [implementacion_auth_supabase.md](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/resources/mds_relevantes/implementacion_auth_supabase.md)
    *   Registra perfiles automáticamente en `public.profiles` ante inserciones en `auth.users`.
*   **Guards del Router:** [app_router.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/core/router/app_router.dart)
    *   Bloquea accesos no autenticados y reconduce al login.

---

## 🎙️ 4. Ajustes de Audio y Grabación de Notas de Voz

Se detalla la configuración del sistema de audio y la grabación de notas de voz personalizadas en las tarjetas de vocabulario.

*   **Archivo modificado:** [create_card_form_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_form_screen.dart)
    *   Habilita la grabación de notas de voz de hasta 15 segundos con indicador circular parpadeante. Sube los archivos a Supabase Storage y asocia el enlace en la base de datos para streaming interactivo en [word_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/screens/word_detail_screen.dart).

---

## 🧪 5. Validación y Pruebas
*   **Análisis estático:** `flutter analyze` finalizó con 0 warnings o errores en los nuevos módulos creados y modificados de autenticación, perfil y chats.
*   **Pruebas de widgets:** Todas las pruebas pasaron de forma exitosa (`All tests passed!`). El arranque de la app simula la redirección al login de forma aislada gracias al override de `supabaseClientProvider` con `mocktail`.
