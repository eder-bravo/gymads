import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/escucha_segundo_plano.dart';

/// El servicio de Android simulado: arrancarlo y detenerlo tarda, como en el
/// teléfono.
class _ServicioFalso extends FlutterForegroundTaskPlatform {
  bool corriendo = false;
  int inicios = 0;
  int detenciones = 0;

  @override
  Future<bool> get isRunningService async => corriendo;

  @override
  Future<void> startService({
    required AndroidNotificationOptions androidNotificationOptions,
    required IOSNotificationOptions iosNotificationOptions,
    required ForegroundTaskOptions foregroundTaskOptions,
    int? serviceId,
    List<ForegroundServiceTypes>? serviceTypes,
    required String notificationTitle,
    required String notificationText,
    NotificationIcon? notificationIcon,
    List<NotificationButton>? notificationButtons,
    String? notificationInitialRoute,
    Function? callback,
  }) async {
    inicios++;
    await Future.delayed(const Duration(milliseconds: 100));
    corriendo = true;
  }

  @override
  Future<void> stopService() async {
    detenciones++;
    await Future.delayed(const Duration(milliseconds: 300));
    corriendo = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ServicioFalso servicio;

  setUp(() {
    servicio = _ServicioFalso();
    FlutterForegroundTaskPlatform.instance = servicio;
    FlutterForegroundTask.skipServiceResponseCheck = true;
    EscuchaSegundoPlano.forzarSoporte = true;
  });

  tearDown(() async {
    await EscuchaSegundoPlano.reiniciarParaPruebas();
    FlutterForegroundTask.resetStatic();
  });

  test('inicia y detiene el servicio', () async {
    await EscuchaSegundoPlano.iniciar();
    expect(servicio.corriendo, isTrue);

    // Con esta opción el paquete detiene el servicio en cuanto la app se va
    // a segundo plano: los pases dejaban de llegar tras el primero.
    expect(FlutterForegroundTask.foregroundTaskOptions?.stopWithTask, isNull,
        reason: 'stopWithTask lo resuelve el manifest');

    await EscuchaSegundoPlano.detener();
    expect(servicio.corriendo, isFalse);
  });

  test('reiniciar la escucha (detener + iniciar seguidos) lo deja activo',
      () async {
    await EscuchaSegundoPlano.iniciar();

    // Lo que hace Configuración al salir, o un cambio de sesión:
    // stopScanning() y startScanning() sin esperar uno al otro.
    final parar = EscuchaSegundoPlano.detener();
    final arrancar = EscuchaSegundoPlano.iniciar();
    await Future.wait([parar, arrancar]);

    expect(servicio.corriendo, isTrue);
    // Y sin apagarlo y prenderlo de más.
    expect(servicio.detenciones, 0);
  });

  test('si se detiene ya iniciado, al final queda detenido', () async {
    await EscuchaSegundoPlano.iniciar();
    final arrancar = EscuchaSegundoPlano.iniciar();
    final parar = EscuchaSegundoPlano.detener();
    await Future.wait([arrancar, parar]);

    expect(servicio.corriendo, isFalse);
  });

  test('si el sistema lo cerró, al volver a la app se vuelve a iniciar',
      () async {
    await EscuchaSegundoPlano.iniciar();
    servicio.corriendo = false; // Android lo cerró con la app en segundo plano.

    // Se va a otra app y vuelve.
    for (final estado in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(estado);
    }
    await Future.delayed(const Duration(milliseconds: 200));

    expect(servicio.corriendo, isTrue);
    expect(servicio.inicios, 2);
  });
}
