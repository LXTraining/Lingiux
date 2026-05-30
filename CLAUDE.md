# Lingiux

App móvil de aprendizaje de idiomas que prioriza la experiencia de aprendizaje mediante chats y textos con palabras tapeables, cards interactivasl contenido creado por el usuario, lecciones personalizadas y muchas dinámicas de aprendizaje moderno.

**Tech Stack:** Flutter 3.22+ (Dart), Riverpod, GoRouter, Supabase (Auth/DB/Storage/Realtime),
Isar (caché offline), get_it + injectable, fpdart, RevenueCat, Sentry, OneSignal

## Quick Start

- **Ejecutar app:** `flutter run`
- **Tests:** `flutter test`
- **Análisis:** `flutter analyze`
- **Formato:** `dart format lib/`

## Project Structure

- `lib/core/constants/` — Colores, strings, rutas
- `lib/core/theme/` — AppTheme (dark mode por defecto)
- `lib/core/errors/` — Clases Failure para fpdart
- `lib/core/services/` — Cliente Supabase, inicialización
- `lib/features/` — Una carpeta por feature (auth, learn, review, progress…)
- `lib/shared/data/` — Mock data y recursos compartidos
- `resources/` — Referencia de diseño y documentación

Cada feature sigue: `data/` → `domain/` → `presentation/` (screens, widgets, providers)

## Architecture Rules

- Sin lógica de negocio en widgets — toda la lógica va en el `StateNotifier`
- Repositorios retornan `Either<Failure, T>` (fpdart)
- Caché local con Isar usando estrategia stale-while-revalidate
- Nombres en inglés en el código, comentarios en español
- Código null-safe, sin `late` innecesarios

## See Also

- `resources/` — Documentación de fases, ui/ux design, prompts y guías de arquitectura
