import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../state/providers.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// Cek sekali saat start: sudah onboarding? Muat preferensi.
/// Juga generate recurring yang jatuh tempo (sekali per buka aplikasi).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final repo = ref.read(repositoryProvider);
    await ref.read(privacyModeProvider.notifier).load();
    await ref.read(themeModeProvider.notifier).load();
    final done = (await repo.getMeta('onboarding_done')) == '1';
    if (done) {
      final n = await repo.generateDueRecurrings(DateTime.now());
      if (n > 0) invalidateAll(ref);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => done ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(AppConfig.appName,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(AppConfig.tagline,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
