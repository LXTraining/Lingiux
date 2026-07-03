# Implementación de Navegación por Gestos de Deslizamiento Bidireccional (Swipe)

Este documento detalla la arquitectura, el diseño de interacción gestual y los cambios técnicos realizados en **Lingiux** para emular la navegación fluida y orgánica que utilizan las aplicaciones líderes del mercado de videos cortos (como TikTok, Instagram Reels y YouTube Shorts) entre el visor vertical de contenido y el perfil de los creadores.

---

## 1. Objetivo y Diseño de Interacción

En interfaces móviles modernas, minimizar las dependencias de botones estáticos y menús tradicionales mejora drásticamente la inmersión del usuario. El objetivo de esta implementación fue conectar el carrusel vertical de tarjetas de vocabulario (`WordDetailScreen`) con la pantalla del perfil del creador de cada tarjeta (`ProfileScreen`), usando gestos horizontales bidireccionales:
* **Swipe hacia la izquierda (Swipe Left):** Deslizar el dedo de derecha a izquierda sobre la tarjeta de vocabulario para empujar la pantalla del perfil del creador de forma fluida.
* **Swipe hacia la derecha (Swipe Right / Swipe Back):** Deslizar el dedo de izquierda a derecha en cualquier parte de la pantalla de perfil (o la de error) para hacer un pop de navegación inmediato y regresar al carrusel de tarjetas.

---

## 2. Conceptos Técnicos de Gestos y Física en Flutter

Para lograr una detección gestual confiable, se utilizó el widget nativo **`GestureDetector`** de Flutter, que expone propiedades físicas de arrastre en tiempo real a través del callback `onHorizontalDragEnd`.

### Detección de la Dirección del Swipe
Cuando el usuario retira el dedo de la pantalla al terminar un arrastre horizontal, el evento nos provee un objeto `DragEndDetails` que contiene la propiedad `primaryVelocity` (medida en píxeles lógicos por segundo):
1. **Velocidad Negativa (`primaryVelocity < -200`):**
   * Indica que el movimiento del dedo fue de derecha a izquierda (hacia la izquierda).
   * La app utiliza esta firma de velocidad para abrir la pantalla de perfil del creador.
2. **Velocidad Positiva (`primaryVelocity > 200`):**
   * Indica que el movimiento del dedo fue de izquierda a derecha (hacia la derecha).
   * La app utiliza esta firma de velocidad en la pantalla de perfil para regresar (hacer pop) a la pila de navegación.

### Respuesta Háptica Integrada
Para enriquecer la experiencia de usuario (UX) mediante micro-interacciones sensoriales físicas, se integró el sistema de **`HapticFeedback`** nativo de Flutter (`package:flutter/services.dart`):
* Se dispara un impacto de intensidad media (`HapticFeedback.mediumImpact()`) al transicionar hacia el perfil.
* Se dispara un impacto ligero (`HapticFeedback.lightImpact()`) al regresar al carrusel por medio de swipe back.

---

## 3. Modulación de Providers con Riverpod (Carga de Terceros)

Anteriormente, la pantalla de perfil (`ProfileScreen`) estaba acoplada estrictamente al usuario autenticado, leyendo directamente las claves del perfil de Supabase a partir de la sesión activa local. 

Para habilitar la visualización del perfil de cualquier usuario de la comunidad al hacer swipe en sus tarjetas, rediseñamos la capa de proveedores (State Providers) utilizando el modificador **`.family`** de Riverpod.

### profileFamilyProvider
Este proveedor asíncrono acepta ahora un parámetro de tipo `String? userId` para buscar la información del perfil correspondiente en la tabla `profiles` de Supabase de manera dinámica:
```dart
final profileFamilyProvider = FutureProvider.family.autoDispose<Map<String, dynamic>?, String?>((ref, userId) async {
  final supabase = ref.read(supabaseClientProvider);
  final effectiveUserId = userId ?? ref.watch(authProvider).user?.id;
  
  if (effectiveUserId == null) return null;

  try {
    return await supabase
        .from('profiles')
        .select()
        .eq('id', effectiveUserId)
        .maybeSingle();
  } catch (e) {
    return null;
  }
});
```

### userWordCardsFamilyProvider
De igual manera, creamos un proveedor parametrizado para consultar la lista de tarjetas de vocabulario creadas por cualquier usuario a partir de su ID:
```dart
final userWordCardsFamilyProvider = FutureProvider.family.autoDispose<List<WordCardModel>, String?>((ref, userId) async {
  final effectiveUserId = userId ?? ref.watch(authProvider).user?.id;
  if (effectiveUserId == null) return [];

  final supabase = ref.read(supabaseClientProvider);
  
  try {
    final response = await supabase
        .from('word_cards')
        .select()
        .eq('user_id', effectiveUserId)
        .order('created_at', ascending: false);
        
    return (response as List<dynamic>)
        .map((json) => WordCardModel.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (e) {
    rethrow;
  }
});
```

