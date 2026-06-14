import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioService {
  bool _initialized = false;
  late Source _tapSource;
  late Source _flipSource;
  final List<AudioPlayer> _pool = [];
  int _nextPlayerIndex = 0;
  static const int _poolSize = 4;

  Future<void> init() async {
    if (_initialized) return;
    try {
      // 1. Detectar si existe tap_pop.mp3 en assets
      try {
        await rootBundle.load('assets/sounds/tap_pop.mp3');
        _tapSource = AssetSource('sounds/tap_pop.mp3');
        debugPrint('AudioService: detectado tap_pop.mp3 en assets');
      } catch (_) {
        _tapSource = AssetSource('sounds/tap_pop.wav');
        debugPrint('AudioService: usando tap_pop.wav de fallback');
      }

      // 2. Detectar si existe card_flip.mp3 en assets
      try {
        await rootBundle.load('assets/sounds/card_flip.mp3');
        _flipSource = AssetSource('sounds/card_flip.mp3');
        debugPrint('AudioService: detectado card_flip.mp3 en assets');
      } catch (_) {
        _flipSource = _tapSource; // Fallback al sonido de tap
        debugPrint('AudioService: usando tap_pop como fallback para card_flip');
      }

      // 3. Inicializar el pool de reproductores con el audio pre-cargado
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

  void playFlip() {
    if (!_initialized || _pool.isEmpty) return;
    try {
      final player = _pool[_nextPlayerIndex];
      player.play(_flipSource);
      _nextPlayerIndex = (_nextPlayerIndex + 1) % _poolSize;
    } catch (e) {
      debugPrint('Error al reproducir flip: $e');
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
