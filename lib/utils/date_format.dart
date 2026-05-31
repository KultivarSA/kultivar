String formatDateTime(DateTime dt) {
  final d = dt.toLocal();
  return '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

String formatDate(DateTime dt) {
  final d = dt.toLocal();
  return '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Human-friendly short date, e.g. "Apr 28".
String fmtShortDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final d = dt.toLocal();
  return '${months[d.month - 1]} ${d.day}';
}

/// Human-friendly short date + time, e.g. "Apr 28 · 14:32".
String fmtShortDateTime(DateTime dt) {
  final d = dt.toLocal();
  final time = '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
  return '${fmtShortDate(d)} · $time';
}
