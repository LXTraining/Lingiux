import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/constants/app_colors.dart';

class StepCardPreview extends StatefulWidget {
  final String wordText;
  final String phoneticText;
  final String definitionText;
  final String exampleText;
  final Uint8List? imageBytes;
  final String? recordedAudioPath;
  final int selectedGradientIndex;
  final String selectedFrameType;

  const StepCardPreview({
    super.key,
    required this.wordText,
    required this.phoneticText,
    required this.definitionText,
    required this.exampleText,
    required this.imageBytes,
    required this.recordedAudioPath,
    required this.selectedGradientIndex,
    required this.selectedFrameType,
  });

  @override
  State<StepCardPreview> createState() => _StepCardPreviewState();
}

class _StepCardPreviewState extends State<StepCardPreview> {
  bool _isFlipped = false;
  final _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  static const List<List<Color>> _gradients = [
    [Color(0xFF6366F1), Color(0xFF3B82F6)], // Indigo-Blue
    [Color(0xFF8B5CF6), Color(0xFFEC4899)], // Purple-Pink
    [Color(0xFF10B981), Color(0xFF059669)], // Emerald
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Amber
    [Color(0xFFF43F5E), Color(0xFFEF4444)], // Rose-Red
    [Color(0xFF14B8A6), Color(0xFF0D9488)], // Teal
  ];

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playRecordedAudio() async {
    if (widget.recordedAudioPath == null) return;
    try {
      if (_isPlayingAudio) {
        await _audioPlayer.stop();
        setState(() => _isPlayingAudio = false);
      } else {
        await _audioPlayer.play(DeviceFileSource(widget.recordedAudioPath!));
        setState(() => _isPlayingAudio = true);
        _audioPlayer.onPlayerComplete.first.then((_) {
          if (mounted) {
            setState(() => _isPlayingAudio = false);
          }
        });
      }
    } catch (e) {
      debugPrint('Error al reproducir audio: $e');
    }
  }

  Widget _buildFrameDecoration(String type, Widget child, {required bool isBack}) {
    if (type == 'normal') {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
        ),
        child: child,
      );
    }

    Color frameColor;
    Color glowColor;
    double borderWidth = 6.0;
    List<BoxShadow> shadows = [];

    switch (type) {
      case 'bronce':
        frameColor = const Color(0xFFCD7F32);
        glowColor = const Color(0xFF8B5A2B);
        shadows = [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ];
        break;
      case 'plata':
        frameColor = const Color(0xFFE0E0E0);
        glowColor = const Color(0xFF9E9E9E);
        shadows = [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 1.5,
          )
        ];
        break;
      case 'oro':
        frameColor = const Color(0xFFFFD700);
        glowColor = const Color(0xFFDAA520);
        shadows = [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.55),
            blurRadius: 14,
            spreadRadius: 2.5,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
        ];
        break;
      case 'neon':
        frameColor = const Color(0xFFEC4899);
        glowColor = const Color(0xFFEC4899);
        shadows = [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.6),
            blurRadius: 16,
            spreadRadius: 3.5,
          ),
        ];
        borderWidth = 5.0;
        break;
      default:
        return child;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: frameColor, width: borderWidth),
        boxShadow: shadows,
      ),
      child: child,
    );
  }

  Widget _buildCardFront(List<Color> gradient) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo degradado
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Imagen con filtro
          if (widget.imageBytes != null) ...[
            Image.memory(
              widget.imageBytes!,
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          // Contenido textual
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icono e indicación de audio si existe
                if (widget.recordedAudioPath != null) ...[
                  Center(
                    child: GestureDetector(
                      onTap: _playRecordedAudio,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlayingAudio ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                // Palabra
                Text(
                  widget.wordText.isNotEmpty ? widget.wordText : 'Palabra',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.phoneticText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.phoneticText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(List<Color> gradient) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo oscuro premium uniforme para lectura clara
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradient[0].withValues(alpha: 0.95),
                  AppColors.darkBackground,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Contenido textual de definición
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.translate_rounded,
                  color: Colors.white54,
                  size: 24,
                ),
                const SizedBox(height: 14),
                const Text(
                  'SIGNIFICADO',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.definitionText.isNotEmpty ? widget.definitionText : 'Definición sin registrar.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.exampleText.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'EJEMPLO',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"${widget.exampleText}"',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Inter',
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[widget.selectedGradientIndex % _gradients.length];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Previsualización de Carta',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toca la tarjeta para voltearla y verificar cómo se ve el frente y el reverso antes de guardarla.',
            style: TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // TARJETA VOLTEABLE 3D EN EL CENTRO
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isFlipped = !_isFlipped;
                });
              },
              child: SizedBox(
                width: 190,
                height: 270,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: _isFlipped ? math.pi : 0.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutCubic,
                  builder: (context, angle, child) {
                    final isBack = angle >= math.pi / 2;

                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(angle),
                      alignment: Alignment.center,
                      child: _buildFrameDecoration(
                        widget.selectedFrameType,
                        Stack(
                          fit: StackFit.expand,
                          children: [
                            if (!isBack)
                              _buildCardFront(gradient)
                            else
                              Transform(
                                transform: Matrix4.identity()..rotateY(math.pi),
                                alignment: Alignment.center,
                                child: _buildCardBack(gradient),
                              ),
                          ],
                        ),
                        isBack: isBack,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // RESUMEN TÉCNICO DE LA TARJETA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                _buildSummaryRow(Icons.title_rounded, 'Palabra', widget.wordText.isNotEmpty ? widget.wordText : 'Sin texto'),
                const Divider(height: 20, thickness: 0.5),
                _buildSummaryRow(Icons.class_rounded, 'Marco', widget.selectedFrameType.toUpperCase()),
                const Divider(height: 20, thickness: 0.5),
                _buildSummaryRow(
                  Icons.audiotrack_rounded,
                  'Pronunciación',
                  widget.recordedAudioPath != null ? 'Audio Grabado' : 'Sin Audio',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
