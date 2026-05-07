import 'dart:io';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/minute_model.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import '../services/foreground_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../services/backend_service.dart';
import 'user_provider.dart';

// Service Providers
final databaseServiceProvider = Provider((ref) => DatabaseService.instance);
final audioServiceProvider = Provider((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Minutes List Provider
final minutesListProvider = StateNotifierProvider<MinutesListNotifier, AsyncValue<List<Minute>>>((ref) {
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
  
  MinutesListNotifier(this._db, this._backend, this._userNotifier) : super(const AsyncValue.loading()) {
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
      print('Error adding minute: $e');
    }
  }

  Future<void> deleteMinute(int id) async {
    try {
      await _db.delete(id);
      await loadMinutes();
    } catch (e) {
      print('Error deleting minute: $e');
    }
  }

  Future<void> generateAISummary(Minute minute) async {
    if (minute.id == null) return;
    
    try {
      final deviceId = _userNotifier.state.userId;
      final summary = await _backend.summarizeWithPoints(
        deviceId: deviceId,
        text: minute.content,
        pointCost: 10, // 実装計画通りの単価
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
      print('Error generating AI summary: $e');
      rethrow;
    }
  }
}

// Recording State Provider
final recordingStateProvider = StateNotifierProvider<RecordingNotifier, RecordingState>((ref) {
  return RecordingNotifier(
    ref.watch(audioServiceProvider),
    ref.watch(backendServiceProvider),
    ref.watch(userProvider.notifier),
    ref.read(minutesListProvider.notifier),
  );
});

enum RecordingStatus { idle, recording, transcribing, success, error }

class RecordingState {
  final RecordingStatus status;
  final String? filePath;
  final String? errorMessage;

  RecordingState({
    this.status = RecordingStatus.idle,
    this.filePath,
    this.errorMessage,
  });

  RecordingState copyWith({
    RecordingStatus? status,
    String? filePath,
    String? errorMessage,
  }) {
    return RecordingState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class RecordingNotifier extends StateNotifier<RecordingState> {
  final AudioService _audio;
  final BackendService _backend;
  final UserNotifier _userNotifier;
  final MinutesListNotifier _listNotifier;

  RecordingNotifier(this._audio, this._backend, this._userNotifier, this._listNotifier) : super(RecordingState()) {
    _initForegroundListener();
  }

  void _initForegroundListener() {
    FlutterForegroundTask.addTaskDataCallback((data) {
      if (data == MyTaskHandler.actionStart) {
        start();
      } else if (data == MyTaskHandler.actionStop) {
        stop();
      }
    });
  }

  Future<void> start() async {
    print('RecordingNotifier: 録音開始要請');
    final path = await _audio.startRecording();
    if (path != null) {
      state = state.copyWith(status: RecordingStatus.recording, filePath: path, errorMessage: null);
      await ForegroundService.updateService(true);
    } else {
      state = state.copyWith(status: RecordingStatus.error, errorMessage: '録音の開始に失敗しました。マイクの権限を確認してください。');
    }
  }

  Future<void> stop() async {
    print('RecordingNotifier: 録音停止要請');
    state = state.copyWith(status: RecordingStatus.transcribing);
    final path = await _audio.stopRecording();
    
    if (path != null) {
      try {
        final file = File(path);
        if (!await file.exists()) {
          throw Exception('録音ファイルが見つかりません。');
        }
        final fileSize = await file.length();
        print('RecordingNotifier: 録音ファイルサイズ: $fileSize bytes');
        
        if (fileSize < 100) {
          throw Exception('録音データが短すぎるか、空のようです。正しく録音されているか確認してください。');
        }

        print('RecordingNotifier: 文字起こし開始 (ファイルパス: $path)');
        final deviceId = _userNotifier.state.userId;
        final text = await _backend.transcribe(
          deviceId: deviceId,
          filePath: path,
        );
        
        if (text == null) {
          throw Exception('サーバーとの通信に失敗しました。サーバーのログまたは接続を確認してください。');
        }
        
        if (text.isEmpty) {
          throw Exception('文字起こし結果が空でした。音声が小さすぎるか、正しく入力されていない可能性があります。');
        }

        final newMinute = Minute(
          title: '議事録 ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day} ${DateTime.now().hour}:${DateTime.now().minute}',
          content: text,
          audioPath: path,
          createdAt: DateTime.now(),
        );
        
        await _listNotifier.addMinute(newMinute);
        state = state.copyWith(status: RecordingStatus.success);
        await ForegroundService.updateService(false);
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) state = state.copyWith(status: RecordingStatus.idle);
        });
      } catch (e) {
        print('RecordingNotifier: エラー発生: $e');
        state = state.copyWith(status: RecordingStatus.error, errorMessage: e.toString());
        await ForegroundService.updateService(false);
      }
    } else {
      state = state.copyWith(status: RecordingStatus.error, errorMessage: '録音ファイルの取得に失敗しました。');
    }
  }
}
