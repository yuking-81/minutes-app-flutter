# Recording Waveform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real-time volume waveform to the recording modal so users can see microphone input while recording.

**Architecture:** Use the existing `record` package's `onAmplitudeChanged()` stream in `AudioService`, normalize dB values to UI-friendly amplitudes, store a capped rolling list in `RecordingState`, and draw it with a lightweight `CustomPainter` in `RecordingView`. No new packages are added.

**Tech Stack:** Flutter, Dart, Riverpod `StateNotifier`, `record` package, `CustomPainter`, Flutter widget tests.

---

## File Structure

- Modify `lib/services/audio_service.dart`: expose a broadcast stream of normalized amplitude values and manage the recorder amplitude subscription lifecycle.
- Modify `lib/providers/minute_provider.dart`: add `amplitudes` to `RecordingState`, cap samples at 48, subscribe/unsubscribe in `RecordingNotifier`.
- Create `lib/widgets/recording_waveform.dart`: render the amplitude list as rounded vertical bars around a center line.
- Modify `lib/views/recording_view.dart`: show the waveform under the recording microphone only while recording.
- Modify `test/widget_test.dart`: add focused tests for `RecordingState` amplitude behavior and waveform visibility.

## Task 1: Add Amplitude State Behavior

**Files:**
- Modify: `lib/providers/minute_provider.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write the failing state tests**

Add these tests to `test/widget_test.dart` below the existing smoke test:

```dart
  test('RecordingState copyWith preserves and updates amplitudes', () {
    final state = RecordingState(amplitudes: [0.1, 0.4]);

    expect(state.copyWith(status: RecordingStatus.recording).amplitudes, [0.1, 0.4]);
    expect(state.copyWith(amplitudes: [0.7]).amplitudes, [0.7]);
  });

  test('RecordingState cappedAmplitudes keeps the latest 48 samples', () {
    final samples = List<double>.generate(60, (index) => index / 100);

    final capped = RecordingState.cappedAmplitudes(samples);

    expect(capped.length, 48);
    expect(capped.first, 0.12);
    expect(capped.last, 0.59);
  });
```

Ensure `test/widget_test.dart` imports `minutes_app/providers/minute_provider.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run from the repository root:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: FAIL because `RecordingState` does not have `amplitudes` or `cappedAmplitudes`.

- [ ] **Step 3: Implement minimal state support**

In `lib/providers/minute_provider.dart`, replace `RecordingState` with:

```dart
class RecordingState {
  static const int maxAmplitudeSamples = 48;

  final RecordingStatus status;
  final String? filePath;
  final String? errorMessage;
  final List<double> amplitudes;

  RecordingState({
    this.status = RecordingStatus.idle,
    this.filePath,
    this.errorMessage,
    this.amplitudes = const [],
  });

  static List<double> cappedAmplitudes(List<double> values) {
    if (values.length <= maxAmplitudeSamples) return List<double>.unmodifiable(values);
    return List<double>.unmodifiable(values.sublist(values.length - maxAmplitudeSamples));
  }

  RecordingState copyWith({
    RecordingStatus? status,
    String? filePath,
    String? errorMessage,
    List<double>? amplitudes,
  }) {
    return RecordingState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
      amplitudes: amplitudes ?? this.amplitudes,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: PASS.

## Task 2: Expose Normalized Amplitude Stream

**Files:**
- Modify: `lib/services/audio_service.dart`

- [ ] **Step 1: Add stream fields and imports**

In `lib/services/audio_service.dart`, keep `dart:async` and add these fields inside `AudioService`:

```dart
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  Stream<double> get amplitudeStream => _amplitudeController.stream;
```

- [ ] **Step 2: Start amplitude monitoring after recorder starts**

In `startRecording()`, immediately after `await _recorder.start(config, path: filePath);`, add:

```dart
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen(
            (amplitude) => _amplitudeController.add(_normalizeAmplitude(amplitude.current)),
            onError: (error) => print('AudioService: 音量取得エラー: $error'),
          );
