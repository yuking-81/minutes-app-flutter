# Recording Waveform Dynamics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the taller recording waveform show more visible dips instead of staying near the top.

**Architecture:** Keep `AudioService` normalization and `RecordingState.amplitudes` unchanged. Adjust only the `RecordingWaveform` display conversion so normalized values below `0.20` sink to baseline, values above that are scaled by `2.0x`, and the final display value is clamped to `0.0..1.0`.

**Tech Stack:** Flutter, Dart, Flutter widget tests.

---

## File Structure

- Modify `lib/widgets/recording_waveform.dart`: update `recordingWaveformDisplayAmplitude` to subtract a display noise floor before applying gain.
- Modify `test/widget_test.dart`: update the display amplitude test to verify low values sink and mid/high values still scale.

## Task 1: Add Display Noise Floor Before 2x Gain

**Files:**
- Modify: `lib/widgets/recording_waveform.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Update the failing display conversion test**

Replace the existing `RecordingWaveform doubles display amplitude and clamps to one` test in `test/widget_test.dart` with:

```dart
  test('RecordingWaveform sinks low display amplitude before applying gain', () {
    expect(recordingWaveformDisplayAmplitude(0.0), 0.0);
    expect(recordingWaveformDisplayAmplitude(0.19), 0.0);
    expect(recordingWaveformDisplayAmplitude(0.25), closeTo(0.125, 0.0001));
    expect(recordingWaveformDisplayAmplitude(0.5), closeTo(0.75, 0.0001));
    expect(recordingWaveformDisplayAmplitude(0.7), 1.0);
    expect(recordingWaveformDisplayAmplitude(0.9), 1.0);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run from the worktree root:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: FAIL because the current display conversion still uses direct `value * 2.0` scaling.

- [ ] **Step 3: Update display conversion**

In `lib/widgets/recording_waveform.dart`, replace `recordingWaveformDisplayAmplitude` with:

```dart
@visibleForTesting
double recordingWaveformDisplayAmplitude(double amplitude) {
  const noiseFloor = 0.20;
  final normalized = recordingWaveformNormalizedAmplitude(amplitude);
  return (((normalized - noiseFloor) / (1.0 - noiseFloor)) * 2.0).clamp(0.0, 1.0).toDouble();
}
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run full verification**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test
/opt/homebrew/share/flutter/bin/flutter build apk --debug
```

Expected: tests pass and debug APK builds.

- [ ] **Step 6: Android visual check**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter run -d 4XVKYPWOHMONUSFQ --debug
```

Expected: app launches on `2407FPN8ER`; during recording, quiet moments dip closer to baseline while speech still produces tall bars.

## Self-Review

- Spec coverage: Covers the approved visual conversion: subtract `0.20`, scale remaining range by `2.0x`, clamp to `0.0..1.0`, and avoid changing audio/state semantics.
- Placeholder scan: No placeholders, TBDs, or vague instructions remain.
- Type consistency: Uses existing `recordingWaveformDisplayAmplitude` and `recordingWaveformNormalizedAmplitude` names.
