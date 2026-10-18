import 'package:sqflite/sqflite.dart';

import '../logic/health_score.dart';
import '../logic/insight_engine.dart';
import '../logic/money.dart';
import '../logic/totals.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/goal.dart';
import '../models/recurring.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import 'app_database.dart';
import 'repository.dart';

/// Implementasi [Repository] berbasis SQLite lokal. Nol network.
class LocalRepository implements Repository {
  LocalRepository(this._db);
  final AppDatabase _db;

  // ============ Dompet ============

  @override
  Future<List<Wallet>> getWallets() async {
    final db = await _db.database;
    final rows = await db.query('wallets', orderBy: 'name');
    return rows.map(Wallet.fromMap).toList();
  }

  @override
  Future<void> saveWallet(Wallet wallet) async {
    final db = await _db.database;
    await db.insert('wallets', wallet.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteWallet(String id) async {
    final db = await _db.database;
    await db.delete('wallets', where: 'id = ?', whereArgs: [id]);
  }

  // ============ Kategori ============

  @override
  Future<List<Category>> getCategories({CategoryKind? kind}) async {
    final db = await _db.database;
    final rows = await db.query(
      'categories',
      where: kind == null ? null : 'kind = ?',
      whereArgs: kind == null ? null : [kind.name],
      orderBy: 'name',
    );
    return rows.map(Category.fromMap).toList();
  }

  @override
  Future<void> saveCategory(Category category) async {
    final db = await _db.database;
    await db.insert('categories', category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ============ Budget ============

  @override
  Future<List<Budget>> getBudgets(String month) async {
    final db = await _db.database;
    final rows = await db.query('budgets', where: 'month = ?', whereArgs: [month]);
    return rows.map(Budget.fromMap).toList();
  }

  @override
  Future<void> saveBudget(Budget budget) async {
    final db = await _db.database;
    await db.insert('budgets', budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> ensureBudgetsForMonth(String month) async {
    final existing = await getBudgets(month);
    if (existing.isNotEmpty) return;

    final method = await getMeta('budget_method') ?? 'percentage';
    final categories = await getCategories(kind: CategoryKind.expense);
    final enabled = categories.where((c) => c.enabled).toList();
    if (enabled.isEmpty) return;

    if (method == 'percentage') {
      final income = int.tryParse(await getMeta('monthly_income') ?? '0') ?? 0;
      final needs = double.tryParse(await getMeta('pct_needs') ?? '50') ?? 50;
      final wants = double.tryParse(await getMeta('pct_wants') ?? '30') ?? 30;
      final savings = double.tryParse(await getMeta('pct_savings') ?? '20') ?? 20;
      // Kelompok kasar: kebutuhan vs keinginan berdasarkan kategori.
      const needsIds = {'cat_makan', 'cat_transport', 'cat_tagihan', 'cat_kesehatan', 'cat_pendidikan'};
      final needsCats = enabled.where((c) => needsIds.contains(c.id)).toList();
      final wantsCats = enabled.where((c) => !needsIds.contains(c.id) && c.id != 'cat_tabungan').toList();
      final saveCats = enabled.where((c) => c.id == 'cat_tabungan').toList();
      await _distribute(month, needsCats, (income * needs / 100).round());
      await _distribute(month, wantsCats, (income * wants / 100).round());
      await _distribute(month, saveCats, (income * savings / 100).round());
    } else {
      // fixed: pakai nominal per kategori dari onboarding (meta fixed_<catId>).
      for (final c in enabled) {
        final raw = await getMeta('fixed_${c.id}');
        final limit = int.tryParse(raw ?? '0') ?? 0;
        if (limit > 0) {
          await saveBudget(Budget(
            id: newId(),
            categoryId: c.id,
            month: month,
            limit: limit,
          ));
        }
      }
    }
  }

  Future<void> _distribute(String month, List<Category> cats, int total) async {
    if (cats.isEmpty || total <= 0) return;
    final each = total ~/ cats.length;
    var rest = total - each * cats.length;
    for (final c in cats) {
      final share = each + (rest > 0 ? 1 : 0);
      if (rest > 0) rest--;
      await saveBudget(Budget(
        id: newId(),
        categoryId: c.id,
        month: month,
        limit: share,
      ));
    }
  }

  // ============ Transaksi ============

  @override
  Future<List<SakuTransaction>> getTransactions({DateTime? from, DateTime? to}) async {
    final db = await _db.database;
    String? where;
    final args = <Object>[];
    if (from != null) {
      where = 'date >= ?';
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where = where == null ? 'date <= ?' : '$where AND date <= ?';
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await db.query('transactions',
        where: where, whereArgs: args.isEmpty ? null : args, orderBy: 'date DESC');
    return rows.map(SakuTransaction.fromMap).toList();
  }

  @override
  Future<List<SakuTransaction>> getTransactionsForMonth(String month) async {
    final start = monthStart(month);
    final end = DateTime(start.year, start.month + 1);
    return getTransactions(from: start, to: end.subtract(const Duration(milliseconds: 1)));
  }

  @override
  Future<void> saveTransaction(SakuTransaction tx) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      // Jika ini edit (id sudah ada), reverse dulu efek lama.
      final old = await txn.query('transactions', where: 'id = ?', whereArgs: [tx.id]);
      if (old.isNotEmpty) {
        await _reverseBalances(txn, SakuTransaction.fromMap(old.first));
      }
      await txn.insert('transactions', tx.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _applyBalances(txn, tx, 1);
    });
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final rows = await txn.query('transactions', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      await _reverseBalances(txn, SakuTransaction.fromMap(rows.first));
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Terapkan efek saldo. [sign]=+1 saat simpan, dipakai bersama
  /// [_reverseBalances] untuk hapus/edit.
  Future<void> _applyBalances(Transaction txn, SakuTransaction tx, int sign) async {
    switch (tx.type) {
      case TransactionType.expense:
        await _bump(txn, tx.walletId, tx.amount, true, sign);
      case TransactionType.income:
        await _bump(txn, tx.walletId, tx.amount, false, sign);
      case TransactionType.transfer:
        await _bump(txn, tx.walletId, tx.amount, true, sign);
        await _bump(txn, tx.toWalletId!, tx.amount, false, sign);
    }
  }

  Future<void> _reverseBalances(Transaction txn, SakuTransaction tx) =>
      _applyBalances(txn, tx, -1);

  /// [isOut]=true berarti uang "keluar" dari dompet (pengeluaran / sumber transfer).
  /// Dompet utang (kartu kredit/paylater) bergerak terbalik: pengeluaran
  /// MENAMBAH utang, pemasukan MENGURANGI utang.
  Future<void> _bump(Transaction txn, String walletId, int amount,
      bool isOut, int sign) async {
    final rows = await txn.query('wallets', where: 'id = ?', whereArgs: [walletId]);
    if (rows.isEmpty) return;
    final w = Wallet.fromMap(rows.first);
    final dir = isOut ? -1 : 1;
    final delta = w.isDebt ? -dir * amount : dir * amount;
    await txn.update('wallets', {'balance': w.balance + sign * delta},
        where: 'id = ?', whereArgs: [walletId]);
  }

  // ============ Target ============

  @override
  Future<List<Goal>> getGoals() async {
    final db = await _db.database;
    final rows = await db.query('goals', orderBy: 'createdAt');
    return rows.map(Goal.fromMap).toList();
  }

  @override
  Future<void> saveGoal(Goal goal) async {
    final db = await _db.database;
    await db.insert('goals', goal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteGoal(String id) async {
    final db = await _db.database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  // ============ Rutin ============

  @override
  Future<List<Recurring>> getRecurrings() async {
    final db = await _db.database;
    final rows = await db.query('recurrings', orderBy: 'nextDue');
    return rows.map(Recurring.fromMap).toList();
  }

  @override
  Future<void> saveRecurring(Recurring recurring) async {
    final db = await _db.database;
    await db.insert('recurrings', recurring.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteRecurring(String id) async {
    final db = await _db.database;
    await db.delete('recurrings', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> generateDueRecurrings(DateTime now) async {
    final db = await _db.database;
    final list = await getRecurrings();
    var created = 0;
    for (final r in list) {
      if (!r.active) continue;
      var due = r.nextDue;
      var guard = 0; // pengaman: maks 36 periode tertinggal per item
      while (!due.isAfter(now) && guard < 36) {
        final tx = SakuTransaction(
          id: newId(),
          type: r.type == 'income' ? TransactionType.income : TransactionType.expense,
          amount: r.amount,
          categoryId: r.categoryId,
          walletId: r.walletId,
          note: r.name,
          date: due,
          recurringId: r.id,
        );
        await db.transaction((txn) async {
          await txn.insert('transactions', tx.toMap());
          await _applyBalances(txn, tx, 1);
        });
        created++;
        due = r.advance(due);
        guard++;
      }
      if (due != r.nextDue) {
        await saveRecurring(r.copyWith(nextDue: due));
      }
    }
    return created;
  }

  @override
  Future<void> skipRecurring(String id) async {
    final list = await getRecurrings();
    for (final r in list) {
      if (r.id == id) {
        await saveRecurring(r.copyWith(nextDue: r.advance(r.nextDue)));
        return;
      }
    }
  }

  // ============ Meta ============

  @override
  Future<String?> getMeta(String key) async {
    final db = await _db.database;
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> setMeta(String key, String value) async {
    final db = await _db.database;
    await db.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ============ Agregat ============

  @override
  Future<int> netWorth() async {
    final wallets = await getWallets();
    var total = 0;
    for (final w in wallets) {
      total += w.isDebt ? -w.balance : w.balance;
    }
    return total;
  }

  @override
  Future<HealthInputs> healthInputs(String month) async {
    final txs = await getTransactionsForMonth(month);
    final totals = totalsExcludingTransfers(txs);
    final budgets = await getBudgets(month);
    final spentByCat = <String, int>{};
    for (final t in txs) {
      if (t.type == TransactionType.expense && t.categoryId != null) {
        spentByCat[t.categoryId!] = (spentByCat[t.categoryId!] ?? 0) + t.amount;
      }
    }
    final last3 = <int>[];
    final base = monthStart(month);
    for (var i = 1; i <= 3; i++) {
      final m = monthKey(DateTime(base.year, base.month - i));
      final t = totalsExcludingTransfers(await getTransactionsForMonth(m));
      last3.add(t.expense);
    }
    final goals = await getGoals();
    return HealthInputs(
      budgetLimits: {for (final b in budgets) b.categoryId: b.limit},
      spentByCategory: spentByCat,
      incomeThisMonth: totals.income,
      expenseThisMonth: totals.expense,
      monthlyExpenses: [totals.expense, ...last3],
      goalProgress: [for (final g in goals) g.progress.clamp(0.0, 1.0)],
    );
  }

  @override
  Future<InsightInputs> insightInputs(String month, DateTime now) async {
    final txs = await getTransactionsForMonth(month);
    final totals = totalsExcludingTransfers(txs);
    final budgets = await getBudgets(month);
    final categories = await getCategories();
    final names = {for (final c in categories) c.id: c.name};

    final spentByCat = <String, int>{};
    final daily = <DateTime, int>{};
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      if (t.categoryId != null) {
        spentByCat[t.categoryId!] = (spentByCat[t.categoryId!] ?? 0) + t.amount;
      }
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      daily[day] = (daily[day] ?? 0) + t.amount;
    }

    final last3ByCat = <String, List<int>>{};
    final base = monthStart(month);
    for (var i = 1; i <= 3; i++) {
      final m = monthKey(DateTime(base.year, base.month - i));
      final past = await getTransactionsForMonth(m);
      final perCat = <String, int>{};
      for (final t in past) {
        if (t.type == TransactionType.expense && t.categoryId != null) {
          perCat[t.categoryId!] = (perCat[t.categoryId!] ?? 0) + t.amount;
        }
      }
      for (final e in perCat.entries) {
        last3ByCat.putIfAbsent(e.key, () => []).add(e.value);
      }
    }
    // Kategori yang tidak muncul di bulan lampau = histori 0.
    for (final id in spentByCat.keys) {
      last3ByCat.putIfAbsent(id, () => [0, 0, 0]);
    }

    final daysInMonth = DateTime(base.year, base.month + 1, 0).day;
    return InsightInputs(
      incomeThisMonth: totals.income,
      expenseThisMonth: totals.expense,
      spentByCategoryThisMonth: spentByCat,
      categoryNames: names,
      last3MonthsByCategory: last3ByCat,
      dayOfMonth: now.day,
      daysInMonth: daysInMonth,
      budgetLimits: {for (final b in budgets) b.categoryId: b.limit},
    );
  }
}
