import 'package:intl/intl.dart';

/// [apiUtc] must be the UTC instant from the API ([DateTime.isUtc] true after parsing).
DateTime appointmentToLocal(DateTime apiUtc) => apiUtc.toUtc().toLocal();

final DateFormat _kDateIso = DateFormat('yyyy-MM-dd');
final DateFormat _kTime12h = DateFormat.jm();

/// Local calendar date for display (same on reception and patient).
String formatAppointmentDateIso(DateTime apiUtc) =>
    _kDateIso.format(appointmentToLocal(apiUtc));

/// Local 12-hour time with AM/PM (locale-aware).
String formatAppointmentTimeHm(DateTime apiUtc) =>
    _kTime12h.format(appointmentToLocal(apiUtc));

/// Single line: `yyyy-MM-dd` + 12h time in the device local zone.
String formatAppointmentDateTimeLine(DateTime apiUtc) =>
    '${formatAppointmentDateIso(apiUtc)} ${formatAppointmentTimeHm(apiUtc)}';

/// For a naive local [DateTime] from pickers (wall clock), same date + 12h formatting.
String formatLocalWallDateTimeLine(DateTime localWall) =>
    '${_kDateIso.format(localWall)} ${_kTime12h.format(localWall)}';
