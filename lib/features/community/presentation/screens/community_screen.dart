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
    with TickerProviderStateMixin {
  final List<GraphNode> _nodes = [];
  final List<GraphEdge> _edges = [];
  bool _isInitialized = false;
  String _viewMode = 'Palabras'; // 'Palabras' o 'Personas'
  String _lastViewMode = 'Palabras';
  late final TransformationController _transformationController;

  late Ticker _ticker;
  GraphNode? _draggedNode;
  GraphNode? _selectedWordNode; // Guardar la palabra seleccionada para previsualización
  String? _previousSelectedWordNodeId; // Para la transición suave del aura
  late final AnimationController _selectionAnimationController;
  Offset? _touchStartPos;
  bool _panEnabled = true;
  int _activePointerCount = 0;
  bool _isCanvasTouched = false;
  Offset _dragOffset = Offset.zero;

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
    _selectionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220), // Transición ligera, suave y rápida
    )..addListener(() {
        _repaintNotifier.requestRepaint(); // Asegurar repintado en cada frame de la transición
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _ticker.dispose();
    _repaintNotifier.dispose();
    _selectionAnimationController.dispose();
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
      _selectWordNode(node);
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
          // Fondo degradado premium sutil que cubre toda la pantalla (Opción A mejorada)
          // Se desvanece hacia un azul celeste pastel muy suave (8% opacidad) en la base en lugar de blanco puro.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.gradientBgStart.withValues(alpha: 0.45),
                    AppColors.gradientBgEnd.withValues(alpha: 0.35),
                    AppColors.gradientBgEnd.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
                    _activePointerCount = 0;
                    _isCanvasTouched = false;
                    _dragOffset = Offset.zero;
                    _selectedWordNode = null;
                    _previousSelectedWordNodeId = null;
                    _selectionAnimationController.value = 0.0;
                    _transformationController.value = Matrix4.identity();
                  });
                }
                ref.refresh(wordCardsProvider);
                ref.refresh(resolvedCardsFamilyProvider(null));
                ref.refresh(resolvedCardsProvider);
                ref.refresh(correctWordCardsProvider);
                ref.refresh(chatsProvider);
                try {
                  await ref.read(correctWordCardsProvider.future);
                  await ref.read(chatsProvider.future);
                } catch (_) {}
              },
              child: CustomScrollView(
                physics: _isCanvasTouched
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
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
          if (_selectedWordNode != null)
            _buildWordPreviewOverlay(_selectedWordNode!),
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
          _activePointerCount = 0;
          _isCanvasTouched = false;
          _selectedWordNode = null;
          _previousSelectedWordNodeId = null;
          _selectionAnimationController.value = 0.0;
          _dragOffset = Offset.zero;
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
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
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
              dropdownColor: AppColors.surface,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.onSurfaceMuted, size: 16),
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
        
        final double initialScale = 0.65; // Alejado al 65% para ver más constelación
        final double targetX = (viewWidth / 2) - (400 * initialScale);
        final double targetY = (viewHeight / 2) - (400 * initialScale);
        
        if (_transformationController.value.isIdentity()) {
          _transformationController.value = Matrix4.identity()
            ..translate(targetX, targetY)
            ..scale(initialScale);
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
              setState(() {
                _activePointerCount++;
                _isCanvasTouched = true;
              });
              if (_activePointerCount > 1) {
                // Si hay más de un dedo, cancelar arrastre de nodo y asegurar paneo/zoom en IV
                if (_draggedNode != null) {
                  setState(() {
                    _draggedNode!.isDragged = false;
                    _draggedNode = null;
                  });
                }
                setState(() {
                  _panEnabled = true;
                });
              }
              
              final localPos = event.localPosition;
              _touchStartPos = localPos;
              
              // Solo intentar arrastrar nodo si hay un único dedo en pantalla
              if (_activePointerCount == 1) {
                final tappedNode = _findNodeAt(localPos);
                if (tappedNode != null) {
                  setState(() {
                    _draggedNode = tappedNode;
                    tappedNode.isDragged = true;
                    _dragOffset = tappedNode.position - localPos; // Guardar el delta de agarre
                    _panEnabled = false; // Bloquear paneo para arrastrar el nodo
                  });
                }
              }
            },
            onPointerMove: (event) {
              if (_draggedNode != null && _activePointerCount == 1) {
                setState(() {
                  _draggedNode!.position = event.localPosition + _dragOffset; // Mover con el delta
                  _draggedNode!.velocity = Offset.zero;
                });
              }
            },
            onPointerUp: (event) {
              setState(() {
                _activePointerCount = math.max(0, _activePointerCount - 1);
                if (_activePointerCount == 0) {
                  _isCanvasTouched = false;
                }
              });
              
              if (_draggedNode != null) {
                final node = _draggedNode!;
                setState(() {
                  node.isDragged = false;
                  _draggedNode = null;
                  _panEnabled = true; // Liberar paneo
                });

                if (_touchStartPos != null && _activePointerCount == 0) {
                  final delta = (event.localPosition - _touchStartPos!).distance;
                  if (delta < 6.0) {
                    _handleNodeTap(node);
                  }
                }
              } else {
                // Tap en canvas vacío: deselecciona la previsualización activa
                if (_touchStartPos != null && _activePointerCount == 0) {
                  final delta = (event.localPosition - _touchStartPos!).distance;
                  if (delta < 6.0) {
                    _selectWordNode(null);
                  }
                }
              }
              _touchStartPos = null;
            },
            onPointerCancel: (event) {
              setState(() {
                _activePointerCount = math.max(0, _activePointerCount - 1);
                if (_activePointerCount == 0) {
                  _isCanvasTouched = false;
                }
              });
              if (_draggedNode != null) {
                setState(() {
                  _draggedNode!.isDragged = false;
                  _draggedNode = null;
                  _panEnabled = true;
                });
              }
            },
            child: CustomPaint(
              size: const Size(800, 800),
              painter: VocabularyGraphPainter(
                nodes: _nodes,
                edges: _edges,
                visibleNodes: _nodes.where(_isNodeVisible).toList(),
                profileImages: _profileImagesCache,
                flagImages: _flagPicturesCache,
                selectedWordNodeId: _selectedWordNode?.id,
                previousSelectedWordNodeId: _previousSelectedWordNodeId,
                selectionAnimationValue: _selectionAnimationController.value,
                repaint: _repaintNotifier,
              ),
            ),
          ),
        );
      },
    );
  }

  List<GraphNode> _getSiblingWordNodes(GraphNode wordNode) {
    if (wordNode.type != 'word' || wordNode.wordCard == null) return [];
    final catName = (wordNode.wordCard!.category ?? 'VOCABULARIO').toUpperCase();
    return _nodes
        .where((n) => n.type == 'word' &&
            n.wordCard != null &&
            (n.wordCard!.category ?? 'VOCABULARIO').toUpperCase() == catName &&
            _isNodeVisible(n))
        .toList();
  }

  void _navigateToSiblingWord(bool next) {
    if (_selectedWordNode == null) return;
    final siblings = _getSiblingWordNodes(_selectedWordNode!);
    if (siblings.length <= 1) return;

    int currentIndex = siblings.indexWhere((n) => n.id == _selectedWordNode!.id);
    if (currentIndex == -1) return;

    int nextIndex;
    if (next) {
      nextIndex = (currentIndex + 1) % siblings.length;
    } else {
      nextIndex = (currentIndex - 1 + siblings.length) % siblings.length;
    }

    HapticFeedback.lightImpact();
    _selectWordNode(siblings[nextIndex]);
  }

  void _selectWordNode(GraphNode? node) {
    if (node?.id == _selectedWordNode?.id) return;

    setState(() {
      _previousSelectedWordNodeId = _selectedWordNode?.id;
      _selectedWordNode = node;
    });

    if (node != null) {
      _selectionAnimationController.forward(from: 0.0);
    } else {
      _previousSelectedWordNodeId = null;
      _selectionAnimationController.value = 0.0;
    }
  }

  Widget _buildWordPreviewOverlay(GraphNode node) {
    final card = node.wordCard;
    if (card == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 24,
      left: 20,
      right: 20,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < 0) {
            // Deslizar a la izquierda -> Siguiente palabra
            _navigateToSiblingWord(true);
          } else if (details.primaryVelocity! > 0) {
            // Deslizar a la derecha -> Palabra anterior
            _navigateToSiblingWord(false);
          }
        },
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WordDetailScreen(selectedWord: card.word),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Stack(
              children: [
                Container(
                  height: 128, // Altura fija estricta para evitar saltos o reajustes visuales
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.30), // Translucidez de cristal esmerilado premium (frosted glass)
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      // Animación de empuje horizontal para simular el carrusel interno
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.08, 0.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: _buildPreviewCardContent(node),
                  ),
                ),
                // Botón de cerrar posicionado absolutamente en la esquina superior derecha
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedWordNode = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.onSurfaceMuted,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCardContent(GraphNode node) {
    final card = node.wordCard;
    if (card == null) return const SizedBox.shrink();

    final hasCategory = card.category != null && card.category!.isNotEmpty;

    return Row(
      key: ValueKey<String>(node.id), // Clave para disparar la animación al cambiar de palabra
      crossAxisAlignment: CrossAxisAlignment.center, // Centrar verticalmente los elementos de la fila
      children: [
        // Imagen de la carta (redondeada, con sombras y fit cover)
        if (card.imageUrl.isNotEmpty)
          Container(
            width: 86, // Ligeramente más compacto para evitar cualquier desbordamiento vertical
            height: 86,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.border.withOpacity(0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Image.network(
                card.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      color: AppColors.onSurfaceMuted,
                      size: 24,
                    ),
                  );
                },
              ),
            ),
          )
        else
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.border.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.image_aspect_ratio_rounded,
                color: AppColors.onSurfaceMuted,
                size: 24,
              ),
            ),
          ),
        const SizedBox(width: 16),
        
        // Textos e información
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, // Centrar verticalmente los textos de la columna
            children: [
              // Badge de Categoría (solo si existe)
              if (hasCategory) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: node.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    card.category!.toUpperCase(),
                    style: TextStyle(
                      color: node.color,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              
              // Palabra con letra capital en mayúscula
              Text(
                card.word.isNotEmpty
                    ? (card.word[0].toUpperCase() + card.word.substring(1))
                    : '',
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              
              // Pronunciación Fonética
              if (card.phonetic.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  card.phonetic,
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
              
              const SizedBox(height: 6),
              
              // Definición
              Text(
                card.definition,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 11.5,
                  height: 1.25,
                  fontFamily: 'Inter',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
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
  final String? selectedWordNodeId; // ID del nodo de palabra seleccionado para el aura
  final String? previousSelectedWordNodeId; // ID del nodo seleccionado anteriormente (para transición)
  final double selectionAnimationValue; // Valor de la transición suave del aura (0.0 a 1.0)

  VocabularyGraphPainter({
    required this.nodes,
    required this.edges,
    required this.visibleNodes,
    required this.profileImages,
    required this.flagImages,
    this.selectedWordNodeId,
    this.previousSelectedWordNodeId,
    this.selectionAnimationValue = 1.0,
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

      // Si es el nodo de palabra seleccionado actualmente, dibujar una hermosa aura brillante de neón de doble capa
      final isSelectedWord = node.type == 'word' && node.id == selectedWordNodeId;
      if (isSelectedWord) {
        // Capa externa del brillo (Bloom amplio)
        final outerGlowPaint = Paint()
          ..color = node.color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(node.position, radius + 12, outerGlowPaint);

        // Capa interna del brillo (Núcleo intenso)
        final innerGlowPaint = Paint()
          ..color = node.color.withValues(alpha: 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(node.position, radius + 6, innerGlowPaint);
      }

      // Efecto brillo de Neón / Aura para nodos Categoría
      if (isCategory) {
        final glowPaint = Paint()
          ..color = node.color.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(node.position, radius + 6, glowPaint);
      }

      // Dibujar cuerpo del nodo (Efecto Burbuja/Gema 2D Cartoon Juguetón)
      if (node.type == 'word') {
        // 1. Cuerpo de color sólido y vibrante (Estilo 2D)
        final bodyPaint = Paint()
          ..color = node.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(node.position, radius, bodyPaint);

        // 2. Contorno blanco sutil
        final rimPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(node.position, radius, rimPaint);

        // 3. Destello especular principal muy blanco y marcado en la parte superior izquierda
        final glossPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.85) // Resplandor blanco sólido para estilo caricatura
          ..style = PaintingStyle.fill;
        final glossCenter = node.position - Offset(radius * 0.30, radius * 0.30);
        canvas.drawCircle(glossCenter, radius * 0.26, glossPaint);

        // 4. Micro reflejo secundario en la parte inferior derecha para dar sensación de volumen 2D
        final minorGlossPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.40)
          ..style = PaintingStyle.fill;
        final minorGlossCenter = node.position + Offset(radius * 0.36, radius * 0.36);
        canvas.drawCircle(minorGlossCenter, radius * 0.12, minorGlossPaint);
      } else {
        // Relleno sólido para categorías y nacionalidades
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
      }

      // Si es la palabra seleccionada, dibujar un borde de selección blanco extra exterior
      if (isSelectedWord) {
        final selectBorderPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(node.position, radius + 3, selectBorderPaint);
      }

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

          // Cortar un cuadrado perfecto del centro de la imagen origen para evitar distorsiones (BoxFit.cover)
          final double srcWidth = loadedImage.width.toDouble();
          final double srcHeight = loadedImage.height.toDouble();
          final double minSide = math.min(srcWidth, srcHeight);
          final double srcX = (srcWidth - minSide) / 2;
          final double srcY = (srcHeight - minSide) / 2;

          final src = Rect.fromLTWH(srcX, srcY, minSide, minSide);
          final dst = Rect.fromCircle(center: node.position, radius: radius - 0.5);
          
          final paint = Paint()..filterQuality = ui.FilterQuality.high;
          canvas.drawImageRect(loadedImage, src, dst, paint);
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

      // Dibujar texto del Label debajo del nodo (Opción A - Estilo badge minimalista claro)
      final textSpan = TextSpan(
        text: node.label,
        style: TextStyle(
          color: AppColors.onSurface,
          fontSize: isCategory ? 11.0 : 8.5,
          fontWeight: isCategory ? FontWeight.bold : FontWeight.w600,
          fontFamily: 'Inter',
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

      // Dibujar caja contenedora blanca semi-translúcida con borde sutil para máximo contraste y elegancia
      final bgRect = Rect.fromLTWH(
        textOffset.dx - 6,
        textOffset.dy - 2,
        textPainter.width + 12,
        textPainter.height + 4,
      );
      
      // Relleno de la caja
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.90),
      );
      
      // Borde fino de la caja
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(6)),
        Paint()
          ..color = AppColors.border
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke,
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
