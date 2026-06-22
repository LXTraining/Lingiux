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

class GraphNode {
  final String id;
  final String label;
  final String type; // 'category' o 'word'
  final Color color;
  final WordCardModel? wordCard; // null para categorías
  Offset position;
  Offset velocity;
  bool isDragged;
  bool isExpanded; // Solo para categorías

  GraphNode({
    required this.id,
    required this.label,
    required this.type,
    required this.color,
    this.wordCard,
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

  late Ticker _ticker;
  GraphNode? _draggedNode;
  Offset? _touchStartPos;
  bool _panEnabled = true;

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

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_nodes.isEmpty) return;

    final width = 800.0;
    final height = 800.0;
    final center = Offset(width / 2, height / 2);

    // Parámetros de física de simulación
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
        if (dist < 1.0) continue; // Evitar división por cero

        final force = kr / (dist * dist);
        fx += (diff.dx / dist) * force;
        fy += (diff.dy / dist) * force;
      }

      // Atracción gravitatoria hacia el centro del espacio
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
    setState(() {
      for (final node in _nodes) {
        if (node.isDragged || !_isNodeVisible(node)) continue;

        node.position = node.position + node.velocity;
        node.velocity = node.velocity * friction;

        // Mantener a los nodos flotantes dentro del canvas de 800x800
        node.position = Offset(
          node.position.dx.clamp(40, width - 40),
          node.position.dy.clamp(40, height - 40),
        );
      }
    });
  }

  bool _isNodeVisible(GraphNode node) {
    if (node.type == 'category') return true;
    final catName = (node.wordCard?.category ?? 'VOCABULARY').toUpperCase();
    final catNode = _nodes.firstWhere(
      (n) => n.id == 'cat_$catName',
      orElse: () => _nodes.first,
    );
    return catNode.isExpanded;
  }

  void _rebuildEdges() {
    _edges.clear();
    for (final node in _nodes) {
      if (node.type == 'word') {
        final catName = (node.wordCard?.category ?? 'VOCABULARY').toUpperCase();
        final catNode = _nodes.firstWhere(
          (n) => n.id == 'cat_$catName',
          orElse: () => _nodes.first,
        );
        if (catNode.isExpanded) {
          _edges.add(GraphEdge(source: catNode, target: node));
        }
      }
    }
  }

  void _syncNodes(List<WordCardModel> cards) {
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

    // 3. Eliminar palabras que ya no estén en la base de datos
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

  GraphNode? _findNodeAt(Offset pos) {
    for (final node in _nodes) {
      if (!_isNodeVisible(node)) continue;
      final radius = node.type == 'category' ? 32.0 : 20.0;
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

        // Si se expande, le damos un empujón de velocidad física a los hijos para crear un rebote elástico
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
    } else if (node.type == 'word' && node.wordCard != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WordDetailScreen(selectedWord: node.wordCard!.word),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordCardsAsync = ref.watch(wordCardsProvider);

    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          // Fondo degradado espacial premium
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
            body: wordCardsAsync.when(
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

                if (!_isInitialized) {
                  _syncNodes(cards);
                  _isInitialized = true;
                } else {
                  _syncNodes(cards);
                }

                return _buildGraphView();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphView() {
    return Column(
      children: [
        // Leyenda superior premium
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.onSurfaceMuted, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Usa pellizco para zoom. Toca o arrastra los nodos.',
                    style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_nodes.where((n) => n.type == 'word').length} palabras',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Canvas del Mapa Mental Interactivo
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                panEnabled: _panEnabled,
                scaleEnabled: true,
                minScale: 0.3,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(400),
                child: Center(
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
                            // Clic táctil sin arrastre
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
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class VocabularyGraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<GraphNode> visibleNodes;

  VocabularyGraphPainter({
    required this.nodes,
    required this.edges,
    required this.visibleNodes,
  });

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

    // 2. Dibujar nodos
    for (final node in visibleNodes) {
      final isCategory = node.type == 'category';
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

      // Mostrar icono expandido / colapsado en el centro de categorías
      if (isCategory) {
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

  @override
  bool shouldRepaint(covariant VocabularyGraphPainter oldDelegate) {
    return true; // Obligatorio para repintar físicas elásticas frame a frame
  }
}
