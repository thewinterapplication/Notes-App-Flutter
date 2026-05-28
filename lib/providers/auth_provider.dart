import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../globals.dart';
import '../models/user_subscription.dart';
import '../screens/auth/login_page.dart';
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
  AuthNotifier() : super(const AuthState()) {
    // Force a logout if the backend reports this number logged in elsewhere.
    ApiService.onSessionRevoked = _handleSessionRevoked;
  }

  bool _handlingRevoke = false;

  /// Load authentication state from SharedPreferences
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? '';
    final userPhone = prefs.getString('userPhone') ?? '';

    // Logged in only if we also hold a session token for this device.
    final hasToken = (ApiService.sessionToken ?? '').isNotEmpty;
    final isLoggedIn = userName.isNotEmpty && userPhone.isNotEmpty && hasToken;

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

  /// Login - save to prefs and update state.
  /// The session token is persisted by ApiService during login/register.
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

  /// Logout - clear the backend session, prefs, and reset state.
  Future<void> logout() async {
    await ApiService.logout();

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

  /// Triggered when another device logs in with this number. Clears local
  /// state and sends the user back to the login screen.
  Future<void> _handleSessionRevoked() async {
    if (_handlingRevoke) return; // avoid duplicate handling from parallel calls
    _handlingRevoke = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userName');
    await prefs.remove('userPhone');
    await ApiService.clearSessionToken();

    state = const AuthState(
      userName: '',
      userPhone: '',
      isLoggedIn: false,
      isLoading: false,
    );

    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      final messengerContext = navigatorKey.currentContext;
      if (messengerContext != null) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(messengerContext).showSnackBar(
          const SnackBar(
            content: Text(
              'You were logged out because your number was used on another device.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }

    _handlingRevoke = false;
  }

  /// Load the latest profile from the backend
  Future<void> refreshProfile() async {
    if (state.userPhone.isEmpty) return;

    try {
      final result = await ApiService.getUserProfile();
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

    final result = await ApiService.updateFavourites(current);
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
