# Guía Completa de Prompts: App Lingiux con Flutter + Supabase

> **Propósito de este documento:** Mostrar cómo pedirle a Claude que construya una app móvil de aprendizaje de idiomas,
> pantalla por pantalla, de manera profesional y lista para publicarse en App Store / Google Play.
> Cada sección es un "turno de conversación" real con Claude.

---

## Índice de Fases

1. [Fase 0 — Definición del Proyecto](#fase-0--definición-del-proyecto)
2. [Fase 1 — Arquitectura y Setup Inicial](#fase-1--arquitectura-y-setup-inicial)
3. [Fase 2 — Screen de Inicio (Feed Principal)](#fase-2--screen-de-inicio-feed-principal)
4. [Fase 3 — Sistema de Chats](#fase-3--sistema-de-chats)
5. [Fase 4 — Crear Nueva Card](#fase-4--crear-nueva-card)
6. [Fase 5 — Screen de Comunidad](#fase-5--screen-de-comunidad)
7. [Fase 6 — Screen de Perfil](#fase-6--screen-de-perfil)
8. [Fase 7 — Integración con Supabase](#fase-7--integración-con-supabase)
9. [Fase 8 — Preparación para Producción](#fase-8--preparación-para-producción)

---

## Cómo usar esta guía

- Copia cada prompt **exactamente como está** en una conversación nueva con Claude.
- Espera a que Claude termine **completamente** antes de enviar el siguiente prompt.
- Si Claude te pide aclaraciones, respóndelas antes de continuar.
- Usa **un proyecto de Claude** (no chats sueltos) para que mantenga el contexto de toda la app.
- Al iniciar el proyecto en Claude, pega primero el **Prompt de Contexto Maestro** (Fase 0).

---

## FASE 0 — Definición del Proyecto

> **Cuándo usarlo:** Este es el PRIMER mensaje que envías. Establece el contexto completo de la app.
> Nunca saltes esta fase.

```
Vamos a construir juntos una app móvil de aprendizaje de idiomas llamada "Lingiux" desde cero.
Quiero que actúes como un senior Flutter developer con experiencia en apps sociales y educativas
publicadas en producción.

### Stack técnico que usaremos:
- Framework: Flutter (Dart)
- Estado: Riverpod (con StateNotifier y AsyncNotifier)
- Backend: Supabase (Auth, Database, Storage, Realtime)
- Navegación: GoRouter
- Base de datos local: Isar (para modo offline y caché)
- Inyección de dependencias: get_it + injectable
- Estilos: ThemeData propio, diseño moderno y minimalista
- Tests: flutter_test + mocktail

### Principios que SIEMPRE debes seguir en todo el proyecto:
1. Arquitectura en capas: data → domain → presentation
2. Separar la lógica de negocio de la UI (sin lógica en los widgets)
3. Código null-safe, sin late innecesarios
4. Manejo de errores con Either<Failure, Success> usando fpdart
5. Nombres en inglés en el código, comentarios en español si los hay
6. Cada feature en su propia carpeta dentro de lib/features/
7. Assets, colores y strings en archivos de constantes separados
8. La app debe funcionar en iOS y Android

### Sobre la app Lingiux:
- Usuarios objetivo: personas que aprenden idiomas (especialmente inglés para profesionales)
- Navegación principal: 5 secciones en BottomNavigationBar
  · Inicio — Feed principal de publicaciones tipo card
  · Chats — Lista y sistema de conversaciones entre usuarios
  · Crear — Publicar una nueva card de contenido
  · Comunidad — Explorador de comunidades por categoría profesional
  · Perfil — Perfil de usuario estilo Instagram con grid de cards
- Modelo de negocio: por definir (estructura preparada para freemium)
- Idioma de la UI: español

Antes de escribir cualquier código, muéstrame:
1. La estructura completa de carpetas del proyecto
2. Las dependencias del pubspec.yaml
3. El plan de implementación por fases

No escribas código todavía. Solo muéstrame la arquitectura y el plan para que yo pueda aprobarlo.
```

---

## FASE 1 — Arquitectura y Setup Inicial

> **Cuándo usarlo:** Después de que Claude muestre y tú apruebes el plan de la Fase 0.

### Prompt 1.1 — Estructura base del proyecto

```
Perfecto, apruebo la arquitectura. Ahora crea la estructura base del proyecto.

Necesito que generes:
1. El pubspec.yaml completo con todas las dependencias y sus versiones exactas compatibles
   con Flutter 3.22+
2. El archivo main.dart con el setup de Riverpod, GoRouter y get_it
3. La carpeta core/ con:
   - core/constants/ (colores, strings, rutas)
   - core/errors/ (clases Failure)
   - core/theme/ (AppTheme con modo claro y oscuro)
   - core/utils/ (helpers reutilizables)
4. El archivo de configuración de Supabase usando variables de entorno con flutter_dotenv

Para el tema visual de Lingiux:
- Diseño moderno, minimalista y limpio
- Color primario: a definir (sugiere una paleta acorde a una app de idiomas/social)
- La app soportará modo claro y oscuro

Genera cada archivo completo, no uses "// ... resto del código".
Empieza por pubspec.yaml.
```

### Prompt 1.2 — Navegación principal y BottomNavigationBar

```
Bien. Ahora configura el sistema de navegación principal de la app con GoRouter.

Rutas que necesito:
- /splash → SplashScreen (verifica auth state)
- /auth/login → LoginScreen
- /auth/register → RegisterScreen
- /home → Shell con BottomNavigationBar de 5 tabs:
  - /home/feed → FeedScreen (Inicio)
  - /home/chats → ChatsScreen (Chats)
  - /home/create → CreateCardScreen (Crear)
  - /home/community → CommunityScreen (Comunidad)
  - /home/profile → ProfileScreen (Perfil)
- /chat/:chatId → ChatDetailScreen (pantalla completa, sin bottom nav)
- /card/:cardId → CardDetailScreen
- /community/:categoryId → CommunityDetailScreen

Lógica de redirect:
- Si no está autenticado → /auth/login
- Si está autenticado → /home/feed

La SplashScreen muestra el logo de Lingiux por 2 segundos mientras verifica el estado auth.
Cada tab mantiene su estado de navegación con nested navigation.
```

---

## FASE 2 — Screen de Inicio (Feed Principal)

> **Cuándo usarlo:** Navegación configurada. Ahora construimos la pantalla principal.

### Prompt 2.1 — Carrusel horizontal de cards

```
Construye la sección del carrusel horizontal de cards en la parte superior del FeedScreen.

El carrusel debe tener un comportamiento visual similar al de las historias/amigos sugeridos
de Facebook, pero con cards personalizadas para Lingiux.

Cada card del carrusel debe incluir:
- Imagen principal (cargada con cached_network_image)
- Nombre o título
- Información breve (por ejemplo: nivel de idioma, categoría)
- Diseño moderno y limpio con bordes redondeados y sombra sutil

Requisitos técnicos:
- ListView horizontal con scroll suave
- Tamaño de card: aproximadamente 120x160px
- Usa mock data por ahora (lista de objetos CarouselCardModel)
- Skeleton loading mientras se cargan las cards
- Crea el widget CarouselSection reutilizable en presentation/widgets/

Genera el widget completo con su modelo de datos y mock data incluidos.
```

### Prompt 2.2 — Feed vertical de publicaciones

```
Ahora construye el feed vertical de publicaciones debajo del carrusel en FeedScreen.

El feed muestra publicaciones tipo card relacionadas con aprendizaje de idiomas.

Cada publicación en el feed debe mostrar:
- Imagen principal de la card (ocupa la mayoría del espacio)
- Nombre del autor con avatar
- Título de la card
- Descripción breve (máx. 2 líneas, con "ver más")
- Tags de idioma, categoría y nivel
- Contador de likes y comentarios
- Botón de guardar/bookmarcar

Requisitos técnicos:
- CustomScrollView con SliverList para rendimiento óptimo
- Carrusel incluido como SliverToBoxAdapter en la parte superior
- Pull to refresh
- Paginación: carga 10 items, al llegar al final carga 10 más
- Skeleton loading en la carga inicial (no CircularProgressIndicator genérico)
- Usa mock data por ahora, estructura lista para conectar con Supabase

Diseño: moderno, minimalista, enfocado en buena experiencia de usuario.
Genera FeedScreen completa con todos los widgets involucrados.
```

---

## FASE 3 — Sistema de Chats

> **Cuándo usarlo:** Feed principal listo. Ahora construimos el módulo de chats.

### Prompt 3.1 — Estructura de datos y lista de chats

```
Construye el módulo de chats de Lingiux.

La lógica base debe replicar el comportamiento esperado de un sistema de chat moderno.

Estructura de datos para los chats (usar mock data por ahora, preparada para Supabase):
- Chat: id, participants (List<UserModel>), lastMessage, lastMessageTime, unreadCount
- Message: id, chatId, senderId, content, type (text/image), timestamp, isRead

ChatsScreen (lista de conversaciones) debe mostrar:
- AppBar con título "Chats" y botón de búsqueda
- Lista de conversaciones con:
  · Avatar del otro usuario
  · Nombre del usuario
  · Último mensaje (truncado a 1 línea)
  · Hora del último mensaje
  · Badge de mensajes no leídos
- Estado vacío si no hay chats: ilustración + texto motivacional

Requisitos técnicos:
- Arquitectura limpia: ChatEntity, ChatRepository (interface), ChatRepositoryImpl
- ChatListNotifier con Riverpod
- Estructura lista para futura integración con Supabase Realtime
- Usa mock data por ahora

Genera la capa de dominio completa y la ChatsScreen.
```

### Prompt 3.2 — Pantalla de chat individual

```
Ahora construye ChatDetailScreen (la pantalla de conversación individual).

Comportamiento esperado:
- AppBar con avatar y nombre del contacto, y botón de llamada/video (íconos, sin funcionalidad por ahora)
- Lista de mensajes en orden cronológico (burbujas de chat)
  · Mensajes propios: burbuja a la derecha, color primario
  · Mensajes recibidos: burbuja a la izquierda, color neutro
  · Timestamp debajo de cada mensaje
  · Indicador de leído/no leído en mensajes enviados
- Campo de texto en la parte inferior con:
  · TextField para escribir el mensaje
  · Botón de adjuntar imagen (abre galería)
  · Botón de enviar (se activa solo cuando hay texto)

Funcionalidades:
- Auto-scroll al último mensaje al abrir y al recibir uno nuevo
- Teclado empuja el contenido hacia arriba (resizeToAvoidBottomInset)
- Soporte para mensajes de imagen además de texto
- Usa mock data con simulación de respuesta automática después de 1 segundo

Genera ChatDetailScreen completa con MessageBubble widget reutilizable.
```

---

## FASE 4 — Crear Nueva Card

> **Cuándo usarlo:** Chats implementado. Ahora el flujo de creación de contenido.

### Prompt 4.1 — Flujo de creación de card

```
Construye CreateCardScreen, la pantalla que aparece al presionar el ícono "+" del BottomNavigationBar.

Flujo esperado:
1. Al entrar a la pantalla, abrir automáticamente la galería del dispositivo
   usando image_picker para seleccionar una imagen
2. Mostrar preview de la imagen seleccionada en la parte superior de la pantalla
   (ocupa ~40% de la pantalla, con opción de cambiar la imagen)
3. Debajo del preview, mostrar el formulario de creación

Campos del formulario:
- Título (requerido, máx. 60 caracteres, con contador)
- Descripción (opcional, máx. 280 caracteres, con contador)
- Idioma (dropdown: Inglés, Español, Francés, Alemán, Portugués, Japonés, Otro)
- Categoría (dropdown dinámico, ver lista en Fase 5)
- Nivel (selector de chips: Principiante / Intermedio / Avanzado)
- Tags opcionales (campo de texto con chips, máx. 5 tags)

Botón "Publicar":
- Desactivado hasta que imagen + título estén completos
- Muestra CircularProgressIndicator dentro del botón al publicar
- Por ahora simula éxito después de 1.5 segundos y regresa al feed

Diseño: simple, rápido y cómodo para publicar. Sin scroll excesivo.
Genera CreateCardScreen completa con validaciones y manejo de estado con Riverpod.
```

---

## FASE 5 — Screen de Comunidad

> **Cuándo usarlo:** Creación de cards funciona. Ahora la sección de exploración por comunidades.

### Prompt 5.1 — Explorador de comunidades

```
Construye CommunityScreen, el explorador de comunidades de Lingiux.

Esta pantalla es temporal y funcionará como punto de entrada a comunidades temáticas.

Categorías iniciales a mostrar (la estructura debe ser flexible y escalable):
- English for Architects
- English for Engineers
- English for Doctors
- Business English
- English for Programming
- (preparar para agregar más categorías fácilmente)

Diseño de la pantalla:
- AppBar con título "Comunidades" y buscador
- Grid de 2 columnas con cards de categoría, cada una con:
  · Imagen o ilustración representativa (usa colores/iconos por ahora)
  · Nombre de la categoría
  · Número de miembros (mock data)
  · Botón de "Unirse" o "Ver"
- Sección superior "Mis comunidades" (lista horizontal, mock data)
- Sección "Explorar" con el grid completo de categorías

Requisitos técnicos:
- CommunityModel con campos: id, name, description, memberCount, imageUrl, category
- Las categorías vienen de un repositorio (usa mock data lista para conectar con Supabase)
- La estructura debe permitir agregar/quitar categorías sin cambiar la UI

Genera CommunityScreen completa con CommunityCard widget reutilizable.
```

### Prompt 5.2 — Detalle de comunidad

```
Construye CommunityDetailScreen, la pantalla que se abre al tocar una categoría.

Contenido:
- Hero image o banner de la comunidad en la parte superior
- Nombre, descripción y número de miembros
- Botón "Unirse a la comunidad" (toggle join/leave)
- Tabs con:
  · "Publicaciones": feed de cards pertenecientes a esta comunidad
    (reutiliza el FeedItem widget de la Fase 2)
  · "Miembros": lista de usuarios con avatar y nombre

Requisitos técnicos:
- SliverAppBar colapsable con el banner como fondo
- El feed de publicaciones usa mock data filtrado por categoría
- Reutiliza los widgets de feed creados en la Fase 2

Genera CommunityDetailScreen completa.
```

---

## FASE 6 — Screen de Perfil

> **Cuándo usarlo:** Comunidades implementadas. Ahora el perfil de usuario.

### Prompt 6.1 — Pantalla de perfil

```
Construye ProfileScreen inspirada en el diseño de perfil de Instagram, pero adaptada a Lingiux.

Elementos del perfil (sección superior):
- Foto de perfil circular (editable, sube a Supabase Storage)
- Nombre del usuario
- Biografía (máx. 150 caracteres, editable)
- Fila de estadísticas: Cards publicadas | Seguidores | Seguidos
  (números clickeables que abren listas de usuarios)
- Botón "Editar perfil" (si es el perfil propio)
  o Botón "Seguir / Siguiendo" (si es perfil de otro usuario)

Grid de contenido:
- En lugar de fotos tradicionales, el grid muestra las cards creadas por el usuario
- Grid de 3 columnas con scroll fluido
- Cada celda muestra la imagen principal de la card
- Al tocar una card del grid, navega a CardDetailScreen
- Infinite scroll: carga más cards al llegar al final

Requisitos técnicos:
- SliverAppBar colapsable con los datos del perfil como header
- CustomScrollView + SliverGrid para el grid de cards
- Skeleton loading para el grid mientras carga
- Cards reutilizables y responsive
- Usa mock data lista para conectar con Supabase

Aplica buenas prácticas modernas de UI/UX.
Genera ProfileScreen completa con ProfileHeader widget separado.
```

### Prompt 6.2 — Edición de perfil

```
Construye EditProfileScreen.

Campos editables:
- Foto de perfil (toca para abrir galería con image_picker)
- Nombre (requerido)
- Nombre de usuario / handle (requerido, único, sin espacios)
- Biografía (opcional, máx. 150 caracteres con contador)
- Idiomas que habla el usuario (chips multi-selección)
- Idiomas que está aprendiendo (chips multi-selección)

Botón "Guardar cambios":
- Desactivado si no hubo cambios
- Valida que el nombre y handle no estén vacíos
- Por ahora simula guardado exitoso (preparado para Supabase)
- Muestra SnackBar de confirmación al guardar

Genera EditProfileScreen completa con validaciones.
```

---

## FASE 7 — Integración con Supabase

> **Cuándo usarlo:** Toda la UI funciona con mock data. Ahora conectamos el backend real.

### Prompt 7.1 — Autenticación con Supabase

```
Implementa el sistema de autenticación real con Supabase.

Flujo de autenticación:
1. LoginScreen: email + contraseña, con opción de "Continuar con Google"
2. RegisterScreen: email, contraseña, nombre, confirmar contraseña
3. SplashScreen verifica si hay sesión activa con Supabase

Implementa:
- AuthRemoteDatasource que usa supabase_flutter
- AuthRepositoryImpl con manejo de errores de Supabase mapeados a Failure
- Casos de uso: SignInUseCase, SignUpUseCase, SignOutUseCase, GetCurrentUserUseCase
- AuthNotifier con Riverpod que expone el estado de autenticación
- Redireccionamiento automático según estado de auth en GoRouter

Al registrarse, crear el perfil del usuario en la tabla profiles de Supabase:
- id (igual al auth.uid)
- username, full_name, avatar_url, bio
- created_at

Genera el feature de auth completo.
```

### Prompt 7.2 — Datos reales: Cards y Feed

```
Reemplaza el mock data del feed y las cards con datos reales de Supabase.

Esquema de Supabase que necesito:
- Tabla cards: id, user_id, title, description, image_url, language, category, level, tags[], likes_count, created_at
- Tabla card_likes: id, card_id, user_id, created_at
- Tabla card_saves: id, card_id, user_id, created_at
- Bucket de Storage: card-images (público)

Implementa:
1. CardRemoteDatasource con métodos:
   - getFeedCards(page, limit) → paginación con offset
   - getCardsByUser(userId)
   - getCardsByCategory(category)
   - createCard(cardData, imageFile)
   - toggleLike(cardId)
   - toggleSave(cardId)
2. CardRepository e implementación
3. Casos de uso correspondientes
4. Actualiza los providers del feed para usar datos reales

También actualiza CreateCardScreen para subir la imagen a Supabase Storage
y guardar la card en la base de datos.

Genera todo el código necesario para reemplazar el mock data.
```

### Prompt 7.3 — Chats con Supabase Realtime

```
Implementa el backend real del sistema de chats usando Supabase Realtime.

Esquema de Supabase:
- Tabla chats: id, created_at
- Tabla chat_participants: id, chat_id, user_id
- Tabla messages: id, chat_id, sender_id, content, type (text/image), is_read, created_at

Implementa:
1. ChatRemoteDatasource con métodos:
   - getUserChats(userId) → lista de chats con último mensaje
   - getChatMessages(chatId, page, limit)
   - sendMessage(chatId, content, type)
   - markMessagesAsRead(chatId)
   - subscribeToMessages(chatId) → Stream<Message> con Supabase Realtime

2. ChatRepository e implementación

3. ChatDetailNotifier que:
   - Carga mensajes históricos al abrir el chat
   - Se suscribe al Stream de mensajes nuevos con Realtime
   - Actualiza la UI en tiempo real al recibir mensajes

4. Actualiza ChatsScreen y ChatDetailScreen para usar datos reales

Genera el código completo.
```

---

## FASE 8 — Preparación para Producción

> **Cuándo usarlo:** Todo funciona con backend real. Preparamos la app para publicar.

### Prompt 8.1 — Performance y optimizaciones

```
Revisa toda la app y aplica las siguientes optimizaciones de producción:

1. Imágenes:
   - Verifica que cached_network_image esté en todos los puntos de carga de imágenes de red
   - Configura el caché con máximo 200 imágenes y 7 días de expiración
   - Asegura que haya placeholders y error widgets en todos los casos

2. Listas largas:
   - Verifica que todos los ListView/GridView con muchos items usen .builder
   - Confirma que la paginación del feed funcione correctamente
   - El grid del perfil también debe paginar (20 items por página)

3. Riverpod:
   - Verifica que los providers se dispongan cuando no se usan
   - El chat activo usa keepAlive() para mantener la suscripción Realtime

4. Splash screen nativa:
   - Configura flutter_native_splash con el logo de Lingiux

5. Íconos de app:
   - Configura flutter_launcher_icons con el ícono de Lingiux
   - Genera todas las resoluciones para iOS y Android

Genera los archivos de configuración necesarios y los cambios de código requeridos.
```

### Prompt 8.2 — Testing

```
Escribe los tests críticos de la app.

Necesito:

1. Unit tests (test/unit/):
   - AuthRepositoryTest: verifica mapeo de errores de Supabase a Failure
   - CardRepositoryTest: verifica paginación y creación de cards
   - ChatNotifierTest: verifica que los mensajes nuevos actualizan el estado

2. Widget tests (test/widget/):
   - FeedScreenTest: verifica skeleton loading y render del feed
   - CreateCardScreenTest: verifica validación del formulario
   - ChatDetailScreenTest: verifica que al enviar un mensaje aparece en la lista

3. Integration test (integration_test/):
   - AuthFlowTest: registro → feed principal (usando Supabase local/emulado)

Usa mocktail para los mocks. Cada test debe tener:
- Nombre descriptivo en español ("debería mostrar skeleton mientras carga el feed")
- Setup (arrange), acción (act) y verificación (assert) claramente separados

También genera el archivo de CI/CD para GitHub Actions (.github/workflows/main.yml) que:
- Corre los tests en cada PR
- Hace build de release para Android e iOS
```

### Prompt 8.3 — Checklist final de lanzamiento

```
Dame el checklist completo de pre-lanzamiento para Lingiux.

Organízalo en estas categorías y para cada item indica cómo verificarlo:

1. Funcionalidad core (feed, chats, crear card, comunidad, perfil)
2. Autenticación y seguridad (Supabase RLS policies, sesiones)
3. Performance (Flutter DevTools, tamaño del build)
4. Realtime y conectividad (comportamiento offline, reconexión)
5. Analytics (configura Firebase Analytics o Supabase Analytics con eventos clave)
6. Crashlytics (configura Firebase Crashlytics)
7. Privacidad y permisos (galería, notificaciones, cámara)
8. Accesibilidad (Semantics, contraste, tamaños de fuente)
9. Pruebas en dispositivos reales (mínimo iOS + Android)
10. Firma y build de release
11. Assets de la Store (screenshots, descripción, ícono)
12. Revisión de las tiendas (tiempos estimados, qué suele rechazarse)

Para cada item usa este formato:
- [ ] Descripción del item — Cómo verificarlo
```

---

## Tips de Prompt Engineering para esta guía

### Lo que hace que estos prompts funcionen bien:

**1. Contexto antes de código**
El Prompt 0 le da a Claude todo el contexto del proyecto antes de escribir una línea.
Claude "recuerda" ese contexto en toda la conversación del proyecto.

**2. Una responsabilidad por prompt**
Cada prompt pide una pantalla o capa específica, no todo a la vez.
"Construye el carrusel" es mejor que "Construye todo el FeedScreen de una vez".

**3. Mock data primero, backend después**
Las Fases 2–6 usan mock data para que la UI quede perfecta antes de conectar el backend.
La Fase 7 reemplaza el mock data con Supabase sin tocar la UI.

**4. Orden respeta las dependencias**
Los prompts siguen el orden: entidades → repositorio → casos de uso → UI.
Nunca pides la UI antes de tener la lógica de negocio definida.

**5. Frases de control útiles para agregar a cualquier prompt:**
- `"No escribas código todavía, primero muéstrame el plan"`
- `"Genera cada archivo completo, sin omitir código con '...'"`
- `"Si necesitas tomar una decisión de diseño, explícala antes de implementarla"`
- `"Recuerda seguir la arquitectura definida al inicio del proyecto"`
- `"Después de generar esto, dime qué necesito para continuar con la siguiente fase"`

**6. Cuando Claude se equivoca:**
- `"Eso no sigue el patrón que definimos. Revisa el Prompt 0 y rehaz [X] usando Either<Failure, T>"`
- `"El widget tiene lógica de negocio directamente. Muévela al StateNotifier"`
- `"Usaste mock data aquí pero en esta fase ya deberíamos tener Supabase real. Corrige eso"`

---

*Documento generado como guía de referencia para construir Lingiux con Claude.*
*Tiempo estimado de implementación siguiendo esta guía: 3-5 semanas de desarrollo activo.*
