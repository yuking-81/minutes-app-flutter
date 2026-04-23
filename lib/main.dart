import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'views/home_screen.dart';
import 'services/foreground_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('--- App Starting ---');
  
  // .envファイルの読み込み検証
  try {
    await dotenv.load(fileName: ".env");
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      print('DEBUG: .env load successful. API Key found (ends with: ...${apiKey.substring(apiKey.length - 4)})');
    } else {
      print('WARNING: .env load successful but GROQ_API_KEY is empty or missing');
    }
  } catch (e) {
    print("ERROR: Could not load .env file: $e");
  }

  // Foreground Service 初期化
  await ForegroundService.init();

  // Mobile Ads 初期化
  await MobileAds.instance.initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
  
  // 起動時にサービスを開始（通知を表示）
  await ForegroundService.startService(false);
}

class NoStretchScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '議事録アプリ',
      debugShowCheckedModeBanner: false,
      scrollBehavior: NoStretchScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: WithForegroundTask(
        child: const HomeScreen(),
      ),
    );
  }
}
