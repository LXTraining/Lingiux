import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../../../vocabulary/presentation/screens/word_detail_screen.dart';
import '../../../vocabulary/domain/models/word_card_model.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/domain/entities/chat_entity.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GraphNode {
  final String id;
  final String label;
  final String type; // 'category', 'word', 'nationality', 'person'
  final Color color;
  final WordCardModel? wordCard; // null para no-palabras
  final Map<String, dynamic>? userProfile; // null para no-personas
  Offset position;
  Offset velocity;
  bool isDragged;
  bool isExpanded; // Solo para categorías y nacionalidades

  GraphNode({
    required this.id,
    required this.label,
    required this.type,
    required this.color,
    this.wordCard,
    this.userProfile,
    required this.position,
    this.velocity = Offset.zero,
    this.isDragged = false,
    this.isExpanded = true,
  });
}

class GraphEdge {
  final GraphNode source;
  final GraphNode target;

  GraphEdge({required this.source, required this.target});
}

class GraphRepaintNotifier extends ChangeNotifier {
  void requestRepaint() {
    notifyListeners();
  }
}

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  final List<GraphNode> _nodes = [];
  final List<GraphEdge> _edges = [];
  bool _isInitialized = false;
  String _viewMode = 'Palabras'; // 'Palabras' o 'Personas'
  String _lastViewMode = 'Palabras';
  late final TransformationController _transformationController;

  late Ticker _ticker;
  GraphNode? _draggedNode;
  Offset? _touchStartPos;
  bool _panEnabled = true;

  // Filtros activos para Cerebro Digital (Originales)
  String _selectedCategoryFilter = 'Todos';
  String _selectedLanguageFilter = 'Todos';
  String _selectedFrameFilter = 'Todos';

  final GraphRepaintNotifier _repaintNotifier = GraphRepaintNotifier();

  // Caché de imágenes de profile cargadas dinámicamente
  final Map<String, ui.Image> _profileImagesCache = {};

  // Caché de imágenes de banderas pre-cargadas (PictureInfo vectorial)
  final Map<String, PictureInfo> _flagPicturesCache = {};

  // Paleta de colores consistente para categorías
  static const List<Color> _categoryColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFFF43F5E), // Rose
    Color(0xFF6366F1), // Indigo
  ];

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'ADJETIVO':
      case 'ADJECTIVE':
        return const Color(0xFFF59E0B);
      case 'VERBO':
      case 'VERB':
        return const Color(0xFFEF4444);
      case 'SUSTANTIVO':
      case 'NOUN':
        return const Color(0xFF10B981);
      case 'FRASAL':
      case 'VERBO FRASAL':
      case 'PHRASE':
        return const Color(0xFF8B5CF6);
      default:
        final index = category.hashCode.abs() % _categoryColors.length;
        return _categoryColors[index];
    }
  }

  Color _getNationalityColor(String nationality) {
    switch (nationality.toUpperCase()) {
      case 'MÉXICO':
      case 'MEXICO':
        return const Color(0xFF10B981); // Verde México
      case 'ESTADOS UNIDOS':
      case 'USA':
        return const Color(0xFF3B82F6); // Azul EEUU
      case 'ALEMANIA':
      case 'GERMANY':
        return const Color(0xFFF59E0B); // Amber
      case 'COLOMBIA':
        return const Color(0xFFEAB308); // Amarillo
      case 'ESPAÑA':
      case 'SPAIN':
        return const Color(0xFFEF4444); // Rojo
      case 'FRANCIA':
      case 'FRANCE':
        return const Color(0xFF6366F1); // Indigo
      case 'ITALIA':
      case 'ITALY':
        return const Color(0xFF14B8A6); // Teal
      case 'PORTUGAL':
        return const Color(0xFFEC4899); // Rosa
      case 'REINO UNIDO':
      case 'UK':
        return const Color(0xFFF43F5E); // Rosado oscuro
      case 'JAPÓN':
      case 'JAPAN':
        return const Color(0xFF94A3B8); // Slate
      default:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _ticker.dispose();
    _repaintNotifier.dispose();
    super.dispose();
  }

  void _preloadProfileImage(String url) {
    if (url.isEmpty || _profileImagesCache.containsKey(url)) return;

    try {
      final imageProvider = NetworkImage(url);
      final ImageStream stream = imageProvider.resolve(ImageConfiguration.empty);
      stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _profileImagesCache[url] = info.image;
          });
          _repaintNotifier.requestRepaint();
        }
      }, onError: (dynamic exception, StackTrace? stackTrace) {
        // Silenciar errores de red
      }));
    } catch (_) {}
  }

  void _preloadFlagImage(String nationality) {
    final asset = _getNationalityFlagAsset(nationality);
    if (asset.isEmpty || _flagPicturesCache.containsKey(asset)) return;

    try {
      final SvgAssetLoader loader = SvgAssetLoader(asset);
      vg.loadPicture(loader, null).then((pictureInfo) {
        if (mounted) {
          setState(() {
            _flagPicturesCache[asset] = pictureInfo;
          });
          _repaintNotifier.requestRepaint();
        }
      }).catchError((_) {
        // Silenciar errores de carga
      });
    } catch (_) {}
  }

  void _onTick(Duration elapsed) {
    if (_nodes.isEmpty) return;

    final width = 800.0;
    final height = 800.0;
    final center = Offset(width / 2, height / 2);

    // Parámetros de física de simulación originales
    const double kr = 15000.0;     // Fuerza de repulsión de Coulomb
    const double ka = 0.09;        // Constante de resorte de Hooke (atracción)
    const double gravity = 0.04;   // Gravedad hacia el centro
    const double springLength = 95.0; // Distancia de separación elástica
    const double friction = 0.84;  // Amortiguación/Fricción

    // 1. Calcular fuerza de repulsión entre todos los nodos visibles
    for (int i = 0; i < _nodes.length; i++) {
      final nodeA = _nodes[i];
      if (nodeA.isDragged || !_isNodeVisible(nodeA)) continue;

      double fx = 0;
      double fy = 0;

      for (int j = 0; j < _nodes.length; j++) {
        if (i == j) continue;
        final nodeB = _nodes[j];
        if (!_isNodeVisible(nodeB)) continue;

        final diff = nodeA.position - nodeB.position;
        final dist = diff.distance;
        
        if (dist < 1.0) {
          final random = math.Random();
          nodeA.position += Offset(
            (random.nextDouble() - 0.5) * 4.0,
            (random.nextDouble() - 0.5) * 4.0,
          );
          continue;
        }

        double currentKr = kr;
        if ((nodeA.type == 'category' || nodeA.type == 'nationality') &&
            (nodeB.type == 'category' || nodeB.type == 'nationality')) {
          currentKr = kr * 10.0; // Fuerte repulsión entre nodos madre
        } else if (nodeA.type == 'category' && nodeB.type == 'word') {
          final catName = (nodeB.wordCard?.category ?? 'VOCABULARY').toUpperCase();
          if (nodeA.id != 'cat_$catName') {
            currentKr = kr * 4.0;
          }
        } else if (nodeA.type == 'word' && nodeB.type == 'category') {
          final catName = (nodeA.wordCard?.category ?? 'VOCABULARY').toUpperCase();
          if (nodeB.id != 'cat_$catName') {
            currentKr = kr * 4.0;
          }
        } else if (nodeA.type == 'nationality' && nodeB.type == 'person') {
          final natName = (nodeB.userProfile?['nationality'] as String? ?? 'México').toUpperCase();
          if (nodeA.id != 'nat_$natName') {
            currentKr = kr * 4.0;
          }
        } else if (nodeA.type == 'person' && nodeB.type == 'nationality') {
          final natName = (nodeA.userProfile?['nationality'] as String? ?? 'México').toUpperCase();
          if (nodeB.id != 'nat_$natName') {
            currentKr = kr * 4.0;
          }
        }

        final double radiusA = (nodeA.type == 'category' || nodeA.type == 'nationality') ? 24.0 : 12.0;
        final double radiusB = (nodeB.type == 'category' || nodeB.type == 'nationality') ? 24.0 : 12.0;
        final double minDistance = radiusA + radiusB + 10.0;

        final double safeDist = math.max(dist, minDistance);
        final force = currentKr / (safeDist * safeDist);
        fx += (diff.dx / dist) * force;
        fy += (diff.dy / dist) * force;
      }

      final diffToCenter = center - nodeA.position;
      final distToCenter = diffToCenter.distance;
      if (distToCenter > 1.0) {
        fx += (diffToCenter.dx / distToCenter) * distToCenter * gravity;
        fy += (diffToCenter.dy / distToCenter) * distToCenter * gravity;
      }

      nodeA.velocity = Offset(nodeA.velocity.dx + fx, nodeA.velocity.dy + fy);
    }

    // 2. Calcular atracción por resortes (Edges conectores)
    for (final edge in _edges) {
      final nodeA = edge.source;
      final nodeB = edge.target;

      if (!_isNodeVisible(nodeA) || !_isNodeVisible(nodeB)) continue;

      final diff = nodeB.position - nodeA.position;
      final dist = diff.distance;
      if (dist < 1.0) continue;

      final force = ka * (dist - springLength);
      final fx = (diff.dx / dist) * force;
      final fy = (diff.dy / dist) * force;

      if (!nodeA.isDragged) {
        nodeA.velocity = Offset(nodeA.velocity.dx + fx, nodeA.velocity.dy + fy);
      }
      if (!nodeB.isDragged) {
        nodeB.velocity = Offset(nodeB.velocity.dx - fx, nodeB.velocity.dy - fy);
      }
    }

    // 3. Aplicar velocidad, fricción y clamping
    for (final node in _nodes) {
      if (node.isDragged || !_isNodeVisible(node)) continue;

      node.position = node.position + node.velocity;
      node.velocity = node.velocity * friction;

      node.position = Offset(
        node.position.dx.clamp(40, width - 40),
        node.position.dy.clamp(40, height - 40),
      );
    }
    _repaintNotifier.requestRepaint();
  }

  bool _isNodeVisible(GraphNode node) {
    if (_viewMode == 'Palabras') {
      if (node.type == 'nationality' || node.type == 'person') return false;
      if (!_doesNodeMatchFilters(node)) return false;
      if (node.type == 'category') return true;
      final catName = (node.wordCard?.category ?? 'VOCABULARY').toUpperCase();
      final catNode = _nodes.firstWhere(
        (n) => n.id == 'cat_$catName',
        orElse: () => _nodes.first,
      );
      return catNode.isExpanded;
    } else {
      if (node.type == 'category' || node.type == 'word') return false;
      if (node.type == 'nationality') return true;
      final natName = (node.userProfile?['nationality'] as String? ?? 'México').toUpperCase();
      final natNode = _nodes.firstWhere(
        (n) => n.id == 'nat_$natName',
        orElse: () => _nodes.first,
      );
      return natNode.isExpanded;
    }
  }

  bool _doesNodeMatchFilters(GraphNode node) {
    if (node.type == 'category') {
      if (_selectedCategoryFilter != 'Todos') {
        final catName = node.label.toUpperCase();
        final expectedCat = _getCategoryFilterKey(_selectedCategoryFilter);
        return catName == expectedCat;
      }
      return true;
    }

    if (node.wordCard == null) return false;
    final card = node.wordCard!;

    // 1. Filtro de Categoría
    if (_selectedCategoryFilter != 'Todos') {
      final cardCat = (card.category ?? '').toUpperCase();
      final expectedCat = _getCategoryFilterKey(_selectedCategoryFilter);
      if (cardCat != expectedCat) return false;
    }

    // 2. Filtro de Idioma
    if (_selectedLanguageFilter != 'Todos') {
      final cardLang = (card.language ?? '').toUpperCase();
      final expectedLang = _selectedLanguageFilter.toUpperCase();
      if (cardLang != expectedLang) return false;
    }

    // 3. Filtro de Nivel (Frame)
    if (_selectedFrameFilter != 'Todos') {
      final cardFrame = (card.canvasDesign?['frame_type'] as String? ?? 'normal').toUpperCase();
      final expectedFrame = _selectedFrameFilter.toUpperCase();
      if (cardFrame != expectedFrame) return false;
    }

    return true;
  }

  String _getCategoryFilterKey(String filter) {
    switch (filter) {
      case 'Verbos':
        return 'VERBO';
      case 'Sustantivos':
        return 'SUSTANTIVO';
      case 'Adjetivos':
        return 'ADJETIVO';
      case 'Frases':
        return 'FRASAL';
      default:
        return filter.toUpperCase();
    }
  }

  void _rebuildEdges() {
    _edges.clear();
    if (_viewMode == 'Palabras') {
      for (final node in _nodes) {
        if (node.type == 'word') {
          final catName = (node.wordCard?.category ?? 'VOCABULARY').toUpperCase();
          final catNode = _nodes.firstWhere(
            (n) => n.id == 'cat_$catName',
            orElse: () => _nodes.first,
          );
          if (_isNodeVisible(node) && _isNodeVisible(catNode)) {
            _edges.add(GraphEdge(source: catNode, target: node));
          }
        }
      }
    } else {
      for (final node in _nodes) {
        if (node.type == 'person') {
          final natName = (node.userProfile?['nationality'] as String? ?? 'México').toUpperCase();
          final natNode = _nodes.firstWhere(
            (n) => n.id == 'nat_$natName',
            orElse: () => _nodes.first,
          );
          if (_isNodeVisible(node) && _isNodeVisible(natNode)) {
            _edges.add(GraphEdge(source: natNode, target: node));
          }
        }
      }
    }
  }

  void _syncWordNodes(List<WordCardModel> cards) {
    final categories = cards
        .map((c) => (c.category ?? 'VOCABULARY').toUpperCase())
        .toSet()
        .toList();

    // 1. Agregar categorías nuevas
    for (final cat in categories) {
      if (!_nodes.any((n) => n.id == 'cat_$cat' && n.type == 'category')) {
        final angle = _nodes.length * 2.0 * math.pi / 8.0;
        final center = const Offset(400, 400);
        final pos = center + Offset(math.cos(angle) * 160, math.sin(angle) * 160);
        _nodes.add(
          GraphNode(
            id: 'cat_$cat',
            label: cat,
            type: 'category',
            color: _getCategoryColor(cat),
            position: pos,
          ),
        );
      }
    }

    // 2. Agregar palabras nuevas
    for (final card in cards) {
      if (!_nodes.any((n) => n.id == card.id && n.type == 'word')) {
        final catName = (card.category ?? 'VOCABULARY').toUpperCase();
        final catNode = _nodes.firstWhere(
          (n) => n.id == 'cat_$catName',
          orElse: () => _nodes.first,
        );

        final random = math.Random();
        final offset = Offset(
          (random.nextDouble() - 0.5) * 80,
          (random.nextDouble() - 0.5) * 80,
        );
        _nodes.add(
          GraphNode(
            id: card.id,
            label: card.word,
            type: 'word',
            color: catNode.color,
            wordCard: card,
            position: catNode.position + offset,
          ),
        );
      }
    }

    // 3. Eliminar palabras viejas
    final cardIds = cards.map((c) => c.id).toSet();
    _nodes.removeWhere((node) {
      if (node.type == 'word') {
        return !cardIds.contains(node.id);
      }
      return false;
    });

    // 4. Eliminar categorías vacías
    final activeCategories = cards.map((c) => 'cat_${(c.category ?? 'VOCABULARY').toUpperCase()}').toSet();
    _nodes.removeWhere((node) {
      if (node.type == 'category') {
        return !activeCategories.contains(node.id);
      }
      return false;
    });

    _rebuildEdges();
  }

  void _syncPeopleNodes(List<ChatEntity> chats) {
    final nationalities = chats
        .map((c) => (c.nationality ?? 'México').toUpperCase())
        .toSet()
        .toList();

    // 1. Agregar categorías de nacionalidades nuevas
    for (final nat in nationalities) {
      _preloadFlagImage(nat);
      if (!_nodes.any((n) => n.id == 'nat_$nat' && n.type == 'nationality')) {
        final angle = _nodes.length * 2.0 * math.pi / 8.0;
        final center = const Offset(400, 400);
        final pos = center + Offset(math.cos(angle) * 160, math.sin(angle) * 160);
        _nodes.add(
          GraphNode(
            id: 'nat_$nat',
            label: nat,
            type: 'nationality',
            color: _getNationalityColor(nat),
            position: pos,
          ),
        );
      }
    }

    // 2. Agregar personas nuevas
    for (final chat in chats) {
      final profileId = chat.otherUserId;
      if (profileId == null || profileId.isEmpty) continue;

      if (chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty) {
        _preloadProfileImage(chat.avatarUrl!);
      }

      if (!_nodes.any((n) => n.id == profileId && n.type == 'person')) {
        final natName = (chat.nationality ?? 'México').toUpperCase();
        final natNode = _nodes.firstWhere(
          (n) => n.id == 'nat_$natName',
          orElse: () => _nodes.first,
        );

        final random = math.Random();
        final offset = Offset(
          (random.nextDouble() - 0.5) * 80,
          (random.nextDouble() - 0.5) * 80,
        );

        final profileMap = {
          'id': profileId,
          'full_name': chat.name,
          'avatar_url': chat.avatarUrl ?? '',
          'nationality': chat.nationality ?? 'México',
        };

        _nodes.add(
          GraphNode(
            id: profileId,
            label: chat.name,
            type: 'person',
            color: natNode.color,
            userProfile: profileMap,
            position: natNode.position + offset,
          ),
        );
      }
    }

    // 3. Eliminar personas viejas
    final activeChatUserIds = chats
        .map((c) => c.otherUserId)
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    _nodes.removeWhere((node) {
      if (node.type == 'person') {
        return !activeChatUserIds.contains(node.id);
      }
      return false;
    });

    // 4. Eliminar nacionalidades vacías
    final activeNationalities = chats
        .map((c) => 'nat_${(c.nationality ?? 'México').toUpperCase()}')
        .toSet();

    _nodes.removeWhere((node) {
      if (node.type == 'nationality') {
        return !activeNationalities.contains(node.id);
      }
      return false;
    });

    _rebuildEdges();
  }

  GraphNode? _findNodeAt(Offset pos) {
    for (final node in _nodes) {
      if (!_isNodeVisible(node)) continue;
      final radius = (node.type == 'category' || node.type == 'nationality') ? 32.0 : 20.0;
      final dist = (node.position - pos).distance;
      if (dist <= radius + 8.0) {
        return node;
      }
    }
    return null;
  }

  void _handleNodeTap(GraphNode node) {
    HapticFeedback.selectionClick();
    if (node.type == 'category') {
      setState(() {
        node.isExpanded = !node.isExpanded;
        _rebuildEdges();

        // Rebote elástico original restaurado
        if (node.isExpanded) {
          final random = math.Random();
          for (final child in _nodes) {
            if (child.type == 'word') {
              final catName = (child.wordCard?.category ?? 'VOCABULARY').toUpperCase();
              if ('cat_$catName' == node.id) {
                child.position = node.position +
                    Offset(
                      (random.nextDouble() - 0.5) * 20,
                      (random.nextDouble() - 0.5) * 20,
                    );
                child.velocity = Offset(
                  (random.nextDouble() - 0.5) * 45,
                  (random.nextDouble() - 0.5) * 45,
                );
              }
            }
          }
        }
      });
    } else if (node.type == 'nationality') {
      setState(() {
        node.isExpanded = !node.isExpanded;
        _rebuildEdges();

        // Rebote elástico homólogo para Personas
        if (node.isExpanded) {
          final random = math.Random();
          for (final child in _nodes) {
            if (child.type == 'person') {
              final natName = (child.userProfile?['nationality'] as String? ?? 'México').toUpperCase();
              if ('nat_$natName' == node.id) {
                child.position = node.position +
                    Offset(
                      (random.nextDouble() - 0.5) * 20,
                      (random.nextDouble() - 0.5) * 20,
                    );
                child.velocity = Offset(
                  (random.nextDouble() - 0.5) * 45,
                  (random.nextDouble() - 0.5) * 45,
                );
              }
            }
          }
        }
      });
    } else if (node.type == 'word' && node.wordCard != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WordDetailScreen(selectedWord: node.wordCard!.word),
        ),
      );
    } else if (node.type == 'person' && node.id.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: node.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordCardsAsync = ref.watch(correctWordCardsProvider);
    final chatsAsync = ref.watch(chatsProvider);

    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          // Fondo degradado espacial premium original RESTAURADO
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.gradientBgStart.withValues(alpha: 0.55),
                    AppColors.gradientBgEnd.withValues(alpha: 0.55),
                    AppColors.darkBackground,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                'cerebro_digital',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Inter',
                ),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
            body: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                if (mounted) {
                  setState(() {
                    _isInitialized = false;
                    _nodes.clear();
                    _edges.clear();
                    _transformationController.value = Matrix4.identity();
                  });
                }
                ref.invalidate(wordCardsProvider);
                ref.invalidate(resolvedCardsFamilyProvider(null));
                ref.invalidate(resolvedCardsProvider);
                ref.invalidate(correctWordCardsProvider);
                ref.invalidate(chatsProvider);
                try {
                  await ref.read(correctWordCardsProvider.future);
                  await ref.read(chatsProvider.future);
                } catch (_) {}
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverHeaderDelegate(
                      height: _viewMode == 'Palabras' ? 112.0 : 56.0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildViewModeToggle(),
                          if (_viewMode == 'Palabras') _buildFiltersCarrusel(),
                        ],
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: _viewMode == 'Palabras'
                        ? wordCardsAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                            error: (err, stack) => Center(
                              child: Text(
                                'Error al inicializar red neuronal: $err',
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                            data: (cards) {
                              if (cards.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 40.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.bubble_chart_outlined,
                                          size: 68,
                                          color: AppColors.onSurfaceMuted,
                                        ),
                                        SizedBox(height: 20),
                                        Text(
                                          'Tu Red Neuronal está vacía',
                                          style: TextStyle(
                                            color: AppColors.onSurface,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'Las palabras y categorías que crees mediante tus Word Cards se conectarán aquí para simular tu constelación mental de aprendizaje.',
                                          style: TextStyle(
                                            color: AppColors.onSurfaceMuted,
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              if (!_isInitialized || _lastViewMode != _viewMode) {
                                _syncWordNodes(cards);
                                _isInitialized = true;
                                _lastViewMode = _viewMode;
                              }

                              return _buildGraphView();
                            },
                          )
                        : chatsAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                            error: (err, stack) => Center(
                              child: Text(
                                'Error al cargar red de comunidad: $err',
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                            data: (chats) {
                              if (chats.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 40.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.forum_outlined,
                                          size: 68,
                                          color: AppColors.onSurfaceMuted,
                                        ),
                                        SizedBox(height: 20),
                                        Text(
                                          'Sin Conversaciones',
                                          style: TextStyle(
                                            color: AppColors.onSurface,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'Inicia un chat con otros usuarios en el feed para ver su nacionalidad en tu Cerebro Mental.',
                                          style: TextStyle(
                                            color: AppColors.onSurfaceMuted,
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              if (!_isInitialized || _lastViewMode != _viewMode) {
                                _syncPeopleNodes(chats);
                                _isInitialized = true;
                                _lastViewMode = _viewMode;
                              }

                              return _buildGraphView();
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTogglePill('Palabras', Icons.category_rounded),
            ),
            Expanded(
              child: _buildTogglePill('Personas', Icons.people_alt_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTogglePill(String mode, IconData icon) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        if (_viewMode == mode) return;
        HapticFeedback.mediumImpact();
        setState(() {
          _viewMode = mode;
          _isInitialized = false; // Forzar resincronización de nodos al cambiar de vista
          _nodes.clear();
          _edges.clear();
          _transformationController.value = Matrix4.identity();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.onSurfaceMuted,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              mode,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.onSurfaceMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleFilter<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 13),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                onChanged(val);
              },
              dropdownColor: AppColors.darkBackground,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 16),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCarrusel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _buildCapsuleFilter<String>(
              label: 'Categoría',
              value: _selectedCategoryFilter,
              icon: Icons.label_outline_rounded,
              items: ['Todos', 'Verbos', 'Sustantivos', 'Adjetivos', 'Frases'].map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(c),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategoryFilter = val;
                    _rebuildEdges();
                  });
                }
              },
            ),
            const SizedBox(width: 8),
            _buildCapsuleFilter<String>(
              label: 'Idioma',
              value: _selectedLanguageFilter,
              icon: Icons.language_rounded,
              items: ['Todos', 'Inglés', 'Alemán', 'Francés', 'Italiano', 'Portugués'].map((l) {
                return DropdownMenuItem(
                  value: l,
                  child: Text(l),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedLanguageFilter = val;
                    _rebuildEdges();
                  });
                }
              },
            ),
            const SizedBox(width: 8),
            _buildCapsuleFilter<String>(
              label: 'Nivel',
              value: _selectedFrameFilter,
              icon: Icons.workspace_premium_rounded,
              items: ['Todos', 'Normal', 'Bronce', 'Plata', 'Oro', 'Neón'].map((f) {
                return DropdownMenuItem(
                  value: f,
                  child: Text(f),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedFrameFilter = val;
                    _rebuildEdges();
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double viewWidth = constraints.maxWidth;
        final double viewHeight = constraints.maxHeight;
        
        final double targetX = (viewWidth / 2) - 400;
        final double targetY = (viewHeight / 2) - 400;
        
        if (_transformationController.value.isIdentity()) {
          _transformationController.value = Matrix4.identity()..translate(targetX, targetY);
        }

        return InteractiveViewer(
          transformationController: _transformationController,
          constrained: false,
          panEnabled: _panEnabled,
          scaleEnabled: true,
          minScale: 0.3,
          maxScale: 2.5,
          boundaryMargin: const EdgeInsets.all(400),
          child: Listener(
            onPointerDown: (event) {
              final localPos = event.localPosition;
              _touchStartPos = localPos;
              final tappedNode = _findNodeAt(localPos);
              if (tappedNode != null) {
                setState(() {
                  _draggedNode = tappedNode;
                  tappedNode.isDragged = true;
                  _panEnabled = false; // Bloquear paneo global para poder arrastrar
                });
              }
            },
            onPointerMove: (event) {
              if (_draggedNode != null) {
                setState(() {
                  _draggedNode!.position = event.localPosition;
                  _draggedNode!.velocity = Offset.zero; // Detener inercias al arrastrar
                });
              }
            },
            onPointerUp: (event) {
              if (_draggedNode != null) {
                final node = _draggedNode!;
                setState(() {
                  node.isDragged = false;
                  _draggedNode = null;
                  _panEnabled = true; // Liberar paneo
                });

                if (_touchStartPos != null) {
                  final delta = (event.localPosition - _touchStartPos!).distance;
                  if (delta < 6.0) {
                    _handleNodeTap(node);
                  }
                }
              }
              _touchStartPos = null;
            },
            child: CustomPaint(
              size: const Size(800, 800),
              painter: VocabularyGraphPainter(
                nodes: _nodes,
                edges: _edges,
                visibleNodes: _nodes.where(_isNodeVisible).toList(),
                profileImages: _profileImagesCache,
                flagImages: _flagPicturesCache,
                repaint: _repaintNotifier,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SliverHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverHeaderDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}

class VocabularyGraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<GraphNode> visibleNodes;
  final Map<String, ui.Image> profileImages;
  final Map<String, PictureInfo> flagImages;

  VocabularyGraphPainter({
    required this.nodes,
    required this.edges,
    required this.visibleNodes,
    required this.profileImages,
    required this.flagImages,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dibujar conexiones (Edges) con gradientes elásticos translúcidos
    final linePaint = Paint()
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final p1 = edge.source.position;
      final p2 = edge.target.position;

      final gradient = ui.Gradient.linear(
        p1,
        p2,
        [
          edge.source.color.withValues(alpha: 0.70),
          edge.target.color.withValues(alpha: 0.15),
        ],
      );

      linePaint.shader = gradient;
      canvas.drawLine(p1, p2, linePaint);
    }

    // 2. Dibujar Nodos
    for (final node in visibleNodes) {
      final isCategory = node.type == 'category' || node.type == 'nationality';
      final radius = isCategory ? 24.0 : 12.0;

      // Efecto brillo de Neón / Aura para nodos Categoría
      if (isCategory) {
        final glowPaint = Paint()
          ..color = node.color.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(node.position, radius + 6, glowPaint);
      }

      // Relleno sólido
      final fillPaint = Paint()
        ..color = isCategory ? node.color : node.color.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, radius, fillPaint);

      // Borde del nodo
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: isCategory ? 0.90 : 0.50)
        ..strokeWidth = isCategory ? 2.5 : 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(node.position, radius, borderPaint);

      // Dibujar contenido interior
      if (node.type == 'category') {
        final icon = node.isExpanded ? Icons.remove_rounded : Icons.add_rounded;
        final iconSpan = TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 16,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        );
        final iconPainter = TextPainter(
          text: iconSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        
        iconPainter.paint(
          canvas,
          node.position - Offset(iconPainter.width / 2, iconPainter.height / 2),
        );
      } else if (node.type == 'nationality') {
        final asset = _getNationalityFlagAsset(node.label);
        final loadedFlag = flagImages[asset];

        if (loadedFlag != null) {
          canvas.save();
          // Clip circular
          final Path clipPath = Path()
            ..addOval(Rect.fromCircle(center: node.position, radius: radius - 0.5));
          canvas.clipPath(clipPath);

          // Dibujar la picture de la bandera escalada para cubrir todo el círculo (BoxFit.cover)
          final svgSize = loadedFlag.size;
          final double nodeDiameter = (radius - 0.5) * 2;
          final double scaleX = nodeDiameter / svgSize.width;
          final double scaleY = nodeDiameter / svgSize.height;
          final double scale = math.max(scaleX, scaleY);

          final double dx = node.position.dx - (svgSize.width * scale) / 2;
          final double dy = node.position.dy - (svgSize.height * scale) / 2;

          canvas.translate(dx, dy);
          canvas.scale(scale);
          canvas.drawPicture(loadedFlag.picture);
          canvas.restore();
        } else {
          final flag = _getNationalityFlag(node.label);
          final flagSpan = TextSpan(
            text: flag,
            style: const TextStyle(fontSize: 16),
          );
          final flagPainter = TextPainter(
            text: flagSpan,
            textDirection: TextDirection.ltr,
          )..layout();

          flagPainter.paint(
            canvas,
            node.position - Offset(flagPainter.width / 2, flagPainter.height / 2),
          );
        }
      } else if (node.type == 'person') {
        final avatarUrl = node.userProfile?['avatar_url'] as String? ?? '';
        final loadedImage = profileImages[avatarUrl];

        if (loadedImage != null) {
          canvas.save();
          final Path clipPath = Path()
            ..addOval(Rect.fromCircle(center: node.position, radius: radius - 0.5));
          canvas.clipPath(clipPath);

          final src = Rect.fromLTWH(0, 0, loadedImage.width.toDouble(), loadedImage.height.toDouble());
          final dst = Rect.fromCircle(center: node.position, radius: radius - 0.5);
          canvas.drawImageRect(loadedImage, src, dst, Paint());
          canvas.restore();
        } else {
          // Fallback: iniciales
          final initials = node.label.trim().isNotEmpty
              ? node.label.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
              : 'U';
          final initialsSpan = TextSpan(
            text: initials,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          );
          final initialsPainter = TextPainter(
            text: initialsSpan,
            textDirection: TextDirection.ltr,
          )..layout();

          initialsPainter.paint(
            canvas,
            node.position - Offset(initialsPainter.width / 2, initialsPainter.height / 2),
          );
        }
      }

      // Dibujar texto del Label debajo del nodo
      final textSpan = TextSpan(
        text: node.label,
        style: TextStyle(
          color: Colors.white,
          fontSize: isCategory ? 11.0 : 8.5,
          fontWeight: isCategory ? FontWeight.bold : FontWeight.w600,
          fontFamily: 'Inter',
          shadows: const [
            Shadow(
              color: Colors.black87,
              offset: Offset(0, 1),
              blurRadius: 2.0,
            ),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final textOffset = Offset(
        node.position.dx - textPainter.width / 2,
        node.position.dy + radius + 4,
      );

      // Dibujar caja contenedora semi-translúcida para mayor contraste y legibilidad
      final bgRect = Rect.fromLTWH(
        textOffset.dx - 5,
        textOffset.dy - 1,
        textPainter.width + 10,
        textPainter.height + 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(5)),
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );

      textPainter.paint(canvas, textOffset);
    }
  }

  String _getNationalityFlag(String nationality) {
    switch (nationality.toUpperCase()) {
      case 'MÉXICO':
      case 'MEXICO':
        return '🇲🇽';
      case 'ESTADOS UNIDOS':
      case 'USA':
      case 'UNITED STATES':
        return '🇺🇸';
      case 'ALEMANIA':
      case 'GERMANY':
        return '🇩🇪';
      case 'COLOMBIA':
        return '🇨🇴';
      case 'ESPAÑA':
      case 'SPAIN':
        return '🇪🇸';
      case 'FRANCIA':
      case 'FRANCE':
        return '🇫🇷';
      case 'ITALIA':
      case 'ITALY':
        return '🇮🇹';
      case 'PORTUGAL':
        return '🇵🇹';
      case 'REINO UNIDO':
      case 'UK':
        return '🇬🇧';
      case 'JAPÓN':
      case 'JAPAN':
        return '🇯🇵';
      default:
        return '🌍';
    }
  }

  @override
  bool shouldRepaint(covariant VocabularyGraphPainter oldDelegate) {
    return true; // Obligatorio para refrescar avatares y físicas elásticas frame a frame
  }
}

String _getNationalityFlagAsset(String nationality) {
  switch (nationality.toUpperCase()) {
    case 'MÉXICO':
    case 'MEXICO':
      return 'assets/flags/mx.svg';
    case 'ESTADOS UNIDOS':
    case 'USA':
    case 'UNITED STATES':
      return 'assets/flags/us.svg';
    case 'ALEMANIA':
    case 'GERMANY':
      return 'assets/flags/de.svg';
    case 'FRANCIA':
    case 'FRANCE':
      return 'assets/flags/fr.svg';
    case 'ITALIA':
    case 'ITALY':
      return 'assets/flags/it.svg';
    case 'BRASIL':
    case 'BRAZIL':
      return 'assets/flags/br.svg';
    default:
      return ''; // No asset available
  }
}
