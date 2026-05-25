import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/minute_provider.dart';
import '../widgets/recording_waveform.dart';

class RecordingView extends ConsumerStatefulWidget {
  const RecordingView({super.key});

  @override
  ConsumerState<RecordingView> createState() => _RecordingViewState();
}

class _RecordingViewState extends ConsumerState<RecordingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // モーダルが開かれたら自動で録音を開始する
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(recordingStateProvider);
      if (state.status == RecordingStatus.idle) {
        ref.read(recordingStateProvider.notifier).start();
      }
      _syncPulseAnimation(ref.read(recordingStateProvider).status);
    });
  }

  void _syncPulseAnimation(RecordingStatus status) {
    if (status == RecordingStatus.recording) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RecordingState>(recordingStateProvider, (previous, next) {
      if (previous?.status != next.status) {
        _syncPulseAnimation(next.status);
      }
    });

    final state = ref.watch(recordingStateProvider);
    final notifier = ref.read(recordingStateProvider.notifier);

    return RecordingViewContent(
      state: state,
      pulseAnimation: _pulseAnimation,
      onStart: () => notifier.start(),
      onStop: () => notifier.stop(),
      onClose: () => Navigator.pop(context),
    );
  }
}

@visibleForTesting
class RecordingViewContent extends StatelessWidget {
  @visibleForTesting
  static const double recordingMicIconSize = 40;

  @visibleForTesting
  static const double recordingMicPadding = 12;

  @visibleForTesting
  static const double recordingMicVisualDiameter =
      recordingMicIconSize + (recordingMicPadding * 2);

  const RecordingViewContent({
    super.key,
    required this.state,
    required this.pulseAnimation,
    this.onStart,
    this.onStop,
    this.onClose,
  });

  final RecordingState state;
  final Animation<double> pulseAnimation;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),

          _buildCenterDisplay(context),
          if (state.status == RecordingStatus.recording) ...[
            const SizedBox(height: 24),
            RecordingWaveform(amplitudes: state.amplitudes),
          ],

          const SizedBox(height: 24),
          Text(
            _getStatusText(state.status),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 13,
                ),
              ),
            ),
          ],

          const SizedBox(height: 40),
          _buildActionButton(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCenterDisplay(BuildContext context) {
    switch (state.status) {
      case RecordingStatus.idle:
        return Icon(
          Icons.mic_none,
          size: 80,
          color: Theme.of(context).colorScheme.outline,
        );
      case RecordingStatus.recording:
        return ScaleTransition(
          scale: pulseAnimation,
          child: Container(
            padding: const EdgeInsets.all(
              RecordingViewContent.recordingMicPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic,
              size: RecordingViewContent.recordingMicIconSize,
              color: Colors.red,
            ),
          ),
        );
      case RecordingStatus.transcribing:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Groq AI 処理中...',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        );
      case RecordingStatus.success:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 48, color: Colors.white),
        );
      case RecordingStatus.error:
        return Icon(
          Icons.error_outline,
          size: 80,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }

  String _getStatusText(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.idle:
        return '録音を開始してください';
      case RecordingStatus.recording:
        return '録音中...';
      case RecordingStatus.transcribing:
        return '音声を解析しています';
      case RecordingStatus.success:
        return '議事録を作成しました！';
      case RecordingStatus.error:
        return 'エラーが発生しました';
    }
  }

  Widget _buildActionButton(BuildContext context) {
    if (state.status == RecordingStatus.recording) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop),
          label: const Text('録音を停止して文字起こし'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    } else if (state.status == RecordingStatus.idle ||
        state.status == RecordingStatus.error) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.mic),
          label: const Text('録音を開始する'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    } else if (state.status == RecordingStatus.success) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: TextButton(onPressed: onClose, child: const Text('閉じる')),
      );
    }
    return const SizedBox(height: 56);
  }
}
