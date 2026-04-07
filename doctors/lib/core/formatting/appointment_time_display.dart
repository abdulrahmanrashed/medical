import 'package:intl/intl.dart';

/// [apiUtc] must be the UTC instant from the API ([DateTime.isUtc] true after parsing).
DateTime appointmentToLocal(DateTime apiUtc) => apiUtc.toUtc().toLocal();

final DateFormat _kDateIso = DateFormat('yyyy-MM-dd');
final DateFormat _kTimeHm = DateFormat('HH:mm');

/// Local calendar date for display (same on reception and patient).
String formatAppointmentDateIso(DateTime apiUtc) =>
    _kDateIso.format(appointmentToLocal(apiUtc));

/// Local 24h time, e.g. 23:00 (same on reception and patient).
String formatAppointmentTimeHm(DateTime apiUtc) =>
    _kTimeHm.format(appointmentToLocal(apiUtc));

/// Single line: `yyyy-MM-dd HH:mm` in the device local zone.
String formatAppointmentDateTimeLine(DateTime apiUtc) =>
    '${formatAppointmentDateIso(apiUtc)} ${formatAppointmentTimeHm(apiUtc)}';

/// For a naive local [DateTime] from pickers (wall clock), same `yyyy-MM-dd HH:mm` formatting.
String formatLocalWallDateTimeLine(DateTime localWall) =>
    '${_kDateIso.format(localWall)} ${_kTimeHm.format(localWall)}';
