import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeTabProvider = StateProvider<int>((ref) => 0);

final pendingWordProvider = StateProvider<String?>((ref) => null);
