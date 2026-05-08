# Recording Waveform Intensity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the recording waveform's visible bar height changes about twice as strong while preserving existing amplitude state semantics.

**Architecture:** Keep `AudioService` normalization and `RecordingState.amplitudes` unchanged. Apply a `2.0x` visual gain only inside the waveform painter, then clamp to `0.0..1.0` before calculating bar height.

**Tech Stack:** Flutter, Dart, `CustomPainter`, Flutter widget tests.

---

## File Structure

- Modify `lib/widgets/recording_waveform.dart`: add a test-visible helper for display amplitude scaling and use it in bar height calculation.
- Modify `test/widget_test.dart`: add a focused unit test that verifies display scaling doubles mid-range values and clamps high values.

## Task 1: Apply 2x Visual Gain to Waveform Bars

**Files:**
- Modify: `lib/widgets/recording_waveform.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

Add this test near the existing `RecordingWaveform renders amplitude samples` test in `test/widget_test.dart`:

```dart
  test('RecordingWaveform doubles display amplitude and clamps to one', () {
    expect(RecordingWaveform.displayAmplitudeForTest(0.0), 0.0);
    expect(RecordingWaveform.displayAmplitudeForTest(0.25), 0.5);
    expect(RecordingWaveform.displayAmplitudeForTest(0.5), 1.0);
    expect(RecordingWaveform.displayAmplitudeForTest(0.9), 1.0);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run from the worktree root:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: FAIL because `RecordingWaveform.displayAmplitudeForTest` does not exist.

- [ ] **Step 3: Add display amplitude helper**

In `lib/widgets/recording_waveform.dart`, ensure this import exists:

```dart
import 'package:flutter/foundation.dart';
```

Add this helper inside `RecordingWaveform`:

```dart
  static double _displayAmplitude(double value) {
    if (value.isNaN || value.isInfinite) return 0;
    return (value * 2.0).clamp(0.0, 1.0).toDouble();
  }

  @visibleForTesting
  static double displayAmplitudeForTest(double value) => _displayAmplitude(value);
```

- [ ] **Step 4: Use helper in painter**

In `_RecordingWaveformPainter.paint`, replace the normalized amplitude calculation with:

```dart
      final normalized = RecordingWaveform._displayAmplitude(samples[i]);
```

Keep the existing `barHeight` formula unchanged:

```dart
      final barHeight = 6 + (normalized * (size.height - 12));
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 6: Run full verification**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test
/opt/homebrew/share/flutter/bin/flutter build apk --debug
```

Expected: tests pass and debug APK builds.

- [ ] **Step 7: Android visual check**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter run -d 4XVKYPWOHMONUSFQ --debug
```

Expected: app launches on `2407FPN8ER`; during recording, waveform height variation is visibly stronger than before, and stopping recording still starts transcription.

## Self-Review

- Spec coverage: Covers the approved design requirement to apply `2.0x` visual emphasis only in `RecordingWaveform`, preserving state and service semantics.
- Placeholder scan: No placeholders, TBDs, or vague implementation steps remain.
- Type consistency: Uses existing `RecordingWaveform`, Dart `double`, and `@visibleForTesting` already used by Flutter code patterns.
