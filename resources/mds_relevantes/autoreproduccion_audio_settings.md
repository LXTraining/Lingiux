# Guía de Implementación y Arquitectura: Auto-reproducción de Audio y Pantalla de Configuración

Este documento describe con el mayor detalle posible la arquitectura, lógica, dependencias e implementaciones realizadas para soportar la reproducción automática de audio al hacer scroll vertical en las tarjetas de vocabulario y la creación de la nueva pantalla completa de configuración de Lingiux.

---

## 1. Contexto del Requerimiento

El objetivo de este requerimiento es doble:
1. **Experiencia de Usuario Inmersiva (Auto-play):** Al navegar y deslizar entre las cartas de vocabulario (Word Cards), el audio de pronunciación correspondiente a la carta en pantalla debe reproducirse automáticamente de forma inmediata, evitando que el usuario tenga que pulsar manualmente el icono del altavoz cada vez.
2. **Control y Configuración:** Debido a que la reproducción automática de audio puede resultar invasiva en entornos silenciosos, se requería una opción de configuración persistente. El usuario debe poder activar o desactivar esta función a través de un interruptor (switch). Por defecto, la auto-reproducción debe estar habilitada (`true`).
3. **Escalabilidad de la Configuración:** En lugar de presentar los ajustes en un menú flotante temporal a mitad de pantalla (Bottom Sheet), se decidió crear una pantalla dedicada a pantalla completa (`SettingsScreen`) que servirá como base modular para todos los futuros ajustes del sistema.

---

## 2. Bibliotecas e Importaciones Utilizadas

Para llevar a cabo esta funcionalidad, se incorporaron e interactúan diversas librerías y componentes clave:

### 1. `shared_preferences: ^2.3.2`
* **¿Qué es?:** Una envoltura multiplataforma para persistir datos sencillos de tipo clave-valor (NSUserDefaults en iOS, SharedPreferences en Android, etc.).
* **Propósito:** Almacenar localmente el estado del interruptor de auto-reproducción para que, cuando el usuario cierre y vuelva a abrir la aplicación, su preferencia se mantenga exactamente igual.
* **Importación:** `import 'package:shared_preferences/shared_preferences.dart';`

### 2. `flutter_riverpod: ^2.6.1`
* **¿Qué es?:** Un motor reactivo de inyección de dependencias y gestión de estados para Flutter.
* **Propósito:** Propagar el estado de la configuración a lo largo de toda la aplicación. Permite que la pantalla de visualización de cartas (`WordDetailScreen`) se entere de forma reactiva de los cambios realizados en la pantalla de ajustes (`SettingsScreen`).
* **Importación:** `import 'package:flutter_riverpod/flutter_riverpod.dart';`

### 3. `audioplayers: ^6.7.1`
* **¿Qué es?:** Una librería de Flutter para la reproducción de archivos de sonido simultáneos tanto en local como desde fuentes remotas (URLs).
* **Propósito:** Cargar la URL de audio alojada en el bucket de Supabase asociada a cada carta y controlar la detención (`stop()`) y reproducción (`play()`) del sonido al deslizar las tarjetas.
* **Importación:** `import 'package:audioplayers/audioplayers.dart';`

### 4. `flutter/services.dart`
* **¿Qué es?:** Servicios del sistema operativo expuestos a Flutter, encargados de la interacción de bajo nivel (teclado físico, portapapeles, vibración háptica).
* **Propósito:** Proporcionar retroalimentación física premium mediante vibraciones táctiles leves (`HapticFeedback.lightImpact()` y `HapticFeedback.selectionClick()`) al pulsar interruptores y botones de navegación.
* **Importación:** `import 'package:flutter/services.dart';`

---

## 3. Arquitectura del Flujo de Datos

Para lograr una carga libre de parpadeos y latencias asíncronas en la interfaz al consultar las preferencias guardadas, implementamos un patrón de inicialización síncrono mediante Riverpod:

```mermaid
graph TD
    A[main.dart: Arranca la App] --> B[sharedPrefs = await SharedPreferences.getInstance()]
    B --> C[main.dart: ProviderScope overrides]
    C --> D[sharedPreferencesProvider sobreescrito síncronamente]
    D --> E[settingsProvider inicializa su State desde SharedPreferences]
    E --> F[SettingsScreen: Lee/Escribe en settingsProvider]
    E --> G[WordDetailScreen: Lee settingsProvider para habilitar auto-play]
```

1. **Pre-inicialización Síncrona:** Cargamos la instancia física de `SharedPreferences` en la función `main()` antes del arranque del árbol de widgets (`runApp`).
2. **Inyección en Scope:** Modificamos la raíz de proveedores (`ProviderScope`) para sobreescribir la instancia de `sharedPreferencesProvider` con el valor ya obtenido en memoria.
3. **Acceso Seguro:** Cualquier widget o notificador puede leer las preferencias inmediatamente sin necesidad de manejar construcciones asíncronas de tipo `FutureBuilder`.

---

## 4. Detalle de Modificaciones en el Código

A continuación se desglosan los cambios específicos aplicados en cada archivo del proyecto:

### 1. [pubspec.yaml](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/pubspec.yaml)
Añadimos la librería oficial de persistencia al catálogo de dependencias directas:
```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... (resto de dependencias)
  path_provider: ^2.1.6
  shared_preferences: ^2.3.2 # <-- Añadida para persistir los ajustes de usuario
```

### 2. [main.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/main.dart)
Modificamos el punto de entrada de la aplicación para inicializar `SharedPreferences` antes de que la interfaz de usuario se construya.
* **Importaciones añadidas:**
  * `import 'package:shared_preferences/shared_preferences.dart';`
  * `import 'features/profile/presentation/providers/settings_provider.dart';`
