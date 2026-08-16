# Documentación de Implementación: Pop-Up de Ejercicios Interactivos en Relatos 📚🧠🎮

Este documento proporciona una explicación detallada, exhaustiva y paso a paso sobre el diseño, estructura, tecnologías utilizadas y el proceso de reversión para los nuevos **Pop-ups de Ejercicios Interactivos** desplegados en la sección de relatos (`StoryReaderScreen`) de Lingiux.

---

## 🌿 1. Concepto e Idea de la Funcionalidad

Anteriormente, al leer un relato y pulsar sobre una palabra que tuviese una tarjeta de vocabulario asociada, el sistema mostraba una miniatura de la carta (`FlippableCard`) que el usuario podía voltear para ver la traducción. Si bien esto era informativo, requería que el usuario saliera del relato o entrara a la sección de repaso de cartas ("Card Scrolling") para resolver el ejercicio interactivo.

Con esta nueva funcionalidad, el sistema **lee dinámicamente la configuración del ejercicio de la tarjeta** directamente del campo `canvas_design` guardado en Supabase, y genera un pop-up interactivo en formato horizontal (con un tamaño exacto de **280x140 píxeles**) que permite resolver el ejercicio al instante, ofreciendo retroalimentación visual, auditiva y táctil en tiempo real sin interrumpir la lectura.

---

## 📸 2. Replicación del Boceto y Estructura del Interfaz

El pop-up replica la estructura dibujada en el boceto a mano alzada del usuario:
```text
┌────────────────────────────────────────────────────────┐
│  [ Imagen ]  │          ¿Es este libro azul?           │
│  [  de la  ]  │                                         │
│  [ Tarjeta]  │          ┌───────┐       ┌───────┐      │
│  [   🎨   ]  │          │  Sí   │       │  No   │      │
│  [ (90px) ]  │          └───────┘       └───────┘      │
└────────────────────────────────────────────────────────┘
```
1.  **Lado Izquierdo (Imagen - 90px):** Ocupa toda la altura izquierda (`140px`). Muestra la imagen de la tarjeta (`imageUrl`) con bordes redondeados adaptados al contenedor. Si la tarjeta no cuenta con una imagen asociada, se muestra un fallback limpio de tipo libreta con un icono representativo de libro.
2.  **Lado Derecho (Ejercicio - Expandido):** Espacio interactivo que varía según el tipo de ejercicio de la tarjeta:
    *   **Pregunta (`pregunta`):** Muestra la oración de ejemplo y dos botones de selección rápida: **Sí** y **No**.
    *   **Completar (`completar`):** Oculta la palabra clave en la oración de ejemplo reemplazándola con `_____` y muestra un selector de botones con la palabra correcta y distractores configurados en la tarjeta.
    *   **Acomodar (`acomodar`):** Oculta la frase. Muestra instrucciones y un botón para reproducir el audio de ejemplo. En la parte central expone una caja de renglón donde se van agregando los chips de palabras que el usuario toca desde el pool de abajo.

---

## 📂 3. Arquitectura y Ubicación en el Proyecto

Los cambios se encuentran centralizados dentro del módulo de relatos de la aplicación:

```text
lib/
└── features/
    └── lessons/
        └── presentation/
            └── screens/
                └── story_reader_screen.dart <--- [MODIFICADO]
resources/
└── mds_relevantes/
    └── implementacion_ejercicios_pop_up_relatos.md <--- [NUEVO] Este Documento
```

---

## 🛠️ 4. Tecnologías y Librerías Utilizadas

Para ofrecer una experiencia interactiva completa, la implementación utiliza las siguientes tecnologías y librerías externas:

1.  **`package:audioplayers/audioplayers.dart`**:
    *   *Propósito*: Permite la reproducción de archivos de audio nativos.
    *   *Uso*: Se utiliza en el ejercicio de tipo **Acomodar** para reproducir de forma asíncrona el audio pregrabado de la tarjeta (`widget.card.audioUrl`) mediante un reproductor local (`AudioPlayer()`).
2.  **`package:flutter_tts/flutter_tts.dart`**:
    *   *Propósito*: Síntesis de voz (Text-to-Speech).
    *   *Uso*: En caso de que la tarjeta de vocabulario no tenga un archivo de audio grabado por el usuario en `audioUrl`, se inicializa el motor TTS nativo del sistema operativo en el idioma correspondiente (`widget.card.language ?? 'en-US'`) para narrar la frase en voz alta y permitir la resolución del ejercicio de audición.
3.  **`HapticFeedback` (`package:flutter/services.dart`)**:
    *   *Propósito*: Motores de vibración del dispositivo (hápticos).
    *   *Uso*:
        *   `HapticFeedback.heavyImpact()` al responder correctamente para dar sensación táctil de éxito.
        *   `HapticFeedback.vibrate()` al cometer un error para indicar un fallo físico leve.
