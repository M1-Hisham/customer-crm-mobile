import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

class DateHelper {
  static String formatDualDate(dynamic dateInput) {
    if (dateInput == null) return 'غير مجدولة';
    try {
      DateTime dt;
      if (dateInput is DateTime) {
        dt = dateInput;
      } else if (dateInput is String) {
        if (dateInput.isEmpty) return 'غير مجدولة';
        final dateOnly = dateInput.contains('T') ? dateInput.split('T')[0] : dateInput;
        final parts = dateOnly.split('-');
        if (parts.length == 3) {
          dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          dt = DateTime.parse(dateInput);
        }
      } else {
        return dateInput.toString();
      }
      
      HijriCalendar.setLocal('ar');
      var hijri = HijriCalendar.fromDate(dt);
      var hijriStr = '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} هـ';
      var gregStr = DateFormat('yyyy/MM/dd').format(dt);
      
      return '$hijriStr ($gregStr)';
    } catch (e) {
      return dateInput.toString();
    }
  }

  static String formatDualDateTime(dynamic dateInput) {
    if (dateInput == null) return 'غير مجدولة';
    try {
      DateTime dt;
      if (dateInput is DateTime) {
        dt = dateInput;
      } else if (dateInput is String) {
        if (dateInput.isEmpty) return 'غير مجدولة';
        dt = DateTime.parse(dateInput);
      } else {
        return dateInput.toString();
      }
      
      HijriCalendar.setLocal('ar');
      var hijri = HijriCalendar.fromDate(dt);
      var hijriStr = '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} هـ';
      var gregStr = DateFormat('yyyy/MM/dd | hh:mm a', 'ar_SA').format(dt);
      
      return '$hijriStr ($gregStr)';
    } catch (e) {
      return dateInput.toString();
    }
  }
}
