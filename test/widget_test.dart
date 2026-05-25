import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minutes_app/main.dart';
import 'package:minutes_app/providers/minute_provider.dart';
import 'package:minutes_app/providers/user_provider.dart';
import 'package:minutes_app/services/backend_service.dart';
import 'package:minutes_app/views/recording_view.dart';
import 'package:minutes_app/widgets/recording_waveform.dart';

class FakeBackendService extends BackendService {
  @override
  Future<AuthUser> me(String token) async {
    return const AuthUser(id: 1, email: 'test@example.com', points: 100);
  }

  @override
  Future<List<PointTransaction>> getTransactions(String token) async => [];
}

void main() {
  testWidgets('shows the minutes home screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendServiceProvider.overrideWithValue(FakeBackendService()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.text('議事録'), findsOneWidget);
    expect(find.text('録音開始'), findsOneWidget);
  });

  testWidgets('RecordingWaveform renders amplitude samples', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RecordingWaveform(amplitudes: [0.1, 0.5, 1.0])),
      ),
    );

    expect(find.byType(RecordingWaveform), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RecordingWaveform),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  test('RecordingWaveform uses expanded recording height', () {
    expect(recordingWaveformHeight, 128);
  });

  test('RecordingView recording mic visual is half height', () {
    expect(RecordingViewContent.recordingMicIconSize, 40);
    expect(RecordingViewContent.recordingMicPadding, 12);
    expect(RecordingViewContent.recordingMicVisualDiameter, 64);
  });

  test('RecordingWaveform spaces samples across the available width', () {
    expect(recordingWaveformBarCenterX(index: 0, barCount: 3, width: 300), 50);
    expect(recordingWaveformBarCenterX(index: 1, barCount: 3, width: 300), 150);
    expect(recordingWaveformBarCenterX(index: 2, barCount: 3, width: 300), 250);
  });

  test('RecordingWaveform treats non-finite amplitudes as zero', () {
    expect(recordingWaveformNormalizedAmplitude(double.nan), 0.0);
    expect(recordingWaveformNormalizedAmplitude(double.infinity), 0.0);
    expect(recordingWaveformNormalizedAmplitude(double.negativeInfinity), 0.0);
  });

  test(
    'RecordingWaveform sinks low display amplitude before applying gain',
    () {
      expect(recordingWaveformDisplayAmplitude(0.0), 0.0);
      expect(recordingWaveformDisplayAmplitude(0.19), 0.0);
      expect(recordingWaveformDisplayAmplitude(0.25), closeTo(0.125, 0.0001));
      expect(recordingWaveformDisplayAmplitude(0.5), closeTo(0.75, 0.0001));
      expect(recordingWaveformDisplayAmplitude(0.7), 1.0);
      expect(recordingWaveformDisplayAmplitude(0.9), 1.0);
    },
  );

  testWidgets('RecordingWaveform renders empty amplitudes without exceptions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RecordingWaveform(amplitudes: [])),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'RecordingWaveform renders non-finite and out-of-range amplitudes without exceptions',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecordingWaveform(amplitudes: [-1.0, double.nan, 0.5, 2.0]),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('RecordingView shows waveform while recording', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingViewContent(
            state: RecordingState(
              status: RecordingStatus.recording,
              amplitudes: [0.2, 0.6, 0.9],
            ),
            pulseAnimation: const AlwaysStoppedAnimation<double>(1.0),
            onStop: () {},
            onStart: () {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.byType(RecordingWaveform), findsOneWidget);
  });

  test('RecordingState copyWith preserves and updates amplitudes', () {
    final state = RecordingState(amplitudes: [0.1, 0.4]);

    expect(state.copyWith(status: RecordingStatus.recording).amplitudes, [
      0.1,
      0.4,
    ]);
    expect(state.copyWith(amplitudes: [0.7]).amplitudes, [0.7]);
  });

  test('RecordingState tracks recording point counters', () {
    final state = RecordingState(
      elapsedSeconds: 59,
      chargedMinutes: 0,
      remainingPoints: 3,
    );

    final updated = state.copyWith(
      elapsedSeconds: 60,
      chargedMinutes: 1,
      remainingPoints: 2,
    );

    expect(updated.elapsedSeconds, 60);
    expect(updated.chargedMinutes, 1);
    expect(updated.remainingPoints, 2);
  });

  test('RecordingState amplitudes defaults to empty', () {
    expect(RecordingState().amplitudes, isEmpty);
  });

  test('RecordingState cappedAmplitudes keeps the latest 48 samples', () {
    final samples = List<double>.generate(60, (index) => index / 100);

    final capped = RecordingState.cappedAmplitudes(samples);

    expect(capped.length, 48);
    expect(capped.first, 0.12);
    expect(capped.last, 0.59);
  });

  test('RecordingState cappedAmplitudes returns an unmodifiable list', () {
    final capped = RecordingState.cappedAmplitudes([0.1, 0.4]);

    expect(() => capped.add(0.7), throwsUnsupportedError);
  });

  test('RecordingState protects amplitudes from external list mutation', () {
    final constructorAmplitudes = [0.1, 0.4];
    final state = RecordingState(amplitudes: constructorAmplitudes);

    constructorAmplitudes.add(0.9);

    expect(state.amplitudes, [0.1, 0.4]);

    final copyAmplitudes = [0.7];
    final copy = state.copyWith(amplitudes: copyAmplitudes);

    copyAmplitudes.add(0.8);

    expect(copy.amplitudes, [0.7]);
  });
}
