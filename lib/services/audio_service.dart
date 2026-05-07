import 'dart:async';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // --- 録音機能 ---

  Future<String?> startRecording() async {
    try {
      print('AudioService: 録音開始準備中...');
      
      // 権限の確認と要求（recordパッケージの機能を使用）
      if (!await _recorder.hasPermission()) {
        print('AudioService: マイク権限がありません');
        return null;
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = p.join(directory.path, 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a');
      
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      );
      
      await _recorder.start(config, path: filePath);
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

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
