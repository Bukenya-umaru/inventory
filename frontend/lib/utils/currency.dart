import 'package:intl/intl.dart';

class Currency {
  static final _whole = NumberFormat.currency(
    locale: 'en_UG',
    symbol: 'UGX ',
    decimalDigits: 0,
  );

  static final _withDecimals = NumberFormat.currency(
    locale: 'en_UG',
    symbol: 'UGX ',
    decimalDigits: 2,
  );

  /// Format as "UGX 50,000" (no decimals) – good for large amounts / headers.
  static String formatWhole(num amount) => _whole.format(amount);

  /// Format as "UGX 50,000.00" (2 decimals) – good for unit prices.
  static String format(num amount) => _withDecimals.format(amount);
}
