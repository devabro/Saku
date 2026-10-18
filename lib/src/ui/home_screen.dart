import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/transaction.dart';
import '../state/providers.dart';
import 'budgets_screen.dart';
import 'dashboard_screen.dart';
import 'debts_screen.dart';
import 'goals_screen.dart';
import 'quick_add_sheet.dart';
import 'sample_data_actions.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';
import 'wallets_screen.dart';

/// Navigasi utama: 6 tab + FAB quick-add.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  List<Widget> _tabs() => [
        DashboardScreen(
          onAdd: () => _quickAdd(),
          onTrySample: () => installSampleData(context, ref),
        ),
        const TransactionsScreen(),
        const BudgetsScreen(),
        const GoalsScreen(),
        const WalletsScreen(),
        const DebtsScreen(),
      ];

  void _quickAdd({TransactionType? type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickAddSheet(initialType: type),
    ).then((saved) {
      if (saved == true) invalidateAll(ref);
    });
  }

  /// FAB mengikuti tab aktif: Catat / Budget / Target / Transfer / Utang.
  Widget _fab() {
    switch (_index) {
      case 2:
        return FloatingActionButton.extended(
          onPressed: () async {
            await showBudgetEditor(context, ref, null);
            invalidateAll(ref);
          },
          icon: const Icon(Icons.add),
          label: const Text('Budget'),
        );
      case 3:
        return FloatingActionButton.extended(
          onPressed: () async {
            await showGoalEditor(context, ref, null);
            invalidateAll(ref);
          },
          icon: const Icon(Icons.add),
          label: const Text('Target'),
        );
      case 4:
        return FloatingActionButton.extended(
          onPressed: () =>
              _quickAdd(type: TransactionType.transfer),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Transfer'),
        );
      case 5:
        return FloatingActionButton.extended(
          onPressed: () => showDebtEditor(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Utang'),
        );
      default:
        return FloatingActionButton.extended(
          onPressed: () => _quickAdd(),
          icon: const Icon(Icons.add),
          label: const Text('Catat'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final privacy = ref.watch(privacyModeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConfig.appName),
        actions: [
          IconButton(
            tooltip: privacy ? 'Tampilkan saldo' : 'Sembunyikan saldo',
            icon: Icon(privacy ? Icons.visibility_off : Icons.visibility),
            onPressed: () =>
                ref.read(privacyModeProvider.notifier).toggle(),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _tabs()),
      floatingActionButton: _fab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transaksi'),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart),
              label: 'Budget'),
          NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: 'Target'),
          NavigationDestination(
              icon: Icon(Icons.wallet_outlined),
              selectedIcon: Icon(Icons.wallet),
              label: 'Dompet'),
          NavigationDestination(
              icon: Icon(Icons.handshake_outlined),
              selectedIcon: Icon(Icons.handshake),
              label: 'Utang'),
        ],
      ),
    );
  }
}
