import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Singleton SQLite.
///
/// - v1: skema awal (fase 1).
/// - v2: + tabel `debts`, `upcoming`, `title_memory`; kolom periode
///   di `budgets` (weekly/monthly/custom). Migrasi di [onUpgrade]
///   tanpa menghapus data lama.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    final db = _db;
    if (db != null) return db;
    return _db = await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'saku.db'),
      version: 2,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE wallets(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE categories(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        kind TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1
      )''');
    // v2: budget punya periode (weekly/monthly/custom) + rentang tanggal.
    await db.execute('''
      CREATE TABLE budgets(
        id TEXT PRIMARY KEY,
        categoryId TEXT NOT NULL,
        month TEXT NOT NULL,
        amountLimit INTEGER NOT NULL,
        periodType TEXT NOT NULL DEFAULT 'monthly',
        startMs INTEGER,
        endMs INTEGER,
        UNIQUE(categoryId, periodType, month, startMs)
      )''');
    await db.execute('''
      CREATE TABLE transactions(
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        categoryId TEXT,
        walletId TEXT NOT NULL,
        toWalletId TEXT,
        note TEXT NOT NULL DEFAULT '',
        date INTEGER NOT NULL,
        receiptPath TEXT,
        recurringId TEXT
      )''');
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await db.execute('''
      CREATE TABLE goals(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        targetAmount INTEGER NOT NULL,
        savedAmount INTEGER NOT NULL DEFAULT 0,
        deadline INTEGER,
        createdAt INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE recurrings(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        categoryId TEXT NOT NULL,
        walletId TEXT NOT NULL,
        frequency TEXT NOT NULL,
        nextDue INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        note TEXT NOT NULL DEFAULT ''
      )''');
    // Key-value untuk flag onboarding, metode budget, preferensi.
    await db.execute('''
      CREATE TABLE meta(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');
    // v2: utang-piutang.
    await db.execute('''
      CREATE TABLE debts(
        id TEXT PRIMARY KEY,
        personName TEXT NOT NULL,
        kind TEXT NOT NULL,
        totalAmount INTEGER NOT NULL,
        paidAmount INTEGER NOT NULL DEFAULT 0,
        dueMs INTEGER,
        walletId TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        createdAt INTEGER NOT NULL
      )''');
    await db.execute('CREATE INDEX idx_debts_due ON debts(dueMs)');
    // v2: transaksi terjadwal (belum memengaruhi saldo).
    await db.execute('''
      CREATE TABLE upcoming(
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        categoryId TEXT,
        walletId TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        dueMs INTEGER NOT NULL,
        remind INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL
      )''');
    await db.execute('CREATE INDEX idx_upcoming_due ON upcoming(dueMs)');
    // v2: memori judul -> kategori (auto-suggest kategori).
    await db.execute('''
      CREATE TABLE title_memory(
        title TEXT PRIMARY KEY,
        categoryId TEXT NOT NULL,
        updatedAt INTEGER NOT NULL
      )''');
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Budget: tambah kolom periode; rebuild tabel agar UNIQUE baru.
      await db.execute('''
        CREATE TABLE budgets_new(
          id TEXT PRIMARY KEY,
          categoryId TEXT NOT NULL,
          month TEXT NOT NULL,
          amountLimit INTEGER NOT NULL,
          periodType TEXT NOT NULL DEFAULT 'monthly',
          startMs INTEGER,
          endMs INTEGER,
          UNIQUE(categoryId, periodType, month, startMs)
        )''');
      await db.execute('''
        INSERT INTO budgets_new(id, categoryId, month, amountLimit, periodType, startMs, endMs)
        SELECT id, categoryId, month, amountLimit, 'monthly',
          CAST(strftime('%s', month || '-01') AS INTEGER) * 1000,
          CAST(strftime('%s', month || '-01', '+1 month') AS INTEGER) * 1000 - 1
        FROM budgets
      ''');
      await db.execute('DROP TABLE budgets');
      await db.execute('ALTER TABLE budgets_new RENAME TO budgets');

      await db.execute('''
        CREATE TABLE debts(
          id TEXT PRIMARY KEY,
          personName TEXT NOT NULL,
          kind TEXT NOT NULL,
          totalAmount INTEGER NOT NULL,
          paidAmount INTEGER NOT NULL DEFAULT 0,
          dueMs INTEGER,
          walletId TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          createdAt INTEGER NOT NULL
        )''');
      await db.execute('CREATE INDEX idx_debts_due ON debts(dueMs)');

      await db.execute('''
        CREATE TABLE upcoming(
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          amount INTEGER NOT NULL,
          categoryId TEXT,
          walletId TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          dueMs INTEGER NOT NULL,
          remind INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL
        )''');
      await db.execute('CREATE INDEX idx_upcoming_due ON upcoming(dueMs)');

      await db.execute('''
        CREATE TABLE title_memory(
          title TEXT PRIMARY KEY,
          categoryId TEXT NOT NULL,
          updatedAt INTEGER NOT NULL
        )''');
    }
  }

  /// Dipakai saat logout/reset — tidak dipakai di fase 1.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
