import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Proveedor para acceder a la instancia de SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Debe ser sobreescrito en el ProviderScope');
});

// Modelo de Configuración de la App
class AppSettings {
  final bool autoPlayAudio;

  const AppSettings({
    required this.autoPlayAudio,
  });

  AppSettings copyWith({
    bool? autoPlayAudio,
  }) {
    return AppSettings(
      autoPlayAudio: autoPlayAudio ?? this.autoPlayAudio,
    );
  }
}

// Notificador de Estado para la Configuración
class SettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(
          AppSettings(
            autoPlayAudio: _prefs.getBool('auto_play_audio') ?? true,
          ),
        );

  Future<void> setAutoPlayAudio(bool value) async {
    await _prefs.setBool('auto_play_audio', value);
    state = state.copyWith(autoPlayAudio: value);
  }
}

// Proveedor global para acceder y modificar las configuraciones
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
