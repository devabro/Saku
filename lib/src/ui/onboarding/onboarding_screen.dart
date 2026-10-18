import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../config/seed_data.dart';
import '../../logic/money.dart';
import '../../models/category.dart';
import '../../models/goal.dart';
import '../../models/wallet.dart';
import '../../state/providers.dart';
import '../home_screen.dart';

/// Draft yang dikumpulkan selama 6 langkah wizard.
class OnboardingDraft {
  final List<Wallet> wallets = [];
  int monthlyIncome = 0;
  String budgetMethod = 'percentage'; // 'percentage' | 'fixed'
  double pctNeeds = 50;
  double pctWants = 30;
  double pctSavings = 20;
  final Map<String, int> fixedBudgets = {};
  final Set<String> enabledCategories = {
    for (final c in SeedData.expenseCategories()) c.id,
  };
  final List<Goal> goals = [];

  bool get percentagesValid =>
      (pctNeeds + pctWants + pctSavings - 100).abs() < 0.01;
}

/// Wizard 6 langkah:
/// 1 dompet → 2 penghasilan → 3 metode budget → 4 kategori →
/// 5 target (opsional) → 6 selesai.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _draft = OnboardingDraft();
  final _pager = PageController();
  int _step = 0;
  bool _saving = false;

  void _go(int step) {
    setState(() => _step = step);
    _pager.animateToPage(step,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _draft.wallets.isNotEmpty &&
            _draft.wallets.every((w) => w.name.trim().isNotEmpty);
      case 1:
        return _draft.monthlyIncome > 0;
      case 2:
        return _draft.budgetMethod == 'fixed' || _draft.percentagesValid;
      case 3:
        return _draft.enabledCategories.isNotEmpty;
      default:
        return true;
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final repo = ref.read(repositoryProvider);
    final allCats = [
      ...SeedData.expenseCategories(),
      ...SeedData.incomeCategories()
    ];
    for (final c in allCats) {
      final enabled = c.kind == CategoryKind.income ||
          _draft.enabledCategories.contains(c.id);
      await repo.saveCategory(c.copyWith(enabled: enabled));
    }
    for (final w in _draft.wallets) {
      await repo.saveWallet(w);
    }
    await repo.setMeta('monthly_income', '${_draft.monthlyIncome}');
    await repo.setMeta('budget_method', _draft.budgetMethod);
    await repo.setMeta('pct_needs', '${_draft.pctNeeds}');
    await repo.setMeta('pct_wants', '${_draft.pctWants}');
    await repo.setMeta('pct_savings', '${_draft.pctSavings}');
    for (final e in _draft.fixedBudgets.entries) {
      await repo.setMeta('fixed_${e.key}', '${e.value}');
    }
    for (final g in _draft.goals) {
      await repo.saveGoal(g);
    }
    await repo.setMeta('onboarding_done', '1');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Dompetmu apa aja?',
      'Penghasilan per bulan',
      'Cara budgeting',
      'Kategori pengeluaran',
      'Target nabung',
      'Siap jalan!',
    ];
    const subtitles = [
      'Catat semua tempat nyimpen uang. Saldo diisi manual — Saku nggak minta akses ke bank kamu, jadi aman.',
      'Gaji pokok + pemasukan rutin. Dipakai buat ngitung budget dan savings rate.',
      'Pilih cara bagi-bagi uang yang paling cocok buatmu.',
      'Matikan kategori yang nggak kamu pakai biar pencatatan sat-set.',
      'Opsional — bisa dilewati. Target bikin nabung ada tujuannya.',
      'Cek ringkasan, kalau oke langsung mulai.',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('${AppConfig.appName} • Langkah ${_step + 1}/6'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_step + 1) / 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titles[_step],
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(subtitles[_step],
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pager,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _WalletStep(
                    draft: _draft, onChanged: () => setState(() {})),
                _IncomeStep(
                    draft: _draft, onChanged: () => setState(() {})),
                _MethodStep(
                    draft: _draft, onChanged: () => setState(() {})),
                _CategoryStep(
                    draft: _draft, onChanged: () => setState(() {})),
                _GoalStep(draft: _draft, onChanged: () => setState(() {})),
                _DoneStep(draft: _draft),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => _go(_step - 1),
                      child: const Text('Kembali'),
                    ),
                  const Spacer(),
                  if (_step < 5)
                    FilledButton(
                      onPressed: _canContinue ? () => _go(_step + 1) : null,
                      child: Text(_step == 4 && _draft.goals.isEmpty
                          ? 'Lewati'
                          : 'Lanjut'),
                    )
                  else
                    FilledButton(
                      onPressed: _saving ? null : _finish,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Mulai pakai Saku'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= LANGKAH 1: dompet =================

class _WalletStep extends StatelessWidget {
  const _WalletStep({required this.draft, required this.onChanged});
  final OnboardingDraft draft;
  final VoidCallback onChanged;

  Future<void> _addWallet(BuildContext context) async {
    final name = TextEditingController();
    final balance = TextEditingController();
    var type = WalletType.bank;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Tambah dompet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration:
                    const InputDecoration(labelText: 'Nama (mis. BCA, GoPay)'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<WalletType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Jenis'),
                items: WalletType.values
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) => setS(() => type = v ?? WalletType.bank),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: balance,
                decoration: InputDecoration(
                  labelText: type == WalletType.kartuKredit ||
                          type == WalletType.paylater
                      ? 'Total tagihan saat ini (Rp)'
                      : 'Saldo awal (Rp)',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tambah')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      draft.wallets.add(Wallet(
        id: newId(),
        name: name.text.trim(),
        type: type,
        balance: parseIdrInput(balance.text),
      ));
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: draft.wallets.isEmpty
              ? const Center(
                  child: Text('Belum ada dompet.\nTambahkan minimal satu ya.',
                      textAlign: TextAlign.center))
              : ListView.builder(
                  itemCount: draft.wallets.length,
                  itemBuilder: (ctx, i) {
                    final w = draft.wallets[i];
                    return ListTile(
                      leading: Icon(_walletIcon(w.type)),
                      title: Text(w.name),
                      subtitle: Text(w.type.label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatIdr(w.balance)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              draft.wallets.removeAt(i);
                              onChanged();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => _addWallet(context),
            icon: const Icon(Icons.add),
            label: const Text('Tambah dompet'),
          ),
        ),
      ],
    );
  }
}

IconData _walletIcon(WalletType t) {
  switch (t) {
    case WalletType.bank:
      return Icons.account_balance;
    case WalletType.ewallet:
      return Icons.smartphone;
    case WalletType.kartuKredit:
      return Icons.credit_card;
    case WalletType.paylater:
      return Icons.schedule;
    case WalletType.tunai:
      return Icons.payments;
  }
}

// ================= LANGKAH 2: penghasilan =================

class _IncomeStep extends StatefulWidget {
  const _IncomeStep({required this.draft, required this.onChanged});
  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  State<_IncomeStep> createState() => _IncomeStepState();
}

class _IncomeStepState extends State<_IncomeStep> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(
        text: widget.draft.monthlyIncome > 0
            ? '${widget.draft.monthlyIncome}'
            : '');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _c,
            decoration: const InputDecoration(
              labelText: 'Penghasilan per bulan (Rp)',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
            onChanged: (v) {
              widget.draft.monthlyIncome = parseIdrInput(v);
              widget.onChanged();
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Kalau penghasilanmu nggak tetap, isi rata-rata 3 bulan terakhir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ================= LANGKAH 3: metode budget =================

class _MethodStep extends StatefulWidget {
  const _MethodStep({required this.draft, required this.onChanged});
  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  State<_MethodStep> createState() => _MethodStepState();
}

class _MethodStepState extends State<_MethodStep> {
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        RadioGroup<String>(
          groupValue: d.budgetMethod,
          onChanged: (v) {
            if (v == null) return;
            d.budgetMethod = v;
            widget.onChanged();
            setState(() {});
          },
          child: const Column(
            children: [
              RadioListTile<String>(
                title: Text('Persentase'),
                subtitle: Text(
                    'Bagi penghasilan pakai %. Klasiknya 50/30/20: kebutuhan, keinginan, nabung.'),
                value: 'percentage',
              ),
              RadioListTile<String>(
                title: Text('Nominal tetap'),
                subtitle: Text(
                    'Tentuin sendiri batas tiap kategori, mis. makan Rp2 jt.'),
                value: 'fixed',
              ),
            ],
          ),
        ),
        if (d.budgetMethod == 'percentage') ...[
          _pctField('Kebutuhan (mis. makan, transport, tagihan)', d.pctNeeds,
              (v) => d.pctNeeds = v),
          _pctField('Keinginan (mis. hiburan, belanja)', d.pctWants,
              (v) => d.pctWants = v),
          _pctField('Nabung & investasi', d.pctSavings, (v) => d.pctSavings = v),
          const SizedBox(height: 8),
          Text(
            'Total: ${(d.pctNeeds + d.pctWants + d.pctSavings).toStringAsFixed(0)}% '
            '${d.percentagesValid ? '✓ pas 100%' : '— harus 100%'}',
            style: TextStyle(
              color: d.percentagesValid ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        if (d.budgetMethod == 'fixed')
          ...SeedData.expenseCategories()
              .where((c) => d.enabledCategories.contains(c.id))
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: '${c.name} (Rp)',
                        prefixIcon: Icon(c.icon, color: c.color),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        d.fixedBudgets[c.id] = parseIdrInput(v);
                        widget.onChanged();
                      },
                    ),
                  )),
      ],
    );
  }

  Widget _pctField(String label, double value, void Function(double) set) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        decoration: InputDecoration(
          labelText: '$label (%)',
          border: const OutlineInputBorder(),
          suffixText: '%',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        controller:
            TextEditingController(text: value.toStringAsFixed(0))
              ..selection = TextSelection.collapsed(
                  offset: value.toStringAsFixed(0).length),
        onChanged: (v) {
          set(double.tryParse(v.replaceAll(',', '.')) ?? 0);
          widget.onChanged();
          setState(() {});
        },
      ),
    );
  }
}

