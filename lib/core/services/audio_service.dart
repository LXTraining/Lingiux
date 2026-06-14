import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioService {
  bool _initialized = false;
  late Source _tapSource;
  final List<AudioPlayer> _pool = [];
  int _nextPlayerIndex = 0;
  static const int _poolSize = 4;

  Future<void> init() async {
    if (_initialized) return;
    try {
      // Intentamos cargar el archivo .mp3 si existe en los assets
      try {
        await rootBundle.load('assets/sounds/tap_pop.mp3');
        _tapSource = AssetSource('sounds/tap_pop.mp3');
        debugPrint('AudioService: detectado tap_pop.mp3 en assets');
      } catch (_) {
        _tapSource = AssetSource('sounds/tap_pop.wav');
        debugPrint('AudioService: usando tap_pop.wav de fallback');
      }

      // Inicializamos el pool de reproductores para evitar retrasos de creación y recolección de basura
      for (int i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        await player.setSource(_tapSource);
        _pool.add(player);
      }
      
      _initialized = true;
      debugPrint('AudioService: Inicializado pool de $_poolSize reproductores');
    } catch (e) {
      debugPrint('Error inicializando AudioService: $e');
    }
  }

  void playTap() {
    if (!_initialized || _pool.isEmpty) return;
    try {
      final player = _pool[_nextPlayerIndex];
      player.play(_tapSource);
      _nextPlayerIndex = (_nextPlayerIndex + 1) % _poolSize;
    } catch (e) {
      debugPrint('Error al reproducir tap: $e');
    }
  }

  void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
    _pool.clear();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  service.init(); // Carga de forma asíncrona en segundo plano al arrancar el provider
  return service;
});
