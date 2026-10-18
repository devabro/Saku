/// Dompet: bank, e-wallet, kartu kredit, paylater, tunai.
///
/// [balance] disimpan sebagai integer rupiah (tanpa desimal).
/// Untuk [WalletType.kartuKredit] dan [WalletType.paylater], balance
/// berarti JUMLAH UTANG (positif = berutang sekian).
enum WalletType {
  bank('Bank'),
  ewallet('E-Wallet'),
  kartuKredit('Kartu Kredit'),
  paylater('PayLater'),
  tunai('Tunai');

  const WalletType(this.label);
  final String label;
}

class Wallet {
  final String id;
  final String name;
  final WalletType type;
  final int balance;

  const Wallet({
    required this.id,
    required this.name,
    required this.type,
    this.balance = 0,
  });

  /// Kartu kredit & paylater dihitung sebagai utang di net worth.
  bool get isDebt =>
      type == WalletType.kartuKredit || type == WalletType.paylater;

  Wallet copyWith({String? id, String? name, WalletType? type, int? balance}) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'balance': balance,
      };

  factory Wallet.fromMap(Map<String, Object?> m) => Wallet(
        id: m['id']! as String,
        name: m['name']! as String,
        type: WalletType.values.byName(m['type']! as String),
        balance: (m['balance']! as num).toInt(),
      );
}
