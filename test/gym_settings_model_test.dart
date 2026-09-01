import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/models/gym_settings_model.dart';

void main() {
  group('HoraDelDia', () {
    test('lee el tipo time de Postgres', () {
      final hora = HoraDelDia.parse('06:30:00', fallback: 0);
      expect(hora.hora, 6);
      expect(hora.minuto, 30);
      expect(hora.etiqueta, '06:30');
    });

    test('usa el respaldo si el valor viene vacío o nulo', () {
      expect(HoraDelDia.parse(null, fallback: 6).hora, 6);
      expect(HoraDelDia.parse('', fallback: 22).hora, 22);
    });

    test('vuelve a SQL en el formato que espera Postgres', () {
      expect(const HoraDelDia(6, 0).toSql(), '06:00:00');
      expect(const HoraDelDia(22, 30).toSql(), '22:30:00');
    });
  });

  group('GymSettingsModel.horasAbierto', () {
    test('horario normal dentro del mismo día', () {
      const ajustes = GymSettingsModel(
        horaApertura: HoraDelDia(6, 0),
        horaCierre: HoraDelDia(22, 0),
      );
      expect(ajustes.horasAbierto, 16);
    });

    test('cierre pasada la medianoche', () {
      const ajustes = GymSettingsModel(
        horaApertura: HoraDelDia(6, 0),
        horaCierre: HoraDelDia(1, 0),
      );
      expect(ajustes.horasAbierto, 19);
    });

    test('apertura igual al cierre se toma como 24 horas', () {
      const ajustes = GymSettingsModel(
        horaApertura: HoraDelDia(0, 0),
        horaCierre: HoraDelDia(0, 0),
      );
      expect(ajustes.horasAbierto, 24);
    });
  });

  group('GymSettingsModel', () {
    test('por defecto no registra salidas', () {
      // El valor conservador: la app se comporta como antes hasta que el
      // dueño active las salidas a propósito.
      expect(const GymSettingsModel().registrarSalidas, isFalse);
    });

    test('toJson y fromJson son simétricos', () {
      const original = GymSettingsModel(
        registrarSalidas: true,
        horaApertura: HoraDelDia(7, 30),
        horaCierre: HoraDelDia(23, 0),
      );
      final vuelta = GymSettingsModel.fromJson(original.toJson());

      expect(vuelta.registrarSalidas, isTrue);
      expect(vuelta.horaApertura, const HoraDelDia(7, 30));
      expect(vuelta.horaCierre, const HoraDelDia(23, 0));
    });
  });
}
