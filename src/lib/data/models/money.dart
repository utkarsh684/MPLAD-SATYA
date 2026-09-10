import 'json.dart';

/// Money crosses the wire as integer paise plus a server-rendered display
/// string. The client never does currency arithmetic and never reformats —
/// `display` is what the officer sees, so the app and the audit log agree.
class Money {
  final int paise;
  final String display;

  const Money({required this.paise, required this.display});

  static const zero = Money(paise: 0, display: '₹0');

  factory Money.fromJson(dynamic json) {
    if (json is Map) {
      return Money(
        paise: asInt(json['paise']),
        display: asString(json['display'], '₹0'),
      );
    }
    // Bare integer paise (eSAKSHI record fields) — format locally as a fallback.
    final paise = asInt(json);
    return Money(paise: paise, display: _fallbackFormat(paise));
  }

  static Money? fromJsonOrNull(dynamic json) =>
      json == null ? null : Money.fromJson(json);

  double get rupees => paise / 100;
  double get lakhs => paise / 10000000;

  /// Only used when the server sent a bare integer instead of a Money object.
  static String _fallbackFormat(int paise) {
    final rupees = paise / 100;
    if (rupees >= 10000000) return '₹${(rupees / 10000000).toStringAsFixed(2)} Cr';
    if (rupees >= 100000) return '₹${(rupees / 100000).toStringAsFixed(2)} L';
    return '₹${rupees.toStringAsFixed(0)}';
  }

  @override
  String toString() => display;
}
