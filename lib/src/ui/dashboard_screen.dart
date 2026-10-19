import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../logic/health_score.dart';
import '../logic/insight_engine.dart';
import '../logic/money.dart';
import '../logic/streak.dart';
import '../logic/totals.dart';
import '../logic/weekly_report.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../state/providers.dart';
import 'widgets/glass.dart';
import 'widgets/masked_amount.dart';

/// Beranda: sapaan hangat, ringkasan bulan, streak, laporan mingguan,
/// health score, donut kategori, tren, perbandingan, insight,
/// dan tombol "Tanya Kuncung".
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.onAdd, this.onTrySample});

  /// Dipanggil saat pengguna menekan CTA "catat" dari empty state.
  final VoidCallback? onAdd;

  /// Dipanggil saat pengguna memilih "coba data contoh" dari empty state.
  final VoidCallback? onTrySample;

  String _prevMonth(String month) {
    final d = monthStart(month);
    return monthKey(DateTime(d.year, d.month - 1));
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(activeMonthProvider);
    final txs = ref.watch(transactionsProvider(month));

    return ListView(
      children: [
        txs.when(
          data: (list) => _heroCard(context, ref, list, month),
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(e.toString()),
        ),
        ref.watch(weeklyReportProvider).when(
              data: (r) => _weeklyCard(context, r),
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),
        ref.watch(healthProvider(month)).when(
              data: (h) => _healthCard(context, h),
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(e.toString()),
            ),
        txs.when(
          data: (list) => ref.watch(categoriesProvider).when(
                data: (cats) =>
                    _donutCard(context, list, cats),
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(e.toString()),
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
          data: (list) => ref
              .watch(transactionsProvider(_prevMonth(month)))
              .when(
                data: (prev) => _compareCard(context, list, prev),
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(e.toString()),
              ),
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(e.toString()),
        ),
        ref.watch(insightsProvider(month)).when(
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

  // ============ HERO: sapaan + ringkasan bulan + streak ============

  Widget _heroCard(BuildContext context, WidgetRef ref,
      List<SakuTransaction> txs, String month) {
    final scheme = Theme.of(context).colorScheme;
    final t = totalsExcludingTransfers(txs);
    final net = t.income - t.expense;
    final netColor = net >= 0 ? const Color(0xFF4C8C6B) : scheme.error;

    return GlassHeroPanel(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hai, cantik!',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('${_greeting()}! Yuk cek uangmu.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: scheme.onPrimaryContainer
                                      .withValues(alpha: 0.75))),
                    ],
                  ),
                ),
                _monthNav(context, ref, month, scheme),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                    child: _heroStat(
                        context, 'Pemasukan', t.income, const Color(0xFF4C8C6B))),
                const SizedBox(width: 12),
                Expanded(
                    child: _heroStat(context, 'Pengeluaran', t.expense,
                        scheme.onPrimaryContainer)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text('Sisa bulan ini',
                      style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  MaskedAmount(net,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: netColor)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ref.watch(streakProvider).when(
                  data: (s) => _streakChip(context, s),
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                ),
          ],
        ),
      ),
    );
  }

  Widget _monthNav(BuildContext context, WidgetRef ref, String month,
      ColorScheme scheme) {
    Widget btn(IconData icon, VoidCallback onTap) => IconButton(
          icon: Icon(icon, size: 20),
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: scheme.surface.withValues(alpha: 0.6),
            minimumSize: const Size(36, 36),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.chevron_left,
            () => ref.read(activeMonthProvider.notifier).state = _prevMonth(month)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(monthLabel(month),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        btn(Icons.chevron_right, () {
          final d = monthStart(month);
          ref.read(activeMonthProvider.notifier).state =
              monthKey(DateTime(d.year, d.month + 1));
        }),
      ],
    );
  }

  Widget _heroStat(
      BuildContext context, String label, int amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer
                    .withValues(alpha: 0.7))),
        const SizedBox(height: 2),
        MaskedAmount(amount,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _streakChip(BuildContext context, int streak) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: anim,
        child: child,
      ),
      child: Container(
        key: ValueKey(streak),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8934A).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.whatshot,
                color: Color(0xFFE8934A), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    streak > 0
                        ? '$streak hari beruntun!'
                        : 'Mulai streak-mu hari ini',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    Streak.message(streak),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ LAPORAN MINGGUAN ============

  Widget _weeklyCard(BuildContext context, WeeklyReport r) {
    final scheme = Theme.of(context).colorScheme;
    final IconData icon;
    final Color tint;
    if (r.thisWeek == 0 && r.lastWeek == 0) {
      icon = Icons.self_improvement_outlined;
      tint = scheme.secondary;
    } else if (r.down || r.flat) {
      icon = Icons.trending_down_rounded;
      tint = const Color(0xFF4C8C6B);
    } else {
      icon = Icons.trending_up_rounded;
      tint = const Color(0xFFC4707F);
    }
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: tint, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Minggu ini',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(r.narrative,
                      style:
                          Theme.of(context).textTheme.bodyMedium),
                  if (r.lastWeek > 0) ...[
                    const SizedBox(height: 6),
                    Text('Minggu lalu: ${formatIdrShort(r.lastWeek)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: scheme.onSurface
                                    .withValues(alpha: 0.6))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ HEALTH SCORE ============

  Widget _healthCard(BuildContext context, HealthResult h) {
    final scheme = Theme.of(context).colorScheme;
    final color = h.score >= 60
        ? const Color(0xFF4C8C6B)
        : h.score >= 40
            ? const Color(0xFFE8934A)
            : scheme.error;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: CircularProgressIndicator(
                      value: h.score / 100,
                      strokeWidth: 11,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor:
                          scheme.surfaceContainerHighest,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${h.score}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w800)),
                      Text('skor',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Financial Health',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(HealthScore.grade(h.score),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _meter(context, 'Budget', h.budgetAdherence),
                  _meter(context, 'Nabung', h.savingsRate),
                  _meter(context, 'Stabil', h.stability),
                  _meter(context, 'Target', h.goalProgress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meter(BuildContext context, String label, double v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 52,
              child: Text(label,
                  style: Theme.of(context).textTheme.labelSmall)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: v.clamp(0.0, 1.0),
                minHeight: 7,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
              width: 36,
              child: Text('${(v * 100).round()}%',
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  // ============ DONUT KATEGORI ============

  Widget _donutCard(BuildContext context, List<SakuTransaction> txs,
      List<Category> categories) {
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

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ke mana uangmu pergi',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Column(
                children: [
                  _emptyState(
                    context,
                    icon: Icons.pie_chart_outline_rounded,
                    text:
                        'Belum ada pengeluaran bulan ini.\nYuk catat yang pertama!',
                    ctaLabel: 'Catat pengeluaran',
                  ),
                  if (onTrySample != null)
                    TextButton(
                      onPressed: onTrySample,
                      child: const Text(
                          'atau coba dengan data contoh dulu'),
                    ),
                ],
              )
            else ...[
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      duration: const Duration(milliseconds: 700),
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 58,
                        sections: _donutSections(
                            context, entries, total, colors),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall),
                        MaskedAmount(total,
                            short: true,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final e in entries.take(5))
                _legendRow(
                    context,
                    colors[e.key] ??
                        Theme.of(context).colorScheme.primary,
                    names[e.key] ?? e.key,
                    e.value,
                    total),
              if (entries.length > 5)
                _legendRow(
                    context,
                    Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    'Lainnya',
                    entries
                        .skip(5)
                        .fold(0, (a, e) => a + e.value),
                    total),
            ],
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _donutSections(
      BuildContext context,
      List<MapEntry<String, int>> entries,
      int total,
      Map<String, Color> colors) {
    final top = entries.take(5).toList();
    final rest =
        entries.skip(5).fold(0, (a, e) => a + e.value);
    final sections = <PieChartSectionData>[];
    for (final e in top) {
      sections.add(PieChartSectionData(
        value: e.value.toDouble(),
        color: colors[e.key] ??
            Theme.of(context).colorScheme.primary,
        radius: 30,
        showTitle: false,
      ));
    }
    if (rest > 0) {
      sections.add(PieChartSectionData(
        value: rest.toDouble(),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        radius: 30,
        showTitle: false,
      ));
    }
    return sections;
  }

  Widget _legendRow(BuildContext context, Color dot, String name,
      int amount, int total) {
    final pct = total == 0 ? 0 : (amount / total * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name)),
          Text('$pct%',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6))),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: MaskedAmount(amount,
                short: true, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ============ EMPTY STATE ============

  Widget _emptyState(BuildContext context,
      {required IconData icon,
      required String text,
      required String ctaLabel}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: scheme.primary),
          ),
          const SizedBox(height: 14),
          Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(ctaLabel),
          ),
        ],
      ),
    );
  }

  // ============ TREN ============

  Widget _trendCard(
      BuildContext context, List<SakuTransaction> txs, String month) {
    final start = monthStart(month);
    final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
    final perDay = <int, int>{};
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      perDay[t.date.day] = (perDay[t.date.day] ?? 0) + t.amount;
    }
    var acc = 0;
    final spots = <FlSpot>[];
    for (var d = 1; d <= daysInMonth; d++) {
      acc += perDay[d] ?? 0;
      spots.add(FlSpot(d.toDouble(), acc.toDouble()));
    }
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tren belanja',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            MaskedAmount(acc,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text('total bulan ini',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                      show: true, drawVerticalLine: false),
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

  // ============ VS BULAN LALU ============

  Widget _compareCard(BuildContext context, List<SakuTransaction> now,
      List<SakuTransaction> prev) {
    final t = totalsExcludingTransfers(now);
    final p = totalsExcludingTransfers(prev);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bulan lalu vs sekarang',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _compareRow(context, 'Pengeluaran', t.expense, p.expense),
            _compareRow(context, 'Pemasukan', t.income, p.income),
            _compareRow(context, 'Sisa', t.net, p.net, goodWhenUp: true),
          ],
        ),
      ),
    );
  }

  Widget _compareRow(BuildContext context, String label, int now,
      int prev, {bool goodWhenUp = false}) {
    final diff = now - prev;
    final up = diff > 0;
    final good = goodWhenUp ? up : !up;
    final color = diff == 0
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
        : good
            ? const Color(0xFF4C8C6B)
            : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          MaskedAmount(now, short: true),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  diff == 0
                      ? Icons.remove_rounded
                      : up
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                  size: 16,
                  color: color,
                ),
                Flexible(
                  child: Text(
                    diff == 0
                        ? 'sama aja'
                        : formatIdrShort(diff.abs()),
                    style: TextStyle(color: color, fontSize: 13),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ INSIGHT ============

  Widget _insightsCard(
      BuildContext context, List<Insight> insights) {
    Color colorFor(InsightSeverity s) {
      switch (s) {
        case InsightSeverity.good:
          return const Color(0xFF4C8C6B);
        case InsightSeverity.warning:
          return const Color(0xFFE8934A);
        case InsightSeverity.danger:
          return Theme.of(context).colorScheme.error;
        case InsightSeverity.info:
          return Theme.of(context).colorScheme.primary;
      }
    }

    IconData iconFor(InsightSeverity s) {
      switch (s) {
        case InsightSeverity.good:
          return Icons.check_circle_outline_rounded;
        case InsightSeverity.warning:
          return Icons.warning_amber_rounded;
        case InsightSeverity.danger:
          return Icons.error_outline_rounded;
        case InsightSeverity.info:
          return Icons.info_outline_rounded;
      }
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catatan buat kamu',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (insights.isEmpty)
              _emptyState(
                context,
                icon: Icons.lightbulb_outline_rounded,
                text:
                    'Belum cukup data buat kasih catatan.\nCatat beberapa transaksi dulu, yuk!',
                ctaLabel: 'Catat transaksi',
              )
            else
              for (final ins in insights)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(iconFor(ins.severity),
                      color: colorFor(ins.severity)),
                  title: Text(ins.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(ins.body),
                ),
          ],
        ),
      ),
    );
  }

  // ============ TANYA KUNCUNG ============

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
                        Clipboard.setData(
                            ClipboardData(text: summary));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Ringkasan disalin.')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Salin'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => SharePlus.instance
                          .share(ShareParams(text: summary)),
                      icon: const Icon(Icons.share_rounded),
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
    return const GlassCard(
      padding: EdgeInsets.zero,
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
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat: $message'),
      ),
    );
  }
}
