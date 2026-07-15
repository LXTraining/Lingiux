import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/word_card_model.dart';

final wordCardsProvider = FutureProvider.autoDispose<List<WordCardModel>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  
  final response = await supabase
      .from('word_cards')
      .select()
      .order('word', ascending: true);
      
  return (response as List<dynamic>)
      .map((json) => WordCardModel.fromJson(json as Map<String, dynamic>))
      .toList();
});

final userWordCardsFamilyProvider = FutureProvider.family.autoDispose<List<WordCardModel>, String?>((ref, userId) async {
  final effectiveUserId = userId ?? ref.watch(authProvider).user?.id;
  if (effectiveUserId == null) {
    return [];
  }

  final supabase = ref.read(supabaseClientProvider);
  
  try {
    final response = await supabase
        .from('word_cards')
        .select()
        .eq('user_id', effectiveUserId)
        .order('created_at', ascending: false);
        
    final cards = (response as List<dynamic>)
        .map((json) => WordCardModel.fromJson(json as Map<String, dynamic>))
        .toList();
    return cards;
  } catch (e) {
    rethrow;
  }
});

final userWordCardsProvider = FutureProvider.autoDispose<List<WordCardModel>>((ref) async {
  return ref.watch(userWordCardsFamilyProvider(null).future);
});

final resolvedCardsFamilyProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String?>((ref, userId) async {
  final effectiveUserId = userId ?? ref.watch(authProvider).user?.id;
  if (effectiveUserId == null) {
    return [];
  }

  final supabase = ref.read(supabaseClientProvider);
  
  try {
    final response = await supabase
        .from('resolved_cards')
        .select()
        .eq('user_id', effectiveUserId)
        .order('created_at', ascending: false);
        
    return List<Map<String, dynamic>>.from(response as List);
  } catch (e) {
    return [];
  }
});

final resolvedCardsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(resolvedCardsFamilyProvider(null).future);
});

final correctWordCardsProvider = FutureProvider.autoDispose<List<WordCardModel>>((ref) async {
  final cards = await ref.watch(wordCardsProvider.future);
  final resolved = await ref.watch(resolvedCardsProvider.future);
  final resolvedCardIds = resolved.map((r) => r['card_id'] as String).toSet();
  return cards.where((card) => resolvedCardIds.contains(card.id)).toList();
});
