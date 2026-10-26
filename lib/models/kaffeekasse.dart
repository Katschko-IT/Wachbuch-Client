class Kaffeekasse {
  const Kaffeekasse({
    required this.balance,
    required this.currency,
    this.ledger = const [],
    this.paymentHint = '',
    this.scope = '',
    this.monthlyFee = 0,
    this.own,
    this.payment,
  });

  /// Server (`GET /api/v1/kaffeekasse/`) liefert `balance_euros` und
  /// `results`; die übrigen Schlüssel bleiben als Rückfall erhalten.
  /// Seit dem Monatsbeitrag kommen `monthly_fee_euros`, `own` (eigene
  /// Monate) und `payment` (Zahlungswege) dazu – ältere Server liefern sie
  /// nicht, dann bleibt die Ansicht wie bisher.
  factory Kaffeekasse.fromJson(Map<String, dynamic> json) {
    final currency = (json['currency'] ?? 'EUR').toString();
    final rawPayment = json['payment'];
    final payment = rawPayment is Map
        ? CoffeePayment.fromJson(Map<String, dynamic>.from(rawPayment))
        : null;
    final rawOwn = json['own'];
    return Kaffeekasse(
      balance: _formatMoney(
        json['balance_euros'] ?? json['balance'] ?? json['saldo'],
        currency,
      ),
      currency: currency,
      ledger: _readLedger(
        json['results'] ?? json['ledger'] ?? json['transactions'] ?? const [],
      ),
      paymentHint: (json['payment_hint'] ??
              payment?.note ??
              (rawPayment is String ? rawPayment : ''))
          .toString()
          .trim(),
      scope: (json['scope'] ?? '').toString(),
      monthlyFee: _parseMoney(json['monthly_fee_euros']),
      own: rawOwn is Map ? CoffeeOwnStatus.fromJson(Map<String, dynamic>.from(rawOwn)) : null,
      payment: payment,
    );
  }

  final String balance;
  final String currency;
  final List<KaffeekasseEntry> ledger;
  final String paymentHint;

  /// `station` (Kassenwart: Saldo aller) oder `own` (eigene Buchungen).
  final String scope;
  final num monthlyFee;
  final CoffeeOwnStatus? own;
  final CoffeePayment? payment;

  bool get isNegative => _parseMoney(balance).isNegative;

  /// Monatsbeitrag aktiv und Person nimmt teil.
  bool get hasMonthlyFee => monthlyFee > 0 && (own?.participant ?? false);
}

/// Eigener Stand beim Monatsbeitrag (`own`).
class CoffeeOwnStatus {
  const CoffeeOwnStatus({
    required this.participant,
    required this.openEuros,
    required this.creditEuros,
    this.months = const [],
  });

  factory CoffeeOwnStatus.fromJson(Map<String, dynamic> json) {
    final months = json['months'];
    return CoffeeOwnStatus(
      participant: json['participant'] == true,
      openEuros: _parseMoney(json['open_euros']),
      creditEuros: _parseMoney(json['credit_euros']),
      months: months is List
          ? months
              .whereType<Map>()
              .map((m) => CoffeeMonth.fromJson(Map<String, dynamic>.from(m)))
              .toList(growable: false)
          : const [],
    );
  }

  final bool participant;
  final num openEuros;
  final num creditEuros;

  /// Neuester Monat zuerst.
  final List<CoffeeMonth> months;

  String get formattedOpen => _formatMoney(openEuros, 'EUR');
  String get formattedCredit => _formatMoney(creditEuros, 'EUR');
}

class CoffeeMonth {
  const CoffeeMonth({required this.month, required this.status, this.openEuros = 0});

  factory CoffeeMonth.fromJson(Map<String, dynamic> json) {
    final raw = (json['month'] ?? '').toString();
    final parts = raw.split('-');
    final year = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return CoffeeMonth(
      month: year != null && month != null ? DateTime(year, month) : null,
      status: (json['status'] ?? '').toString(),
      openEuros: _parseMoney(json['open_euros']),
    );
  }

  final DateTime? month;

