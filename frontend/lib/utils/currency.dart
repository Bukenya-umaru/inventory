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

  static String formatWhole(num amount) => _whole.format(amount);

  static String format(num amount) => _withDecimals.format(amount);
}