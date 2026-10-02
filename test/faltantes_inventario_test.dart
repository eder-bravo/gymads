import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/app/modules/inventario/controllers/inventario_controller.dart';

Product _producto(String nombre, {required int stock, required double precio}) {
  return Product(
    id: nombre,
    name: nombre,
    description: '',
    categoryId: null,
    price: precio,
    stock: stock,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  late InventarioController controller;

  setUp(() => controller = InventarioController());

  group('faltantes', () {
    test('un stock negativo son unidades vendidas sin existencias', () {
      controller.products.value = [
        _producto('Agua', stock: -3, precio: 15),
        _producto('Barra', stock: 10, precio: 40),
      ];

      expect(controller.hayFaltantes, isTrue);
      expect(controller.productosConFaltante.length, 1);
      expect(controller.unidadesFaltantes, 3);
      expect(controller.valorFaltante, 45.0);
    });

    test('suma varios productos en falta', () {
      controller.products.value = [
        _producto('Agua', stock: -3, precio: 15),
        _producto('Proteína', stock: -4, precio: 20.75),
        _producto('Barra', stock: 2, precio: 40),
      ];

      expect(controller.productosConFaltante.length, 2);
      expect(controller.unidadesFaltantes, 7);
      expect(controller.valorFaltante, closeTo(45 + 83, 0.001));
    });

    test('el stock en cero no es un faltante', () {
      // Agotado no es lo mismo que deber unidades: cero significa que no hay,
      // negativo que ya se vendieron.
      controller.products.value = [_producto('Agua', stock: 0, precio: 15)];

      expect(controller.hayFaltantes, isFalse);
      expect(controller.unidadesFaltantes, 0);
      expect(controller.valorFaltante, 0);
    });

    test('sin faltantes no hay nada que reponer', () {
      controller.products.value = [
        _producto('Agua', stock: 9, precio: 15),
        _producto('Barra', stock: 1, precio: 40),
      ];

      expect(controller.hayFaltantes, isFalse);
      expect(controller.productosConFaltante, isEmpty);
    });
  });

  group('filtro de faltantes', () {
    test('deja en la lista solo lo que hay que reponer', () {
      controller.products.value = [
        _producto('Agua', stock: -3, precio: 15),
        _producto('Barra', stock: 10, precio: 40),
      ];
      controller.filterProducts();
      expect(controller.filteredProducts.length, 2);

      controller.toggleSoloFaltantes();
      expect(controller.filteredProducts.length, 1);
      expect(controller.filteredProducts.first.name, 'Agua');

      controller.toggleSoloFaltantes();
      expect(controller.filteredProducts.length, 2);
    });
  });
}
