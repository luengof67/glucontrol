import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../datos/datos.dart';

/// Notificaciones: recordatorios, tomas de medicación y stock.
///
/// - Android: cada aviso se programa una vez y se repite solo (cada día o
///   cada semana); sobrevive a reinicios del teléfono.
/// - Windows no admite avisos repetidos: se programan los de los próximos
///   7 días cada vez que se abre la app o cambia algo.
class Avisos {
  static final _p = FlutterLocalNotificationsPlugin();
  static bool _listo = false;
  static String _ultimaFirma = '';

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _windows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'recordatorios',
      'Recordatorios',
      channelDescription: 'Medicación, medir la glucosa y citas',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_gota',
    ),
    windows: WindowsNotificationDetails(),
  );

  static Future<void> iniciar() async {
    if (!_android && !_windows) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
      await _p.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_gota'),
          windows: WindowsInitializationSettings(
            appName: 'GluControl',
            appUserModelId: 'JoseLuengo.GluControl',
            guid: '5b3c2a7e-6f1d-4e8a-9c2b-7d4f1a0e9b63',
          ),
        ),
      );
      _listo = true;
    } catch (e) {
      debugPrint('Avisos: $e');
    }
  }

  /// Android 13+: pide permiso para mostrar notificaciones.
  static Future<void> pedirPermiso() async {
    if (!_listo || !_android) return;
    final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await a?.requestNotificationsPermission();
  }

  static Future<void> probar() async {
    if (!_listo) return;
    await pedirPermiso();
    await _p.show(
        id: 1, title: 'GluControl', body: 'Las notificaciones funcionan.', notificationDetails: _detalles);
  }

  /// Vuelve a programar todo a partir de los recordatorios y medicamentos.
  /// Solo hace algo si ha cambiado alguno de ellos (o si [forzar]).
  static Future<void> reprogramar(Datos d, {bool forzar = false}) async {
    if (!_listo) return;
    final items = <_Item>[];
    for (final r in d.recordatorios.where((r) => r.activo && r.dias.isNotEmpty)) {
      items.add(_Item('r${r.id}', _titulo(r.tipo), r.nombre, r.hora, r.dias));
    }
    for (final m in d.medicamentos.where((m) => m.avisar)) {
      for (final h in m.horarios) {
        items.add(_Item('m${m.id}$h', 'Toca tomar ${m.nombre}',
            '${m.dosis.isNotEmpty ? '${m.dosis} · ' : ''}$h${m.stockBajo || m.agotado ? ' · quedan ${m.stock}' : ''}',
            h, const [0, 1, 2, 3, 4, 5, 6]));
      }
    }
    final firma = '${fechaTexto(DateTime.now())}|${items.map((i) => i.firma).join(';')}';
    if (!forzar && firma == _ultimaFirma) return;
    _ultimaFirma = firma;

    try {
      await _p.cancelAll();
    } catch (_) {}

    var modo = AndroidScheduleMode.inexactAllowWhileIdle;
    if (_android) {
      final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (await a?.canScheduleExactNotifications() ?? false) modo = AndroidScheduleMode.exactAllowWhileIdle;
    }

    final ahora = tz.TZDateTime.now(tz.local);
    for (final it in items) {
      final p = it.hora.split(':');
      final h = int.tryParse(p.first) ?? 9, mi = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
      try {
        if (_android) {
          if (it.dias.length == 7) {
            await _p.zonedSchedule(
                id: _id(it.clave),
                title: it.titulo,
                body: it.cuerpo,
                scheduledDate: _proxima(ahora, h, mi, null),
                notificationDetails: _detalles,
                androidScheduleMode: modo,
                matchDateTimeComponents: DateTimeComponents.time);
          } else {
            for (final dia in it.dias) {
              await _p.zonedSchedule(
                  id: _id('${it.clave}#$dia'),
                  title: it.titulo,
                  body: it.cuerpo,
                  scheduledDate: _proxima(ahora, h, mi, dia == 0 ? 7 : dia),
                  notificationDetails: _detalles,
                  androidScheduleMode: modo,
                  matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime);
            }
          }
        } else {
          // Windows: una a una, los próximos 7 días.
          for (var k = 0; k < 7; k++) {
            final dia = tz.TZDateTime(tz.local, ahora.year, ahora.month, ahora.day + k, h, mi);
            if (!dia.isAfter(ahora)) continue;
            if (!it.dias.contains(dia.weekday % 7)) continue;
            await _p.zonedSchedule(
                id: _id('${it.clave}@${fechaTexto(dia)}'),
                title: it.titulo,
                body: it.cuerpo,
                scheduledDate: dia,
                notificationDetails: _detalles,
                androidScheduleMode: modo);
          }
        }
      } catch (e) {
        debugPrint('Avisos: no se pudo programar ${it.clave}: $e');
      }
    }
  }

  /// Una vez al día, al abrir la app: aviso si hay medicación agotada o baja.
  static Future<void> avisoStock(Datos d) async {
    if (!_listo) return;
    const almacen = FlutterSecureStorage();
    final hoy = hoyTexto();
    if (await almacen.read(key: 'gc_aviso_stock') == hoy) return;
    final agotados = d.medicamentos.where((m) => m.agotado).map((m) => m.nombre).toList();
    final bajos = d.medicamentos.where((m) => m.stockBajo).map((m) => '${m.nombre} (${m.stock})').toList();
    if (agotados.isEmpty && bajos.isEmpty) return;
    await almacen.write(key: 'gc_aviso_stock', value: hoy);
    await _p.show(
        id: 2,
        title: agotados.isNotEmpty ? 'Medicación agotada' : 'Queda poca medicación',
        body: [if (agotados.isNotEmpty) 'Agotado: ${agotados.join(', ')}', if (bajos.isNotEmpty) 'Bajo: ${bajos.join(', ')}']
            .join(' · '),
        notificationDetails: _detalles);
  }

  static String _titulo(String tipo) => switch (tipo) {
        'medicacion' => 'Medicación',
        'glucemia' => 'Toca medir la glucosa',
        'cita' => 'Cita médica',
        _ => 'Recordatorio',
      };

  /// Próxima fecha a esa hora (y ese día de la semana, 1=lunes...7=domingo).
  static tz.TZDateTime _proxima(tz.TZDateTime ahora, int h, int mi, int? diaSemana) {
    var t = tz.TZDateTime(tz.local, ahora.year, ahora.month, ahora.day, h, mi);
    while (!t.isAfter(ahora) || (diaSemana != null && t.weekday != diaSemana)) {
      t = tz.TZDateTime(tz.local, t.year, t.month, t.day + 1, h, mi);
    }
    return t;
  }

  /// Id numérico estable a partir de un texto (FNV-1a, 31 bits).
  static int _id(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return (h & 0x7FFFFFFF) | 0x10; // evita 1 y 2 (prueba y stock)
  }
}

class _Item {
  final String clave, titulo, cuerpo, hora;
  final List<int> dias;
  _Item(this.clave, this.titulo, this.cuerpo, this.hora, this.dias);
  String get firma => '$clave|$titulo|$cuerpo|$hora|${dias.join(',')}';
}
