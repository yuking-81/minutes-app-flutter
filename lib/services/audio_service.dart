import 'dart:async';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  bool _isDisposed = false;

  Stream<double> get amplitudeStream => _amplitudeController.stream;

  // --- 録音機能 ---

  Future<String?> startRecording() async {
    try {
      if (_isDisposed) return null;
      print('AudioService: 録音開始準備中...');
      
      // 権限の確認と要求（recordパッケージの機能を使用）
      if (!await _recorder.hasPermission()) {
        print('AudioService: マイク権限がありません');
        return null;
      }
      if (_isDisposed) return null;

      final directory = await getApplicationDocumentsDirectory();
      if (_isDisposed) return null;
      final filePath = p.join(directory.path, 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a');
      
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      );
      
      await _recorder.start(config, path: filePath);
      if (_isDisposed) {
        await _recorder.stop();
        return null;
      }
      try {
        await _amplitudeSubscription?.cancel();
        if (_isDisposed) {
          await _recorder.stop();
          return null;
        }
        _amplitudeSubscription = _recorder
            .onAmplitudeChanged(const Duration(milliseconds: 100))
            .listen(
              (amplitude) {
                if (!_isDisposed && !_amplitudeController.isClosed) {
                  _amplitudeController.add(_normalizeAmplitude(amplitude.current));
                }
              },
              onError: (error) => print('AudioService: 音量取得エラー: $error'),
            );
      } catch (e) {
        await _amplitudeSubscription?.cancel();
        _amplitudeSubscription = null;
        if (_isDisposed) {
          await _recorder.stop();
          return null;
        }
        print('AudioService: 音量監視を開始できませんでした: $e');
      }
      print('AudioService: 録音開始成功 ($filePath)');
      return filePath;
    } catch (e) {
      print('AudioService: 録音開始エラー: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      print('AudioService: 録音停止中...');
      final path = await _recorder.stop();
      print('AudioService: 録音停止完了, path: $path');
      return path;
    } catch (e) {
      print('AudioService: 録音停止エラー: $e');
      return null;
    } finally {
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
    }
  }

  // --- 再生機能 ---

  AudioPlayer get player => _player;

  Future<void> play(String path) async {
    await _player.play(DeviceFileSource(path));
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stopPlayer() async {
    await _player.stop();
  }

  Future<void> resume() async {
    await _player.resume();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  double _normalizeAmplitude(double decibels) {
    const minDb = -60.0;
    const maxDb = 0.0;
    final clamped = decibels.clamp(minDb, maxDb) as double;
    return ((clamped - minDb) / (maxDb - minDb)).clamp(0.0, 1.0).toDouble();
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    if (!_amplitudeController.isClosed) {
      await _amplitudeController.close();
    }
    await _recorder.dispose();
    await _player.dispose();
  }
}
