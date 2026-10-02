import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/referencia_de_pago.dart';
import 'package:gymads/app/core/widgets/metodo_de_pago.dart';
import 'package:gymads/core/theme/app_theme.dart';

class _Cobro extends GetxController with ReferenciaDePago {}

void main() {
  test('débito y crédito van por separado, y llevan referencia', () {
    expect(metodosDePago,
        ['efectivo', 'tarjeta_debito', 'tarjeta_credito', 'transferencia']);
    expect(metodosConReferencia,
        {'tarjeta_debito', 'tarjeta_credito', 'transferencia'});
    expect(metodosConReferencia.contains('efectivo'), isFalse);
    expect(nombreMetodoDePago('tarjeta_debito'), 'Tarjeta de débito');
    expect(nombreMetodoDePago('tarjeta_credito'), 'Tarjeta de crédito');
  });

  test('la referencia se guarda sin espacios, o nada si quedó vacía', () {
    final cobro = _Cobro();
    expect(cobro.referenciaParaGuardar, isNull);
    cobro.setReferenciaPago('  004521 ');
    expect(cobro.referenciaParaGuardar, '004521');
    cobro.usarReferenciaSugerida('ABC123');
    expect(cobro.referenciaCtrl.text, 'ABC123');
    cobro.limpiarReferencia();
    expect(cobro.referenciaParaGuardar, isNull);
    expect(cobro.referenciaCtrl.text, isEmpty);
    cobro.onClose();
  });

  testWidgets('el campo se escribe a mano y ofrece escanear', (tester) async {
    final cobro = _Cobro();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.claro,
      home: Scaffold(body: CampoReferenciaPago(controlador: cobro)),
    ));
    await tester.enterText(find.byType(TextField), '778899');
    expect(cobro.referenciaParaGuardar, '778899');
    expect(find.text('Escanear referencia'), findsOneWidget);
    expect(find.byTooltip('Elegir de la galería'), findsOneWidget);
  });

  testWidgets('el selector marca el elegido y avisa al tocar otro',
      (tester) async {
    String? tocado;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.oscuro,
      home: Scaffold(
        body: SelectorMetodoPago(
          metodos: metodosDePago,
          elegido: 'efectivo',
          onElegir: (m) => tocado = m,
        ),
      ),
    ));
    await tester.tap(find.text('Tarjeta de crédito'));
    expect(tocado, 'tarjeta_credito');
  });
}
