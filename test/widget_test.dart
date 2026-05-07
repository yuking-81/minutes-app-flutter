import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minutes_app/main.dart';
import 'package:minutes_app/providers/user_provider.dart';
import 'package:minutes_app/services/backend_service.dart';

class FakeBackendService extends BackendService {
  @override
  Future<int> getBalance(String deviceId) async => 0;
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
}
