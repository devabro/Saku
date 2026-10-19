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
import 'widgets/glass.dart';

/// Navigasi utama: Liquid Glass — top bar & dock melayang di atas
/// gradien lembut. 6 tab + FAB quick-add.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  static const _dockItems = [
    DockItem(icon: Icons.dashboard_rounded, label: 'Beranda'),
    DockItem(icon: Icons.receipt_long_rounded, label: 'Transaksi'),
    DockItem(icon: Icons.pie_chart_rounded, label: 'Budget'),
    DockItem(icon: Icons.flag_rounded, label: 'Target'),
    DockItem(icon: Icons.wallet_rounded, label: 'Dompet'),
    DockItem(icon: Icons.handshake_rounded, label: 'Utang'),
  ];

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
      backgroundColor: Colors.transparent,
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
          icon: const Icon(Icons.add_rounded),
          label: const Text('Budget'),
        );
      case 3:
        return FloatingActionButton.extended(
          onPressed: () async {
            await showGoalEditor(context, ref, null);
            invalidateAll(ref);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Target'),
        );
      case 4:
        return FloatingActionButton.extended(
          onPressed: () => _quickAdd(type: TransactionType.transfer),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Transfer'),
        );
      case 5:
        return FloatingActionButton.extended(
          onPressed: () => showDebtEditor(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Utang'),
        );
      default:
        return FloatingActionButton.extended(
          onPressed: () => _quickAdd(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Catat'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final privacy = ref.watch(privacyModeProvider);
    final topPad = MediaQuery.of(context).padding.top + 60;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          const SakuBackdrop(),
          Positioned.fill(
            child: Padding(
              // Ruang untuk top bar melayang + dock melayang.
              padding: EdgeInsets.only(top: topPad, bottom: 96),
              child: IndexedStack(index: _index, children: _tabs()),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GlassTopBar(
              title: AppConfig.appName,
              actions: [
                IconButton(
                  tooltip:
                      privacy ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                  icon: Icon(privacy
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                  onPressed: () =>
                      ref.read(privacyModeProvider.notifier).toggle(),
                ),
                IconButton(
                  tooltip: 'Pengaturan',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _fab(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassDock(
            items: _dockItems,
            selected: _index,
            onTap: (i) => setState(() => _index = i),
          ),
        ),
      ),
    );
  }
}
