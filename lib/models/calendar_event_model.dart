class CalendarEventModel {
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final bool isAllDay;

  const CalendarEventModel({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
    this.isAllDay = false,
  });

  String get timeLabel {
    if (isAllDay) return 'All day';
    final h = startTime.hour;
    final m = startTime.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'pm' : 'am';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }
}
