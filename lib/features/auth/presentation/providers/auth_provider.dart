import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthState {
  final User? user;
  final Session? session;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.session,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    User? user,
    Session? session,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return AuthState(
      user: clearSession ? null : (user ?? this.user),
      session: clearSession ? null : (session ?? this.session),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _supabase;
  StreamSubscription? _authSubscription;

  AuthNotifier(this._supabase) : super(const AuthState(isLoading: true)) {
    _init();
  }

  void _init() {
    // 1. Obtener la sesión actual si existe al arrancar
    final currentSession = _supabase.auth.currentSession;
    state = AuthState(
      user: currentSession?.user,
      session: currentSession,
      isLoading: false,
    );

    // 2. Escuchar cambios de sesión en tiempo real de Supabase
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      state = AuthState(
        user: session?.user,
        session: session,
        isLoading: false,
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(
        user: response.user,
        session: response.session,
        isLoading: false,
      );
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Ocurrió un error inesperado al iniciar sesión.',
      );
    }
  }

  Future<void> signUp(String email, String password, String fullName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      state = state.copyWith(
        user: response.user,
        session: response.session,
        isLoading: false,
      );
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Ocurrió un error inesperado al registrarse.',
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _supabase.auth.signOut();
      state = const AuthState(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al cerrar sesión: $e',
      );
    }
  }
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthNotifier(client);
});
