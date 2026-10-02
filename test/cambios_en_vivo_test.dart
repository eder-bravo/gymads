import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/services/cambios_en_vivo_service.dart';

class _Pantalla extends GetxController with RecargaEnVivoMixin {
  _Pantalla(Set<TablaEnVivo> tablas, {this.duracion = Duration.zero}) {
    recargarAlCambiar(tablas, () async {
      recargas++;
      await Future.delayed(duracion);
    });
  }

  final Duration duracion;
  int recargas = 0;
}

void main() {
  late CambiosEnVivoService servicio;

  setUp(() {
    servicio = Get.put(CambiosEnVivoService(seguirSesion: false));
  });
  tearDown(Get.reset);

  testWidgets(
      'una ráfaga de cambios se avisa una sola vez, con todas las tablas',
      (tester) async {
    var avisos = 0, ingresos = 0, productos = 0;
    CambiosEnVivoService.cambiosEn(TablaEnVivo.values.toSet())
        .listen((_) => avisos++);
    CambiosEnVivoService.cambiosEn({TablaEnVivo.ingresos})
        .listen((_) => ingresos++);
    CambiosEnVivoService.cambiosEn({TablaEnVivo.productos})
        .listen((_) => productos++);

    // Una venta: se inserta el ingreso y baja el stock del producto.
    servicio.anotar([TablaEnVivo.ingresos]);
    await tester.pump(const Duration(milliseconds: 300));
    servicio.anotar([TablaEnVivo.productos]);
    await tester.pump(const Duration(milliseconds: 300));
    servicio.anotar([TablaEnVivo.productos]);

    await tester.pump(const Duration(seconds: 2));
    expect(avisos, 1);
    expect(ingresos, 1);
    expect(productos, 1);
  });

  testWidgets('cada pantalla recarga solo con los cambios de sus tablas',
      (tester) async {
    final clientes = _Pantalla({TablaEnVivo.clientes});
    final pos = _Pantalla({TablaEnVivo.productos, TablaEnVivo.categorias});

    servicio.anotar([TablaEnVivo.clientes]);
    await tester.pump(const Duration(seconds: 2));
    expect(clientes.recargas, 1);
    expect(pos.recargas, 0);

    servicio.anotar([TablaEnVivo.categorias]);
    await tester.pump(const Duration(seconds: 2));
    expect(clientes.recargas, 1);
    expect(pos.recargas, 1);
  });

  testWidgets(
      'un cambio durante una recarga provoca una recarga más, no dos a la vez',
      (tester) async {
    final pantalla =
        _Pantalla({TablaEnVivo.ingresos}, duracion: const Duration(seconds: 3));

    servicio.anotar([TablaEnVivo.ingresos]);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(pantalla.recargas, 1);

    // Llegan dos avisos mientras la primera recarga sigue en curso.
    servicio.anotar([TablaEnVivo.ingresos]);
    await tester.pump(const Duration(milliseconds: 1100));
    servicio.anotar([TablaEnVivo.ingresos]);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(pantalla.recargas, 1);

    await tester.pump(const Duration(seconds: 10));
    expect(pantalla.recargas, 2);
  });

  testWidgets('al cerrar la pantalla deja de recargar', (tester) async {
    final pantalla = _Pantalla({TablaEnVivo.accesos});
    pantalla.onDelete();

    servicio.anotar([TablaEnVivo.accesos]);
    await tester.pump(const Duration(seconds: 2));
    expect(pantalla.recargas, 0);
  });

  test('sin el servicio (pruebas de otras pantallas) no avisa', () async {
    Get.reset();
    final avisos = <void>[];
    final sub = CambiosEnVivoService.cambiosEn({TablaEnVivo.clientes})
        .listen(avisos.add);
    await Future<void>.delayed(Duration.zero);
    expect(avisos, isEmpty);
    await sub.cancel();
  });
}
