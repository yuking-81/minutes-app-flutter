import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/minute_provider.dart';
import 'recording_view.dart';
import 'detail_screen.dart';
import '../providers/user_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSheetOpen = false;

  void _showRecordingSheet() {
    if (_isSheetOpen) return;
    
    _isSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RecordingView(),
    ).then((_) => _isSheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final minutesAsync = ref.watch(minutesListProvider);
    final userState = ref.watch(userProvider);

    // 録音ステートを監視し、録音中になったら自動でシートを開く（通知からの起動用）
    ref.listen(recordingStateProvider, (previous, next) {
      if (next.status == RecordingStatus.recording && !_isSheetOpen) {
        _showRecordingSheet();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('議事録', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.monetization_on, size: 18, color: Colors.amber),
              label: Text(
                '${userState.points} pt',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showShopDialog(context, ref),
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              side: BorderSide.none,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
      body: minutesAsync.when(
        data: (minutes) => minutes.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.all(16),
                itemCount: minutes.length,
                itemBuilder: (context, index) {
                  final minute = minutes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      title: Text(
                        minute.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            minute.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('yyyy/MM/dd HH:mm').format(minute.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailScreen(minute: minute),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('エラーが発生しました: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const RecordingView(),
          );
        },
        icon: const Icon(Icons.mic),
        label: const Text('録音開始'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            '議事録がありません',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            '下のボタンから録音を開始して作成しましょう',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showShopDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ポイントを取得'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.blue),
              title: const Text('動画広告を見て 5pt ゲット'),
              subtitle: const Text('リワード広告が再生されます'),
              onTap: () {
                ref.read(userProvider.notifier).showRewardAd(
                  onComplete: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('5ポイント追加されました！')),
                    );
                  },
                  onError: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('広告の読み込みに失敗しました')),
                    );
                  },
                );
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.shopping_bag, color: Colors.orange),
              title: const Text('100ポイント購入 (テスト用)'),
              subtitle: const Text('タップすると即座に100pt追加されます'),
              onTap: () async {
                await ref.read(userProvider.notifier).addPoints(100);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('100ポイント追加されました！')),
                  );
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