### Preservación de Compatibilidad Asíncrona (`.future`)
Para evitar duplicar lógica o romper la retrocompatibilidad con las pantallas que ya consumían `profileProvider` y `userWordCardsProvider` sin parámetros (que por defecto muestran el perfil del usuario actual), los redefinimos consumiendo internamente los nuevos family providers. 
Dado que el callback de un `FutureProvider` espera retornar un `Future`, utilizamos el selector **`.future`** para enganchar directamente el flujo asíncrono subyacente:
```dart
final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return ref.watch(profileFamilyProvider(null).future);
});

final userWordCardsProvider = FutureProvider.autoDispose<List<WordCardModel>>((ref) async {
  return ref.watch(userWordCardsFamilyProvider(null).future);
});
```

---

## 4. Adaptación Dinámica de la Pantalla de Perfil

Cuando se navega a `ProfileScreen`, el widget determina si el usuario está viendo su propio perfil o el de un tercero comparando el `userId` inyectado con el de su sesión en Supabase (`isOwnProfile = userId == null || userId == currentUserId`):

1. **Si es perfil ajeno (`!isOwnProfile`):**
   * **Seguridad y Privacidad:** Se desactiva el callback `onTap` de la foto de perfil para impedir que un usuario intente subir o alterar el avatar de otra persona.
   * **Ocultamiento de Controles:** Se ocultan los menús superiores de configuración, el menú de hamburguesa y los botones de editar/compartir perfil de la cabecera.
   * **Mensajería Instantánea Integrada:** Se renderiza un botón principal de **"Enviar Mensaje"**. Al pulsarlo, el sistema llama de forma asíncrona a `getOrCreateConversation` del servicio de chat, crea/busca la sala en Supabase, inicializa la entidad `ChatEntity` y redirige de inmediato al chat privado en `ChatDetailScreen`.
2. **Si es perfil propio (`isOwnProfile`):**
   * Se habilitan todos los controles de edición, menús de SharedPreferences y actualización de avatar de manera normal.

---

## 5. Gestión del Swipe sin Creador: `ProfileErrorScreen`

En Lingiux, todas las tarjetas deben soportar el deslizamiento horizontal para mantener una consistencia visual de primer nivel. Sin embargo, existen casos de tarjetas temporales de invitación o pre-cargadas de manera local (cuyo `userId` es nulo o vacío). 

Para resolver este escenario sin romper la experiencia fluida del usuario, implementamos la clase **`ProfileErrorScreen`**:
* En lugar de mostrar un aviso flotante (SnackBar) que interrumpe el flujo, la app abre una pantalla minimalista diseñada profesionalmente.
* Cuenta con un indicador circular animado de error en color carmesí difuminado, el mensaje *"No se pudo encontrar el perfil de este creador."* y un botón de retorno.
* **Consistencia Gestual:** Esta pantalla también está envuelta en un `GestureDetector` horizontal, lo que permite al usuario regresar al carrusel simplemente deslizando su dedo hacia la derecha.

---

## 6. Archivos Modificados y Creados

A continuación se detalla la lista de los archivos modificados con enlaces directos dentro de la estructura del proyecto:

### Capa de Proveedores y Modelos
* **[profile_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/providers/profile_provider.dart):**
  * Añadida la definición de `profileFamilyProvider`.
  * Rediseñado `profileProvider` para delegar de forma reactiva al family provider utilizando el stream de `.future`.
* **[vocabulary_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/providers/vocabulary_provider.dart):**
  * Añadida la definición de `userWordCardsFamilyProvider`.
  * Rediseñado `userWordCardsProvider` para delegar al family provider asíncrono.
  * Removidos imports redundantes para optimizar el análisis del compilador.

### Capa de Vistas e Interfaz de Usuario
* **[word_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/screens/word_detail_screen.dart):**
  * Importadas las pantallas `ProfileScreen` y `ProfileErrorScreen`.
  * Envuelto el carrusel de `itemBuilder` en un `GestureDetector` con detección de swipe hacia la izquierda.
  * Si hay creador, navega al perfil; en caso contrario, navega a la pantalla de error.
* **[profile_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/screens/profile_screen.dart):**
  * Añadido el parámetro `userId` opcional al constructor.
  * Envuelto el árbol de la pantalla principal en un `GestureDetector` con detección de swipe hacia la derecha para regresar.
  * Modificada la visibilidad de controles y botones condicionados por `isOwnProfile`.
  * Integrado el botón premium de chat directo ("Enviar Mensaje") conectado al API del servicio de Supabase.
  * Añadida la clase de interfaz de usuario de error `ProfileErrorScreen` al final del archivo.
