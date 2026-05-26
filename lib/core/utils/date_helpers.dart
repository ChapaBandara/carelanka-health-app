import 'package:intl/intl.dart';

class DateHelpers {
  static String formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);
  static String formatDmySlashes(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
  static String formatDateTime(DateTime date) => DateFormat('dd MMM yyyy, hh:mm a').format(date);
  static String formatTime(DateTime time) => DateFormat('h:mm a').format(time);
}