// ================= LANGKAH 4: kategori =================

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({required this.draft, required this.onChanged});
  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cats = SeedData.expenseCategories();
    return ListView.builder(
      itemCount: cats.length,
      itemBuilder: (ctx, i) {
        final c = cats[i];
        final on = draft.enabledCategories.contains(c.id);
        return SwitchListTile(
          secondary: Icon(c.icon, color: c.color),
          title: Text(c.name),
          value: on,
          onChanged: (v) {
            if (v) {
              draft.enabledCategories.add(c.id);
            } else {
              draft.enabledCategories.remove(c.id);
            }
            onChanged();
          },
        );
      },
    );
  }
}

// ================= LANGKAH 5: target (opsional) =================

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.draft, required this.onChanged});
  final OnboardingDraft draft;
  final VoidCallback onChanged;

  Future<void> _addGoal(BuildContext context) async {
    final name = TextEditingController();
    final target = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Target nabung'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration:
                    const InputDecoration(labelText: 'Buat apa? (mis. Dana darurat)')),
            const SizedBox(height: 8),
            TextField(
              controller: target,
              decoration:
                  const InputDecoration(labelText: 'Target (Rp)', prefixText: 'Rp '),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tambah')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      draft.goals.add(Goal(
        id: newId(),
        name: name.text.trim(),
        targetAmount: parseIdrInput(target.text),
        createdAt: DateTime.now(),
      ));
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: draft.goals.isEmpty
              ? const Center(
                  child: Text('Nggak wajib.\nPencet "Lewati" kalau belum ada target.',
                      textAlign: TextAlign.center))
              : ListView.builder(
                  itemCount: draft.goals.length,
                  itemBuilder: (ctx, i) {
                    final g = draft.goals[i];
                    return ListTile(
                      leading: const Icon(Icons.flag),
                      title: Text(g.name),
                      subtitle: Text('Target ${formatIdr(g.targetAmount)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          draft.goals.removeAt(i);
                          onChanged();
                        },
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => _addGoal(context),
            icon: const Icon(Icons.add),
            label: const Text('Tambah target'),
          ),
        ),
      ],
    );
  }
}

// ================= LANGKAH 6: ringkasan =================

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.draft});
  final OnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _row('Dompet', '${draft.wallets.length} dompet'),
        _row('Penghasilan', formatIdr(draft.monthlyIncome)),
        _row('Metode budget',
            draft.budgetMethod == 'percentage'
                ? 'Persentase ${draft.pctNeeds.toStringAsFixed(0)}/'
                    '${draft.pctWants.toStringAsFixed(0)}/'
                    '${draft.pctSavings.toStringAsFixed(0)}'
                : 'Nominal tetap'),
        _row('Kategori aktif', '${draft.enabledCategories.length} kategori'),
        _row('Target nabung',
            draft.goals.isEmpty ? '—' : '${draft.goals.length} target'),
        const SizedBox(height: 16),
        Text(
          'Semua data tersimpan di HP kamu. Nggak ada yang dikirim ke mana pun.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
