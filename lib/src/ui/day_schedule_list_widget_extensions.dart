import 'package:day_schedule_list/src/models/exceptions.dart';
import 'package:day_schedule_list/src/ui/interval_containers/appointment_container/appointment_container.dart';
import 'package:day_schedule_list/src/ui/interval_containers/appointment_container/dynamic_height_container.dart';
import 'package:flutter/material.dart';

import '../helpers/date_time_extensions.dart';
import '../helpers/time_of_day_extensions.dart';
import '../models/interval_range.dart';
import '../models/minute_interval.dart';
import '../models/schedule_item_position.dart';
import 'day_schedule_list_widget.dart';
import 'interval_containers/appointment_container_overlay.dart';
import 'time_of_day_widget.dart';

mixin DayScheduleListWidgetMethods {
  final MinuteInterval minimumMinuteInterval = MinuteInterval.one;
  final MinuteInterval appointmentMinimumDuration = MinuteInterval.twentyNine;

  double get hourHeight => 0;

  late double minimumMinuteIntervalHeight =
      (hourHeight * minimumMinuteInterval.numberValue.toDouble()) / 60.0;

  late double timeOfDayWidgetHeight = 10 * minimumMinuteIntervalHeight;

  final LayerLink link = LayerLink();
  OverlayEntry? appointmentOverlayEntry;
  late ScheduleItemPosition appointmentOverlayPosition;
  late AppointmentUpdatingMode appointmentUpdateMode;

  double calculateTimeOfDayIndicatorsInset(double timeOfDayWidgetHeight) {
    return timeOfDayWidgetHeight / 2.0;
  }

  bool intersectsOtherInterval<T extends IntervalRange>({
    required List<T> intervals,
    T? excludingInterval,
    required IntervalRange newInterval,
  }) {
    return intervals.any((element) {
      return excludingInterval != null
          ? element != excludingInterval && newInterval.intersects(element)
          : newInterval.intersects(element);
    });
  }

  List<IntervalRange> buildInternalUnavailableIntervals({
    required List<IntervalRange> unavailableIntervals,
  }) {
    try {
      return unavailableIntervals
          .where(
            (element) =>
                element.start > const TimeOfDay(hour: 0, minute: 0) &&
                element.end < const TimeOfDay(hour: 23, minute: 59),
          )
          .toList();
    } catch (error) {
      return [];
    }
  }

  bool belongsToInternalUnavailableRange({
    required TimeOfDay time,
    required List<IntervalRange> unavailableIntervals,
  }) {
    final List<IntervalRange> internalUnavailableIntervals =
        buildInternalUnavailableIntervals(
      unavailableIntervals: unavailableIntervals,
    );
    return internalUnavailableIntervals
        .any((element) => element.containsTimeOfDay(time));
  }

  ScheduleItemPosition calculateItemRangePosition<T extends IntervalRange>({
    required T itemRange,
    required double insetVertical,
    required ScheduleTimeOfDay? firstValidTime,
  }) {
    final int deltaTop =
        itemRange.start.toMinutes - (firstValidTime?.time.toMinutes ?? 0);
    final deltaIntervalInMinutes = itemRange.deltaIntervalIMinutes;

    return ScheduleItemPosition(
        top: minimumMinuteIntervalHeight *
                (deltaTop / minimumMinuteInterval.numberValue) +
            insetVertical,
        height: minimumMinuteIntervalHeight *
            (deltaIntervalInMinutes / minimumMinuteInterval.numberValue));
  }

  IntervalRange calculateItervalRangeForNewHeight({
    required TimeOfDay start,
    required double newDurationHeight,
  }) {
    final int durationInMinutes = convertDeltaYToMinutes(
      deltaY: newDurationHeight,
    );
    final DateTime endDateTime =
        DateTime(DateTime.now().year, 1, 1, start.hour, start.minute)
            .add(Duration(minutes: durationInMinutes));
    TimeOfDay end;
    if (endDateTime.day != 1) {
      end = const TimeOfDay(hour: 23, minute: 59);
    } else {
      end = TimeOfDay.fromDateTime(endDateTime);
    }
    return IntervalRange(start: start, end: end);
  }

  IntervalRange calculateItervalRangeForNewHeightFromTop({
    required TimeOfDay end,
    required double newDurationHeight,
  }) {
    final int durationInMinutes = convertDeltaYToMinutes(
      deltaY: newDurationHeight,
    );
    final DateTime startDateTime =
        DateTime(DateTime.now().year, 1, 1, end.hour, end.minute).subtract(
      Duration(minutes: durationInMinutes),
    );
    TimeOfDay newStart;
    if (startDateTime.day != 1) {
      newStart = const TimeOfDay(hour: 0, minute: 0);
    } else {
      newStart = TimeOfDay.fromDateTime(startDateTime);
    }
    return IntervalRange(start: newStart, end: end);
  }

  IntervalRange calculateItervalRangeForNewPosition({
    required IntervalRange range,
    required ScheduleItemPosition newPosition,
    required ScheduleTimeOfDay firstValidTime,
    required double insetVertical,
  }) {
    final start = range.start;
    final end = range.end;
    final int newStartIncrement =
        firstValidTime.time.hour > 0 || firstValidTime.time.minute > 0
            ? firstValidTime.time.toMinutes
            : 0;
    final int newStartInMinutes = convertDeltaYToMinutes(
          deltaY: newPosition.top - insetVertical,
        ) +
        newStartIncrement;

    final int newEndInMinutes = convertDeltaYToMinutes(
          deltaY: newPosition.top + newPosition.height - insetVertical,
        ) +
        newStartIncrement;

    final startDeltaInMinutes = newStartInMinutes - start.toMinutes;
    final endDeltaInMinutes = newEndInMinutes - end.toMinutes;

    final DateTime startDateTime =
        DateTime(DateTime.now().year, 1, 1, start.hour, start.minute)
            .add(Duration(minutes: startDeltaInMinutes));
    final TimeOfDay newStart = TimeOfDay.fromDateTime(startDateTime);

    final DateTime endDateTime =
        DateTime(DateTime.now().year, 1, 1, end.hour, end.minute)
            .add(Duration(minutes: endDeltaInMinutes));
    final TimeOfDay newEnd = TimeOfDay.fromDateTime(endDateTime);

    if (newStart < newEnd) {
      return IntervalRange(start: newStart, end: newEnd);
    }
    return IntervalRange(start: start, end: end);
  }

  int convertDeltaYToMinutes({
    required double deltaY,
  }) {
    return ((deltaY * minimumMinuteInterval.numberValue) /
            minimumMinuteIntervalHeight)
        .round();
  }

  List<ScheduleTimeOfDay> populateValidTimesList({
    required List<IntervalRange> unavailableIntervals,
  }) {
    List<ScheduleTimeOfDay> validTimesList = [];
    final verifyUnavailableIntervals = unavailableIntervals.isNotEmpty;
    for (var item = 0; item < 49; item++) {
      final hasTimeBefore = item > 0;
      final TimeOfDay time = TimeOfDay(
          hour: (item == 48 || item == 47) ? 23 : (item / 2).floor(),
          minute: item == 48
              ? 59
              : item % 2 == 0
                  ? 0
                  : 30);
      if (verifyUnavailableIntervals) {
        final IntervalRange first = unavailableIntervals.first;
        final IntervalRange last = unavailableIntervals.last;

        final belongsToFirst = first.containsTimeOfDay(time);
        final belongsToLast = last.containsTimeOfDay(time);

        if (hasTimeBefore) {
          final beforeDateTime =
              DateTime(DateTime.now().year, 1, 1, time.hour, time.minute)
                  .subtract(const Duration(hours: 1));
          final timeBefore = TimeOfDay.fromDateTime(beforeDateTime);
          final timeBeforeBelongsToFirst = first.containsTimeOfDay(timeBefore);
          final timeBeforeBelongsToLast = last.containsTimeOfDay(timeBefore);
          if (timeBeforeBelongsToFirst && !belongsToFirst) {
            final dateTimeToAdd = DateTime(
                    DateTime.now().year, 1, 1, first.end.hour, first.end.minute)
                .add(Duration(minutes: minimumMinuteInterval.numberValue));
            final timeOfDayToAdd = TimeOfDay.fromDateTime(dateTimeToAdd);
            if (time.toMinutes - timeOfDayToAdd.toMinutes >=
                minimumMinuteInterval.numberValue) {
              validTimesList.add(
                belongsToInternalUnavailableRange(
                  time: timeOfDayToAdd,
                  unavailableIntervals: unavailableIntervals,
                )
                    ? ScheduleTimeOfDay.unavailable(time: timeOfDayToAdd)
                    : ScheduleTimeOfDay.available(time: timeOfDayToAdd),
              );
            }
          } else if (!timeBeforeBelongsToLast && belongsToLast) {
            final dateTimeToAdd = DateTime(DateTime.now().year, 1, 1,
                    last.start.hour, last.start.minute)
                .subtract(Duration(minutes: minimumMinuteInterval.numberValue));
            final timeOfDayToAdd = TimeOfDay.fromDateTime(dateTimeToAdd);
            if (time.toMinutes - timeOfDayToAdd.toMinutes >=
                minimumMinuteInterval.numberValue) {
              validTimesList.add(
                belongsToInternalUnavailableRange(
                  time: timeOfDayToAdd,
                  unavailableIntervals: unavailableIntervals,
                )
                    ? ScheduleTimeOfDay.unavailable(time: timeOfDayToAdd)
                    : ScheduleTimeOfDay.available(time: timeOfDayToAdd),
              );
            }
          }
        }

        if (!belongsToFirst && !belongsToLast) {
          validTimesList.add(
            belongsToInternalUnavailableRange(
              time: time,
              unavailableIntervals: unavailableIntervals,
            )
                ? ScheduleTimeOfDay.unavailable(time: time)
                : ScheduleTimeOfDay.available(time: time),
          );
        }
      } else {
        validTimesList.add(
          belongsToInternalUnavailableRange(
            time: time,
            unavailableIntervals: unavailableIntervals,
          )
              ? ScheduleTimeOfDay.unavailable(time: time)
              : ScheduleTimeOfDay.available(time: time),
        );
      }
    }
    return validTimesList;
  }

  bool canUpdateHeightOfInterval<S extends IntervalRange>({
    required HeightUpdateFrom from,
    required int index,
    required List<S> appointments,
    required List<IntervalRange> unavailableIntervals,
    required double newHeight,
    required List<ScheduleTimeOfDay> validTimesList,
    required double insetVertical,
  }) {
    bool canUpdate = true;
    final interval = appointments[index];

    final possibleNewInterval = from == HeightUpdateFrom.bottom
        ? calculateItervalRangeForNewHeight(
            start: interval.start,
            newDurationHeight: newHeight,
          )
        : calculateItervalRangeForNewHeightFromTop(
            newDurationHeight: newHeight,
            end: interval.end,
          );

    switch (from) {
      case HeightUpdateFrom.top:
        final hasBeforeInterval = index > 0;
        if (hasBeforeInterval) {
          final beforeInterval = appointments[index - 1];
          canUpdate &= !beforeInterval.intersects(possibleNewInterval);
        }
        final exceedsMinValidTime =
            possibleNewInterval.start < validTimesList.first.time;
        canUpdate &= !exceedsMinValidTime;
        break;
      case HeightUpdateFrom.bottom:
        final hasNextInterval = index < appointments.length - 1;
        if (hasNextInterval) {
          final nextInterval = appointments[index + 1];
          canUpdate &= !nextInterval.intersects(possibleNewInterval);
        }
        final exceedsMaxValidTime =
            possibleNewInterval.end > validTimesList.last.time;
        canUpdate &= !exceedsMaxValidTime;
        break;
    }

    final intersectsUnavailableInterval = unavailableIntervals
        .any((element) => element.intersects(possibleNewInterval));
    final isBiggerThanMinimumDuration =
        possibleNewInterval.deltaIntervalIMinutes >=
            appointmentMinimumDuration.numberValue;
    canUpdate &= isBiggerThanMinimumDuration;
    canUpdate &= !intersectsUnavailableInterval;
    return canUpdate;
  }

  bool canUpdatePositionOfInterval<S extends IntervalRange>({
    required int index,
    required List<S> appointments,
    required ScheduleItemPosition newPosition,
    required double insetVertical,
    required double contentHeight,
  }) {
    final minTop = insetVertical;
    final maxEnd = contentHeight - insetVertical;
    return newPosition.top >= minTop &&
        newPosition.top + newPosition.height <= maxEnd;
  }

  ///Try to create a new appointment at the position tapped by the user
  IntervalRange? newAppointmentForTappedPosition(
      {required Offset startPosition,
      required List<IntervalRange> appointments,
      required List<IntervalRange> unavailableIntervals,
      required ScheduleTimeOfDay firstValidTimeList,
      required ScheduleTimeOfDay lastValidTimeList}) {
    final now = DateTime.now();
    final startInMinutes = convertDeltaYToMinutes(deltaY: startPosition.dy);

    final baseStartDate = DateTime(now.year, now.month, now.day,
        firstValidTimeList.time.hour, firstValidTimeList.time.minute, 0);
    final startDate = baseStartDate.add(
      Duration(minutes: startInMinutes - 29),
    );
    final start = baseStartDate.isSameDay(dateTime: startDate)
        ? TimeOfDay.fromDateTime(
            startDate,
          ).roundMin
        : firstValidTimeList.time;

    final baseEndDate =
        DateTime(now.year, now.month, now.day, start.hour, start.minute, 0);
    final endDate = baseEndDate.add(const Duration(minutes: 30));
    final end = endDate.isSameDay(dateTime: baseEndDate)
        ? TimeOfDay.fromDateTime(
            endDate,
          )
        : lastValidTimeList.time;

    IntervalRange? possibleNewAppointment =
        IntervalRange(start: start, end: end);

    final List<IntervalRange> fullList = [
      ...appointments,
      ...buildInternalUnavailableIntervals(
          unavailableIntervals: unavailableIntervals),
    ];

    List<IntervalRange> intersections = [];
    try {
      intersections = fullList
          .where(
            (element) => element.intersects(possibleNewAppointment!),
          )
          .toList();
    } catch (error) {
      debugPrint('$error');
    }

    ///Adjusts duration avoiding intersections
    for (var index = 0; index < intersections.length; index++) {
      if (possibleNewAppointment != null) {
        final intersectedInterval = intersections[index];
        final containsStart =
            intersectedInterval.containsTimeOfDay(possibleNewAppointment.start);
        final containsEnd =
            intersectedInterval.containsTimeOfDay(possibleNewAppointment.end);
        final needChangeStart = containsStart && !containsEnd;
        final needChangeEnd = !containsStart && containsEnd;

        if (needChangeStart) {
          debugPrint('1');
          possibleNewAppointment.start = intersectedInterval.end.add(
            hours: 0,
            minutes: 1,
          );
        } else if (needChangeEnd) {
          debugPrint('2');
          possibleNewAppointment.end = intersectedInterval.start.subtract(
            hours: 0,
            minutes: 1,
          );
        } else if (containsStart && containsEnd) {
          possibleNewAppointment = null;
          break;
        }
      }
    }

    ///Adjusts duration avoiding min valid time interval and max valid time interval
    if (possibleNewAppointment != null &&
        possibleNewAppointment.start < firstValidTimeList.time) {
      possibleNewAppointment.start = firstValidTimeList.time;
    } else if (possibleNewAppointment != null &&
        possibleNewAppointment.end > lastValidTimeList.time) {
      possibleNewAppointment.end = lastValidTimeList.time;
    }

    if (possibleNewAppointment == null ||
        possibleNewAppointment.deltaIntervalIMinutes <
            appointmentMinimumDuration.numberValue) {
      throw UnavailableIntervalToAddAppointmentException(
        appointmentMinimumDuration: appointmentMinimumDuration,
      );
    }

    return possibleNewAppointment;
  }

  void showUpdateOverlay<S extends IntervalRange>({
    required BuildContext context,
    required S interval,
    required AppointmentUpdatingMode mode,
    required double insetVertical,
    required List<ScheduleTimeOfDay> validTimesList,
    required double timeOfDayWidgetHeight,
    required AppointmentWidgetBuilder<S> appointmentBuilder,
  }) {
    appointmentOverlayPosition = calculateItemRangePosition<S>(
      itemRange: interval,
      insetVertical: insetVertical,
      firstValidTime: validTimesList.first,
    );
    appointmentUpdateMode = mode;

    debugPrint('$mode');
    hideAppoinmentOverlay();
    appointmentOverlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        final updatedInterval = calculateItervalRangeForNewPosition(
          range: interval,
          newPosition: appointmentOverlayPosition,
          firstValidTime: validTimesList.first,
          insetVertical: insetVertical,
        );

        return AppointmentContainerOverlay(
          position: appointmentOverlayPosition,
          updateMode: mode,
          interval: updatedInterval,
          link: link,
          timeIndicatorsInset:
              calculateTimeOfDayIndicatorsInset(timeOfDayWidgetHeight),
          child: appointmentBuilder(
            context,
            interval,
            appointmentOverlayPosition.height,
          ),
        );
      },
    );
    Overlay.of(context)?.insert(appointmentOverlayEntry!);
  }

  void updateAppointmentOverlay(ScheduleItemPosition newPosition) {
    appointmentOverlayPosition = newPosition;
    appointmentOverlayEntry?.markNeedsBuild();
  }

  void hideAppoinmentOverlay() {
    try {
      final overlay = appointmentOverlayEntry;
      if (overlay != null) {
        appointmentOverlayEntry = null;
        overlay.remove();
      }
    } catch (error) {
      debugPrint('$error');
    }
  }
}
