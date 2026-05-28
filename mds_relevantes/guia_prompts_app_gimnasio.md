# Guía Completa de Prompts: App de Gimnasio con Flutter + Claude

> **Propósito de este documento:** Mostrar cómo pedirle a Claude que construya una app móvil completa,
> funcionalidad por funcionalidad, de manera profesional y lista para publicarse en App Store / Google Play.
> Cada sección es un "turno de conversación" real con Claude.

---

## Índice de Fases

1. [Fase 0 — Definición del Proyecto](#fase-0--definición-del-proyecto)
2. [Fase 1 — Arquitectura y Setup Inicial](#fase-1--arquitectura-y-setup-inicial)
3. [Fase 2 — Sistema de Autenticación](#fase-2--sistema-de-autenticación)
4. [Fase 3 — Perfil de Usuario y Onboarding](#fase-3--perfil-de-usuario-y-onboarding)
5. [Fase 4 — Dashboard Principal](#fase-4--dashboard-principal)
6. [Fase 5 — Módulo de Rutinas y Ejercicios](#fase-5--módulo-de-rutinas-y-ejercicios)
7. [Fase 6 — Registro de Entrenamientos](#fase-6--registro-de-entrenamientos)
8. [Fase 7 — Progreso y Estadísticas](#fase-7--progreso-y-estadísticas)
9. [Fase 8 — Nutrición y Seguimiento de Calorías](#fase-8--nutrición-y-seguimiento-de-calorías)
10. [Fase 9 — Notificaciones y Recordatorios](#fase-9--notificaciones-y-recordatorios)
11. [Fase 10 — Suscripciones y Pagos (Premium)](#fase-10--suscripciones-y-pagos-premium)
12. [Fase 11 — Preparación para Producción](#fase-11--preparación-para-producción)

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
Vamos a construir juntos una app móvil de gimnasio llamada "FitCore" desde cero.
Quiero que actúes como un senior Flutter developer con experiencia en apps de fitness
publicadas en producción.

### Stack técnico que usaremos:
- Framework: Flutter (Dart)
- Estado: Riverpod (con StateNotifier y AsyncNotifier)
- Backend: Firebase (Auth, Firestore, Storage, Cloud Functions)
- Navegación: GoRouter
- Base de datos local: Isar (para modo offline)
- Inyección de dependencias: get_it + injectable
- Estilos: ThemeData propio, sin paquetes de UI externos salvo flutter_svg
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

### Sobre la app FitCore:
- Usuarios objetivo: personas que van al gimnasio de forma regular (principiantes a intermedios)
- Funcionalidades clave: rutinas, registro de entrenamientos, progreso, nutrición
- Modelo de negocio: freemium (funciones básicas gratis, premium con suscripción mensual/anual)
- Idioma de la UI: español (México)

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
4. El archivo de configuración de Firebase (sin las keys reales, usando variables de entorno
   con flutter_dotenv)

Para el tema visual de FitCore:
- Color primario: naranja energético (#FF6B35)
- Color secundario: negro profundo (#1A1A2E)
- Fondo oscuro: #0F0F1A
- Texto principal: blanco (#FFFFFF)
- La app usará dark mode por defecto

Genera cada archivo completo, no uses "// ... resto del código".
Empieza por pubspec.yaml.
```

### Prompt 1.2 — Firebase y variables de entorno

```
Bien. Ahora configura la integración con Firebase:

1. Crea core/services/firebase_service.dart que inicialice Firebase al arrancar la app
2. Crea el archivo .env.example con todas las variables de entorno necesarias para Firebase
   (sin valores reales, solo los nombres de las variables)
3. Crea core/config/app_config.dart que lea las variables del .env usando flutter_dotenv
4. Agrega las instrucciones en comentarios de cómo el desarrollador debe configurar
   google-services.json y GoogleService-Info.plist sin incluir esos archivos en el repo

También crea el .gitignore apropiado para un proyecto Flutter con Firebase y dotenv.
```

---

## FASE 2 — Sistema de Autenticación

> **Cuándo usarlo:** Con la base del proyecto lista. Esta fase construye el login completo.

### Prompt 2.1 — Capa de datos de autenticación

```
Ahora construimos el módulo de autenticación completo. Empieza por la capa de datos.

Crea lib/features/auth/ con la siguiente estructura:
- data/datasources/auth_remote_datasource.dart (Firebase Auth)
- data/models/user_model.dart (extiende la entidad)
- data/repositories/auth_repository_impl.dart
- domain/entities/user_entity.dart
- domain/repositories/auth_repository.dart (interface)
- domain/usecases/ (uno por caso de uso)
- presentation/screens/
- presentation/widgets/
- presentation/providers/

Casos de uso que necesito en esta fase:
1. SignInWithEmailUseCase
2. SignUpWithEmailUseCase
3. SignInWithGoogleUseCase
4. SignOutUseCase
5. GetCurrentUserUseCase
6. ForgotPasswordUseCase

Empieza generando las entidades y la interfaz del repositorio. No generes la UI todavía.
Recuerda usar Either<Failure, T> en todos los métodos del repositorio.
```

### Prompt 2.2 — Implementación del repositorio de auth

```
Ahora implementa auth_repository_impl.dart y auth_remote_datasource.dart completos.

El datasource debe manejar:
- signInWithEmailAndPassword → devuelve UserModel
- createUserWithEmailAndPassword → devuelve UserModel
- signInWithGoogle → devuelve UserModel (usando google_sign_in)
- signOut
- sendPasswordResetEmail
- authStateChanges → Stream<UserModel?>

El repositorio impl debe:
- Capturar FirebaseAuthException y mapearlas a Failure específicos
  (InvalidCredentialsFailure, EmailAlreadyInUseFailure, NetworkFailure, etc.)
- Guardar el usuario en Isar localmente después del login exitoso
- Verificar si hay usuario cacheado en Isar al abrir la app (soporte offline)

Genera ambos archivos completos.
```

### Prompt 2.3 — UI de autenticación

```
Ahora construye las pantallas de autenticación. Necesito:

1. LoginScreen:
   - Email y contraseña con validación en tiempo real
   - Botón "Entrar con Google" (con el logo oficial de Google como SVG asset)
   - Link a ForgotPasswordScreen
   - Link a RegisterScreen
   - Loading state mientras se autentica
   - Manejo de errores inline (no dialogs, sino texto debajo del campo)

2. RegisterScreen:
   - Nombre completo, email, contraseña, confirmar contraseña
   - Validación: contraseña mínimo 8 caracteres, una mayúscula, un número
   - Checkbox de aceptar términos (requerido)
   - Misma estética que LoginScreen

3. ForgotPasswordScreen:
   - Solo campo de email
   - Mensaje de éxito cuando se envía el correo

Requisitos de UI:
- Animaciones de entrada con AnimatedOpacity y SlideTransition
- Teclado se cierra al hacer tap fuera de los campos
- Botones con estado de loading (CircularProgressIndicator dentro del botón)
- Todos los textos usando el sistema de internacionalización que definamos después
  (por ahora usa strings directos en español)

Usa Riverpod con StateNotifier para el estado de cada pantalla.
Genera cada pantalla en un archivo separado, completo.
```

---

## FASE 3 — Perfil de Usuario y Onboarding

> **Cuándo usarlo:** Auth funciona. Ahora personalizamos la experiencia del usuario nuevo.

### Prompt 3.1 — Onboarding

```
Construye el flujo de onboarding que aparece una sola vez cuando el usuario se registra
por primera vez.

El onboarding tiene 4 pasos (pantallas dentro de un PageView):

Paso 1 - Objetivo:
  Opciones con iconos: "Perder peso", "Ganar músculo", "Mantener forma", "Mejorar resistencia"
  Solo una selección posible.

Paso 2 - Nivel de experiencia:
  Opciones: "Principiante (< 6 meses)", "Intermedio (6m - 2 años)", "Avanzado (> 2 años)"

Paso 3 - Datos físicos:
  - Género (hombre/mujer/prefiero no decir)
  - Fecha de nacimiento (DatePicker)
  - Peso actual (kg o lb, toggle de unidades)
  - Estatura (cm o ft/in, toggle de unidades)

Paso 4 - Días disponibles para entrenar:
  Selector de días de la semana (lunes a domingo), múltiple selección.

Al finalizar:
- Guarda todo en Firestore en users/{uid}/profile
- Guarda también en Isar localmente
- Navega al Dashboard

Requisitos técnicos:
- No se puede retroceder al paso 1 una vez completado el onboarding (usar SharedPreferences
  para la flag onboarding_completed)
- Barra de progreso animada entre pasos
- El botón "Siguiente" se desactiva si no hay selección
- Animación de transición entre pasos con SlideTransition
```

### Prompt 3.2 — Perfil editable

```
Crea la pantalla de perfil de usuario (accesible desde el menú principal).

Secciones del perfil:
1. Header: foto de perfil (editable, sube a Firebase Storage), nombre y email
2. Datos físicos: peso, estatura, edad (editables, con historial de cambios en Firestore)
3. Objetivo actual (editable, mismas opciones del onboarding)
4. Estadísticas rápidas: total de entrenamientos, racha actual, semanas activo
5. Sección premium: si es usuario free, mostrar banner de upgrade

Al editar el peso:
- Guarda el nuevo peso en users/{uid}/weight_history con timestamp
- Esto alimentará el gráfico de progreso más adelante

Genera el feature completo: datasource, repository, usecases, provider y screen.
```

---

## FASE 4 — Dashboard Principal

> **Cuándo usarlo:** El usuario puede loguearse y tiene perfil. Ahora la pantalla principal.

### Prompt 4.1 — Layout del Dashboard

```
Construye el Dashboard principal (HomeScreen) de FitCore.

Layout:
- Bottom navigation bar con 4 tabs: Inicio, Rutinas, Progreso, Nutrición
- Cada tab mantiene su estado de navegación (nested navigation con GoRouter)

Pantalla de Inicio (tab 1) debe mostrar:
1. Header: "Buenos días, {nombre}" con el día y fecha actual
2. Card de "Entrenamiento de hoy": muestra la rutina programada para hoy o "Día de descanso"
   con botón de inicio rápido
3. Card de racha actual: días consecutivos entrenando (con animación de fuego si > 7 días)
4. Sección "Actividad reciente": últimos 3 entrenamientos (fecha, duración, rutina)
5. Card de "Progreso semanal": barra circular con % de días entrenados vs objetivo
6. Banner de hidratación: vasos de agua tomados hoy (con botón +1 vaso)

Requisitos:
- Toda la pantalla en un CustomScrollView con SliverAppBar colapsable
- Pull to refresh que recargue los datos de Firestore
- Skeleton loading mientras carga (no CircularProgressIndicator genérico)
- La data del dashboard se cachea en Isar y se muestra inmediatamente,
  luego se actualiza en background con los datos de Firestore
```

### Prompt 4.2 — Bottom Navigation y Routing

```
Configura el sistema de navegación completo de la app con GoRouter.

Rutas que necesito:
- /splash → SplashScreen (verifica auth state)
- /onboarding → OnboardingScreen
- /auth/login → LoginScreen
- /auth/register → RegisterScreen
- /auth/forgot-password → ForgotPasswordScreen
- /home → Shell con bottom nav
  - /home/dashboard → HomeTab
  - /home/routines → RoutinesTab
  - /home/progress → ProgressTab
  - /home/nutrition → NutritionTab
- /workout/start/:routineId → ActiveWorkoutScreen (pantalla completa, sin bottom nav)
- /workout/summary/:workoutId → WorkoutSummaryScreen
- /profile → ProfileScreen
- /settings → SettingsScreen
- /premium → PremiumScreen

Lógica de redirect:
- Si no está autenticado → /auth/login
- Si está autenticado pero no completó onboarding → /onboarding
- Si está autenticado y completó onboarding → /home/dashboard

La SplashScreen muestra el logo de FitCore por 2 segundos mientras verifica el estado.
Implementa deep links para la ruta /premium (para campañas de marketing).
```

---

## FASE 5 — Módulo de Rutinas y Ejercicios

> **Cuándo usarlo:** Dashboard navegable. Ahora el corazón de la app: las rutinas.

### Prompt 5.1 — Base de datos de ejercicios

```
Construye el catálogo de ejercicios de la app.

Estructura en Firestore:
- exercises/{exerciseId}:
  - name: string
  - muscle_groups: List<string> (primary y secondary)
  - equipment: string (mancuernas, barra, máquina, peso corporal, etc.)
  - instructions: List<string> (pasos numerados)
  - tips: List<string>
  - video_url: string (puede ser null en free tier)
  - difficulty: enum (principiante/intermedio/avanzado)
  - category: enum (fuerza/cardio/flexibilidad/funcional)
  - image_url: string

Crea un script de seed (tools/seed_exercises.dart) que cargue 50 ejercicios reales
a Firestore con datos completos. Incluye al menos:
- 15 ejercicios de pecho
- 15 ejercicios de espalda
- 10 ejercicios de pierna
- 10 ejercicios de hombro/brazo

También crea el modelo Isar para cachear los ejercicios localmente con sincronización
"stale-while-revalidate" (muestra cache, actualiza en background).

Genera: ExerciseEntity, ExerciseModel, ExerciseRemoteDatasource,
ExerciseLocalDatasource (Isar), ExerciseRepository, y los usecases:
GetExercisesUseCase, SearchExercisesUseCase, GetExerciseByIdUseCase.
```

### Prompt 5.2 — Rutinas predefinidas y personalizadas

```
Implementa el sistema de rutinas. Hay dos tipos:

1. Rutinas del sistema (predefinidas por FitCore):
   Almacenadas en Firestore en system_routines/{routineId}
   Disponibles para todos los usuarios
   Incluye al menos: "Push Pull Legs", "Full Body 3 días", "Rutina de principiante"

2. Rutinas del usuario (personalizadas):
   Almacenadas en users/{uid}/routines/{routineId}
   El usuario las crea desde cero o duplica una del sistema

Estructura de una rutina:
- name, description, difficulty
- days_per_week: int
- estimated_duration_minutes: int
- days: List<RoutineDay>
  - day_name: string ("Día 1 - Push")
  - exercises: List<RoutineExercise>
    - exercise_id: string
    - sets: int
    - reps_range: string ("8-12") o duration_seconds: int
    - rest_seconds: int
    - notes: string (opcional)

UI que necesito:
- RoutinesScreen: tabs "Para ti" (recomendadas por objetivo) y "Mis rutinas"
- RoutineDetailScreen: muestra todos los días y ejercicios con imágenes
- CreateRoutineScreen: wizard de 3 pasos para crear rutina personalizada
  (nombre/descripción → seleccionar días → agregar ejercicios por día)
- ExercisePickerScreen: buscador con filtros por músculo/equipo para agregar ejercicios

Las rutinas del sistema son solo lectura. El botón "Usar esta rutina" la asigna
al usuario. Solo los usuarios premium pueden crear más de 2 rutinas personalizadas.
```

---

## FASE 6 — Registro de Entrenamientos

> **Cuándo usarlo:** Las rutinas existen. Ahora el usuario puede iniciar y registrar entrenos.

### Prompt 6.1 — Pantalla de entrenamiento activo

```
Esta es la pantalla más importante de la app. Construye ActiveWorkoutScreen.

Flujo de la pantalla:
1. Se inicia desde "Empezar entrenamiento" en una rutina específica
2. Muestra el ejercicio actual con: nombre, imagen, sets programados
3. Para cada set el usuario registra:
   - Peso utilizado (kg/lb, con toggle)
   - Repeticiones realizadas (o tiempo si es ejercicio por duración)
   - Botón "Set completado" que hace haptic feedback y marca el set con checkmark
4. Timer de descanso: al completar un set, inicia automáticamente el timer de descanso
   programado con sonido al finalizar (configurable en settings)
5. Navegación entre ejercicios: swipe o botones "Anterior" / "Siguiente"
6. Botón "Finalizar entrenamiento" (con confirmación si quedan ejercicios)

Funcionalidades adicionales:
- La pantalla permanece activa (WakeLock) durante el entrenamiento
- Si el usuario sale de la app, el entrenamiento continúa en background
- Si cierra la app accidentalmente, al reabrir pregunta si quiere continuar el entreno
- Cronómetro general del entrenamiento visible en el AppBar
- El usuario puede agregar notas por ejercicio
- Puede sustituir un ejercicio por otro (usa ExercisePickerScreen)

Estado del entrenamiento se maneja con un WorkoutSessionNotifier en Riverpod
que persiste el estado en Isar cada 30 segundos como backup.
```

### Prompt 6.2 — Resumen post-entrenamiento

```
Construye WorkoutSummaryScreen que aparece al finalizar un entrenamiento.

Muestra:
1. Animación de celebración (confetti usando confetti package)
2. Métricas del entrenamiento:
   - Duración total
   - Volumen total (suma de sets × reps × peso)
   - Número de sets completados vs programados
   - Calorías quemadas (estimación basada en duración e intensidad)
3. Desglose por ejercicio: tabla con sets/reps/peso de cada ejercicio
4. Campo de notas generales del entreno
5. Calificación del entrenamiento (1-5 estrellas)
6. Botón "Compartir" que genera una imagen resumen con los stats
   (usando screenshot package para capturar el widget y share_plus para compartir)
7. Botón "Continuar" que va al Dashboard

Al finalizar guarda en Firestore:
- users/{uid}/workouts/{workoutId} con todos los datos del entrenamiento
- Actualiza la racha en users/{uid}/profile
- Si es el primer entrenamiento del día, otorga puntos de experiencia (gamificación básica)
```

---

## FASE 7 — Progreso y Estadísticas

> **Cuándo usarlo:** El usuario puede registrar entrenos. Ahora visualizamos el progreso.

### Prompt 7.1 — Pantalla de progreso

```
Construye ProgressScreen completa con estadísticas y gráficas.

Usa el paquete fl_chart para las gráficas.

Secciones:

1. Resumen del período (selector: semana / mes / 3 meses / año):
   - Entrenamientos realizados
   - Volumen total levantado
   - Minutos entrenando
   - Racha más larga

2. Gráfica de frecuencia: barras por semana mostrando días entrenados

3. Gráfica de volumen: línea de tendencia del volumen total por semana

4. Progreso de peso corporal:
   - Línea de tiempo con el histórico de pesos registrados
   - Diferencia vs peso inicial y peso del mes pasado

5. Récords personales (PRs) por ejercicio:
   - Lista de los top 10 ejercicios con su peso máximo registrado
   - Fecha en que se logró el PR
   - Badge especial si el PR fue esta semana

6. Medidas corporales (opcional, usuario puede registrar):
   - Cintura, pecho, brazos, piernas
   - Gráfica de evolución por medida

Solo los usuarios premium pueden ver el historial más allá de 30 días.
Para usuarios free, mostrar un blur con CTA de upgrade en los datos > 30 días.
```

---

## FASE 8 — Nutrición y Seguimiento de Calorías

> **Cuándo usarlo:** Progreso implementado. Añadimos el módulo de nutrición.

### Prompt 8.1 — Tracking de macros

```
Construye el módulo de nutrición.

El objetivo es sencillo: el usuario registra lo que come y ve su progreso de
calorías y macros del día.

Funcionalidades:

1. Meta diaria de calorías:
   - Calculada automáticamente con la fórmula Mifflin-St Jeor basada en el perfil
   - El usuario puede ajustarla manualmente

2. NutritionScreen muestra el día de hoy:
   - Anillo de progreso de calorías (consumidas / meta)
   - Barras de progreso para proteínas, carbohidratos y grasas
   - Lista de comidas del día agrupadas por: Desayuno, Almuerzo, Cena, Snacks
   - Botón "+" en cada comida para agregar alimentos

3. FoodSearchScreen:
   - Busca en la API pública de Open Food Facts (https://world.openfoodfacts.org/api)
   - Muestra resultados con nombre, calorías por 100g, y macros
   - El usuario selecciona cantidad en gramos o una porción predefinida
   - Guarda el alimento consumido en Firestore

4. Alimentos frecuentes:
   - Los 10 alimentos más usados por el usuario aparecen primero en la búsqueda
   - Se pueden crear alimentos personalizados

5. Historial de nutrición:
   - Vista de calendario con días completados (verde) vs días sin registro (gris)

Nota: toda la comunicación con Open Food Facts debe pasar por una Cloud Function
para evitar exponer la app a cambios en la API externa y para cachear respuestas.
```

---

## FASE 9 — Notificaciones y Recordatorios

> **Cuándo usarlo:** App funcional completa. Añadimos engagement con notificaciones.

### Prompt 9.1 — Sistema de notificaciones

```
Implementa el sistema de notificaciones con firebase_messaging y flutter_local_notifications.

Tipos de notificaciones:

1. Recordatorio de entrenamiento (local, programada):
   - El usuario elige los días y hora en Settings
   - "¡Es hora de entrenar! Tienes programado {nombre_rutina} hoy"
   - Se programa con flutter_local_notifications usando exact alarms

2. Racha en riesgo (local, programada):
   - Si el usuario tiene racha > 3 días y no ha entrenado hoy a las 8 PM:
   - "Tu racha de {N} días está en riesgo. ¡Tienes 4 horas para entrenar!"

3. Hidratación (local, recurrente, solo si usuario activa):
   - Cada 2 horas entre 8 AM y 8 PM: "Recuerda hidratarte 💧"

4. Push notifications remotas (Firebase Cloud Messaging):
   - Nuevas rutinas del sistema disponibles
   - Ofertas especiales de premium
   - Logros desbloqueados

Pantalla de Settings > Notificaciones:
- Toggle para cada tipo de notificación
- Selector de hora para el recordatorio de entrenamiento
- Selector de días de la semana para el recordatorio

Pide permiso de notificaciones durante el onboarding (paso 5, nuevo paso)
con una pantalla de "¿Quieres que te recordemos entrenar?" antes del permiso nativo.
```

---

## FASE 10 — Suscripciones y Pagos (Premium)

> **Cuándo usarlo:** La app está completa en funcionalidad. Monetizamos.

### Prompt 10.1 — Paywall y suscripciones

```
Implementa el sistema de suscripciones con RevenueCat (SDK: purchases_flutter).

Planes a ofrecer:
- Free: funciones básicas (máx. 2 rutinas personalizadas, historial 30 días, sin gráficas)
- Premium Mensual: $4.99 USD/mes
- Premium Anual: $34.99 USD/año (muestra "Ahorra 42%")

PremiumScreen (paywall):
1. Hero visual: imagen motivacional con el logo
2. Lista de beneficios premium con íconos:
   - ✓ Rutinas personalizadas ilimitadas
   - ✓ Historial y estadísticas sin límite
   - ✓ Gráficas avanzadas de progreso
   - ✓ Videos de ejercicios HD
   - ✓ Planes de nutrición personalizados
   - ✓ Sin anuncios
3. Toggle mensual/anual con el ahorro destacado
4. Botón de compra con el precio
5. Links a Términos y Condiciones y Política de Privacidad
6. "Restaurar compras" para usuarios que reinstalan la app

Implementa:
- PremiumNotifier que verifica el estado del usuario con RevenueCat
- Hook en el AppRouter que redirige a PremiumScreen cuando un usuario free
  intenta acceder a una función premium
- El estado premium se verifica al abrir la app y cada vez que la app vuelve
  al foreground (AppLifecycleListener)
- Webhook de Cloud Function que actualiza users/{uid}/subscription en Firestore
  cuando RevenueCat notifica un cambio (compra, renovación, cancelación)
```

---

## FASE 11 — Preparación para Producción

> **Cuándo usarlo:** Todo funciona y probado. Preparamos la app para publicar.

### Prompt 11.1 — Performance y optimizaciones

```
Revisa toda la app y aplica las siguientes optimizaciones de producción:

1. Imágenes:
   - Usa cached_network_image en todos los lugares donde se cargan imágenes de red
   - Configura el cache con máximo 100 imágenes y 7 días de expiración
   - Agrega placeholders y error widgets apropiados

2. Listas largas:
   - Verifica que todos los ListView con muchos items usen ListView.builder
   - En el catálogo de ejercicios, implementa paginación (20 items por página)
     usando Firestore startAfterDocument

3. Riverpod:
   - Verifica que los providers se dispongan (dispose) cuando no se usan
   - Usa keepAlive() solo donde sea necesario (providers del workout activo)

4. Fonts:
   - Configura la fuente personalizada (usa Inter de Google Fonts)
   - Pre-carga los assets de fuentes en main.dart

5. Splash screen nativa:
   - Configura flutter_native_splash con el logo de FitCore
   - Fondo negro (#0F0F1A)

6. Íconos de app:
   - Configura flutter_launcher_icons con el icono de FitCore
   - Genera todas las resoluciones para iOS y Android

Genera los archivos de configuración necesarios y los cambios de código requeridos.
```

### Prompt 11.2 — Testing

```
Escribe los tests críticos de la app.

Necesito:

1. Unit tests (test/unit/):
   - AuthRepositoryTest: verifica mapeo de FirebaseAuthException a Failure
   - WorkoutSessionNotifierTest: verifica que el estado se actualiza correctamente
   - CalorieCalculatorTest: verifica la fórmula Mifflin-St Jeor

2. Widget tests (test/widget/):
   - LoginScreenTest: verifica validación de formulario
   - ActiveWorkoutScreenTest: verifica que al completar un set se actualiza la UI

3. Integration test (integration_test/):
   - AuthFlowTest: register → onboarding → dashboard (usando Firebase Emulator)

Usa mocktail para los mocks. Cada test debe tener:
- Nombre descriptivo en español ("debería mostrar error cuando el email es inválido")
- Setup (arrange), acción (act) y verificación (assert) claramente separados

También genera el archivo de CI/CD para GitHub Actions (.github/workflows/main.yml) que:
- Corre los tests en cada PR
- Hace build de release para Android e iOS
- Notifica en Slack si falla (usando un webhook que el usuario configurará)
```

### Prompt 11.3 — Store Listing y Metadatos

```
Ayúdame a preparar los metadatos para publicar en las tiendas.

Para Google Play Store, genera:
1. Título de la app (máx 30 caracteres): en español
2. Descripción corta (máx 80 caracteres)
3. Descripción completa (máx 4000 caracteres): atractiva, con keywords de fitness
4. Lista de keywords relevantes para ASO (App Store Optimization)
5. Clasificación de contenido recomendada y justificación

Para App Store (iOS), genera:
1. Nombre de la app (máx 30 caracteres)
2. Subtítulo (máx 30 caracteres)
3. Descripción (máx 4000 caracteres)
4. Keywords (máx 100 caracteres totales, separados por coma)
5. Notas de revisión para el equipo de Apple

También genera:
- La Política de Privacidad completa (en español, cumple con GDPR y CCPA)
  considerando que recolectamos: email, datos físicos, datos de salud/fitness
- Los Términos y Condiciones básicos
- El texto del email de bienvenida que se envía al registrarse
  (usar Firebase Extension "Trigger Email")
```

### Prompt 11.4 — Checklist final

```
Dame el checklist completo de pre-lanzamiento para FitCore.

Organízalo en estas categorías y para cada item indica cómo verificarlo:

1. Funcionalidad core
2. Autenticación y seguridad
3. Performance (incluye cómo medir con Flutter DevTools)
4. Monetización (RevenueCat, compras de prueba en sandbox)
5. Analytics (configura Firebase Analytics con los eventos clave de la app)
6. Crashlytics (configura Firebase Crashlytics y verifica que captura crashes)
7. Privacidad y permisos
8. Accesibilidad (Semantics, contraste de colores, tamaños de fuente)
9. Pruebas en dispositivos reales (qué dispositivos mínimo probar)
10. Firma y build de release
11. Assets de la Store (screenshots, preview video, icono)
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
Cada prompt pide una capa o módulo específico, no todo a la vez.
"Construye el repositorio" es mejor que "Construye el módulo de auth completo".

**3. Especificidad técnica**
Nombrar paquetes, patrones y estructuras de carpetas evita que Claude adivine
e introduce inconsistencias. Si no especificas, Claude elegirá por ti (no siempre bien).

**4. Orden respeta las dependencias**
Los prompts siguen el orden: entidades → repositorio → usecases → UI.
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
- `"Usaste Provider en lugar de Riverpod. Corrige eso"`

---

*Documento generado como guía de referencia para construir FitCore con Claude.*
*Tiempo estimado de implementación siguiendo esta guía: 4-6 semanas de desarrollo activo.*
