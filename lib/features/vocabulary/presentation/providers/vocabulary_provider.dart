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
