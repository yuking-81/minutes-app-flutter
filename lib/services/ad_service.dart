import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  // テスト用ユニットID
  final String _androidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  final String _iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';

  String get _adUnitId => Platform.isAndroid ? _androidRewardedId : _iosRewardedId;

  // 広告をロード
  void loadRewardedAd({void Function()? onAdLoaded}) {
    if (_isAdLoading || _rewardedAd != null) return;
    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
          onAdLoaded?.call();
          print('AdService: Rewarded ad loaded.');
        },
        onAdFailedToLoad: (error) {
          _isAdLoading = false;
          _rewardedAd = null;
          print('AdService: Rewarded ad failed to load: $error');
        },
      ),
    );
  }

  // 広告を表示
  void showRewardedAd({
    required Function(double amount, String type) onReward,
    required Function() onDismissed,
  }) {
    if (_rewardedAd == null) {
      print('AdService: Warning - Ad not loaded yet.');
      onDismissed();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        onDismissed();
        loadRewardedAd(); // 次回のためにリロード
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        onDismissed();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onReward(reward.amount.toDouble(), reward.type);
      },
    );
  }

  void dispose() {
    _rewardedAd?.dispose();
  }
}
