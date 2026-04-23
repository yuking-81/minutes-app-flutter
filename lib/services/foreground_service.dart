import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  static const String actionStart = 'start';
  static const String actionStop = 'stop';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('ForegroundTask: Service Started');
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('ForegroundTask: Button Pressed: $id');
    // アプリを起動（フォアグラウンドに持ってくる）
    FlutterForegroundTask.launchApp();
    // 通知ボタンが押されたことをメインアイソレートに伝える
    FlutterForegroundTask.sendDataToMain(id);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 繰り返し処理のコールバック（必須実装）
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('ForegroundTask: Service Destroyed (timeout: $isTimeout)');
  }
}

class ForegroundService {
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'recording_service',
        channelName: '録音中通知',
        channelDescription: '録音操作用の常駐通知です',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> startService(bool isRecording) async {
    // 権限確認 (Android 13+ の通知許可など)
    final NotificationPermission notificationPermissionStatus = 
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      await updateService(isRecording);
      return;
    }

    await FlutterForegroundTask.startService(
      notificationTitle: isRecording ? '録音中...' : '議事録アプリ待機中',
      notificationText: isRecording ? '音声をキャプチャしています' : 'ボタンを押して録音を開始',
      callback: startCallback,
      notificationButtons: _getButtons(isRecording),
    );
  }

  static Future<void> updateService(bool isRecording) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: isRecording ? '録音中...' : '議事録アプリ待機中',
      notificationText: isRecording ? '音声をキャプチャしています' : 'ボタンを押して録音を開始',
      notificationButtons: _getButtons(isRecording),
    );
  }

  static Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
  }

  static List<NotificationButton> _getButtons(bool isRecording) {
    if (isRecording) {
      return [
        const NotificationButton(id: MyTaskHandler.actionStop, text: '停止', textColor: Colors.red),
      ];
    } else {
      return [
        const NotificationButton(id: MyTaskHandler.actionStart, text: '録音開始'),
      ];
    }
  }
}
