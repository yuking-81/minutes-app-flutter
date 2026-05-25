import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/minute_model.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import '../services/app_logger.dart';
import '../services/foreground_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../services/backend_service.dart';
import 'user_provider.dart';

// Service Providers
final databaseServiceProvider = Provider((ref) => DatabaseService.instance);
final audioServiceProvider = Provider((ref) {
  final service = AudioService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

// Minutes List Provider
final minutesListProvider =
    StateNotifierProvider<MinutesListNotifier, AsyncValue<List<Minute>>>((ref) {
      return MinutesListNotifier(
        ref.watch(databaseServiceProvider),
        ref.watch(backendServiceProvider),
        ref.watch(userProvider.notifier),
      );
    });

class MinutesListNotifier extends StateNotifier<AsyncValue<List<Minute>>> {
  final DatabaseService _db;
  final BackendService _backend;
  final UserNotifier _userNotifier;

  MinutesListNotifier(this._db, this._backend, this._userNotifier)
    : super(const AsyncValue.loading()) {
    loadMinutes();
  }

  Future<void> loadMinutes() async {
    state = const AsyncValue.loading();
    try {
      final minutes = await _db.readAllMinutes();
      state = AsyncValue.data(minutes);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addMinute(Minute minute) async {
    try {
      await _db.create(minute);
      await loadMinutes();
    } catch (e) {
      appLog('Error adding minute: $e');
    }
  }

  Future<void> deleteMinute(int id) async {
    try {
      await _db.delete(id);
      await loadMinutes();
    } catch (e) {
      appLog('Error deleting minute: $e');
    }
  }

  Future<void> generateAISummary(Minute minute) async {
    if (minute.id == null) return;
    final token = _userNotifier.state.token;
    if (token == null) throw Exception('ログインが必要です');

    try {
      final summary = await _backend.summarizeWithPoints(
        token: token,
        text: minute.content,
      );

      if (summary == null) throw Exception('APIからの応答がありませんでした');

      final updatedMinute = Minute(
        id: minute.id,
        title: minute.title,
        content: minute.content,
        aiSummary: summary,
        audioPath: minute.audioPath,
        createdAt: minute.createdAt,
      );

      await _db.update(updatedMinute);
      await loadMinutes();

      // ポイントのローカル表示を更新
      await _userNotifier.refreshBalance();
    } catch (e) {
      appLog('Error generating AI summary: $e');
      rethrow;
    }
  }
}

// Recording State Provider
final recordingStateProvider =
    StateNotifierProvider<RecordingNotifier, RecordingState>((ref) {
      return RecordingNotifier(
        ref.watch(audioServiceProvider),
        ref.watch(backendServiceProvider),
        ref.watch(userProvider.notifier),
        ref.read(minutesListProvider.notifier),
      );
    });

enum RecordingStatus { idle, recording, transcribing, success, error }

class RecordingState {
  static const int maxAmplitudeSamples = 48;

  final RecordingStatus status;
  final String? filePath;
  final String? errorMessage;
  final List<double> amplitudes;
  final int elapsedSeconds;
  final int chargedMinutes;
  final int remainingPoints;

  RecordingState({
    this.status = RecordingStatus.idle,
    this.filePath,
    this.errorMessage,
    List<double> amplitudes = const [],
    this.elapsedSeconds = 0,
    this.chargedMinutes = 0,
    this.remainingPoints = 0,
  }) : amplitudes = List<double>.unmodifiable(amplitudes);

  static List<double> cappedAmplitudes(List<double> values) {
    if (values.length <= maxAmplitudeSamples) {
      return List<double>.unmodifiable(values);
    }
    return List<double>.unmodifiable(
      values.sublist(values.length - maxAmplitudeSamples),
    );
  }

  RecordingState copyWith({
    RecordingStatus? status,
    String? filePath,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<double>? amplitudes,
    int? elapsedSeconds,
    int? chargedMinutes,
    int? remainingPoints,
  }) {
    return RecordingState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      amplitudes: amplitudes ?? this.amplitudes,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      chargedMinutes: chargedMinutes ?? this.chargedMinutes,
      remainingPoints: remainingPoints ?? this.remainingPoints,
    );
  }
}

class RecordingNotifier extends StateNotifier<RecordingState> {
  final AudioService _audio;
  final BackendService _backend;
  final UserNotifier _userNotifier;
  final MinutesListNotifier _listNotifier;
  StreamSubscription<double>? _amplitudeSubscription;
  Timer? _recordingTimer;
  int _recordingSession = 0;
  bool _isDisposed = false;
  bool _isStarting = false;
  final bool _registerForegroundListener;
  final bool _updateForegroundOnDispose;

  RecordingNotifier(
    this._audio,
    this._backend,
    this._userNotifier,
    this._listNotifier, {
    bool registerForegroundListener = true,
    bool updateForegroundOnDispose = true,
  }) : _registerForegroundListener = registerForegroundListener,
       _updateForegroundOnDispose = updateForegroundOnDispose,
       super(RecordingState()) {
    if (_registerForegroundListener) {
      _initForegroundListener();
    }
  }

  void _initForegroundListener() {
    FlutterForegroundTask.addTaskDataCallback(_handleForegroundTaskData);
  }

  void _handleForegroundTaskData(Object data) {
    if (_isDisposed || !mounted) return;
    if (data == MyTaskHandler.actionStart) {
      unawaited(start());
    } else if (data == MyTaskHandler.actionStop) {
      unawaited(stop());
    }
  }

  Future<void> start() async {
    if (_isDisposed || !mounted) return;
    if (state.status != RecordingStatus.idle &&
        state.status != RecordingStatus.error) {
      return;
    }
    if (_isStarting) return;
    if (!_userNotifier.state.isAuthenticated) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: '録音にはログインが必要です。',
        amplitudes: const [],
      );
      return;
    }
    if (_userNotifier.state.points < 1) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'ポイントが不足しています。動画広告などでポイントを追加してください。',
        amplitudes: const [],
      );
      return;
    }
    _isStarting = true;
    try {
      appLog('RecordingNotifier: 録音開始要請');
      final session = ++_recordingSession;
      bool isCurrent() =>
          !_isDisposed && mounted && session == _recordingSession;

      final path = await _audio.startRecording();
      if (!isCurrent()) {
        if (path != null) await _audio.stopRecording();
        return;
      }
      if (path != null) {
        state = state.copyWith(
          status: RecordingStatus.recording,
          filePath: path,
          clearErrorMessage: true,
          amplitudes: const [],
          elapsedSeconds: 0,
          chargedMinutes: 0,
          remainingPoints: _userNotifier.state.points,
        );
        await _amplitudeSubscription?.cancel();
        if (!isCurrent()) return;
        _amplitudeSubscription = _audio.amplitudeStream.listen((value) {
          if (_isDisposed ||
              !mounted ||
              state.status != RecordingStatus.recording) {
            return;
          }
          state = state.copyWith(
            amplitudes: RecordingState.cappedAmplitudes([
              ...state.amplitudes,
              value,
            ]),
          );
        }, onError: (error) => appLog('RecordingNotifier: 音量ストリームエラー: $error'));
        if (!isCurrent()) return;
        _startRecordingTimer(session);
        await ForegroundService.updateService(true);
        if (!isCurrent()) {
          if (_isDisposed ||
              !mounted ||
              state.status != RecordingStatus.recording) {
            unawaited(ForegroundService.updateService(false));
          }
          return;
        }
      } else {
        state = state.copyWith(
          status: RecordingStatus.error,
          errorMessage: '録音の開始に失敗しました。マイクの権限を確認してください。',
          amplitudes: const [],
        );
      }
    } finally {
      _isStarting = false;
    }
  }

  void _startRecordingTimer(int session) {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed || !mounted || session != _recordingSession) return;
      if (state.status != RecordingStatus.recording) return;

      final nextElapsedSeconds = state.elapsedSeconds + 1;
      state = state.copyWith(elapsedSeconds: nextElapsedSeconds);

      if (nextElapsedSeconds % 60 == 0) {
        unawaited(_consumeRecordingMinute(session));
      }
    });
  }

  Future<void> _consumeRecordingMinute(int session) async {
    if (_isDisposed || !mounted || session != _recordingSession) return;
    try {
      await _userNotifier.consumeRecordingPoint();
      if (_isDisposed || !mounted || session != _recordingSession) return;
      state = state.copyWith(
        chargedMinutes: state.chargedMinutes + 1,
        remainingPoints: _userNotifier.state.points,
      );
    } on InsufficientPointsException {
      if (_isDisposed || !mounted || session != _recordingSession) return;
      state = state.copyWith(
        errorMessage: 'ポイントが不足したため録音を停止します。',
        remainingPoints: _userNotifier.state.points,
      );
      unawaited(stop());
    } catch (e) {
      appLog('RecordingNotifier: ポイント消費エラー: $e');
    }
  }

  Future<void> stop() async {
    if (_isDisposed || !mounted) return;
    if (_isStarting && state.status != RecordingStatus.recording) {
      _recordingSession++;
      unawaited(ForegroundService.updateService(false));
      return;
    }
    if (state.status != RecordingStatus.recording) return;
    appLog('RecordingNotifier: 録音停止要請');
    final session = ++_recordingSession;
    bool isCurrent() => !_isDisposed && mounted && session == _recordingSession;

    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    if (!isCurrent()) return;
    state = state.copyWith(status: RecordingStatus.transcribing);
    final path = await _audio.stopRecording();
    if (!isCurrent()) return;

    if (path != null) {
      try {
        final file = File(path);
        final exists = await file.exists();
        if (!isCurrent()) return;
        if (!exists) {
          throw Exception('録音ファイルが見つかりません。');
        }
        final fileSize = await file.length();
        if (!isCurrent()) return;
        appLog('RecordingNotifier: 録音ファイルサイズ: $fileSize bytes');

        if (fileSize < 100) {
          throw Exception('録音データが短すぎるか、空のようです。正しく録音されているか確認してください。');
        }

        appLog('RecordingNotifier: 文字起こし開始 (ファイルパス: $path)');
        final token = _userNotifier.state.token;
        if (token == null) throw Exception('ログインが必要です');
        final text = await _backend.transcribe(token: token, filePath: path);
        if (!isCurrent()) return;

        if (text == null) {
          throw Exception('サーバーとの通信に失敗しました。サーバーのログまたは接続を確認してください。');
        }

        if (text.isEmpty) {
          throw Exception('文字起こし結果が空でした。音声が小さすぎるか、正しく入力されていない可能性があります。');
        }

        final newMinute = Minute(
          title:
              '議事録 ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day} ${DateTime.now().hour}:${DateTime.now().minute}',
          content: text,
          audioPath: path,
          createdAt: DateTime.now(),
        );

        await _listNotifier.addMinute(newMinute);
        if (!isCurrent()) return;
        state = state.copyWith(
          status: RecordingStatus.success,
          amplitudes: const [],
          remainingPoints: _userNotifier.state.points,
        );
        await ForegroundService.updateService(false);
        if (!isCurrent()) return;

        Future.delayed(const Duration(seconds: 2), () {
          if (isCurrent()) state = state.copyWith(status: RecordingStatus.idle);
        });
      } catch (e) {
        appLog('RecordingNotifier: エラー発生: $e');
        if (!isCurrent()) return;
        state = state.copyWith(
          status: RecordingStatus.error,
          errorMessage: e.toString(),
          amplitudes: const [],
        );
        await ForegroundService.updateService(false);
        if (!_isDisposed &&
            mounted &&
            session != _recordingSession &&
            state.status == RecordingStatus.recording) {
          unawaited(ForegroundService.updateService(true));
        }
      }
    } else {
      if (!isCurrent()) return;
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: '録音ファイルの取得に失敗しました。',
        amplitudes: const [],
      );
      await ForegroundService.updateService(false);
      if (!_isDisposed &&
          mounted &&
          session != _recordingSession &&
          state.status == RecordingStatus.recording) {
        unawaited(ForegroundService.updateService(true));
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isStarting = false;
    _recordingSession++;
    if (_registerForegroundListener) {
      FlutterForegroundTask.removeTaskDataCallback(_handleForegroundTaskData);
    }
    final subscription = _amplitudeSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (_updateForegroundOnDispose) {
      unawaited(ForegroundService.updateService(false));
    }
    super.dispose();
  }
}
