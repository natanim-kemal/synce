import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'home_page.dart';
import 'pages/login_page.dart';
import 'logic/auth_provider.dart';

void main() {
  runApp(ProviderScope(child: const SynceApp()));
}

class SynceApp extends ConsumerWidget {
  const SynceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Synce',
      theme: DesignSystem.lightTheme,
      darkTheme: DesignSystem.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 0.8),
          child: child!,
        );
      },
      home: authState.when(
        data: (isAuthenticated) => isAuthenticated ? const HomePage() : const LoginPage(),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => const LoginPage(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