  /// `paid`, `open` oder `waived`.
  final String status;
  final num openEuros;

  String get formattedOpen => _formatMoney(openEuros, 'EUR');
}

/// Zahlungswege der Wache (`payment`).
class CoffeePayment {
  const CoffeePayment({
    this.methods = const ['cash'],
    this.suggestedEuros = 0,
    this.iban = '',
    this.bic = '',
    this.accountHolder = '',
    this.transferText = '',
    this.paypalUrl = '',
    this.weroUrl = '',
    this.note = '',
  });

  factory CoffeePayment.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] ?? '').toString().trim();
    final methods = json['methods'];
    return CoffeePayment(
      methods: methods is List && methods.isNotEmpty
          ? methods.map((m) => m.toString()).toList(growable: false)
          : const ['cash'],
      suggestedEuros: _parseMoney(json['suggested_euros']),
      iban: text('iban'),
      bic: text('bic'),
      accountHolder: text('account_holder'),
      transferText: text('transfer_text'),
      paypalUrl: _httpsOnly(text('paypal_me_url')),
      weroUrl: _httpsOnly(text('wero_link')),
      note: text('note'),
    );
  }

  final List<String> methods;
  final num suggestedEuros;
  final String iban;
  final String bic;
  final String accountHolder;
  final String transferText;
  final String paypalUrl;
  final String weroUrl;
  final String note;

  /// IBAN in Vierergruppen zum Lesen.
  String get formattedIban => iban
      .replaceAllMapped(RegExp(r'.{1,4}'), (m) => '${m[0]} ')
      .trim();
}

/// Nur https-Links öffnen (Zahlungslinks kommen vom Server, nicht vom Nutzer).
String _httpsOnly(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty ? url : '';
}

class KaffeekasseEntry {
  const KaffeekasseEntry({
    required this.id,
    required this.amount,
    this.description = '',
    this.userName = '',
    this.createdAt,
  });

  factory KaffeekasseEntry.fromJson(Map<String, dynamic> json) {
    return KaffeekasseEntry(
      id: _readInt(json['id']),
      amount: _parseMoney(json['amount_euros'] ?? json['amount'] ?? json['value']),
      description:
          (json['reason'] ?? json['description'] ?? json['memo'] ?? '')
              .toString()
              .trim(),
      userName: _readUser(json['user'] ?? json['member']),
      createdAt: _readDate(json['created_at'] ?? json['date']),
    );
  }

  final int id;
  final num amount;
  final String description;
  final String userName;
  final DateTime? createdAt;

  bool get isNegative => amount < 0;

  String get formattedAmount => _formatSignedMoney(amount);
}

List<KaffeekasseEntry> _readLedger(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((entry) => KaffeekasseEntry.fromJson(Map<String, dynamic>.from(entry)))
      .toList(growable: false);
}

String _readUser(Object? value) {
  if (value is Map) {
    return (value['display_name'] ?? value['name'] ?? '').toString().trim();
  }
  return value?.toString().trim() ?? '';
}

num _parseMoney(Object? value) {
  if (value is num) return value;
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return 0;
  var cleaned = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  final hasComma = cleaned.contains(',');
  final hasDot = cleaned.contains('.');
  if (hasComma && hasDot) {
    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
  } else if (hasComma) {
    cleaned = cleaned.replaceAll(',', '.');
  }
  return num.tryParse(cleaned) ?? 0;
}

String _currencySymbol(String currency) =>
    switch (currency.toUpperCase()) { 'EUR' => '€', 'USD' => r'$', _ => currency };

String _formatMoney(Object? value, String currency) {
  final amount = _parseMoney(value);
  final absolute = amount.abs().toStringAsFixed(2).replaceAll('.', ',');
  final sign = amount < 0 ? '-' : '';
  return '$sign$absolute ${_currencySymbol(currency)}';
}

String _formatSignedMoney(num amount) {
  final absolute = amount.abs().toStringAsFixed(2).replaceAll('.', ',');
  if (amount < 0) return '-$absolute €';
  if (amount > 0) return '+$absolute €';
  return '$absolute €';
}

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

int _readInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
