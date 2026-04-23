import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/backend_service.dart';
import '../services/ad_service.dart';

// Service Provider
final backendServiceProvider = Provider((ref) => BackendService());
final adServiceProvider = Provider((ref) => AdService());

// User State Model
class UserState {
  final String userId;
  final int points;
  final bool isLoading;

  UserState({
    required this.userId,
    this.points = 0,
    this.isLoading = false,
  });

  UserState copyWith({String? userId, int? points, bool? isLoading}) {
    return UserState(
      userId: userId ?? this.userId,
      points: points ?? this.points,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// User Notifier
class UserNotifier extends StateNotifier<UserState> {
  final BackendService _backend;
  final AdService _ad;
  
  UserNotifier(this._backend, this._ad) : super(UserState(userId: '')) {
    _init();
    _ad.loadRewardedAd();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_unique_id');

    // IDがない場合は新規発行（デバイスIDをベースにする）
    if (userId == null) {
      userId = await _generateDeviceId();
      await prefs.setString('user_unique_id', userId);
    }

    state = state.copyWith(userId: userId);
    await refreshBalance();
  }

  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String id = const Uuid().v4(); // デフォルトはランダム
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        id = androidInfo.id; // Setting.Secure.ANDROID_ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        id = iosInfo.identifierForVendor ?? id;
      }
    } catch (e) {
      print('UserNotifier: Device info error: $e');
    }
    return id;
  }

  // ポイント残高をサーバーから更新
  Future<void> refreshBalance() async {
    if (state.userId.isEmpty) return;
    
    final balance = await _backend.getBalance(state.userId);
    state = state.copyWith(points: balance, isLoading: false);
  }

  // ポイントを追加 (報酬)
  Future<void> addPoints(int amount) async {
    final newBalance = await _backend.addReward(state.userId, amount);
    if (newBalance != null) {
      state = state.copyWith(points: newBalance);
    }
  }

  // ポイントを消費できたか確認（バックエンドで同期されるが、UI反映用）
  void deductPoints(int amount) {
    state = state.copyWith(points: state.points - amount);
  }

  // 広告を表示して報酬を獲得
  void showRewardAd({required Function() onComplete, required Function() onError}) {
    _ad.showRewardedAd(
      onReward: (amount, type) async {
        await addPoints(amount.toInt());
        onComplete();
      },
      onDismissed: () {
        // ロードされていない場合は、明示的に再ロード
        _ad.loadRewardedAd();
      },
    );
  }
}

// Global Provider
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final backend = ref.watch(backendServiceProvider);
  final ad = ref.watch(adServiceProvider);
  return UserNotifier(backend, ad);
});
