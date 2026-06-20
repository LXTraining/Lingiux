import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  
  if (user == null) {
    return null;
  }

  final supabase = ref.read(supabaseClientProvider);
  
  try {
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return data;
  } catch (e) {
    return null;
  }
});
