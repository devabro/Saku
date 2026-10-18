import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/biometric_service.dart';
import '../services/notification_service.dart';
import '../state/providers.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// Cek sekali saat start: sudah onboarding? Muat preferensi.
/// Juga generate recurring yang jatuh tempo, cek notifikasi,
/// dan minta biometrik bila kunci aktif.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String? _lockError;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final repo = ref.read(repositoryProvider);
    await ref.read(privacyModeProvider.notifier).load();
    await ref.read(themeModeProvider.notifier).load();
    await ref.read(biometricLockProvider.notifier).load();
    await ref.read(notifBudgetProvider.notifier).load();
    await ref.read(notifUpcomingProvider.notifier).load();
    await ref.read(notifDebtProvider.notifier).load();
    await ref.read(notifDailyProvider.notifier).load();
    await ref.read(sampleDataActiveProvider.notifier).load();
    final done = (await repo.getMeta('onboarding_done')) == '1';
    if (done) {
      final n = await repo.generateDueRecurrings(DateTime.now());
      if (n > 0) invalidateAll(ref);
      // Cek notifikasi (budget, terjadwal, utang) — best effort.
      try {
        await NotificationService.instance
            .checkAndNotify(repo, DateTime.now());
      } catch (_) {
        // Notifikasi gagal = tidak fatal.
      }
      // Kunci biometrik sebelum masuk.
      if (ref.read(biometricLockProvider)) {
        final ok = await BiometricService.instance.authenticate();
        if (!ok) {
          if (mounted) {
            setState(() => _lockError =
                'Autentikasi gagal. Ketuk tombol di bawah untuk coba lagi.');
          }
          return;
        }
      }
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
            if (_lockError != null) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(_lockError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text('Coba lagi'),
                onPressed: () {
                  setState(() => _lockError = null);
                  _boot();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
