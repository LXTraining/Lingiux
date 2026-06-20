// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:lingiux_app/app.dart';
import 'package:lingiux_app/features/auth/presentation/screens/login_screen.dart';
import 'package:lingiux_app/features/auth/presentation/providers/auth_provider.dart';

class MockSupabaseClient extends Mock implements supa.SupabaseClient {}
class MockGoTrueClient extends Mock implements supa.GoTrueClient {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentSession).thenReturn(null);
    when(() => mockAuth.onAuthStateChange).thenAnswer(
      (_) => Stream<supa.AuthState>.empty(),
    );
  });

  testWidgets('App boot smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
        child: const LingiuxApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that our LoginScreen is successfully mounted.
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
