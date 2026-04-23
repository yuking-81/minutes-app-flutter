import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GroqService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.groq.com/openai/v1/audio/transcriptions';

  Future<String> transcribe(String filePath) async {
    final apiKey = dotenv.env['GROQ_API_KEY'];
    print('GroqService: API Key available: ${apiKey != null}');
    if (apiKey == null) {
      throw Exception('Groq API Key not found in .env');
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('録音ファイルが見つかりません: $filePath');
      }
      final fileSize = await file.length();
      print('GroqService: 送信ファイルサイズ: ${fileSize} bytes');
      
      if (fileSize < 100) {
        throw Exception('録音データが空に近い（${fileSize} bytes）ため、文字起こしを中断しました。');
      }

      print('GroqService: Groq APIへアップロード中 ($filePath)...');
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: 'audio.m4a',
          contentType: DioMediaType('audio', 'm4a'),
        ),
        'model': 'whisper-large-v3-turbo',
        'temperature': 0,
        'response_format': 'verbose_json',
      });

      final response = await _dio.post(
        _baseUrl,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
          validateStatus: (status) => true, // すべてのステータスコードをキャッチして詳細を確認
        ),
      );

      print('GroqService: レスポンスステータス: ${response.statusCode}');
      if (response.statusCode == 200) {
        final text = response.data['text'] ?? '';
        print('GroqService: 文字起こし成功。文字数: ${text.length}');
        return text;
      } else {
        print('GroqService: APIエラーレスポンス: ${response.data}');
        final errorMsg = response.data['error']?['message'] ?? response.statusMessage;
        throw Exception('Groq APIエラー ($errorMsg)');
      }
    } catch (e) {
      print('GroqService: 例外発生: $e');
      if (e is DioException) {
        print('GroqService: Dioエラー詳細: ${e.response?.data}');
      }
      throw Exception('文字起こしに失敗しました: $e');
    }
  }

  Future<String> summarize(String content) async {
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null) {
      throw Exception('Groq API Key not found in .env');
    }

    try {
      print('GroqService: AI要約開始...');
      final response = await _dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        data: {
          'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
          'messages': [
            {
              'role': 'system',
              'content': 'あなたは優秀な秘書です。提供された会議の文字起こしテキストを、以下の形式で構造化された議事録にまとめてください。\n'
                  '1. 議題（タイトル）\n'
                  '2. 要約（3〜5文程度）\n'
                  '3. 決定事項（箇条書き）\n'
                  '4. ネクストアクション（ToDo、期限があれば含む）\n'
                  '出力は必ず日本語で行ってください。',
            },
            {
              'role': 'user',
              'content': content,
            }
          ],
          'temperature': 0.7,
          'max_completion_tokens': 2048,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final text = response.data['choices'][0]['message']['content'] ?? '';
        print('GroqService: AI要約成功');
        return text;
      } else {
        print('GroqService: AI要約エラー: ${response.data}');
        throw Exception('AI要約に失敗しました: ${response.statusMessage}');
      }
    } catch (e) {
      print('GroqService: AI要約中に例外発生: $e');
      throw Exception('AI要約プロセス中にエラーが発生しました: $e');
    }
  }
}
