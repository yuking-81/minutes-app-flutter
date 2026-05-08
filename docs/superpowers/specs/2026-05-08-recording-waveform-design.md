# Recording Waveform Design

## Goal

Show a real-time volume waveform while the user is recording audio, so the recording modal gives immediate feedback that the microphone is receiving sound.

## Current Context

The recording modal is implemented in `lib/views/recording_view.dart`. It currently shows a pulsing red microphone icon while `RecordingStatus.recording` is active.

Recording is managed by `AudioService` in `lib/services/audio_service.dart`, which uses the existing `record` package. The installed `record` package exposes `onAmplitudeChanged(Duration interval)`, so real-time volume can be implemented without adding a new dependency.

Recording state is managed by `RecordingNotifier` and `RecordingState` in `lib/providers/minute_provider.dart`. The notifier already owns the start/stop lifecycle and is the right place to receive amplitude samples and expose UI-ready values.

## Chosen Approach

Use `record` package amplitude updates and render a lightweight custom waveform in Flutter.

- `AudioService` subscribes to `AudioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100))` while recording.
- The dB amplitude value is normalized into a `0.0` to `1.0` range.
- `RecordingNotifier` stores a rolling list of recent normalized amplitudes in `RecordingState`.
- `RecordingView` renders the rolling list with a `CustomPainter` only while recording.

This avoids adding `audio_waveforms` or replacing the current recording implementation.

## Audio Data Flow

1. User opens the recording modal.
2. `RecordingView` auto-starts recording through `RecordingNotifier.start()`.
3. `AudioService.startRecording()` starts the recorder and begins listening for amplitude updates.
4. `AudioService` exposes normalized amplitude values through a broadcast stream.
5. `RecordingNotifier` listens to the stream and appends values to `RecordingState.amplitudes`.
6. `RecordingView` watches `RecordingState` and paints the waveform from `amplitudes`.
7. On stop, error, or disposal, amplitude subscriptions are cancelled and the waveform stops updating.

## UI Behavior

During recording, keep the existing red microphone visual and add a horizontal waveform under it.

The waveform should:

- Use the app's existing modal styling.
- Reduce the recording microphone visual from about `128px` total diameter to about `64px` total diameter by using smaller circle padding and a smaller icon.
- Use the freed vertical space to increase the waveform canvas height from `64px` to `128px`.
- Draw vertical rounded bars around a center line.
- Show roughly the last 40 to 60 samples.
- Animate by updating as new amplitude samples arrive.
- Visually emphasize the bar height at paint time while preserving visible dips: subtract a `0.20` display noise floor, scale the remaining range by `2.0x`, then clamp to `0.0` to `1.0`.
- Fall back to low bars if there is silence.
- Not appear during idle, transcribing, success, or error states.

## State Shape

Add `List<double> amplitudes` to `RecordingState`.

Rules:

- Values are normalized from `0.0` to `1.0`.
- Stored values remain raw normalized amplitudes; visual emphasis is handled only by `RecordingWaveform` so state semantics stay unchanged.
- Recording start clears previous amplitudes.
- Each new sample appends one value.
- Keep only the most recent 48 values to avoid unbounded state growth.
- Stop/error/success do not need to preserve waveform history.

## Error Handling

Amplitude updates are best-effort UI feedback. If amplitude reading fails, recording should continue.

- Log amplitude stream errors for diagnostics.
- Do not transition recording state to error solely because amplitude updates fail.
- Always cancel the amplitude subscription when recording stops or `AudioService.dispose()` runs.

## Testing

Add widget-level or unit-level coverage around the state behavior instead of trying to test actual microphone input.

Required checks:

- `RecordingState.copyWith` preserves and updates `amplitudes` correctly.
- The rolling sample list is capped at 48 values.
- `RecordingView` shows the waveform widget only while recording.

Manual device verification:

- Start recording on Android.
- Speak normally and confirm the waveform bars respond.
- Stay silent and confirm the waveform drops close to baseline.
- Stop recording and confirm transcription still works.

## Out of Scope

- Persisting waveform data with saved minutes.
- Rendering playback waveforms for existing audio files.
- Replacing the existing `record` package or recording pipeline.
- Adding an external waveform package.
