import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_subscription.dart';
import '../services/api_service.dart';

/// Authentication state
class AuthState {
  final String userName;
  final String userPhone;
  final bool isLoggedIn;
  final bool isLoading;
  final List<String> favourites;
  final UserSubscription subscription;

  const AuthState({
    this.userName = '',
    this.userPhone = '',
    this.isLoggedIn = false,
    this.isLoading = true,
    this.favourites = const [],
    this.subscription = const UserSubscription(),
  });

  AuthState copyWith({
    String? userName,
    String? userPhone,
    bool? isLoggedIn,
    bool? isLoading,
    List<String>? favourites,
    UserSubscription? subscription,
  }) {
    return AuthState(
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      favourites: favourites ?? this.favourites,
      subscription: subscription ?? this.subscription,
    );
  }

  bool isFavourite(String pdfId) => favourites.contains(pdfId);
  bool get hasActiveSubscription => subscription.isEntitled;
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
      await refreshProfile();
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

    await refreshProfile();
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

  /// Load the latest profile from the backend
  Future<void> refreshProfile() async {
    if (state.userPhone.isEmpty) return;

    try {
      final result = await ApiService.getUserProfile(state.userPhone);
      debugPrint('[Auth] getUserProfile result: $result');

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        // Backend returns {success, data: {user...}} — try data['user'], then
        // data['data'] (double-wrapped), then fall back to data itself.
        final user = (data['user'] as Map<String, dynamic>?)
            ?? (data['data'] as Map<String, dynamic>?)
            ?? data;
        debugPrint('[Auth] Extracted user subscription field: ${user['subscription']}');
        _applyUserPayload(user);
      } else {
        debugPrint('[Auth] getUserProfile failed or no data: success=${result['success']}, data=${result['data']}');
      }
    } catch (e) {
      debugPrint('[Auth] refreshProfile exception: $e');
      // Keep the current state if the profile refresh fails.
    }
  }

  /// Backwards-compatible alias for older call sites.
  Future<void> loadFavourites() => refreshProfile();

  /// Update auth state from a backend user payload
  void updateUserData(Map<String, dynamic> user) {
    debugPrint('[Auth] updateUserData called with subscription: ${user['subscription']}');
    _applyUserPayload(user);
  }

  void _applyUserPayload(Map<String, dynamic> user) {
    final favs =
        (user['favourites'] as List?)?.cast<String>() ?? state.favourites;
    final subscription = UserSubscription.fromJson(
      (user['subscription'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
    );

    debugPrint('[Auth] Parsed subscription: status=${subscription.status}, isEntitled=${subscription.isEntitled}, subscriptionId=${subscription.subscriptionId}');

    state = state.copyWith(
      userName: (user['name'] as String?) ?? state.userName,
      userPhone: (user['phone'] as String?) ?? state.userPhone,
      favourites: favs,
      subscription: subscription,
    );
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

    state = state.copyWith(favourites: current);

    final result = await ApiService.updateFavourites(state.userPhone, current);
    if (result['success'] == true && result['favourites'] != null) {
      state = state.copyWith(
        favourites: List<String>.from(result['favourites']),
      );
    }
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
