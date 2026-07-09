import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class AddedPeopleNotifier extends StateNotifier<List<String>> {
  final String? _currentUserId;

  AddedPeopleNotifier(this._currentUserId) : super([]) {
    _loadAddedPeople();
  }

  Future<void> _loadAddedPeople() async {
    if (_currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('added_people_$_currentUserId') ?? [];
  }

  Future<void> toggleAddPerson(String userId) async {
    if (_currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final currentList = List<String>.from(state);
    
    if (currentList.contains(userId)) {
      currentList.remove(userId);
    } else {
      currentList.add(userId);
    }
    
    await prefs.setStringList('added_people_$_currentUserId', currentList);
    state = currentList;
  }
}

final addedPeopleProvider = StateNotifierProvider.autoDispose<AddedPeopleNotifier, List<String>>((ref) {
  final currentUserId = ref.watch(authProvider).user?.id;
  return AddedPeopleNotifier(currentUserId);
});

final addedPeopleProfilesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final currentUserId = ref.watch(authProvider).user?.id;
  if (currentUserId == null) return [];
  
  final prefs = await SharedPreferences.getInstance();
  final addedIds = prefs.getStringList('added_people_$currentUserId') ?? [];
  if (addedIds.isEmpty) return [];

  final supabase = ref.read(supabaseClientProvider);
  try {
    final response = await supabase
        .from('profiles')
        .select()
        .inFilter('id', addedIds);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    return [];
  }
});
