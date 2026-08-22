import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_colors.dart';

class StepWordIdentity extends StatefulWidget {
  final TextEditingController wordController;
  final String selectedLanguage;
  final ValueChanged<String?> onLanguageChanged;
  final String? conversationId;

  const StepWordIdentity({
    super.key,
    required this.wordController,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    this.conversationId,
  });

  @override
  State<StepWordIdentity> createState() => _StepWordIdentityState();
}

class _StepWordIdentityState extends State<StepWordIdentity> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  // Estados de animación del botón de verificación
  double _buttonScale = 1.0;
  bool _isVerified = false;
  bool _hasError = false;

  // Lista de idiomas de aprendizaje comunes
  static const List<String> _languages = [
    'Inglés',
    'Español',
    'Portugués',
    'Francés',
    'Italiano',
    'Alemán',
  ];

  static const Map<String, String> _languageFlags = {
    'Inglés': 'assets/flags/us.svg',
    'Español': 'assets/flags/mx.svg',
    'Portugués': 'assets/flags/br.svg',
    'Francés': 'assets/flags/fr.svg',
    'Italiano': 'assets/flags/it.svg',
    'Alemán': 'assets/flags/de.svg',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Oscila suavemente sobre el eje Y (rotación lateral 3D)
    _rotationAnimation = Tween<double>(
      begin: -0.65, // Aproximadamente -37 grados en radianes
      end: 0.65,    // Aproximadamente 37 grados en radianes
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Simulación de verificación animada de palabra
  void _verifyWord() async {
    final word = widget.wordController.text.trim();
    if (word.isEmpty) {
      // Feedback visual de error
      setState(() {
        _hasError = true;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _hasError = false);
      });
      return;
    }

    // Micro-animación de encogimiento
    setState(() {
      _buttonScale = 0.82;
    });
    await Future.delayed(const Duration(milliseconds: 140));

    // Rebote y marcación de éxito
    if (mounted) {
      setState(() {
        _buttonScale = 1.08;
        _isVerified = true;
      });
    }
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) {
      setState(() {
        _buttonScale = 1.0;
      });
    }

    // Desactivar el estado verificado tras 2.5 segundos
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      setState(() {
        _isVerified = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),

          // 1. TÍTULO: Palabra Clave Centrado con tipografía restaurada
          Center(
            child: Text(
              widget.conversationId != null ? 'Crear Palabra Local' : 'Palabra Clave',
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 35),

          // 2. SIMULACIÓN DE CARTA VACÍA CON GIRO LATERAL 3D
          Center(
            child: AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015) // Perspectiva de profundidad de cámara 3D
                    ..rotateY(_rotationAnimation.value), // Rotación Y real en 3D
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: Container(
                width: 130,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      AppColors.primary.withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.style_rounded,
                    color: AppColors.primary,
                    size: 44,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 50),

          // 3. CAMPO DE ENTRADA UNIFICADO (Input palabra + Dropdown bandera redondeado)
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Input de la palabra
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: TextFormField(
                      controller: widget.wordController,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: AppColors.onSurface,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),

                // Contenedor de Dropdown de Idioma (Cápsula redondeada y mejorada a la derecha)
                Container(
                  height: 56,
                  width: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.border.withValues(alpha: 0.2), // Fondo gris suave
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(23),
                      bottomRight: Radius.circular(23),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.selectedLanguage,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.onSurfaceMuted),
                      onChanged: widget.onLanguageChanged,
                      selectedItemBuilder: (BuildContext context) {
                        return _languages.map<Widget>((String lang) {
                          final flagAsset = _languageFlags[lang] ?? 'assets/flags/us.svg';
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: SvgPicture.asset(
                                flagAsset,
                                width: 28,
                                height: 19,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        }).toList();
                      },
                      items: _languages.map((lang) {
                        final flagAsset = _languageFlags[lang] ?? 'assets/flags/us.svg';
                        return DropdownMenuItem<String>(
                          value: lang,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: SvgPicture.asset(
                                  flagAsset,
                                  width: 22,
                                  height: 16,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lang,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Inter',
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // 4. BOTÓN DE VERIFICACIÓN ANIMADO (Escala + Color dinámico)
          Center(
            child: AnimatedScale(
              scale: _buttonScale,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutBack,
              child: GestureDetector(
                onTap: _verifyWord,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isVerified
                        ? Colors.green
                        : (_hasError ? Colors.red : AppColors.primary),
                    boxShadow: [
                      BoxShadow(
                        color: (_isVerified
                                ? Colors.green
                                : (_hasError ? Colors.red : AppColors.primary))
                            .withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isVerified
                            ? Icons.check_circle_rounded
                            : (_hasError ? Icons.error_outline_rounded : Icons.check_rounded),
                        key: ValueKey<String>('${_isVerified}_$_hasError'),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