```

- [ ] **Step 3: Add normalization helper**

Add this private method before `dispose()`:

```dart
  double _normalizeAmplitude(double decibels) {
    const minDb = -60.0;
    const maxDb = 0.0;
    final clamped = decibels.clamp(minDb, maxDb) as double;
    return ((clamped - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
  }
```

- [ ] **Step 4: Stop amplitude monitoring**

In `stopRecording()`, immediately after `final path = await _recorder.stop();`, add:

```dart
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
```

In `dispose()`, replace the current body with:

```dart
  void dispose() {
    _amplitudeSubscription?.cancel();
    _amplitudeController.close();
    _recorder.dispose();
    _player.dispose();
  }
```

- [ ] **Step 5: Run tests**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: PASS.

## Task 3: Subscribe RecordingNotifier to Amplitudes

**Files:**
- Modify: `lib/providers/minute_provider.dart`

- [ ] **Step 1: Add subscription field**

Inside `RecordingNotifier`, add:

```dart
  StreamSubscription<double>? _amplitudeSubscription;
```

`dart:async` is already imported at the top of `minute_provider.dart`; if it is not, add:

```dart
import 'dart:async';
```

- [ ] **Step 2: Start listening when recording starts**

In `start()`, replace the successful state update:

```dart
      state = state.copyWith(status: RecordingStatus.recording, filePath: path, errorMessage: null);
```

with:

```dart
      state = state.copyWith(
        status: RecordingStatus.recording,
        filePath: path,
        errorMessage: null,
        amplitudes: const [],
      );
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _audio.amplitudeStream.listen(
        (value) {
          if (state.status != RecordingStatus.recording) return;
          state = state.copyWith(
            amplitudes: RecordingState.cappedAmplitudes([...state.amplitudes, value]),
          );
        },
        onError: (error) => print('RecordingNotifier: 音量ストリームエラー: $error'),
      );
```

- [ ] **Step 3: Stop listening when recording stops**

At the beginning of `stop()`, immediately after `print('RecordingNotifier: 録音停止要請');`, add:

```dart
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
```

- [ ] **Step 4: Clear amplitudes on terminal states**

In `stop()`, change terminal state updates to clear amplitudes:

```dart
        state = state.copyWith(status: RecordingStatus.success, amplitudes: const []);
```

```dart
        state = state.copyWith(status: RecordingStatus.error, errorMessage: e.toString(), amplitudes: const []);
```

```dart
      state = state.copyWith(status: RecordingStatus.error, errorMessage: '録音ファイルの取得に失敗しました。', amplitudes: const []);
```

- [ ] **Step 5: Cancel subscription in dispose**

Add this method to `RecordingNotifier`:

```dart
  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    super.dispose();
  }
```

- [ ] **Step 6: Run tests**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: PASS.

## Task 4: Add Waveform Widget

**Files:**
- Create: `lib/widgets/recording_waveform.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write failing widget test**

Add this import to `test/widget_test.dart`:

```dart
import 'package:minutes_app/widgets/recording_waveform.dart';
```

Add this test:

```dart
  testWidgets('RecordingWaveform renders amplitude samples', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RecordingWaveform(amplitudes: [0.1, 0.5, 1.0]),
        ),
      ),
    );

    expect(find.byType(RecordingWaveform), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: FAIL because `RecordingWaveform` does not exist.

- [ ] **Step 3: Create waveform widget**

Create `lib/widgets/recording_waveform.dart`:

```dart
import 'package:flutter/material.dart';

class RecordingWaveform extends StatelessWidget {
  final List<double> amplitudes;

  const RecordingWaveform({
    super.key,
    required this.amplitudes,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 64,
      width: double.infinity,
      child: CustomPaint(
        painter: _RecordingWaveformPainter(
          amplitudes: amplitudes,
          color: color,
          baselineColor: color.withOpacity(0.16),
        ),
      ),
    );
  }
}

class _RecordingWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;
  final Color baselineColor;

  _RecordingWaveformPainter({
    required this.amplitudes,
    required this.color,
    required this.baselineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final baselinePaint = Paint()
      ..color = baselineColor
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), baselinePaint);

    final samples = amplitudes.isEmpty ? const [0.04] : amplitudes;
    final barCount = samples.length;
    final gap = 3.0;
    final barWidth = (size.width - (gap * (barCount - 1))) / barCount;
    final safeBarWidth = barWidth.clamp(2.0, 8.0).toDouble();
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = safeBarWidth;

    for (var i = 0; i < barCount; i++) {
      final x = i * (safeBarWidth + gap) + safeBarWidth / 2;
      if (x > size.width) break;
      final normalized = samples[i].clamp(0.0, 1.0);
      final barHeight = 6 + (normalized * (size.height - 12));
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RecordingWaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.color != color ||
        oldDelegate.baselineColor != baselineColor;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: PASS.

## Task 5: Show Waveform in Recording Modal

**Files:**
- Modify: `lib/views/recording_view.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write failing visibility test**

Add this test to `test/widget_test.dart`:

```dart
  testWidgets('RecordingView shows waveform while recording', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingStateProvider.overrideWith(
            (ref) => _FakeRecordingNotifier(
              RecordingState(
                status: RecordingStatus.recording,
                amplitudes: const [0.2, 0.6, 0.9],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: RecordingView())),
      ),
    );

    await tester.pump();

    expect(find.byType(RecordingWaveform), findsOneWidget);
  });
```

Add this fake notifier near `FakeBackendService`:

```dart
class _FakeRecordingNotifier extends RecordingNotifier {
  _FakeRecordingNotifier(RecordingState initialState)
      : super(AudioService(), FakeBackendService(), _FakeUserNotifier(), _FakeMinutesListNotifier()) {
    state = initialState;
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

class _FakeUserNotifier extends UserNotifier {
  _FakeUserNotifier() : super(FakeBackendService());
}

class _FakeMinutesListNotifier extends MinutesListNotifier {
  _FakeMinutesListNotifier() : super(DatabaseService());
}
```

Ensure these imports exist:

```dart
import 'package:minutes_app/services/audio_service.dart';
import 'package:minutes_app/services/database_service.dart';
import 'package:minutes_app/views/recording_view.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: FAIL because `RecordingView` does not render `RecordingWaveform` yet.

- [ ] **Step 3: Render waveform while recording**

In `lib/views/recording_view.dart`, add:

```dart
import '../widgets/recording_waveform.dart';
```

In the `children` list, immediately after `_buildCenterDisplay(context, state),`, add:

```dart
          if (state.status == RecordingStatus.recording) ...[
            const SizedBox(height: 24),
            RecordingWaveform(amplitudes: state.amplitudes),
          ],
```

Keep the existing status text and action button unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: PASS.

## Task 6: Full Verification

**Files:**
- Read only verification

- [ ] **Step 1: Run Flutter tests**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test
```

Expected: `All tests passed!`.

- [ ] **Step 2: Build Android debug APK**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter build apk --debug
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 3: Run on connected Android device**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter devices
/opt/homebrew/share/flutter/bin/flutter run -d 4XVKYPWOHMONUSFQ --debug
```

Expected: app launches on `2407FPN8ER`.

- [ ] **Step 4: Manual device checks**

On the device:

1. Open the recording modal.
2. Confirm the waveform appears during recording.
3. Speak normally and confirm bars rise.
4. Stay silent and confirm bars drop close to baseline.
5. Stop recording and confirm transcription still succeeds.
