import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:client/main.dart';
import 'package:client/logic/auth_provider.dart';

class _Unauthenticated extends AuthNotifier {
  _Unauthenticated(super.ref);

  @override
  Future<void> checkAuthStatus() async {
    state = const AsyncValue.data(false);
  }
}

void main() {
  testWidgets('shows the login screen when there is no session', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith((ref) => _Unauthenticated(ref))],
        child: const SynceApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
