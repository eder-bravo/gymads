import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/global_widgets/tarjeta_del_formulario.dart';

void main() {
  group('alta', () {
    test('vacía → lista → cambiada → misma', () {
      final ctrl = TextEditingController();
      final t = TarjetaDelFormulario(ctrl);
      expect(t.estado, EstadoTarjeta.vacia);

      expect(t.pasar('A'), ResultadoPase.asignada);
      expect(t.estado, EstadoTarjeta.lista);

      expect(t.pasar('B'), ResultadoPase.cambiada);
      expect(t.estado, EstadoTarjeta.cambiada);
      expect(ctrl.text, 'B');

      expect(t.pasar('B'), ResultadoPase.misma);
      expect(t.estado, EstadoTarjeta.cambiada);
    });

    test('quitar y volver a pasar empieza de nuevo como "lista"', () {
      final t = TarjetaDelFormulario(TextEditingController());
      t.pasar('A');
      t.pasar('B');
      t.quitar();
      expect(t.estado, EstadoTarjeta.vacia);
      t.pasar('C');
      expect(t.estado, EstadoTarjeta.lista);
    });

    test('la que trae el aviso "Registrar" ya está lista', () {
      final t = TarjetaDelFormulario(TextEditingController(text: 'A'));
      expect(t.estado, EstadoTarjeta.lista);
      expect(t.editando, isFalse);
    });
  });

  group('edición', () {
    test('sin cambio → nueva → deshacer', () {
      final ctrl = TextEditingController(text: 'A');
      final t = TarjetaDelFormulario(ctrl, original: 'A');
      expect(t.estado, EstadoTarjeta.sinCambio);

      expect(t.pasar('B'), ResultadoPase.cambiada);
      expect(t.estado, EstadoTarjeta.nueva);

      t.deshacer();
      expect(ctrl.text, 'A');
      expect(t.estado, EstadoTarjeta.sinCambio);
    });

    test('quitar → deshacer', () {
      final ctrl = TextEditingController(text: 'A');
      final t = TarjetaDelFormulario(ctrl, original: 'A');
      t.quitar();
      expect(t.estado, EstadoTarjeta.quitada);
      t.deshacer();
      expect(t.estado, EstadoTarjeta.sinCambio);
    });

    test('pasar la suya otra vez la recupera', () {
      final t = TarjetaDelFormulario(TextEditingController(text: 'A'),
          original: 'A');
      t.pasar('B');
      expect(t.esLaOriginal('A'), isTrue);
      expect(t.pasar('A'), ResultadoPase.cambiada);
      expect(t.estado, EstadoTarjeta.sinCambio);
    });

    test('un cliente sin tarjeta se edita como un alta', () {
      final t = TarjetaDelFormulario(TextEditingController(), original: '');
      expect(t.editando, isFalse);
      expect(t.estado, EstadoTarjeta.vacia);
    });
  });
}
