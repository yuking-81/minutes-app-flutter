import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_logger.dart';

class AuthUser {
  final int id;
  final String email;
  final int points;

  const AuthUser({required this.id, required this.email, required this.points});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      email: json['email'] as String,
      points: json['points'] as int,
    );
  }
}

class AuthResult {
  final String token;
  final AuthUser user;

  const AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class PointTransaction {
  final int id;
  final int amount;
  final String type;
  final String? reason;
  final DateTime createdAt;

  const PointTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.reason,
    required this.createdAt,
  });

  factory PointTransaction.fromJson(Map<String, dynamic> json) {
    return PointTransaction(
      id: json['id'] as int,
      amount: json['amount'] as int,
      type: json['type'] as String,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class InsufficientPointsException implements Exception {
  const InsufficientPointsException();

  @override
  String toString() => 'ポイントが不足しています';
}

class BackendService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  final String _baseUrl;

  BackendService()
    : _baseUrl = dotenv.isInitialized
          ? dotenv.get('BACKEND_URL', fallback: 'http://localhost:3000')
          : 'http://localhost:3000';

  Options _authOptions(String token) {
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  void _logDioError(String operation, Object error) {
    if (error is DioException) {
      appLog('BackendService: $operation url=${error.requestOptions.uri}');
      appLog(
        'BackendService: $operation status=${error.response?.statusCode} data=${error.response?.data}',
      );
    }
  }

  Future<AuthResult> register({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/auth/register',
      data: {'email': email, 'password': password},
    );
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthUser> me(String token) async {
    final response = await _dio.get(
      '$_baseUrl/me',
      options: _authOptions(token),
    );
    return AuthUser.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  Future<int> getBalance(String token) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/points/balance',
        options: _authOptions(token),
      );
      return response.data['points'] as int;
    } catch (e) {
      _logDioError('getBalance', e);
      appLog('BackendService: getBalance error: $e');
      rethrow;
    }
  }

  Future<List<PointTransaction>> getTransactions(String token) async {
    final response = await _dio.get(
      '$_baseUrl/points/transactions',
      options: _authOptions(token),
    );
    final items = response.data['transactions'] as List<dynamic>;
    return items
        .map((item) => PointTransaction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<int> addReward({
    required String token,
    required int amount,
    String type = 'reward_ad',
    String reason = 'Rewarded ad',
  }) async {
    final response = await _dio.post(
      '$_baseUrl/points/reward',
      data: {'amount': amount, 'type': type, 'reason': reason},
      options: _authOptions(token),
    );
    return response.data['points'] as int;
  }

  Future<int> consumePoints({
    required String token,
    required int amount,
    required String type,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/points/consume',
        data: {'amount': amount, 'type': type, 'reason': reason},
        options: _authOptions(token),
      );
      return response.data['points'] as int;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 403) {
        throw const InsufficientPointsException();
      }
      _logDioError('consumePoints', e);
      rethrow;
    }
  }

  Future<String?> summarizeWithPoints({
    required String token,
    required String text,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/ai/summarize',
        data: {'text': text},
        options: _authOptions(token),
      );
      return response.data['summary'] as String;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 403) {
        throw const InsufficientPointsException();
      }
      _logDioError('summarize', e);
      appLog('BackendService: summarize error: $e');
      rethrow;
    }
  }

  Future<String?> transcribe({
    required String token,
    required String filePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: 'recording.m4a',
        ),
      });

      final response = await _dio.post(
        '$_baseUrl/ai/transcribe',
        data: formData,
        options: _authOptions(token),
      );
      return response.data['text'] as String;
    } catch (e) {
      _logDioError('transcribe', e);
      appLog('BackendService: transcribe error: $e');
      return null;
    }
  }
}