4.  **`AudioService` (`lib/core/services/audio_service.dart`)**:
    *   *Propósito*: Reproducción centralizada de sonidos UX de la aplicación.
    *   *Uso*: Reproduce los archivos de sonido UX correspondientes al seleccionar respuestas.

---

## ⚙️ 5. Detalles de la Implementación del Código

### Lógica de Inicialización (`_initializeQuiz`)
Cuando el pop-up se instancia, extrae la configuración directamente de `canvasDesign`:

```dart
  void _initializeQuiz() {
    final design = widget.card.canvasDesign;
    if (design == null || design['quiz_type'] == null) {
      // Ejercicio de Fallback de traducción si no tiene quiz configurado
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

### Lógica de Feedback y Reintentos
*   **Si es Correcto**: Pinta el botón/contenedor de color verde (`#DCFCE7`), emite vibración táctil pesada, reproduce sonido UX positivo y llama a `widget.onDismiss()` tras **1.6 segundos** de visualización de éxito.
*   **Si es Incorrecto**: Pinta de color rojo (`#FEE2E2`), emite vibración leve, reproduce sonido UX neutro y llama de forma recursiva a `_initializeQuiz()` tras **1.6 segundos**, restableciendo el estado y limpiando los botones para que el usuario pueda intentar de nuevo el ejercicio.

---

## 🔄 6. Protocolo de Reversión (Cómo Deshacer los Cambios)

Si se desea desinstalar los pop-ups de ejercicios interactivos y restablecer las tarjetas normales con rotación 3D, siga las siguientes instrucciones detalladas:

### Paso 1: Reestablecer Imports en `story_reader_screen.dart`
Abra [`story_reader_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/lessons/presentation/screens/story_reader_screen.dart), elimine el import de `audioplayers` y vuelva a agregar el import de la pantalla de detalle:
```diff
- import 'package:audioplayers/audioplayers.dart';
+ import '../../../vocabulary/presentation/screens/word_detail_screen.dart';
```

### Paso 2: Revertir la Función `_showWordCard`
Reemplace el cuerpo de la función `_showWordCard` en [`story_reader_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/lessons/presentation/screens/story_reader_screen.dart#L302-L373) por la declaración original de la tarjeta flippable 3D:

```dart
  void _showWordCard(String word, WordCardModel? card, Offset wordCenter, Size wordSize) {
    _dismissOverlay();

    final cleanWord = word.replaceAll(RegExp(r"[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ']"), '');
    if (cleanWord.length < 2) return;

    final wordList = ref.read(wordCardsProvider).value ?? [];
    final matches = wordList.where((w) => w.word.toLowerCase() == cleanWord.toLowerCase()).toList();
    
    WordCardModel? selectedWordCard = card;
    if (selectedWordCard == null && matches.isNotEmpty) {
      selectedWordCard = matches.first;
    }

    if (selectedWordCard == null) return;

    ref.read(audioServiceProvider).playTap();
    HapticFeedback.lightImpact();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    const cardWidth = 96.0;
    const cardHeight = 136.0;

    double left = wordCenter.dx - (cardWidth / 2);
    left = left.clamp(16.0, screenWidth - cardWidth - 16.0);

    bool isBelow = true;
    double top = wordCenter.dy + wordSize.height + 8.0;

    if (top + cardHeight > screenHeight - 100) {
      isBelow = false;
      top = wordCenter.dy - cardHeight - 8.0;
    }

    final arrowLeft = (wordCenter.dx - left).clamp(16.0, cardWidth - 16.0);
    final cardController = FlippableCardController();

    void navigateToDetail() {
      _dismissOverlay();
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => WordDetailScreen(
            selectedWord: cleanWord,
            cardId: selectedWordCard?.id,
            conversationId: null,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
    }

    _overlayEntry = OverlayEntry(
      builder: (_) => OverlayEntrance(
        left: left,
        top: top,
        isBelow: isBelow,
        onDismiss: _dismissOverlay,
        onShare: () {},
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 200) {
            final swipeRight = details.primaryVelocity! > 0;
            cardController.flip(swipeRight: swipeRight);
            HapticFeedback.selectionClick();
          }
        },
        child: SizedBox(
          width: cardWidth,
          height: cardHeight + 8.0,
          child: FlippableCard(
            controller: cardController,
            isBelow: isBelow,
            arrowLeft: arrowLeft,
            front: WordMiniCardFront(
              word: cleanWord,
              card: selectedWordCard,
              onTap: navigateToDetail,
            ),
            back: WordMiniCardBack(
              word: cleanWord,
              card: selectedWordCard,
              onTap: navigateToDetail,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }
```

### Paso 3: Eliminar Clases del Extremo Inferior
Abra la parte final de [`story_reader_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/lessons/presentation/screens/story_reader_screen.dart) y elimine por completo las siguientes clases declaradas:
*   `class StoryExercisePopup`
*   `class _StoryExercisePopupState`
*   `class StoryWordExercise`
*   `class _ExerciseRandom`
