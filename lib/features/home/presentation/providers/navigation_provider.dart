import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeTabProvider = StateProvider<int>((ref) => 0);

final pendingWordProvider = StateProvider<String?>((ref) => null);

final homeScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>((ref) {
  return GlobalKey<ScaffoldState>();
});

final isCardEditorActiveProvider = StateProvider<bool>((ref) => false);
