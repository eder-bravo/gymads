import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:gymads/app/core/utils/app_logger.dart';

/// Android: mantiene viva la app en segundo plano mientras este teléfono
/// atiende el lector, para que los pases se sigan procesando (y avisando con
/// una notificación) aunque se use otra app.
///
/// Sin esto Android congela la app poco después de dejarla y le corta la red
/// (`sendto failed: EPERM`): el sondeo del lector se detiene. El servicio en
/// primer plano no hace nada por sí mismo (no tiene tarea propia): solo evita
/// que el sistema congele la app, que sigue sondeando con su `Timer` de
/// siempre. Se ve como una notificación fija, y se detiene si se cierra la app
/// desde recientes.
///
/// En iOS no existe algo equivalente: no hace nada.
class EscuchaSegundoPlano {
  EscuchaSegundoPlano._();

  static bool _configurado = false;

  /// Lo último que se pidió: que el servicio esté activo o no.
  static bool _deseado = false;

  /// Las órdenes se aplican de una en una. Reiniciar la escucha (Configuración,
  /// cambio de sesión) es detener + iniciar seguidos: en paralelo, iniciar veía
  /// el servicio todavía "activo" mientras se detenía, no hacía nada, y la
  /// escucha quedaba apagada.
  static Future<void> _enCurso = Future.value();

  static AppLifecycleListener? _alVolver;

  @visibleForTesting
  static bool forzarSoporte = false;

  static bool get _soportado =>
      forzarSoporte || (!kIsWeb && Platform.isAndroid);

  /// Pide que el servicio esté activo.
  static Future<void> iniciar() => _pedir(true);

  /// Pide que el servicio se detenga.
  static Future<void> detener() => _pedir(false);

  static Future<void> _pedir(bool activo) {
    if (!_soportado) return Future.value();
    _deseado = activo;
    _vigilarRegreso();
    return _enCurso = _enCurso.then((_) => _sincronizar());
  }

  /// Deja el servicio como indica [_deseado] (el valor de ese momento, no el
  /// de cuando se pidió: detener + iniciar seguidos no lo reinician).
  static Future<void> _sincronizar() async {
    try {
      _configurar();
      final activo = _deseado;
      final corriendo = await FlutterForegroundTask.isRunningService;
      if (activo == corriendo) return;

      if (activo) {
        final resultado = await FlutterForegroundTask.startService(
          serviceTypes: [ForegroundServiceTypes.connectedDevice],
          notificationTitle: 'GymOne escucha el lector',
          notificationText: 'Los pases te llegan aunque uses otra app.',
          notificationIcon: const NotificationIcon(
            metaDataName: 'com.gymone.ic_notificacion',
          ),
        );
        if (resultado is ServiceRequestFailure) {
          AppLogger.warning('EscuchaSegundoPlano',
              'No se pudo iniciar el servicio: ${resultado.error}');
        } else {
          AppLogger.info('EscuchaSegundoPlano',
              'Servicio en primer plano iniciado: el lector se escucha en segundo plano');
        }
      } else {
        await FlutterForegroundTask.stopService();
        AppLogger.info(
            'EscuchaSegundoPlano', 'Servicio en primer plano detenido');
      }
    } catch (e) {
      AppLogger.error(
          'EscuchaSegundoPlano', 'Error al sincronizar el servicio', e);
    }
  }

  /// Al volver a la app se comprueba que el servicio siga activo, por si el
  /// sistema lo cerró. Iniciarlo solo se permite con la app a la vista.
  static void _vigilarRegreso() {
    _alVolver ??= AppLifecycleListener(onResume: () {
      if (_deseado) _pedir(true);
    });
  }

  static void _configurar() {
    if (_configurado) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'lector_activo',
        channelName: 'Lector activo',
        channelDescription:
            'Aviso fijo mientras la app escucha al lector en segundo plano.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        // El lector está en la red local: sin esto el WiFi puede dormirse
        // con la pantalla apagada.
        allowWifiLock: true,
        // Si el sistema lo mata, no se reinicia solo: sin la app ya no hay
        // quien sondee, y la notificación prometería algo falso.
        allowAutoRestart: false,
        // NO poner `stopWithTask` aquí. En flutter_foreground_task 10 esa
        // opción no espera a que se cierre la app desde recientes: detiene
        // el servicio en cuanto la app deja de verse (TrackVisibilityUtils,
        // al pausarse la última pantalla), que es justo cuando hace falta.
        // Detenerlo al cerrar la app lo hace `android:stopWithTask="true"`
        // en AndroidManifest.xml, que el paquete usa si aquí no se indica.
      ),
    );
    _configurado = true;
  }

  @visibleForTesting
  static Future<void> reiniciarParaPruebas() async {
    await _enCurso;
    _alVolver?.dispose();
    _alVolver = null;
    _deseado = false;
    _configurado = false;
    forzarSoporte = false;
  }
}
