import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@visibleForTesting
const double recordingWaveformHeight = 128;

@visibleForTesting
double recordingWaveformBarCenterX({
  required int index,
  required int barCount,
  required double width,
}) {
  final slotWidth = width / barCount;
  return (index * slotWidth) + (slotWidth / 2);
}

@visibleForTesting
double recordingWaveformNormalizedAmplitude(double amplitude) {
  if (!amplitude.isFinite) return 0.0;
  return amplitude.clamp(0.0, 1.0).toDouble();
}

@visibleForTesting
double recordingWaveformDisplayAmplitude(double amplitude) {
  const noiseFloor = 0.20;
  final normalized = recordingWaveformNormalizedAmplitude(amplitude);
  return (((normalized - noiseFloor) / (1.0 - noiseFloor)) * 2.0).clamp(0.0, 1.0).toDouble();
}

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
      height: recordingWaveformHeight,
      width: double.infinity,
      child: CustomPaint(
        painter: _RecordingWaveformPainter(
          amplitudes: amplitudes,
          color: color,
          baselineColor: color.withValues(alpha: 0.16),
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
    final slotWidth = size.width / barCount;
    final barWidth = slotWidth - gap;
    final safeBarWidth = barWidth.clamp(2.0, 8.0).toDouble();
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = safeBarWidth;

    for (var i = 0; i < barCount; i++) {
      final x = recordingWaveformBarCenterX(index: i, barCount: barCount, width: size.width);
      if (x > size.width) break;
      final normalized = recordingWaveformDisplayAmplitude(samples[i]);
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
