import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ad_service.dart';
import '../services/app_logger.dart';
import '../services/backend_service.dart';

final backendServiceProvider = Provider((ref) => BackendService());
final adServiceProvider = Provider((ref) => AdService());

class UserState {
  final int? userId;
  final String? email;
  final String? token;
  final int points;
  final bool isLoading;
  final List<PointTransaction> transactions;
  final String? errorMessage;

  const UserState({
    this.userId,
    this.email,
    this.token,
    this.points = 0,
    this.isLoading = false,
    this.transactions = const [],
    this.errorMessage,
  });

  bool get isAuthenticated => token != null && email != null;

  UserState copyWith({
    int? userId,
    String? email,
    String? token,
    int? points,
    bool? isLoading,
    List<PointTransaction>? transactions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UserState(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      token: token ?? this.token,
      points: points ?? this.points,
      isLoading: isLoading ?? this.isLoading,
      transactions: transactions ?? this.transactions,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  UserState signedOut() => const UserState();
}

class UserNotifier extends StateNotifier<UserState> {
  static const _tokenKey = 'auth_token';

  final BackendService _backend;
  final AdService _ad;

  UserNotifier(this._backend, this._ad) : super(const UserState()) {
    _restoreSession();
    _ad.loadRewardedAd();
  }

  Future<void> _restoreSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) {
      state = const UserState();
      return;
    }

    try {
      final user = await _backend.me(token);
      state = state.copyWith(
        userId: user.id,
        email: user.email,
        token: token,
        points: user.points,
        isLoading: false,
        clearError: true,
      );
      await refreshTransactions();
    } catch (e) {
      appLog('UserNotifier: restore session failed: $e');
      await prefs.remove(_tokenKey);
      state = const UserState(errorMessage: 'ログイン状態を復元できませんでした');
    }
  }

  Future<void> register(String email, String password) async {
    await _authenticate(
      () => _backend.register(email: email, password: password),
    );
  }

  Future<void> login(String email, String password) async {
    await _authenticate(() => _backend.login(email: email, password: password));
  }

  Future<void> _authenticate(Future<AuthResult> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await action();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, result.token);
      state = state.copyWith(
        userId: result.user.id,
        email: result.user.email,
        token: result.token,
        points: result.user.points,
        isLoading: false,
        clearError: true,
      );
      await refreshTransactions();
    } catch (e) {
      appLog('UserNotifier: authentication failed: $e');
      state = state.copyWith(isLoading: false, errorMessage: '認証に失敗しました');
      rethrow;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    state = state.signedOut();
  }

  Future<void> refreshBalance() async {
    final token = state.token;
    if (token == null) return;

    final balance = await _backend.getBalance(token);
    state = state.copyWith(points: balance, isLoading: false);
  }

  Future<void> refreshTransactions() async {
    final token = state.token;
    if (token == null) return;

    final transactions = await _backend.getTransactions(token);
    state = state.copyWith(transactions: transactions);
  }

  Future<void> addPoints(
    int amount, {
    String type = 'test_purchase',
    String reason = 'Test point purchase',
  }) async {
    final token = state.token;
    if (token == null) throw Exception('ログインが必要です');

    final newBalance = await _backend.addReward(
      token: token,
      amount: amount,
      type: type,
      reason: reason,
    );
    state = state.copyWith(points: newBalance);
    await refreshTransactions();
  }

  Future<void> consumeRecordingPoint() async {
    final token = state.token;
    if (token == null) throw Exception('ログインが必要です');

    final newBalance = await _backend.consumePoints(
      token: token,
      amount: 1,
      type: 'recording',
      reason: 'Recording minute',
    );
    state = state.copyWith(points: newBalance);
    await refreshTransactions();
  }

  void showRewardAd({
    required Function() onComplete,
    required Function() onError,
  }) {
    if (state.token == null) {
      onError();
      return;
    }

    _ad.showRewardedAd(
      onReward: (amount, type) async {
        try {
          await addPoints(5, type: 'reward_ad', reason: 'Rewarded ad');
          onComplete();
        } catch (e) {
          appLog('UserNotifier: reward failed: $e');
          onError();
        }
      },
      onDismissed: () {
        _ad.loadRewardedAd();
      },
    );
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final backend = ref.watch(backendServiceProvider);
  final ad = ref.watch(adServiceProvider);
  return UserNotifier(backend, ad);
});
