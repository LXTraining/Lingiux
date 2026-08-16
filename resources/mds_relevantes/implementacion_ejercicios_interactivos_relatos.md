# Especificación Técnica: Ejercicios Interactivos In-App en Relatos 📚🧠

Este documento detalla la arquitectura, el diseño estético, la estructura del código y el proceso de reversión para la implementación de los pop-ups de ejercicios interactivos basados en la configuración de la tarjeta (`StoryReaderScreen`).

---

## 🌿 1. Introducción y Concepto Educativo

Para sincronizar la experiencia con el creador de tarjetas de vocabulario, en lugar de generar una pregunta genérica inventada por la aplicación, el lector de relatos lee de forma dinámica la configuración del ejercicio asignado a la tarjeta de vocabulario del usuario (`widget.card.canvasDesign`). 

Soportamos los tres tipos de ejercicios configurados en la aplicación:
1.  **Pregunta (True / False / Sí / No):**
    *   Muestra la frase de ejemplo (`exampleSentence`) y pregunta al usuario si es verdadera o falsa.
    *   El usuario responde presionando "Sí" o "No", comparando contra la clave `quiz_answer` guardada en la tarjeta.
    *   Si la tarjeta no tiene un ejercicio configurado, se auto-genera dinámicamente un ejercicio de tipo pregunta de traducción de vocabulario (*¿"[palabra]" significa "[definición]"?* con respuesta "Sí" como fallback seguro).
2.  **Completar la Palabra Faltante (Fill in the Blank):**
    *   Muestra la frase de ejemplo ocultando la palabra seleccionada por el creador (`quiz_hidden_word`), reemplazándola por `_____`.
    *   El usuario debe seleccionar la palabra correcta de un conjunto de botones mezclados (`_shuffledOptions`), que incluye la correcta y las incorrectas configuradas en la tarjeta (`quiz_distractors`).
3.  **Acomodar Palabras (Duolingo Style):**
    *   Instruye al usuario a escuchar la frase y ordenar las palabras desordenadas.
    *   Permite reproducir el audio grabado de la tarjeta (`audioUrl`) usando un reproductor de audio local (`AudioPlayer`). Si la tarjeta no cuenta con audio pregrabado, utiliza TTS (`FlutterTts`) para leer la frase con pronunciación nativa.
    *   El usuario ordena las palabras pulsando sobre el pool de chips mezclados (`_wordPool`) para subirlos a la barra de frase (`_assembledWords`).

---

## 📂 2. Archivos Afectados en la Estructura

```text
lib/
└── features/
    └── lessons/
        └── presentation/
            └── screens/
                └── story_reader_screen.dart <--- [MODIFICADO] Implementados layouts específicos para pregunta, 
                                                  completar y acomodar (con AudioPlayer y TTS).
resources/
└── mds_relevantes/
    └── implementacion_ejercicios_interactivos_relatos.md <--- [MODIFICADO] Actualización de la documentación técnica.
```

---

## ⚙️ 3. Detalles de la Implementación del Código

### A. Carga y Selección del Ejercicio en el Inicializador

Al cargar el pop-up, leemos la configuración directa del objeto JSON `canvasDesign`:

```dart
  void _initializeQuiz() {
    final design = widget.card.canvasDesign;
    if (design == null || design['quiz_type'] == null) {
      _quizType = 'pregunta';
      _exampleSentence = '¿"${widget.card.word}" significa "${widget.card.definition}"?';
      _quizAnswer = 'Sí';
    } else {
      _quizType = design['quiz_type'] as String? ?? 'pregunta';
      _quizAnswer = design['quiz_answer'] as String? ?? 'Sí';
      _quizHiddenWord = design['quiz_hidden_word'] as String? ?? '';
      _exampleSentence = widget.card.exampleSentence ?? '';
    }

    if (_quizType == 'acomodar') {
      final cleanSentence = _exampleSentence.replaceAll(RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()?¿¡]'), '');
      final words = cleanSentence.split(RegExp(r'\s+')).map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
      final List<dynamic> distractorsRaw = design?['quiz_distractors'] as List<dynamic>? ?? [];
      final distractors = distractorsRaw.map((e) => e.toString()).toList();
      _wordPool = [...words, ...distractors].where((w) => w.isNotEmpty).toList()..shuffle();
      _assembledWords = [];
    } else if (_quizType == 'completar') {
      final List<dynamic> distractorsRaw = design?['quiz_distractors'] as List<dynamic>? ?? [];
      final distractors = distractorsRaw.map((e) => e.toString()).toList();
      _shuffledOptions = [_quizHiddenWord, ...distractors].where((e) => e.isNotEmpty).toSet().toList()..shuffle();
      _selectedOption = null;
    }
  }
```

### B. Reproducción de Audio (Local AudioPlayer & TTS Fallback)

```dart
  Future<void> _playExampleAudio() async {
    if (_isPlayingAudio) {
      await _localAudioPlayer.stop();
      setState(() => _isPlayingAudio = false);
      return;
    }

    final url = widget.card.audioUrl;
    if (url != null && url.isNotEmpty) {
      try {
        setState(() => _isPlayingAudio = true);
        await _localAudioPlayer.play(UrlSource(url));
        _localAudioPlayer.onPlayerComplete.first.then((_) {
          if (mounted) setState(() => _isPlayingAudio = false);
        });
      } catch (e) {
        if (mounted) setState(() => _isPlayingAudio = false);
      }
    } else {
      final tts = FlutterTts();
      await tts.setLanguage(widget.card.language ?? 'en-US');
      await tts.speak(_exampleSentence);
    }
  }
```

### C. Lógica de Feedback y Reintento

*   **Si es correcto:** Se reproduce el sonido positivo, vibra el dispositivo y el pop-up se cierra automáticamente tras **1.6 segundos**.
*   **Si es incorrecto:** Se reproduce el sonido neutral/incorrecto, vibra y la interfaz se reinicia automáticamente tras **1.6 segundos** para que el usuario pueda intentar resolver el ejercicio de nuevo.

---

## 🔄 4. Protocolo de Reversión (Regresar a la Tarjeta Flippable Anterior)

1.  Abra [`story_reader_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/lessons/presentation/screens/story_reader_screen.dart).
2.  Remueva el import de `audioplayers`:
    ```dart
    import 'package:audioplayers/audioplayers.dart';
    ```
3.  Revierta el widget `SizedBox` de la propiedad `child` en `_showWordCard` para que dibuje el componente `FlippableCard` con las caras delantera y trasera normales.
4.  Elimine las clases `StoryExercisePopup` y sus auxiliares en el extremo inferior del archivo.
