import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';

class WordDetailScreen extends StatefulWidget {
  final String selectedWord;

  const WordDetailScreen({super.key, required this.selectedWord});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  late PageController _pageController;
  late List<String> _words;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    final others = wordCards
        .where((w) => w.toLowerCase() != widget.selectedWord.toLowerCase())
        .toList();
    _words = [widget.selectedWord, ...others];
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.swipe_vertical_rounded,
                  color: AppTheme.onSurfaceMuted,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Swipe up to explore more words',
                  style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(_currentPage % _words.length) + 1} / ${_words.length}+',
                    style: const TextStyle(
                      color: AppTheme.onSurfaceMuted,
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
                final wordIndex = index % _words.length;
                return _WordCard(
                  word: _words[wordIndex],
                  gradientIndex: index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final String word;
  final int gradientIndex;

  const _WordCard({required this.word, required this.gradientIndex});

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
    final key = word.toLowerCase();
    final definition = wordDefinitions[key] ??
        'A fascinating word worth exploring and understanding in context.';
    final phonetic = wordPhonetics[key] ?? '/${word.toLowerCase()}/';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
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
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
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
                    word,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.bold,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    phonetic,
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
                  Row(
                    children: [
                      _Tag(label: 'adjective'),
                      const SizedBox(width: 8),
                      _Tag(label: 'B2 level'),
                      const SizedBox(width: 8),
                      _Tag(label: 'English'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    definition,
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
