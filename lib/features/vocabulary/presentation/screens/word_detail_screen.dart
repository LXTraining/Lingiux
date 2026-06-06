import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/word_card_model.dart';
import '../providers/vocabulary_provider.dart';

class WordDetailScreen extends ConsumerStatefulWidget {
  final String selectedWord;

  const WordDetailScreen({super.key, required this.selectedWord});

  @override
  ConsumerState<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends ConsumerState<WordDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wordCardsAsync = ref.watch(wordCardsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Word Cards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: wordCardsAsync.when(
        loading: () => const _WordCardsSkeleton(),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error al cargar tarjetas:\n$err',
                style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(wordCardsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (wordCards) {
          if (wordCards.isEmpty) {
            return const Center(
              child: Text(
                'No hay tarjetas disponibles.',
                style: TextStyle(color: AppColors.onSurfaceMuted),
              ),
            );
          }

          // Ordenar para mostrar la palabra seleccionada primero
          final selectedIndex = wordCards.indexWhere(
            (w) => w.word.toLowerCase() == widget.selectedWord.toLowerCase(),
          );

          final List<WordCardModel> sortedWords = [];
          if (selectedIndex != -1) {
            sortedWords.add(wordCards[selectedIndex]);
            sortedWords.addAll(
              wordCards.where(
                (w) => w.word.toLowerCase() != widget.selectedWord.toLowerCase(),
              ),
            );
          } else {
            // Si la palabra no está (por ejemplo si es inventada/custom), agregar un placeholder temporal
            sortedWords.add(
              WordCardModel(
                id: 'temp',
                word: widget.selectedWord,
                definition: 'Definición no encontrada para esta palabra.',
                phonetic: '/${widget.selectedWord.toLowerCase()}/',
                imageUrl: 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=600',
                createdAt: DateTime.now(),
              ),
            );
            sortedWords.addAll(wordCards);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.swipe_vertical_rounded,
                      color: AppColors.onSurfaceMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Desliza verticalmente para explorar',
                      style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(_currentPage % sortedWords.length) + 1} / ${sortedWords.length}',
                        style: const TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final wordIndex = index % sortedWords.length;
                    return _WordCard(
                      wordCard: sortedWords[wordIndex],
                      gradientIndex: index,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final WordCardModel wordCard;
  final int gradientIndex;

  const _WordCard({required this.wordCard, required this.gradientIndex});

  static const List<List<Color>> _gradients = [
    [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    [Color(0xFF0284C7), Color(0xFF6366F1)],
    [Color(0xFF059669), Color(0xFF0284C7)],
    [Color(0xFFD97706), Color(0xFFDC2626)],
    [Color(0xFFDB2777), Color(0xFF7C3AED)],
    [Color(0xFF0D9488), Color(0xFF2563EB)],
    [Color(0xFF7C3AED), Color(0xFFDB2777)],
    [Color(0xFF1D4ED8), Color(0xFF059669)],
  ];

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[gradientIndex % _gradients.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // 1. Imagen representativa de fondo cargada desde Supabase
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: wordCard.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.surfaceVariant,
                    child: const Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, err) => Container(
                    color: AppColors.surfaceVariant,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.onSurfaceMuted,
                      size: 40,
                    ),
                  ),
                ),
              ),

              // 2. Capa de degradado semi-transparente para legibilidad de textos
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        gradient[0].withOpacity(0.80),
                        gradient[1].withOpacity(0.92),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // 3. Círculos de diseño abstractos y sutiles
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // 4. Información de la palabra
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'VOCABULARY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      wordCard.word,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 46,
                        fontWeight: FontWeight.bold,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      wordCard.phonetic,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.18),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        _Tag(label: 'adjective'),
                        SizedBox(width: 8),
                        _Tag(label: 'B2 level'),
                        SizedBox(width: 8),
                        _Tag(label: 'English'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      wordCard.definition,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 15,
                        height: 1.65,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: _CardAction(
                            icon: Icons.bookmark_border_rounded,
                            label: 'Save',
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CardAction(
                            icon: Icons.quiz_outlined,
                            label: 'Practice',
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordCardsSkeleton extends StatefulWidget {
  const _WordCardsSkeleton();

  @override
  State<_WordCardsSkeleton> createState() => _WordCardsSkeletonState();
}

class _WordCardsSkeletonState extends State<_WordCardsSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 120,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.onSurface.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.onSurface.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 220,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 100,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    height: 1,
                    color: AppColors.onSurface.withOpacity(0.08),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: List.generate(
                      3,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 70,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.onSurface.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 150,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.onSurface.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.onSurface.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
