# Recording Waveform Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink the recording microphone visual and use the freed space to make the waveform taller.

**Architecture:** Keep recording state and amplitude processing unchanged. Add test-visible layout constants to `RecordingViewContent` and `RecordingWaveform`, then use those constants in the recording UI so tests can verify the desired dimensions without depending on private widget internals.

**Tech Stack:** Flutter, Dart, Flutter widget tests.

---

## File Structure

- Modify `lib/views/recording_view.dart`: introduce recording microphone size constants and use smaller padding/icon values for the recording status only.
- Modify `lib/widgets/recording_waveform.dart`: introduce a waveform height constant and increase it from `64` to `128`.
- Modify `test/widget_test.dart`: add focused tests for the recording microphone layout constants and waveform height constant.

## Task 1: Shrink Recording Mic and Grow Waveform

**Files:**
- Modify: `lib/views/recording_view.dart`
- Modify: `lib/widgets/recording_waveform.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write failing layout tests**

Add these tests near the existing `RecordingWaveform` tests in `test/widget_test.dart`:

```dart
  test('RecordingWaveform uses expanded recording height', () {
    expect(recordingWaveformHeight, 128);
  });

  test('RecordingView recording mic visual is half height', () {
    expect(RecordingViewContent.recordingMicIconSize, 40);
    expect(RecordingViewContent.recordingMicPadding, 12);
    expect(RecordingViewContent.recordingMicVisualDiameter, 64);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run from the worktree root:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: FAIL because `recordingWaveformHeight`, `RecordingViewContent.recordingMicIconSize`, `RecordingViewContent.recordingMicPadding`, and `RecordingViewContent.recordingMicVisualDiameter` do not exist.

- [ ] **Step 3: Add waveform height constant**

In `lib/widgets/recording_waveform.dart`, add this top-level constant after the imports:

```dart
@visibleForTesting
const double recordingWaveformHeight = 128;
```

Then replace the `SizedBox` height in `RecordingWaveform.build` with:

```dart
      height: recordingWaveformHeight,
```

- [ ] **Step 4: Add recording microphone constants**

In `lib/views/recording_view.dart`, add these static constants inside `RecordingViewContent`:

```dart
  @visibleForTesting
  static const double recordingMicIconSize = 40;

  @visibleForTesting
  static const double recordingMicPadding = 12;

  @visibleForTesting
  static const double recordingMicVisualDiameter = recordingMicIconSize + (recordingMicPadding * 2);
```

- [ ] **Step 5: Use smaller recording microphone values**

In `RecordingViewContent._buildCenterDisplay`, update only the `RecordingStatus.recording` branch:

```dart
        return ScaleTransition(
          scale: pulseAnimation,
          child: Container(
            padding: const EdgeInsets.all(RecordingViewContent.recordingMicPadding),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic,
              size: RecordingViewContent.recordingMicIconSize,
              color: Colors.red,
            ),
          ),
        );
```

- [ ] **Step 6: Run focused tests**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 7: Run full verification**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter test
/opt/homebrew/share/flutter/bin/flutter build apk --debug
```

Expected: tests pass and debug APK builds.

- [ ] **Step 8: Android visual check**

Run:

```bash
/opt/homebrew/share/flutter/bin/flutter run -d 4XVKYPWOHMONUSFQ --debug
```

Expected: app launches on `2407FPN8ER`; during recording, the red mic is visually about half the previous size and the waveform is about twice as tall.

## Self-Review

- Spec coverage: Covers the approved visual direction: recording mic total diameter about `64px`, waveform height `128px`, and existing amplitude behavior unchanged.
- Placeholder scan: No placeholders, TBDs, or vague instructions remain.
- Type consistency: Uses existing Dart constants and `@visibleForTesting`; all names are defined before use.
