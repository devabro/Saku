import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../state/providers.dart';
import 'splash_screen.dart';

/// Root aplikasi. Nama & tema dibaca dari konstanta/provider,
/// bukan hardcode di tiap screen.
class SakuApp extends ConsumerWidget {
  const SakuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
