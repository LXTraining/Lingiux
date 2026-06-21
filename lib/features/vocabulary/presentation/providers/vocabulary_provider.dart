import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/word_card_model.dart';

final wordCardsProvider = FutureProvider.autoDispose<List<WordCardModel>>((ref) async {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return [];

  final supabase = ref.read(supabaseClientProvider);
  
  final response = await supabase
      .from('word_cards')
      .select()
      .or('user_id.eq.${user.id},user_id.is.null')
      .order('word', ascending: true);
      
  return (response as List<dynamic>)
      .map((json) => WordCardModel.fromJson(json as Map<String, dynamic>))
      .toList();
});

final userWordCardsProvider = FutureProvider.autoDispose<List<WordCardModel>>((ref) async {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    debugPrint('userWordCardsProvider: user is null');
    return [];
  }

  final supabase = ref.read(supabaseClientProvider);
  
  try {
    debugPrint('userWordCardsProvider: Fetching cards for user ${user.id}...');
    final response = await supabase
        .from('word_cards')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
        
    final cards = (response as List<dynamic>)
        .map((json) => WordCardModel.fromJson(json as Map<String, dynamic>))
        .toList();
    debugPrint('userWordCardsProvider: Successfully fetched ${cards.length} cards: ${cards.map((c) => c.word).toList()}');
    return cards;
  } catch (e, stack) {
    debugPrint('userWordCardsProvider error: $e');
    debugPrint(stack.toString());
    rethrow;
  }
});
