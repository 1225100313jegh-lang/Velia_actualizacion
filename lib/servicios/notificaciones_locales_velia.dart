import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../modelos/modelos_velia.dart';
import 'servicio_nube_velia.dart';

class NotificacionesLocalesVelia {
  NotificacionesLocalesVelia._();
  static final instancia = NotificacionesLocalesVelia._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _listo = false;

  Future<void> _inicializar() async {
    if (_listo) return;
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
    _listo = true;
  }

  /// Programa en el dispositivo los avisos de rutina y citas próximas.
  Future<void> sincronizar(PerfilAdulto adulto) async {
    await _inicializar();
    await _plugin.cancelAll();
    final service = ServicioNubeVelia.instancia;
    final routine = await service.listarRutina(adulto.id);
    final appointments = await service.listarCitas(adulto.id);
    final now = DateTime.now();
    var count = 0;
    for (var dayOffset = 0; dayOffset < 7 && count < 48; dayOffset++) {
      final day =
          DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      for (final item in routine) {
        if (!item.activo || !item.dias.contains(day.weekday)) continue;
        if (item.fechaInicio != null &&
            day.isBefore(DateTime(item.fechaInicio!.year,
                item.fechaInicio!.month, item.fechaInicio!.day))) continue;
        if (!item.periodoIndeterminado &&
            item.fechaFin != null &&
            day.isAfter(DateTime(
                item.fechaFin!.year, item.fechaFin!.month, item.fechaFin!.day)))
          continue;
        final times = _times(item);
        for (final clock in times) {
          final parts = clock.split(':');
          final at = DateTime(day.year, day.month, day.day, int.parse(parts[0]),
              int.parse(parts[1]));
          if (!at.isAfter(now) || count >= 48) continue;
          await _schedule(
            id: _id(adulto.id, 'r-${item.id}-$dayOffset-$clock'),
            title: item.tipo == TipoRutina.medicamento
                ? 'Hora de tu medicamento'
                : 'Actividad programada',
            body:
                '${item.nombre}${item.dosis.isEmpty ? '' : ' · ${item.dosis}'}',
            at: at,
          );
          count++;
        }
      }
    }
    for (final appointment in appointments) {
      if (appointment.estado != EstadoCita.programada ||
          !appointment.fecha.isAfter(now)) continue;
      final reminder = DateTime(appointment.fecha.year, appointment.fecha.month,
          appointment.fecha.day - appointment.recordatorioDias, 9);
      final at = reminder.isAfter(now)
          ? reminder
          : appointment.fecha.subtract(const Duration(minutes: 30));
      if (!at.isAfter(now)) continue;
      await _schedule(
        id: _id(adulto.id, 'c-${appointment.id}'),
        title: 'Próxima cita',
        body:
            '${appointment.asunto} · ${appointment.fecha.day}/${appointment.fecha.month} a las ${appointment.fecha.hour.toString().padLeft(2, '0')}:${appointment.fecha.minute.toString().padLeft(2, '0')}',
        at: at,
      );
    }
  }

  List<String> _times(ElementoRutina item) {
    if (item.modo == ModoHorario.horasFijas) return item.horas;
    final start = item.horaInicio ?? '08:00';
    final parts = start.split(':');
    final startMinute = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final interval = (item.intervaloHoras ?? 8) * 60;
    final result = <String>[];
    for (var minute = startMinute; minute < 24 * 60; minute += interval) {
      result.add(
          '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}');
    }
    return result;
  }

  Future<void> _schedule(
      {required int id,
      required String title,
      required String body,
      required DateTime at}) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'velia_local_reminders',
          'Recordatorios de Velia',
          channelDescription: 'Avisos de rutina y citas próximos',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  int _id(String adultId, String key) =>
      '${adultId}_$key'.hashCode & 0x7fffffff;
}
