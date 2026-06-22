class EmailBrief {
  final String subject;
  final String from;
  final String snippet;
  final DateTime date;

  const EmailBrief({
    required this.subject,
    required this.from,
    required this.snippet,
    required this.date,
  });
}
