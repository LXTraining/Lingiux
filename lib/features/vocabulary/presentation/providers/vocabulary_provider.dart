import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/word_card_model.dart';

final wordCardsProvider = FutureProvider<List<WordCardModel>>((ref) async {
  final supabase = Supabase.instance.client;
  
  final response = await supabase
      .from('word_cards')
      .select()
      .order('word', ascending: true);
      
  return (response as List<dynamic>)
      .map((json) => WordCardModel.fromJson(json as Map<String, dynamic>))
      .toList();
});
