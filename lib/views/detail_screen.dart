import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/minute_model.dart';
import '../providers/minute_provider.dart';
import 'components/audio_player_widget.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final Minute minute;

  const DetailScreen({super.key, required this.minute});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  bool _isLoading = false;

  Future<void> _generateAI() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(minutesListProvider.notifier)
          .generateAISummary(widget.minute);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('AIによる議事録変換が完了しました')));
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString();
        if (errorMessage.contains('ポイントが不足しています')) {
          _showPointShortageDialog();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPointShortageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ポイント不足'),
        content: const Text('AI要約を実行するためのポイントが足りません。\n広告を見るか、ポイントを購入してください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ホーム画面右上のボタンからチャージしてください')),
              );
            },
            child: const Text('チャージする'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMinute() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: const Text('この議事録を削除してもよろしいですか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (widget.minute.id != null) {
        await ref
            .read(minutesListProvider.notifier)
            .deleteMinute(widget.minute.id!);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('削除が完了しました')));
        }
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('クリップボードにコピーしました')));
  }

  @override
  Widget build(BuildContext context) {
    final minutesAsync = ref.watch(minutesListProvider);
    final currentMinute = minutesAsync.when(
      data: (list) => list.firstWhere(
        (m) => m.id == widget.minute.id,
        orElse: () => widget.minute,
      ),
      loading: () => widget.minute,
      error: (_, _) => widget.minute,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('議事録詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _deleteMinute,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('共有機能は将来的に実装予定です')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat(
                    'yyyy年MM月dd日 HH:mm',
                  ).format(currentMinute.createdAt),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(context, '文字起こしテキスト', Icons.notes),
            const SizedBox(height: 12),
            _buildContentBox(context, currentMinute.content),

            const SizedBox(height: 32),

            if (currentMinute.aiSummary != null) ...[
              _buildSectionTitle(context, 'AI 議事録要約', Icons.auto_awesome),
              const SizedBox(height: 12),
              _buildAIContentBox(context, currentMinute.aiSummary!),
              const SizedBox(height: 24),
            ],

            if (currentMinute.audioPath != null) ...[
              _buildSectionTitle(context, '録音データ', Icons.audiotrack),
              const SizedBox(height: 12),
              AudioPlayerWidget(audioPath: currentMinute.audioPath!),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'ファイル: ${currentMinute.audioPath?.split('/').last}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ),
              const SizedBox(height: 32),
            ],

            Center(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _generateAI,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(
                        currentMinute.aiSummary == null
                            ? 'AIで議事録に変換'
                            : 'AIで再変換',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildContentBox(BuildContext context, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: SelectableText(
        content,
        style: const TextStyle(fontSize: 16, height: 1.6),
      ),
    );
  }

  Widget _buildAIContentBox(BuildContext context, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.3),
            Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => _copyToClipboard(content),
                tooltip: '要約をコピー',
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.7,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
