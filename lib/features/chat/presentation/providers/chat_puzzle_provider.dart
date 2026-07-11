import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final chatPuzzleProvider = StreamProvider.family.autoDispose<Map<String, dynamic>?, String>((ref, conversationId) {
  final supabase = ref.read(supabaseClientProvider);

  _getOrCreatePuzzle(supabase, conversationId);

  return supabase
      .from('chat_puzzles')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .map((list) {
        if (list.isEmpty) return null;
        return list.first;
      });
});

Future<void> _getOrCreatePuzzle(SupabaseClient supabase, String conversationId) async {
  try {
    final existing = await supabase
        .from('chat_puzzles')
        .select()
        .eq('conversation_id', conversationId)
        .maybeSingle();

    if (existing == null) {
      final puzzleImages = [
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&auto=format&fit=crop&q=80', // Beach
        'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&auto=format&fit=crop&q=80', // Landscape
        'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800&auto=format&fit=crop&q=80', // Lake/Mountains
        'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=800&auto=format&fit=crop&q=80', // Forest
        'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&auto=format&fit=crop&q=80', // Yosemite
        'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=800&auto=format&fit=crop&q=80', // Alps
      ];
      final randomImage = (puzzleImages..shuffle()).first;
      final pieceOrder = List.generate(12, (i) => i)..shuffle();

      await supabase.from('chat_puzzles').insert({
        'conversation_id': conversationId,
        'points': 0,
        'total_pieces': 12,
        'piece_order': pieceOrder,
        'image_url': randomImage,
      });
    }
  } catch (e) {
    // Silently catch or log
  }
}

Future<void> incrementPuzzlePoints(SupabaseClient supabase, String conversationId) async {
  try {
    final puzzle = await supabase
        .from('chat_puzzles')
        .select('points, total_pieces')
        .eq('conversation_id', conversationId)
        .maybeSingle();

    if (puzzle != null) {
      final currentPoints = puzzle['points'] as int;
      final totalPieces = puzzle['total_pieces'] as int;
      final maxPoints = totalPieces * 3; // 3 points per piece (36 total)

      if (currentPoints < maxPoints) {
        await supabase
            .from('chat_puzzles')
            .update({'points': currentPoints + 1})
            .eq('conversation_id', conversationId);
      }
    }
  } catch (e) {
    // Silently catch
  }
}

Future<void> resetPuzzle(SupabaseClient supabase, String conversationId) async {
  try {
    final puzzleImages = [
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=800&auto=format&fit=crop&q=80',
    ];
    final randomImage = (puzzleImages..shuffle()).first;
    final pieceOrder = List.generate(12, (i) => i)..shuffle();

    await supabase
        .from('chat_puzzles')
        .update({
          'points': 0,
          'piece_order': pieceOrder,
          'image_url': randomImage,
        })
        .eq('conversation_id', conversationId);
  } catch (e) {
    // Silently catch
  }
}
