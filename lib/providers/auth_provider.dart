import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

/// Authentication state
class AuthState {
  final String userName;
  final String userPhone;
  final bool isLoggedIn;
  final bool isLoading;
  final List<String> favourites;

  const AuthState({
    this.userName = '',
    this.userPhone = '',
    this.isLoggedIn = false,
    this.isLoading = true,
    this.favourites = const [],
  });

  AuthState copyWith({
    String? userName,
    String? userPhone,
    bool? isLoggedIn,
    bool? isLoading,
    List<String>? favourites,
  }) {
    return AuthState(
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      favourites: favourites ?? this.favourites,
    );
  }

  bool isFavourite(String pdfId) => favourites.contains(pdfId);
}

/// Authentication state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Load authentication state from SharedPreferences
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? '';
    final userPhone = prefs.getString('userPhone') ?? '';

    final isLoggedIn = userName.isNotEmpty && userPhone.isNotEmpty;

    state = AuthState(
      userName: userName,
      userPhone: userPhone,
      isLoggedIn: isLoggedIn,
      isLoading: false,
    );

    if (isLoggedIn) {
      await loadFavourites();
    }
  }

  /// Login - save to prefs and update state
  Future<void> login(String name, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setString('userPhone', phone);

    state = AuthState(
      userName: name,
      userPhone: phone,
      isLoggedIn: true,
      isLoading: false,
    );

    await loadFavourites();
  }

  /// Logout - clear prefs and reset state
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userName');
    await prefs.remove('userPhone');

    state = const AuthState(
      userName: '',
      userPhone: '',
      isLoggedIn: false,
      isLoading: false,
    );
  }

  /// Load favourites from server
  Future<void> loadFavourites() async {
    if (state.userPhone.isEmpty) return;

    try {
      final result = await ApiService.getUserProfile(state.userPhone);
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        final user = (data['user'] as Map<String, dynamic>?) ?? data;
        final favs = (user['favourites'] as List?)?.cast<String>() ?? [];
        state = state.copyWith(favourites: favs);
      }
    } catch (_) {
      // Silently fail — keep empty favourites
    }
  }

  /// Toggle a PDF in favourites
  Future<void> toggleFavourite(String pdfId) async {
    if (state.userPhone.isEmpty) return;

    final current = List<String>.from(state.favourites);
    if (current.contains(pdfId)) {
      current.remove(pdfId);
    } else {
      current.add(pdfId);
    }

    // Optimistic update
    state = state.copyWith(favourites: current);

    // Sync with server
    final result = await ApiService.updateFavourites(state.userPhone, current);
    if (result['success'] == true && result['favourites'] != null) {
      state = state.copyWith(favourites: List<String>.from(result['favourites']));
    }
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
