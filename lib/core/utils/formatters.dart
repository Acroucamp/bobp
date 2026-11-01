import 'package:intl/intl.dart';

class Fmt {
  static final _dateTime = DateFormat('EEE d MMM, HH:mm');
  static final _date = DateFormat('EEE d MMM yyyy');
  static final _time = DateFormat('HH:mm');

  static String dateTime(DateTime d) => _dateTime.format(d.toLocal());
  static String date(DateTime d) => _date.format(d.toLocal());
  static String time(DateTime d) => _time.format(d.toLocal());

  /// yyyy-MM-dd for passing a calendar day to the database.
  static String isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
}
