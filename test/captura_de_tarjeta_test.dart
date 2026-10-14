import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/repositories/abono_prices_repository.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/services/captura_de_tarjeta.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/modules/abonar/controllers/abonar_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Usuarios extends Fake implements UserRepository {
  @override
  Future<List<UserModel>> getAllUsers() async => [];
}

class _Precios extends Fake implements AbonoPricesRepository {
  @override
  Future<AbonoPricesModel> getPrices() async =>
      const AbonoPricesModel(priceMonth: 500);
}

class _Ingresos extends Fake implements IngresoService {}

class _SinTours implements ToursDelEmpleado {
  @override
  Future<Set<String>?> vistos(String rol) async => {};
  @override
  Future<void> marcarVisto(String rol, String tourId) async {}
}

UserModel _cliente(String id, String nombre) => UserModel(
      id: id,
      name: nombre,
      phone: '+520000000000',
      joinDate: DateTime(2026, 1, 1),
      userNumber: id,
    );

void main() {
  group('CapturaDeTarjeta', () {
    test('sin nadie capturando, el pase sigue de largo', () {
      expect(CapturaDeTarjeta.ofrecer('AAAA', null), isFalse);
    });

    test('el formulario abierto encima de Abonar recibe el pase; al cerrarlo, '
        'vuelve a Abonar', () {
      final recibidos = <String>[];
      final soltarAbonar = CapturaDeTarjeta.tomar((uid, _) {
        recibidos.add('abonar');
        return false;
      });
      final soltarFormulario = CapturaDeTarjeta.tomar((uid, _) {
        recibidos.add('formulario');
        return true;
      });

      expect(CapturaDeTarjeta.ofrecer('AAAA', null), isTrue);
      soltarFormulario();
      expect(CapturaDeTarjeta.ofrecer('AAAA', null), isFalse);
      expect(recibidos, ['formulario', 'abonar']);

      soltarAbonar();
      expect(CapturaDeTarjeta.ofrecer('AAAA', null), isFalse);
      expect(recibidos, ['formulario', 'abonar']);
    });

    test('soltar fuera de orden no le quita el pase al de arriba', () {
      final soltarAbajo = CapturaDeTarjeta.tomar((_, __) => false);
      final soltarArriba = CapturaDeTarjeta.tomar((_, __) => true);

      soltarAbajo();
      expect(CapturaDeTarjeta.ofrecer('AAAA', null), isTrue);
      // Soltar dos veces no quita a nadie más.
      soltarAbajo();
      expect(CapturaDeTarjeta.ofrecer('AAAA', null), isTrue);

      soltarArriba();
      expect(CapturaDeTarjeta.ofrecer('AAAA', null), isFalse);
    });
  });

  group('Abonar con el lector', () {
    late AbonarController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Get.put(WelcomeTourService(
        toursDelEmpleado: _SinTours(),
        sesion: () =>
            (gymId: 'gym', perfilId: 'p', rol: 'owner_admin', esEmpleado: false),
      ));
      controller = Get.put(AbonarController(
        userRepository: _Usuarios(),
        ingresoService: _Ingresos(),
        pricesRepository: _Precios(),
      ));
    });
    tearDown(Get.reset);

    testWidgets('nunca se queda con el pase, y al cerrar Abonar lo suelta',
        (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
      expect(CapturaDeTarjeta.ofrecer('AAAA', _cliente('1', 'Ana')), isFalse);

      var abajo = 0;
      Get.delete<AbonarController>();
      final soltar = CapturaDeTarjeta.tomar((_, __) {
        abajo++;
        return false;
      });
      addTearDown(soltar);
      CapturaDeTarjeta.ofrecer('AAAA', null);
      expect(abajo, 1);
    });

    testWidgets('la tarjeta abre el cobro de su cliente, aunque se cobrara a '
        'otro', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
      controller.selectClient(_cliente('1', 'Ana'));
      controller.pasoActual.value = 2;

      controller.abrirCobroDe(_cliente('2', 'Beto'));
      expect(controller.selectedClient.value?.name, 'Beto');
      expect(controller.pasoActual.value, 1);
    });

    testWidgets('si ya se cobraba a ese cliente, sigue en el paso donde iba',
        (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
      controller.selectClient(_cliente('1', 'Ana'));
      controller.pasoActual.value = 3;

      controller.abrirCobroDe(_cliente('1', 'Ana'));
      expect(controller.pasoActual.value, 3);
    });

    testWidgets('después de un abono, la tarjeta empieza otro cobro',
        (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
      controller.selectClient(_cliente('1', 'Ana'));
      controller.isSuccess.value = true;

      controller.abrirCobroDe(_cliente('1', 'Ana'));
      expect(controller.isSuccess.value, isFalse);
      expect(controller.selectedClient.value?.name, 'Ana');
      expect(controller.pasoActual.value, 1);
    });
  });
}
