import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El acceso del empleado en la base: `staff_accesos.tours_vistos`, con
/// entradas 'rol:recorrido'.
class _AccesoFalso implements ToursDelEmpleado {
  _AccesoFalso([Set<String>? entradas]) : guardados = entradas;

  /// Null: quien usa la app no tiene acceso.
  Set<String>? guardados;
  bool sinRed = false;
  int lecturas = 0;

  @override
  Future<Set<String>?> vistos(String rol) async {
    lecturas++;
    if (sinRed) throw Exception('Failed host lookup');
    final todos = guardados;
    if (todos == null) return null;
    return {
      for (final entrada in todos)
        if (entrada.startsWith('$rol:')) entrada.substring(rol.length + 1),
    };
  }

  @override
  Future<void> marcarVisto(String rol, String tourId) async =>
      guardados!.add('$rol:$tourId');
}

/// Todos los recorridos de [rol], vistos.
Set<String> todoVistoComo(String rol) =>
    {for (final tour in AppTours.all) '$rol:$tour'};

void main() {
  late _AccesoFalso acceso;
  late SesionTour sesion;

  WelcomeTourService servicio() => WelcomeTourService(
        toursDelEmpleado: acceso,
        sesion: () => sesion,
      );

  SesionTour empleado(String rol, {String perfil = 'perfil-1'}) =>
      (gymId: 'gym', perfilId: perfil, rol: rol, esEmpleado: true);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Empleado', () {
    test('nuevo: ve cada recorrido de su rol una vez', () async {
      acceso = _AccesoFalso({});
      sesion = empleado('mostrador');
      final tours = servicio();

      expect(await tours.isPending(AppTours.home), isTrue);

      await tours.marcarVistosParaPruebas([AppTours.home]);
      expect(await tours.isPending(AppTours.home), isFalse);
      // Queda en su acceso, con el rol con el que lo vio.
      expect(acceso.guardados, {'mostrador:home'});
      expect(await tours.isPending(AppTours.clientes), isTrue);
    });

    test('con un código nuevo no vuelve a ver nada', () async {
      acceso = _AccesoFalso({});
      sesion = empleado('mostrador');
      await servicio().marcarVistosParaPruebas([AppTours.home]);

      // Regenerar el código le da otro perfil (y quizá otro teléfono), pero su
      // acceso es el mismo.
      sesion = empleado('mostrador', perfil: 'perfil-2');
      expect(await servicio().isPending(AppTours.home), isFalse);
    });

    test('de Mostrador a Almacén ve lo de Almacén; al regresar, nada',
        () async {
      acceso = _AccesoFalso({
        'mostrador:home',
        'mostrador:clientes',
        'mostrador:abonar',
        'mostrador:entradas',
      });

      sesion = empleado('almacen');
      var tours = servicio();
      expect(await tours.isPending(AppTours.inventario), isTrue);
      // Inicio también: con otro rol muestra otras cosas.
      expect(await tours.isPending(AppTours.home), isTrue);
      await tours.marcarVistosParaPruebas([AppTours.home, AppTours.inventario]);

      sesion = empleado('mostrador');
      tours = servicio();
      for (final tour in [
        AppTours.home,
        AppTours.clientes,
        AppTours.abonar,
        AppTours.entradas,
      ]) {
        expect(await tours.isPending(tour), isFalse, reason: tour);
      }
    });

    test('de Encargado (que ve todo) a Almacén también ve lo de Almacén',
        () async {
      // El caso de Gael: como Encargado ya vio todas las pantallas.
      acceso = _AccesoFalso(todoVistoComo('encargado'));

      sesion = empleado('almacen');
      final tours = servicio();
      expect(await tours.isPending(AppTours.inventario), isTrue);
      await tours.marcarVistosParaPruebas([AppTours.inventario]);
      expect(acceso.guardados, contains('almacen:inventario'));

      sesion = empleado('encargado');
      for (final tour in AppTours.all) {
        expect(await tours.isPending(tour), isFalse, reason: tour);
      }
    });

    test('si le cambian el rol con la app abierta, se leen los del nuevo',
        () async {
      acceso = _AccesoFalso(todoVistoComo('mostrador'));
      sesion = empleado('mostrador');
      final tours = servicio();
      expect(await tours.isPending(AppTours.home), isFalse);

      sesion = empleado('almacen');
      expect(await tours.isPending(AppTours.home), isTrue);
      expect(acceso.lecturas, 2);
    });

    test('lo que ya vio se lee una sola vez de la base', () async {
      acceso = _AccesoFalso({});
      sesion = empleado('mostrador');
      final tours = servicio();
      await tours.isPending(AppTours.home);
      await tours.isPending(AppTours.clientes);
      expect(acceso.lecturas, 1);
    });

    test('sin acceso o sin red no se muestra; sin red se reintenta', () async {
      sesion = empleado('mostrador');
      acceso = _AccesoFalso();
      expect(await servicio().isPending(AppTours.home), isFalse);

      acceso = _AccesoFalso({})..sinRed = true;
      final tours = servicio();
      expect(await tours.isPending(AppTours.home), isFalse);

      acceso.sinRed = false;
      expect(await tours.isPending(AppTours.home), isTrue);
    });

    test('las banderas viejas del teléfono no cuentan para el empleado',
        () async {
      acceso = _AccesoFalso({'mostrador:home'});
      sesion = empleado('mostrador');
      SharedPreferences.setMockInitialValues(
          {'onboarding_tour_pending_gym_home': true});
      expect(await servicio().isPending(AppTours.home), isFalse);
    });
  });

  group('Dueño', () {
    setUp(() {
      acceso = _AccesoFalso();
      sesion = (
        gymId: 'gym',
        perfilId: 'dueno',
        rol: 'owner_admin',
        esEmpleado: false,
      );
    });

    test('sigue usando el teléfono: pendientes tras el asistente inicial',
        () async {
      final tours = servicio();
      expect(await tours.isPending(AppTours.home), isFalse);

      await tours.markPending();
      expect(await tours.isPending(AppTours.home), isTrue);

      await tours.marcarVistosParaPruebas([AppTours.home]);
      expect(await tours.isPending(AppTours.home), isFalse);
      expect(await tours.isPending(AppTours.clientes), isTrue);
      expect(acceso.lecturas, 0, reason: 'el dueño no consulta la base');
    });
  });
}
