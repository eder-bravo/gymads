import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/models/access_log_model.dart';
import 'package:gymads/app/data/models/gym_settings_model.dart';
import 'package:gymads/app/modules/access_logs/controllers/access_logs_controller.dart';

/// Un acceso a la hora indicada del 1 de septiembre.
AccessLogModel _acceso(int hora, {String tipo = 'entrada'}) {
  return AccessLogModel(
    id: 'x$hora$tipo',
    userId: 'u1',
    userName: 'Cliente',
    userNumber: '1',
    accessType: tipo,
    method: 'rfid',
    staffUser: 'staff',
    accessTime: DateTime(2026, 9, 1, hora, 15),
    createdAt: DateTime(2026, 9, 1, hora, 15),
  );
}

void main() {
  late AccessLogsController controller;

  setUp(() {
    controller = AccessLogsController();
    controller.ajustes.value = const GymSettingsModel(
      horaApertura: HoraDelDia(6, 0),
      horaCierre: HoraDelDia(22, 0),
    );
  });

  group('entradasPorFranja', () {
    test('crea un bloque de dos horas por cada tramo del horario', () {
      controller.accessLogs.value = [];
      // 06:00 a 22:00 son 16 horas = 8 bloques.
      expect(controller.entradasPorFranja.keys.toList(),
          [6, 8, 10, 12, 14, 16, 18, 20]);
    });

    test('conserva las franjas vacías para leer el perfil del día', () {
      controller.accessLogs.value = [_acceso(18)];
      final franjas = controller.entradasPorFranja;

      expect(franjas.length, 8);
      expect(franjas[18], 1);
      expect(franjas[6], 0);
    });

    test('agrupa cada entrada en su bloque', () {
      controller.accessLogs.value = [
        _acceso(6),
        _acceso(7),
        _acceso(8),
        _acceso(19),
        _acceso(19),
      ];
      final franjas = controller.entradasPorFranja;

      expect(franjas[6], 2); // 06:15 y 07:15
      expect(franjas[8], 1);
      expect(franjas[18], 2);
    });

    test('las salidas no cuentan como visita', () {
      controller.accessLogs.value = [
        _acceso(10),
        _acceso(11, tipo: 'salida'),
      ];

      expect(controller.entradasPorFranja[10], 1);
      expect(controller.totalEntries.value, 0); // aún sin calcular
      controller.calculateStatistics();
      expect(controller.totalEntries.value, 1);
      expect(controller.totalExits.value, 1);
    });

    test('una entrada antes de abrir cae en el primer bloque', () {
      controller.accessLogs.value = [_acceso(5)];
      expect(controller.entradasPorFranja[6], 1);
      expect(controller.entradasPorFranja[20], 0);
    });

    test('una entrada después de cerrar cae en el último bloque', () {
      controller.accessLogs.value = [_acceso(23)];
      expect(controller.entradasPorFranja[20], 1);
      expect(controller.entradasPorFranja[6], 0);
    });

    test('ninguna entrada se pierde por caer fuera del horario', () {
      controller.accessLogs.value = [
        for (var h = 0; h < 24; h++) _acceso(h),
      ];
      final total = controller.entradasPorFranja.values
          .fold<int>(0, (suma, v) => suma + v);
      expect(total, 24);
    });
  });

  group('franjaPico', () {
    test('es la franja con más entradas', () {
      controller.accessLogs.value = [
        _acceso(7),
        _acceso(19),
        _acceso(19),
        _acceso(20),
      ];
      expect(controller.franjaPico, 18);
      expect(controller.franjaPicoLabel, '18:00 – 20:00');
      expect(controller.maximoPorFranja, 2);
    });

    test('es nulo si no hubo ninguna entrada', () {
      controller.accessLogs.value = [];
      expect(controller.franjaPico, isNull);
      expect(controller.franjaPicoLabel, '—');
    });
  });

  group('horario que cruza la medianoche', () {
    test('reparte los bloques desde la apertura', () {
      controller.ajustes.value = const GymSettingsModel(
        horaApertura: HoraDelDia(20, 0),
        horaCierre: HoraDelDia(2, 0),
      );
      controller.accessLogs.value = [_acceso(21), _acceso(1)];

      final franjas = controller.entradasPorFranja;
      expect(franjas.keys.toList(), [20, 22, 0]);
      expect(franjas[20], 1);
      expect(franjas[0], 1);
    });
  });
}
