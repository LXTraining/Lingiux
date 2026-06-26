# Plan de Implementación: Pantalla de Configuración y Auto-reproducción de Audio

Este plan describe los cambios necesarios para agregar la reproducción automática de audio al deslizar cartas de vocabulario, e introduce una nueva pantalla completa de configuración (SettingsScreen) accesible desde el perfil para alternar esta preferencia.

## User Review Required

> [!IMPORTANT]
> **Adición de Dependencias:** Añadiremos el paquete `shared_preferences` al archivo `pubspec.yaml` para persistir localmente las preferencias del usuario entre reinicios de la aplicación.
>
> **Comportamiento por Defecto:** La opción de reproducción automática de audio estará activada (`true`) por defecto en la primera carga.

## Open Questions

*No hay preguntas abiertas en este momento. El comportamiento por defecto de auto-reproducción y la navegación a pantalla completa están completamente definidos.*

## Proposed Changes

### Core & Dependencies

#### [MODIFY] [pubspec.yaml](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/pubspec.yaml)
- Añadir la dependencia `shared_preferences: ^2.3.2` bajo la sección de dependencias.

#### [MODIFY] [main.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/main.dart)
- Inicializar `SharedPreferences` asíncronamente en el método `main()` antes del arranque de la app.
- Sobreescribir `sharedPreferencesProvider` dentro del `ProviderScope` para inyectar la instancia de forma síncrona a la aplicación.

---

### State Management & Providers

#### [NEW] [settings_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/providers/settings_provider.dart)
- Crear el proveedor `sharedPreferencesProvider`.
- Crear el modelo de configuración `AppSettings` (con el atributo booleano `autoPlayAudio`).
- Crear `SettingsNotifier` (StateNotifier) para persistir la configuración usando la clave `auto_play_audio` y notificar cambios de estado.
- Registrar el `settingsProvider`.

---

### UI Components & Screens

#### [NEW] [settings_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/screens/settings_screen.dart)
- Crear una nueva pantalla completa con un diseño premium y limpio (`AppColors.background`).
- Estructurar el menú en secciones Soft UI utilizando contenedores redondeados (`24px`/`28px`) con sombra difusa:
  - **Preferencias de Audio:** Fila con switch de alternancia (`AppColors.primary`) para "Reproducción automática de audio".
  - **Cuenta:** Ajustes como "Editar perfil", "Notificaciones".
  - **Soporte:** "Ayuda y soporte".
  - **Sesión:** Botón/Tile llamativo para "Cerrar sesión" con confirmación visual.

#### [MODIFY] [profile_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/profile/presentation/screens/profile_screen.dart)
- Reemplazar la llamada a `_showSettingsBottomSheet` por una navegación directa a la nueva pantalla completa:
  ```dart
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  );
  ```
- Retirar el método obsoleto `_showSettingsBottomSheet` para mantener el archivo limpio.

#### [MODIFY] [word_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/screens/word_detail_screen.dart)
- Crear un método interno `_playAudio(String? url)` para reproducir explícitamente audios (deteniendo el reproductor previo y estableciendo el estado).
- Añadir la bandera local `_hasPlayedInitialAudio` para detectar la primera carga de datos del listado de cartas.
- En `onPageChanged`, verificar si `autoPlayAudio` está activo. De ser así, invocar `_playAudio` con el audio de la carta actual.
- Al cargar la palabra seleccionada por primera vez, reproducir su audio inmediatamente usando `WidgetsBinding.instance.addPostFrameCallback` si la opción está activa.

---

## Verification Plan

### Automated Tests
- Ejecutar `flutter analyze` para verificar que no haya advertencias o errores estáticos.
- Ejecutar `flutter test` para corroborar que no se rompa la inicialización base de la app.

### Manual Verification
1. Abrir el perfil del usuario y hacer clic en el botón de configuración (icono de engranaje o menú). Verificar que se abra la nueva pantalla completa de Ajustes con transiciones fluidas.
2. Comprobar que el interruptor "Reproducción automática de audio" esté activado por defecto.
3. Ir al listado de vocabulario y abrir el detalle de una carta. El audio debería reproducirse automáticamente en la carga y al deslizar verticalmente entre cartas.
4. Regresar a Configuración, desactivar el interruptor y volver a las cartas. Comprobar que al deslizar ya no se reproduce automáticamente y requiere hacer clic manual en el botón de altavoz.
5. Cerrar y abrir la aplicación para corroborar que la configuración modificada persiste correctamente en `SharedPreferences`.
