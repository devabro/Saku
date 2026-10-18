import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../logic/health_score.dart';
import '../logic/insight_engine.dart';
import '../logic/money.dart';
import '../logic/totals.dart';
import '../models/transaction.dart';
import '../state/providers.dart';
import 'widgets/masked_amount.dart';

/// Beranda: health score, net worth, tren, breakdown kategori,
/// perbandingan bulan, insight, dan tombol "Tanya Kuncung".
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _prevMonth(String month) {
    final d = monthStart(month);
    return monthKey(DateTime(d.year, d.month - 1));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(activeMonthProvider);
    final health = ref.watch(healthProvider(month));
    final insights = ref.watch(insightsProvider(month));
    final txs = ref.watch(transactionsProvider(month));
    final prevTxs = ref.watch(transactionsProvider(_prevMonth(month)));
    final netWorth = ref.watch(netWorthProvider);
    final categories = ref.watch(categoriesProvider);

    return ListView(
      children: [
        _monthSwitcher(context, ref, month),
        health.when(
          data: (h) => _healthCard(context, h),
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(e.toString()),
        ),
        netWorth.when(
          data: (nw) => Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Total kekayaan bersih'),
              subtitle: const Text('Aset − utang (kartu kredit & paylater)'),
              trailing: MaskedAmount(nw,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(e.toString()),
        ),
        txs.when(
          data: (list) => _trendCard(context, list, month),
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(e.toString()),
        ),
        txs.when(
          data: (list) => categories.when(
            data: (cats) => _breakdownCard(context, list, cats),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(e.toString()),
          ),
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(e.toString()),
        ),
        txs.when(
          data: (list) => prevTxs.when(
            data: (prev) => _compareCard(context, list, prev, month),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(e.toString()),
          ),
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(e.toString()),
        ),
        insights.when(
          data: (list) => _insightsCard(context, list),
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(e.toString()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: FilledButton.icon(
            onPressed: () => _askKuncung(context, ref, month),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Tanya Kuncung'),
          ),
        ),
      ],
    );
  }

  Widget _monthSwitcher(BuildContext context, WidgetRef ref, String month) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(activeMonthProvider.notifier).state =
                _prevMonth(month),
          ),
          Text(monthLabel(month),
              style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final d = monthStart(month);
              ref.read(activeMonthProvider.notifier).state =
                  monthKey(DateTime(d.year, d.month + 1));
            },
          ),
        ],
      ),
    );
  }

  Widget _healthCard(BuildContext context, HealthResult h) {
    final scheme = Theme.of(context).colorScheme;
    final color = h.score >= 60
        ? Colors.green
        : h.score >= 40
            ? Colors.orange
            : Colors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: h.score / 100,
                    strokeWidth: 10,
                    color: color,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${h.score}',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const Text('skor', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Financial Health',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(HealthScore.grade(h.score),
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _meter('Budget', h.budgetAdherence),
                  _meter('Nabung', h.savingsRate),
                  _meter('Stabil', h.stability),
                  _meter('Target', h.goalProgress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meter(String label, double v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: LinearProgressIndicator(
              value: v.clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
              width: 34,
              child: Text('${(v * 100).round()}%',
                  style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _trendCard(
      BuildContext context, List<SakuTransaction> txs, String month) {
    final start = monthStart(month);
    final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
    final perDay = <int, int>{};
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      perDay[t.date.day] = (perDay[t.date.day] ?? 0) + t.amount;
    }
    // Kumulatif biar tren kebaca: garis naik = makin banyak belanja.
    var acc = 0;
    final spots = <FlSpot>[];
    for (var d = 1; d <= daysInMonth; d++) {
      acc += perDay[d] ?? 0;
      spots.add(FlSpot(d.toDouble(), acc.toDouble()));
    }
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tren belanja (kumulatif)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Total bulan ini: ${formatIdr(acc)}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData:
                      const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: scheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: scheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownCard(BuildContext context, List<SakuTransaction> txs,
      List categories) {
    final spent = <String, int>{};
    for (final t in txs) {
      if (t.type == TransactionType.expense && t.categoryId != null) {
        spent[t.categoryId!] = (spent[t.categoryId!] ?? 0) + t.amount;
      }
    }
    final total = spent.values.fold(0, (a, b) => a + b);
    final entries = spent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final names = {for (final c in categories) c.id: c.name};
    final colors = {for (final c in categories) c.id: c.color};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ke mana uangmu pergi',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('Belum ada pengeluaran bulan ini.')
            else
              for (final e in entries.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(names[e.key] ?? e.key,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Expanded(
                        flex: 4,
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : e.value / total,
                          color: colors[e.key],
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 88,
                        child: Text(formatIdrShort(e.value),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _compareCard(BuildContext context, List<SakuTransaction> now,
      List<SakuTransaction> prev, String month) {
    final t = totalsExcludingTransfers(now);
    final p = totalsExcludingTransfers(prev);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('vs bulan lalu',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _compareRow('Pengeluaran', t.expense, p.expense),
            _compareRow('Pemasukan', t.income, p.income),
            _compareRow('Sisa', t.net, p.net, goodWhenUp: true),
          ],
        ),
      ),
    );
  }

  Widget _compareRow(String label, int now, int prev,
      {bool goodWhenUp = false}) {
    final diff = now - prev;
    final up = diff > 0;
    final good = goodWhenUp ? up : !up;
    final color = diff == 0
        ? Colors.grey
        : good
            ? Colors.green
            : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(formatIdrShort(now)),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              diff == 0
                  ? 'sama'
                  : '${up ? '▲' : '▼'} ${formatIdrShort(diff.abs())}',
              style: TextStyle(color: color, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightsCard(BuildContext context, List<Insight> insights) {
    Color colorFor(InsightSeverity s) {
      switch (s) {
        case InsightSeverity.good:
          return Colors.green;
        case InsightSeverity.warning:
          return Colors.orange;
        case InsightSeverity.danger:
          return Colors.red;
        case InsightSeverity.info:
          return Colors.blue;
      }
    }

    IconData iconFor(InsightSeverity s) {
      switch (s) {
        case InsightSeverity.good:
          return Icons.check_circle_outline;
        case InsightSeverity.warning:
          return Icons.warning_amber_outlined;
        case InsightSeverity.danger:
          return Icons.error_outline;
        case InsightSeverity.info:
          return Icons.info_outline;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Insight bulan ini',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (insights.isEmpty)
              const Text('Belum cukup data. Catat beberapa transaksi dulu.')
            else
              for (final ins in insights)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(iconFor(ins.severity),
                      color: colorFor(ins.severity)),
                  title: Text(ins.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(ins.body),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _askKuncung(
      BuildContext context, WidgetRef ref, String month) async {
    final repo = ref.read(repositoryProvider);
    final inputs = await repo.insightInputs(month, DateTime.now());
    final health = await repo.healthInputs(month);
    final score = HealthScore.compute(health).score;
    final insights = InsightEngine.analyze(inputs);
    final summary = InsightEngine.buildKuncungSummary(
      appName: AppConfig.appName,
      monthLabel: monthLabel(month),
      healthScore: score,
      income: inputs.incomeThisMonth,
      expense: inputs.expenseThisMonth,
      spentByCategory: inputs.spentByCategoryThisMonth,
      categoryNames: inputs.categoryNames,
      budgetLimits: inputs.budgetLimits,
      insights: insights,
    );
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tanya Kuncung',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text(
                  'Salin atau bagikan ringkasan ini ke Kuncung buat dapat saran personal.'),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  child: SelectableText(summary),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: summary));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Ringkasan disalin.')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Salin'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => SharePlus.instance
                          .share(ShareParams(text: summary)),
                      icon: const Icon(Icons.share),
                      label: const Text('Bagikan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat: $message'),
      ),
    );
  }
}