* **Cambios en `main()`:**
  * Declaración de `final sharedPrefs = await SharedPreferences.getInstance();`.
  * Configuración del parámetro `overrides` en `ProviderScope` para asignar la instancia a `sharedPreferencesProvider`.

### 3. [settings_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/providers/settings_provider.dart) [NUEVO]
Implementa el estado del modelo y el controlador que vincula las actualizaciones visuales del usuario con la base de datos local de SharedPreferences:
* **`sharedPreferencesProvider`:** Un proveedor síncrono que expone la instancia. Lanza una excepción si se intenta usar sin sobreescribir primero.
* **`AppSettings`:** Una clase modelo inmutable. Actualmente maneja el atributo `autoPlayAudio`, lista para expandirse con opciones como "Tema oscuro", "Descarga automática", o "Idioma por defecto".
* **`SettingsNotifier`:** Un `StateNotifier<AppSettings>` que se inicializa consultando la clave `'auto_play_audio'`. Si no existe un valor previo en memoria (primera ejecución), asigna `true` por defecto. Proporciona el método `setAutoPlayAudio(bool)` que actualiza la base de datos de manera persistente y emite el nuevo estado a los escuchadores reactivos.
* **`settingsProvider`:** Expone el estado inmutable y el controlador a la interfaz.

### 4. [settings_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/screens/settings_screen.dart) [NUEVO]
Implementa una pantalla completa y sumamente cuidada a nivel de diseño:
* **Estructura Estética:**
  * Fondo base en `#F8F9FD` (`AppColors.background`).
  * Un degradado sutil en la parte superior para atenuar la visualización y dar un aire de alta fidelidad.
  * Grupos de ajustes encapsulados en contenedores con bordes redondeados a `24px` y sombras difusas muy suaves, simulando una interfaz limpia estilo "Soft UI".
* **Preferencias de Audio:** Incorpora un switch adaptativo (`Switch.adaptive`) que lee su valor desde `ref.watch(settingsProvider).autoPlayAudio` y despacha el cambio al notificador.
* **Sección de Cuenta:** Elementos de lista de navegación clásicos para "Editar Perfil", "Notificaciones" y "Ayuda".
* **Cierre de Sesión:** Un tile en color de error destructivo (`AppColors.error`). Al pulsarlo, no realiza la acción directamente, sino que muestra un modal de confirmación (`AlertDialog`) estilizado con esquinas redondeadas a `28px` e indicaciones claras.

### 5. [profile_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/screens/profile_screen.dart)
Adaptamos los puntos de acceso para la configuración para que naveguen a la nueva pantalla:
* **Importaciones añadidas:** `import 'settings_screen.dart';`
* **Limpieza:** Eliminamos por completo la antigua función de ayuda `_showSettingsBottomSheet(...)` que construía el modal inferior a media pantalla.
* **Puntos de navegación actualizados:** Tanto el botón en el AppBar (`Icons.settings_outlined`) como el botón del menú de hamburguesa (`Icons.menu_rounded`) en los accesos rápidos fueron modificados en sus eventos de tap/press para abrir la nueva pantalla completa:
  ```dart
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  );
  ```

### 6. [word_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/screens/word_detail_screen.dart)
Esta pantalla es el núcleo consumidor de la funcionalidad de audio automático:
* **Importaciones añadidas:** `import '../../../profile/presentation/providers/settings_provider.dart';`
* **Método `_playAudio(String? url)`:** Encargado de centralizar la reproducción de audio de pronunciaciones. Detiene el reproductor previamente activo (`_networkPlayer.stop()`), actualiza los estados locales de reproducción para iluminar la interfaz de la carta activa y reproduce el nuevo audio mediante `UrlSource(url)`.
* **Reproducción Automática en Carga Inicial:**
  * Introdujimos la bandera `_hasPlayedInitialAudio` inicializada en `false`.
  * Al ingresar a la pantalla y renderizar con éxito el estado `data(wordCards)`, comprobamos si `_hasPlayedInitialAudio` es falso.
  * Si es falso, la marcamos como `true` y utilizamos `WidgetsBinding.instance.addPostFrameCallback` para consultar `ref.read(settingsProvider).autoPlayAudio`. Si está activo y la carta seleccionada tiene una URL de audio válida, esta se reproduce de manera inmediata.
* **Reproducción Automática en Deslizamiento (Scroll):**
  * Modificamos el evento `onPageChanged` del `PageView.builder`.
  * Además de actualizar la página actual y detener el reproductor, se consulta `settings.autoPlayAudio`. Si está activo y la nueva carta tiene audio, se invoca `_playAudio` para que empiece a sonar inmediatamente después de pasar la página.

---

## 5. Control de Calidad y Pruebas

Para asegurar que estos cambios masivos no introdujeran comportamientos indeseados, se completaron dos niveles de pruebas locales:

1. **Análisis de Lints y Tipados (`flutter analyze`):**
   * Validamos que todas las llamadas de la app no tengan problemas sintácticos.
   * Corregimos los accesos relativos de importación incorrectos (cambiando `../../` por `../../../`).
   * Eliminamos el warning de deprecación del interruptor adaptativo reemplazando `activeColor` por `activeThumbColor` según las recomendaciones más recientes de Flutter SDK.
2. **Pruebas Automatizadas del Motor (`flutter test`):**
   * Corrimos los tests de widgets nativos de la aplicación, comprobando que la inicialización base, la inyección del `ProviderScope` y los widgets raíz respondan con éxito sin romper flujos del backend o UI de autenticación.
