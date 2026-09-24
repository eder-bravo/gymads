import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/services/permisos_app.dart';
import 'package:gymads/app/modules/permisos/controllers/permisos_controller.dart';
import 'package:gymads/app/modules/permisos/permisos_middleware.dart';
import 'package:gymads/app/modules/permisos/views/permisos_view.dart';
import 'package:gymads/app/routes/app_pages.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SolicitudFalsa implements SolicitudPermisos {
  _SolicitudFalsa(this.permisos, this.respuesta);

  @override
  final List<PermisoApp> permisos;
  final Map<PermisoApp, EstadoPermiso> respuesta;
  int pedidas = 0;

  @override
  Future<Map<PermisoApp, EstadoPermiso>> estados() async => respuesta;

  @override
  Future<Map<PermisoApp, EstadoPermiso>> pedirTodos() async {
    pedidas++;
    return respuesta;
  }

  @override
  Future<void> abrirAjustes() async {}
}

const _deIphone = [
  PermisoApp.notificaciones,
  PermisoApp.camara,
  PermisoApp.bluetooth,
  PermisoApp.redLocal,
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PermisosApp.reiniciarParaPruebas();
  });

  group('Qué se pide', () {
    test('iPhone: notificaciones, cámara, Bluetooth y red local', () {
      final mapa = permisosDelSistema(ios: true);
      expect(mapa.keys, _deIphone);
      expect(mapa[PermisoApp.bluetooth], [Permission.bluetooth]);
      // La red local no es de permission_handler: la comprueba el código
      // propio de iOS.
      expect(mapa[PermisoApp.redLocal], isEmpty);
    });

    test('Android 14: Bluetooth es "Dispositivos cercanos", sin ubicación', () {
      final mapa = permisosDelSistema(ios: false, sdkAndroid: 34);
      expect(mapa.keys, [
        PermisoApp.notificaciones,
        PermisoApp.camara,
        PermisoApp.bluetooth,
      ]);
      expect(mapa[PermisoApp.bluetooth],
          [Permission.bluetoothScan, Permission.bluetoothConnect]);
    });

    test('Android 11: buscar por Bluetooth también pide la ubicación', () {
      final mapa = permisosDelSistema(ios: false, sdkAndroid: 30);
      expect(
          mapa[PermisoApp.bluetooth], contains(Permission.locationWhenInUse));
    });
  });

  test('cómo se lee cada respuesta del sistema', () {
    expect(estadoDe(PermissionStatus.granted), EstadoPermiso.permitido);
    expect(estadoDe(PermissionStatus.limited), EstadoPermiso.permitido);
    expect(estadoDe(PermissionStatus.provisional), EstadoPermiso.permitido);
    expect(estadoDe(PermissionStatus.denied), EstadoPermiso.denegado);
    expect(
        estadoDe(PermissionStatus.permanentlyDenied), EstadoPermiso.bloqueado);
    expect(estadoDe(PermissionStatus.restricted), EstadoPermiso.bloqueado);

    // La red local de iPhone: negada ya solo se cambia en Ajustes.
    expect(estadoRedLocal(true), EstadoPermiso.permitido);
    expect(estadoRedLocal(false), EstadoPermiso.bloqueado);
    expect(estadoRedLocal(null), EstadoPermiso.sinDato);

    // Bluetooth en Android son dos: cuenta el peor.
    expect(peorEstado([EstadoPermiso.permitido, EstadoPermiso.denegado]),
        EstadoPermiso.denegado);
  });

  group('Una vez por teléfono', () {
    test('antes de pedirlos, Inicio manda a la pantalla de permisos', () async {
      await PermisosApp.cargar();
      expect(PermisosApp.yaSePidieron, isFalse);
      expect(destinoAntesDeInicio()?.name, Routes.PERMISOS);

      var listos = false;
      PermisosApp.listos.then((_) => listos = true);
      await Future<void>.delayed(Duration.zero);
      expect(listos, isFalse, reason: 'el lector aún no debe arrancar');

      await PermisosApp.marcarPedidos();
      await Future<void>.delayed(Duration.zero);
      expect(listos, isTrue);
      expect(destinoAntesDeInicio(), isNull);
    });

    test('al abrir la app otra vez ya no se muestra', () async {
      SharedPreferences.setMockInitialValues({'permisos_pedidos_v1': true});
      await PermisosApp.cargar();
      expect(PermisosApp.yaSePidieron, isTrue);
      expect(destinoAntesDeInicio(), isNull);
      await PermisosApp.listos; // No se queda esperando.
    });
  });

  group('Pantalla', () {
    tearDown(Get.reset);

    Future<_SolicitudFalsa> mostrar(
      WidgetTester tester, {
      required Map<PermisoApp, EstadoPermiso> respuesta,
      List<PermisoApp> permisos = _deIphone,
      bool desdeConfiguracion = false,
    }) async {
      final solicitud = _SolicitudFalsa(permisos, respuesta);
      Get.put(PermisosController(
        solicitud: solicitud,
        desdeConfiguracion: desdeConfiguracion,
      ));
      await tester.pumpWidget(const GetMaterialApp(home: PermisosView()));
      await tester.pumpAndSettle();
      return solicitud;
    }

    testWidgets('al entrar: lista todos y los pide con un solo botón',
        (tester) async {
      final solicitud = await mostrar(tester, respuesta: {
        PermisoApp.notificaciones: EstadoPermiso.permitido,
        PermisoApp.camara: EstadoPermiso.permitido,
        PermisoApp.bluetooth: EstadoPermiso.permitido,
        PermisoApp.redLocal: EstadoPermiso.sinDato,
      });

      for (final titulo in [
        'Notificaciones',
        'Cámara',
        'Bluetooth',
        'Red local',
      ]) {
        expect(find.text(titulo), findsOneWidget);
      }
      // Antes de preguntar no se muestra ningún estado.
      expect(find.text('Permitido'), findsNothing);
      expect(find.text('Ahora no'), findsOneWidget);

      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();

      expect(solicitud.pedidas, 1);
      expect(find.text('Permitido'), findsNWidgets(3));
      expect(find.text('Sin confirmar'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      expect(find.text('Abrir ajustes'), findsNothing);
      expect(PermisosApp.yaSePidieron, isTrue);
    });

    testWidgets('en Android no aparece la red local', (tester) async {
      await mostrar(
        tester,
        permisos: const [
          PermisoApp.notificaciones,
          PermisoApp.camara,
          PermisoApp.bluetooth,
        ],
        respuesta: const {},
      );
      expect(find.text('Red local'), findsNothing);
      expect(find.text('Bluetooth'), findsOneWidget);
    });

    testWidgets('si alguno quedó bloqueado, ofrece abrir los ajustes',
        (tester) async {
      await mostrar(tester, respuesta: {
        PermisoApp.notificaciones: EstadoPermiso.bloqueado,
        PermisoApp.camara: EstadoPermiso.permitido,
        PermisoApp.bluetooth: EstadoPermiso.permitido,
        PermisoApp.redLocal: EstadoPermiso.sinDato,
      });
      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();

      expect(find.text('Bloqueado'), findsOneWidget);
      expect(find.text('Abrir ajustes'), findsOneWidget);
    });

    testWidgets(
        'desde Configuración: muestra cómo quedaron y deja volver a '
        'pedir los negados', (tester) async {
      await mostrar(
        tester,
        desdeConfiguracion: true,
        respuesta: {
          PermisoApp.notificaciones: EstadoPermiso.denegado,
          PermisoApp.camara: EstadoPermiso.permitido,
          PermisoApp.bluetooth: EstadoPermiso.permitido,
          PermisoApp.redLocal: EstadoPermiso.sinDato,
        },
      );

      expect(find.text('No permitido'), findsOneWidget);
      expect(find.text('Permitir'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);
      expect(find.text('Ahora no'), findsNothing);
    });
  });
}
