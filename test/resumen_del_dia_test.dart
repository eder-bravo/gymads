import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/modules/home/controllers/resumen_del_dia.dart';

import 'herramientas/resumen_de_prueba.dart';

void main() {
  test('totales, conteos y listas de hoy, de lo más reciente a lo más viejo',
      () async {
    final resumen = resumenDePrueba();
    await resumen.cargar(
        ingresos: true, entradas: true, vencen: true, precio: true);
    expect(resumen.ingresos.value, 4350);
    expect(resumen.ventas.value, 1);
    expect(resumen.abonos.value, 1);
    // Las 4 salidas no cuentan.
    expect(resumen.entradas.value, 38);
    expect(
        resumen.ultimasEntradas.first.accessTime
            .isAfter(resumen.ultimasEntradas.last.accessTime),
        isTrue);
    expect(resumen.cobros.map((c) => c.concepto),
        ['visita', 'producto', 'renovacion']);
    // Vencen en 7 días: ni la vencida ni la de dentro de 40 días.
    expect(resumen.vencen.value, 5);
    expect(resumen.porVencer.map((c) => c.name), [
      'Laura Gómez',
      'Pedro Sánchez',
      'Sofía Torres',
      'Diego Herrera',
      'Valeria Castro',
    ]);
    expect(resumen.activos.value, 6);
    expect(resumen.precioDia.value, 50);
    expect(resumen.cargando.value, isFalse);
  });

  test('si una fuente falla, las demás se muestran', () async {
    final resumen = ResumenDelDia(
      cobrosDeHoy: () async => throw Exception('sin conexión'),
      accesosDeHoy: () async => [],
      clientes: () async => [],
    );
    await resumen.cargar(ingresos: true, entradas: true, vencen: true);
    expect(resumen.ingresos.value, isNull);
    expect(resumen.entradas.value, 0);
    expect(resumen.vencen.value, 0);
    expect(resumen.cargando.value, isFalse);
  });

  test('solo pide lo que el rol puede ver', () async {
    var pedidos = 0;
    final resumen = ResumenDelDia(
      cobrosDeHoy: () async {
        pedidos++;
        return [];
      },
      accesosDeHoy: () async {
        pedidos++;
        return [];
      },
      clientes: () async {
        pedidos++;
        return [];
      },
      precioDelDia: () async {
        pedidos++;
        return 50;
      },
    );
    await resumen.cargar(ingresos: false, entradas: true, vencen: false);
    expect(pedidos, 1);
    expect(resumen.ingresos.value, isNull);
    expect(resumen.precioDia.value, isNull);
  });
}
