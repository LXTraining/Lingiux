# Flutter para Producción: Todo lo que necesitas saber

## ¿Es Flutter bueno para producción?

**Sí, definitivamente.** Flutter está en producción en apps masivas:
- **Google Pay**, **eBay**, **BMW**, **Alibaba (Xianyu)**, **Nubank**
- Ideal para MVPs y startups porque un solo codebase corre en iOS, Android, Web y Desktop

---

## Mejores Prácticas

### Arquitectura
- Usa **clean architecture** o al menos separa en capas: `data / domain / presentation`
- Para state management: **Riverpod** (recomendado hoy en día), Bloc/Cubit, o Provider
- Evita poner lógica en los widgets directamente

### Estructura de proyecto
```
lib/
  features/
    auth/
      data/
      domain/
      presentation/
  shared/
    widgets/
    utils/
  core/
    router/
    theme/
```

### Código
- Preferir `const` en widgets siempre que sea posible (clave para performance)
- Separar widgets grandes en widgets pequeños y reutilizables
- Usar `flutter_lints` o `very_good_analysis` para enforcer calidad

---

## Limitaciones reales de Flutter

| Limitación | Detalle |
|---|---|
| **Plugins nativos** | Si necesitas algo muy específico del OS (hardware exótico, APIs nuevas de Android/iOS), a veces no hay plugin y toca escribir código nativo (Platform Channels) |
| **Web tiene limitaciones** | SEO es pobre, las apps web en Flutter no son indexables bien por Google. No reemplaza React/Next para sitios web |
| **Tamaño del APK/IPA** | Un APK Flutter mínimo pesa ~5-10 MB más que uno nativo. Para apps móviles normales no es problema |
| **Acceso muy profundo al OS** | Bluetooth complejo, VPN, extensiones de teclado, widgets nativos del sistema → requieren trabajo nativo adicional |
| **Maps** | Google Maps en Flutter funciona pero tiene quirks; Mapbox es una mejor alternativa |

---

## ¿Qué NO hacer en Flutter?

- No abusar de `setState` en widgets grandes (causa rebuilds innecesarios)
- No usar `BuildContext` fuera del árbol de widgets sin cuidado
- No ignorar el análisis de memoria y CPU en dispositivos reales
- No hardcodear tamaños en píxeles sin usar `MediaQuery` o `LayoutBuilder`

---

## GoRouter

**GoRouter** es el paquete oficial de routing (navegación) de Flutter, mantenido por el equipo de Google.

### Por qué usarlo
- Soporta **deep linking** (abrir la app desde una URL, necesario para producción)
- Maneja **URL en web** correctamente
- Soporta **guards de autenticación** (redirigir si no estás logueado)
- Navigation Stack declarativo y predecible

```dart
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => HomeScreen()),
    GoRoute(path: '/profile/:id', builder: (_, state) => ProfileScreen(id: state.pathParameters['id']!)),
  ],
  redirect: (context, state) {
    final isLoggedIn = ref.read(authProvider);
    if (!isLoggedIn) return '/login';
    return null;
  },
);
```

**Alternativa:** `auto_route` (más potente pero más setup)

---

## ¿Flutter se lagea?

**En teoría: no. En práctica: depende de cómo escribas el código.**

Flutter corre a **60fps o 120fps** nativamente con su propio motor de renderizado (Skia/Impeller). No usa componentes nativos del OS, todo lo dibuja él mismo → consistencia visual perfecta entre plataformas.

### Por qué se puede lagear tu app

| Causa | Solución |
|---|---|
| Widgets reconstruyéndose innecesariamente | Usar `const`, separar en widgets más pequeños, Riverpod selectivo |
| Trabajo pesado en el **main thread (UI thread)** | Mover a `Isolate` o `compute()` |
| Imágenes muy grandes sin caché | Usar `cached_network_image`, redimensionar en servidor |
| Listas largas sin lazy loading | Usar `ListView.builder` siempre, nunca `ListView` con todos los items |
| Animaciones complejas mal implementadas | Usar `AnimationController` correctamente, evitar `setState` en animaciones |
| Sombras y blur excesivos | `BoxShadow` y `BackdropFilter` son caros, úsalos con moderación |

### Herramientas para diagnosticar lag
```bash
flutter run --profile   # modo profile, muestra performance real
flutter run --trace-skia  # ver frames lentos
```
El **Flutter DevTools** tiene un Performance profiler que muestra exactamente qué widget tarda.

---

## Veredicto para tu proyecto

**Flutter es una excelente elección para:**
- App móvil (iOS + Android) con un solo equipo/persona
- MVP rápido que necesita verse profesional
- Startups que no quieren mantener dos codebases

**Considera otra opción si:**
- Tu producto principal es un **sitio web** (usa Next.js)
- Necesitas integraciones de hardware muy específicas desde el día 1
