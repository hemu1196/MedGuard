import 'package:timezone/timezone.dart' as tz;
import '../models/medicine.dart';

class PlannedDose {
  final tz.TZDateTime instant;
  final String time;
  PlannedDose(this.instant, this.time);
  String get day =>
      '${instant.year.toString().padLeft(4, '0')}-${instant.month.toString().padLeft(2, '0')}-${instant.day.toString().padLeft(2, '0')}';
}

/// Construct each calendar day in the selected IANA zone, rather than adding
/// 24-hour durations across daylight-saving changes.
class MedicineSchedule {
  static List<PlannedDose> upcoming(
    Medicine medicine,
    tz.Location zone,
    DateTime now, {
    int horizonDays = 30,
  }) {
    if (medicine.frequency.toLowerCase() == 'as needed') return [];
    final localNow = tz.TZDateTime.from(now, zone);
    final start = medicine.startDate ?? localNow;
    final startDay = DateTime(start.year, start.month, start.day);
    final end = medicine.endDate;
    final result = <PlannedDose>[];
    for (var offset = 0; offset < horizonDays; offset++) {
      final day = DateTime(
        localNow.year,
        localNow.month,
        localNow.day + offset,
      );
      if (day.isBefore(startDay)) continue;
      if (end != null && day.isAfter(DateTime(end.year, end.month, end.day))) {
        continue;
      }
      final frequency = medicine.frequency.toLowerCase();
      if (frequency == 'once' && day != startDay) continue;
      if (frequency == 'weekly' && day.weekday != startDay.weekday) continue;
      if (frequency == 'specific days' &&
          !medicine.weekdays.contains(day.weekday)) {
        continue;
      }
      for (final text in medicine.reminderTimes) {
        final match = RegExp(
          r'^(\d{1,2}):(\d{2})\s*([APap][Mm])?$',
        ).firstMatch(text.trim().replaceAll('\u202f', ' '));
        if (match == null) continue;
        var hour = int.parse(match[1]!);
        final minute = int.parse(match[2]!);
        final ampm = match[3]?.toUpperCase();
        if (ampm == 'PM' && hour < 12) hour += 12;
        if (ampm == 'AM' && hour == 12) hour = 0;
        if (hour > 23 ||
            minute > 59 ||
            (ampm != null &&
                (int.parse(match[1]!) < 1 || int.parse(match[1]!) > 12))) {
          continue;
        }
        final instant = tz.TZDateTime(
          zone,
          day.year,
          day.month,
          day.day,
          hour,
          minute,
        );
        // A nonexistent spring-forward wall time is skipped rather than moved silently.
        if (instant.hour != hour ||
            instant.minute != minute ||
            !instant.isAfter(localNow)) {
          continue;
        }
        final time =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        if (!result.any((p) => p.instant == instant)) {
          result.add(PlannedDose(instant, time));
        }
      }
    }
    return result..sort((a, b) => a.instant.compareTo(b.instant));
  }
}
