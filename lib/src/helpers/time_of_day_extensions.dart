import 'package:flutter/material.dart';

extension HelperMethods on TimeOfDay {
  int get toMinutes => hour * 60 + minute;
  bool operator <(Object other) {
    return other is TimeOfDay &&
        (other.hour > hour || (other.hour == hour && other.minute > minute));
  }

  bool operator >(Object other) {
    return other is TimeOfDay &&
        (other.hour < hour || (other.hour == hour && other.minute < minute));
  }

  bool operator <=(Object other) {
    return other is TimeOfDay &&
            (other.hour > hour ||
                (other.hour == hour && other.minute > minute)) ||
        other == this;
  }

  bool operator >=(Object other) {
    return other is TimeOfDay &&
            (other.hour < hour ||
                (other.hour == hour && other.minute < minute)) ||
        other == this;
  }

  TimeOfDay add({required int hours, required int minutes}) {
    final now = DateTime.now();
    final newDate =
        DateTime(now.year, now.month, now.day, hour, minute).add(Duration(
      hours: hours,
      minutes: minutes,
    ));
    return TimeOfDay.fromDateTime(newDate);
  }

  TimeOfDay subtract({required int hours, required int minutes}) {
    final now = DateTime.now();
    final newDate =
        DateTime(now.year, now.month, now.day, hour, minute).subtract(Duration(
      hours: hours,
      minutes: minutes,
    ));
    return TimeOfDay.fromDateTime(newDate);
  }

  TimeOfDay get roundMin {
    var _hour = hour;
    var _min = minute;
    if (minute < 30 && minute < 15) {
      _min = 0;
    } else if (minute < 45) {
      _min = 30;
    } else {
      _hour++;
      _min = 0;
    }
    return TimeOfDay(hour: _hour, minute: _min);
  }
}
