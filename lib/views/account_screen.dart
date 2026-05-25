import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(userProvider.notifier);
    try {
      if (_isRegisterMode) {
        await notifier.register(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        await notifier.login(_emailController.text, _passwordController.text);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isRegisterMode ? '登録しました' : 'ログインしました')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールアドレスまたはパスワードを確認してください')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('アカウント / ポイント')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (state.isAuthenticated)
            _AccountSummary(state: state)
          else
            _AuthForm(
              emailController: _emailController,
              passwordController: _passwordController,
              isRegisterMode: _isRegisterMode,
              isLoading: state.isLoading,
              onToggleMode: () {
                setState(() => _isRegisterMode = !_isRegisterMode);
              },
              onSubmit: _submit,
            ),
          const SizedBox(height: 24),
          if (state.isAuthenticated) ...[
            _PointActions(state: state),
            const SizedBox(height: 24),
            _TransactionList(state: state),
          ],
        ],
      ),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.emailController,
    required this.passwordController,
    required this.isRegisterMode,
    required this.isLoading,
    required this.onToggleMode,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isRegisterMode;
  final bool isLoading;
  final VoidCallback onToggleMode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isRegisterMode ? 'アカウント登録' : 'ログイン',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'パスワード',
            helperText: '8文字以上',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: isLoading ? null : onSubmit,
          child: Text(isRegisterMode ? '登録' : 'ログイン'),
        ),
        TextButton(
          onPressed: isLoading ? null : onToggleMode,
          child: Text(isRegisterMode ? 'ログインに切り替え' : '新規登録に切り替え'),
        ),
      ],
    );
  }
}

class _AccountSummary extends ConsumerWidget {
  const _AccountSummary({required this.state});

  final UserState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(state.email ?? ''),
          subtitle: Text('${state.points} pt'),
        ),
        OutlinedButton.icon(
          onPressed: () => ref.read(userProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('ログアウト'),
        ),
      ],
    );
  }
}

class _PointActions extends ConsumerWidget {
  const _PointActions({required this.state});

  final UserState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ポイント操作', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () {
            ref
                .read(userProvider.notifier)
                .showRewardAd(
                  onComplete: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('5ポイント追加されました')),
                    );
                  },
                  onError: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('広告を再生できませんでした')),
                    );
                  },
                );
          },
          icon: const Icon(Icons.video_library),
          label: const Text('動画広告を見て 5pt 追加'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => ref
              .read(userProvider.notifier)
              .addPoints(100, type: 'test_purchase', reason: 'Test purchase'),
          icon: const Icon(Icons.shopping_bag),
          label: const Text('100pt 追加（テスト用）'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            ref.read(userProvider.notifier).refreshBalance();
            ref.read(userProvider.notifier).refreshTransactions();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('更新'),
        ),
      ],
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.state});

  final UserState state;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy/MM/dd HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ポイント履歴', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (state.transactions.isEmpty)
          const Text('履歴はまだありません')
        else
          for (final transaction in state.transactions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                transaction.amount >= 0
                    ? Icons.add_circle
                    : Icons.remove_circle,
                color: transaction.amount >= 0 ? Colors.green : Colors.red,
              ),
              title: Text(transaction.reason ?? transaction.type),
              subtitle: Text(formatter.format(transaction.createdAt)),
              trailing: Text(
                '${transaction.amount > 0 ? '+' : ''}${transaction.amount} pt',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
      ],
    );
  }
}
