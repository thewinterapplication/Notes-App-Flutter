import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_plan.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class SubscriptionState {
  final List<SubscriptionPlan> plans;
  final String? selectedPlanCode;
  final bool isLoading;
  final bool isProcessing;
  final String? errorMessage;

  const SubscriptionState({
    this.plans = const [],
    this.selectedPlanCode,
    this.isLoading = false,
    this.isProcessing = false,
    this.errorMessage,
  });

  SubscriptionState copyWith({
    List<SubscriptionPlan>? plans,
    String? selectedPlanCode,
    bool? isLoading,
    bool? isProcessing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SubscriptionState(
      plans: plans ?? this.plans,
      selectedPlanCode: selectedPlanCode ?? this.selectedPlanCode,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  SubscriptionPlan? get selectedPlan {
    if (selectedPlanCode == null) {
      return plans.isEmpty ? null : plans.first;
    }

    for (final plan in plans) {
      if (plan.code == selectedPlanCode) {
        return plan;
      }
    }

    return plans.isEmpty ? null : plans.first;
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier(this._ref) : super(const SubscriptionState());

  final Ref _ref;

  Future<void> loadPlans({bool forceRefresh = false}) async {
    if (state.isLoading) return;
    if (!forceRefresh && state.plans.isNotEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);
    final result = await ApiService.getSubscriptionPlans();

    if (result['success'] == true) {
      final plans = (result['plans'] as List<SubscriptionPlan>? ?? const []);
      state = state.copyWith(
        plans: plans,
        selectedPlanCode:
            plans.any((plan) => plan.code == state.selectedPlanCode)
            ? state.selectedPlanCode
            : (plans.isNotEmpty ? plans.first.code : null),
        isLoading: false,
        errorMessage: null,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      plans: state.plans,
      selectedPlanCode:
          state.plans.any((plan) => plan.code == state.selectedPlanCode)
          ? state.selectedPlanCode
          : (state.plans.isNotEmpty ? state.plans.first.code : null),
      isLoading: false,
      errorMessage: null,
    );
  }

  void selectPlan(String planCode) {
    state = state.copyWith(selectedPlanCode: planCode, clearError: true);
  }

  Future<Map<String, dynamic>> startCheckout({
    required String phone,
    String? planCode,
  }) async {
    final resolvedPlanCode = planCode ?? state.selectedPlan?.code;
    if (resolvedPlanCode == null || resolvedPlanCode.isEmpty) {
      return {
        'success': false,
        'message': 'Please select a subscription plan.',
      };
    }

    state = state.copyWith(isProcessing: true, clearError: true);
    final result = await ApiService.createSubscriptionCheckout(
      phone: phone,
      planCode: resolvedPlanCode,
    );
    state = state.copyWith(
      isProcessing: false,
      errorMessage: null,
      clearError: result['success'] == true,
    );

    final user = result['user'] as Map<String, dynamic>?;
    if (user != null) {
      _ref.read(authProvider.notifier).updateUserData(user);
    }

    return result;
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String phone,
    required String subscriptionId,
    required String paymentId,
    required String signature,
  }) async {
    state = state.copyWith(isProcessing: true, clearError: true);
    final result = await ApiService.verifySubscriptionPayment(
      phone: phone,
      subscriptionId: subscriptionId,
      paymentId: paymentId,
      signature: signature,
    );
    state = state.copyWith(
      isProcessing: false,
      errorMessage: result['success'] == true
          ? null
          : result['message'] as String?,
      clearError: result['success'] == true,
    );

    final user = result['user'] as Map<String, dynamic>?;
    if (user != null) {
      _ref.read(authProvider.notifier).updateUserData(user);
    } else if (result['success'] == true) {
      await _ref.read(authProvider.notifier).refreshProfile();
    }

    return result;
  }

  Future<Map<String, dynamic>> refreshSubscription(String phone) async {
    state = state.copyWith(isProcessing: true, clearError: true);
    final result = await ApiService.refreshSubscription(phone);
    state = state.copyWith(
      isProcessing: false,
      errorMessage: result['success'] == true
          ? null
          : result['message'] as String?,
      clearError: result['success'] == true,
    );

    final user = result['user'] as Map<String, dynamic>?;
    if (user != null) {
      _ref.read(authProvider.notifier).updateUserData(user);
    }

    return result;
  }

  Future<Map<String, dynamic>> cancelSubscription({
    required String phone,
    bool cancelAtCycleEnd = true,
  }) async {
    state = state.copyWith(isProcessing: true, clearError: true);
    final result = await ApiService.cancelSubscription(
      phone: phone,
      cancelAtCycleEnd: cancelAtCycleEnd,
    );
    state = state.copyWith(
      isProcessing: false,
      errorMessage: result['success'] == true
          ? null
          : result['message'] as String?,
      clearError: result['success'] == true,
    );

    final user = result['user'] as Map<String, dynamic>?;
    if (user != null) {
      _ref.read(authProvider.notifier).updateUserData(user);
    }

    return result;
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
      return SubscriptionNotifier(ref);
    });
