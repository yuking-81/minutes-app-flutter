import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60), // AI処理待ちのため長めに設定
  ));
  final String _baseUrl;

  BackendService() : _baseUrl = dotenv.get('BACKEND_URL', fallback: 'http://localhost:3000');

  // ユーザーのポイント残高を取得
  Future<int> getBalance(String deviceId) async {
    try {
      final response = await _dio.get('$_baseUrl/user/balance/$deviceId');
      return response.data['points'] as int;
    } catch (e) {
      print('BackendService: getBalance error: $e');
      return 0;
    }
  }

  // 報酬ポイント（広告視聴など）を加算
  Future<int?> addReward(String deviceId, int amount) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/user/reward',
        data: {'deviceId': deviceId, 'amount': amount},
      );
      return response.data['points'] as int;
    } catch (e) {
      print('BackendService: addReward error: $e');
      return null;
    }
  }

  // AI要約を実行（ポイント消費を伴う）
  Future<String?> summarizeWithPoints({
    required String deviceId,
    required String text,
    required int pointCost,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/ai/summarize',
        data: {
          'deviceId': deviceId,
          'text': text,
          'pointCost': pointCost,
        },
      );
      return response.data['summary'] as String;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 403) {
        throw Exception('ポイントが不足しています');
      }
      print('BackendService: summarize error: $e');
      rethrow;
    }
  }

  // 文字起こしを実行（音声ファイルを送信）
  Future<String?> transcribe({
    required String deviceId,
    required String filePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'deviceId': deviceId,
        'file': await MultipartFile.fromFile(filePath, filename: 'recording.m4a'),
      });

      final response = await _dio.post(
        '$_baseUrl/ai/transcribe',
        data: formData,
      );
      return response.data['text'] as String;
    } catch (e) {
      print('BackendService: transcribe error: $e');
      return null;
    }
  }
}
