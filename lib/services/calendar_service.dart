import 'package:device_calendar/device_calendar.dart';
import '../models/calendar_event_model.dart';

class CalendarService {
  static final _plugin = DeviceCalendarPlugin();

  static Future<List<CalendarEventModel>> getTodayEvents() async {
    try {
      final permResult = await _plugin.requestPermissions();
      if (permResult.data != true) return [];

      final calendarsResult = await _plugin.retrieveCalendars();
      final calendars = calendarsResult.data ?? [];

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final events = <CalendarEventModel>[];

      for (final cal in calendars) {
        if (cal.isReadOnly == false || cal.isReadOnly == null) {
          // include all calendars
        }
        final eventsResult = await _plugin.retrieveEvents(
          cal.id!,
          RetrieveEventsParams(startDate: start, endDate: end),
        );
        for (final e in eventsResult.data ?? []) {
          if (e.title == null || e.title!.isEmpty) continue;
          events.add(CalendarEventModel(
            title: e.title!,
            startTime: e.start ?? start,
            endTime: e.end ?? end,
            location: e.location,
            isAllDay: e.allDay ?? false,
          ));
        }
      }

      events.sort((a, b) => a.startTime.compareTo(b.startTime));
      return events;
    } catch (_) {
      return [];
    }
  }
}
