import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

final profileFamilyProvider = FutureProvider.family.autoDispose<Map<String, dynamic>?, String?>((ref, userId) async {
  final supabase = ref.read(supabaseClientProvider);
  final effectiveUserId = userId ?? ref.watch(authProvider).user?.id;
  
  if (effectiveUserId == null) {
    return null;
  }

  try {
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', effectiveUserId)
        .maybeSingle();
    return data;
  } catch (e) {
    return null;
  }
});

final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return ref.watch(profileFamilyProvider(null).future);
});
