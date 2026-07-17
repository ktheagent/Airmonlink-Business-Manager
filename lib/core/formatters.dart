import 'package:intl/intl.dart';

class AppFormatters {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_GH',
    symbol: 'GH₵ ',
    decimalDigits: 2,
  );

  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, HH:mm');
  static final DateFormat _date = DateFormat('dd MMM yyyy');

  static String money(num value) => _currency.format(value);
  static String dateTime(DateTime value) => _dateTime.format(value);
  static String date(DateTime value) => _date.format(value);

  AppFormatters._();
}
