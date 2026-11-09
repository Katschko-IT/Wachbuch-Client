import 'package:flutter/material.dart';

/// Datum und Uhrzeit in der Sprache der App (24-Stunden-Format), z. B.
/// „9.11.2026, 14:05“.
String formatDateTimeShort(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: true,
  );
  return '${material.formatShortDate(local)}, $time';
}

/// Nur das Datum in der Sprache der App, z. B. „9.11.2026“.
String formatDateShort(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatShortDate(value.toLocal());
}
