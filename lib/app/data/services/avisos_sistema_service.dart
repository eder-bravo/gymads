import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gymads/app/core/utils/app_logger.dart';

/// Qué pasó con una tarjeta en el lector.
enum ResultadoPase { entrada, salida, vencida, inactiva, noRegistrada }

/// Título y texto de la notificación de un pase.
///
/// Sin el número de la tarjeta ni el del cliente: la notificación puede verse
/// en la pantalla bloqueada.
({String titulo, String cuerpo}) avisoDePase(
  ResultadoPase resultado, {
  String? nombre,
  int? diasRestantes,
}) {
  final quien = (nombre ?? '').trim().isEmpty ? 'Cliente' : nombre!.trim();
  switch (resultado) {
    case ResultadoPase.entrada:
      return (titulo: '$quien entró', cuerpo: _textoDias(diasRestantes));
    case ResultadoPase.salida:
      return (titulo: '$quien salió', cuerpo: _textoDias(diasRestantes));
    case ResultadoPase.vencida:
      return (titulo: 'Acceso denegado: $quien', cuerpo: 'Membresía vencida');
    case ResultadoPase.inactiva:
      return (titulo: 'Acceso denegado: $quien', cuerpo: 'Membresía inactiva');
    case ResultadoPase.noRegistrada:
      return (
        titulo: 'Tarjeta no registrada',
        cuerpo: 'Regístrala en Clientes para darle acceso',
      );
  }
}

String _textoDias(int? dias) {
  if (dias == null) return 'Acceso registrado';
  if (dias == 1) return 'Le queda 1 día';
  return 'Le quedan $dias días';
}

/// Notificaciones del sistema (como las de un mensaje) para los pases del
/// lector cuando la app está en segundo plano. En primer plano se usan los
/// avisos de la propia app.
class AvisosSistema {
  AvisosSistema._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _listo = false;
  static int _siguienteId = 1;

  static const _canal = AndroidNotificationChannel(
    'pases_lector',
    'Pases del lector',
    description: 'Quién entra, sale o es rechazado en el lector mientras '
        'usas otra app.',
    importance: Importance.high,
  );

  static bool get _soportado =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Prepara las notificaciones. No pide permiso: eso se hace solo en el
  /// teléfono que atiende el lector ([pedirPermiso]).
  static Future<void> init() async {
    if (!_soportado || _listo) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notificacion'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_canal);
      _listo = true;
    } catch (e) {
      AppLogger.error('AvisosSistema', 'No se pudieron preparar', e);
    }
  }

  /// Pide permiso para mostrar notificaciones (Android 13+ e iOS). Si la
  /// persona ya contestó, el sistema no vuelve a preguntar.
  static Future<void> pedirPermiso() async {
    if (!_soportado) return;
    await init();
    try {
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true);
      }
    } catch (e) {
      AppLogger.error('AvisosSistema', 'No se pudo pedir el permiso', e);
    }
  }

  /// Avisa de un pase con una notificación del sistema.
  static Future<void> mostrarPase(
    ResultadoPase resultado, {
    String? nombre,
    int? diasRestantes,
  }) async {
    if (!_listo) return;
    final aviso =
        avisoDePase(resultado, nombre: nombre, diasRestantes: diasRestantes);
    try {
      await _plugin.show(
        id: _siguienteId++,
        title: aviso.titulo,
        body: aviso.cuerpo,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _canal.id,
            _canal.name,
            channelDescription: _canal.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notificacion',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('AvisosSistema', 'No se pudo mostrar la notificación', e);
    }
  }
}
