import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Singleton SQLite. Skema v1 — migrasi ditambah di [onUpgrade]
/// saat fase berikutnya butuh kolom/tabel baru.
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
      version: 1,
      onCreate: _create,
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
    await db.execute('''
      CREATE TABLE budgets(
        id TEXT PRIMARY KEY,
        categoryId TEXT NOT NULL,
        month TEXT NOT NULL,
        amountLimit INTEGER NOT NULL,
        UNIQUE(categoryId, month)
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
  }

  /// Dipakai saat logout/reset — tidak dipakai di fase 1.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
