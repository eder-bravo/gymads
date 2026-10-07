import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/app/data/models/sale_model.dart';
import 'package:gymads/app/data/repositories/sale_repository.dart';
import 'package:gymads/app/data/services/carrito_guardado.dart';
import 'package:gymads/app/modules/point_of_sale/controllers/point_of_sale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Ventas extends Fake implements SaleRepository {
  bool falla = false;
  @override
  Future<({Sale? sale, List<String> stockFallido})> createSale(
          Sale sale) async =>
      (sale: falla ? null : sale, stockFallido: const <String>[]);
}

class _Venta extends PointOfSaleController {
  _Venta(CarritoGuardado guardado, {_Ventas? ventas})
      : super(carritoGuardado: guardado, saleRepository: ventas);
  @override
  Future<void> loadProducts({bool silencioso = false}) async {}
}

class _CargaLenta extends CarritoGuardado {
  _CargaLenta() : super(gymId: 'gym', userId: 'usuario');
  final continuar = Completer<void>();
  @override
  Future<({List<SaleItem> items, double descuento, double impuesto})?>
      leer() async {
    await continuar.future;
    return super.leer();
  }
}

Product producto(String id, {double precio = 20}) => Product(
      id: id,
      name: id,
      description: '',
      categoryId: null,
      price: precio,
      stock: 100,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Get.reset);

  CarritoGuardado almacen(
          {String gym = 'gym',
          String usuario = 'usuario',
          String sucursal = 'sucursal'}) =>
      CarritoGuardado(gymId: gym, userId: usuario, branchId: sucursal);

  test('al recrear Venta recupera productos, cantidades y totales del disco',
      () async {
    final venta = _Venta(almacen());
    await venta.addProductToCart(producto('Agua'), quantity: 2);
    await venta.addProductToCart(producto('Barra', precio: 35));
    await venta.updateCartItemQuantity('Agua', 3);
    venta.applyDiscount(5);
    venta.setTaxRate(0.16);
    venta.setReceivedAmount(200);
    venta.setReferenciaPago('folio');
    await venta.guardarCarrito();
    venta.onClose();

    // Invalida la caché para que la recuperación use lo persistido.
    await (await SharedPreferences.getInstance()).reload();
    final regreso = _Venta(almacen());
    await regreso.restaurarCarrito();
    expect(regreso.totalUnidades, 4);
    expect(
        regreso.cartItems.map((item) => item.productName), ['Agua', 'Barra']);
    expect(regreso.cartItems.first.quantity, 3);
    expect(regreso.totalAmount, 95);
    expect(regreso.taxAmount, closeTo(15.2, 0.001));
    expect(regreso.discountAmount, 5);
    expect(regreso.finalAmount, closeTo(105.2, 0.001));
    expect(regreso.receivedAmount, 0);
    expect(regreso.referenciaPago, isEmpty);
    regreso.onClose();
  });

  test('volver enseguida espera las escrituras anteriores', () async {
    final venta = _Venta(almacen());
    await venta.addProductToCart(producto('Agua'));
    await venta.updateCartItemQuantity('Agua', 8);
    venta.removeFromCart('Agua');
    await venta.addProductToCart(producto('Barra'));
    final regreso = _Venta(almacen());
    await regreso.restaurarCarrito();
    expect(regreso.cartItems.single.productId, 'Barra');
    expect(regreso.totalUnidades, 1);
    venta.onClose();
    regreso.onClose();
  });

  test('no mezcla usuarios, gimnasios ni sucursales', () async {
    final venta = _Venta(almacen());
    await venta.addProductToCart(producto('Agua'));
    await venta.guardarCarrito();
    for (final otro in [
      almacen(usuario: 'otro'),
      almacen(gym: 'otro'),
      almacen(sucursal: 'otra')
    ]) {
      final regreso = _Venta(otro);
      await regreso.restaurarCarrito();
      expect(regreso.cartItems, isEmpty);
      regreso.onClose();
    }
    venta.onClose();
  });

  test('vaciar borra el borrador y el descuento', () async {
    final venta = _Venta(almacen());
    await venta.addProductToCart(producto('Agua'));
    venta.applyDiscount(5);
    venta.clearCart();
    await venta.guardarCarrito();
    expect(await almacen().leer(), isNull);
    expect(venta.finalAmount, 0);
    await venta.addProductToCart(producto('Barra'));
    expect(venta.finalAmount, 20);
    venta.onClose();
  });

  test('vaciar mientras carga no resucita el carrito anterior', () async {
    final lento = _CargaLenta();
    final anterior = _Venta(lento);
    // Guarda directamente para dejar pendiente la carga del controlador.
    await lento.guardar([
      SaleItem(
          productId: 'Agua',
          productName: 'Agua',
          quantity: 2,
          unitPrice: 20,
          total: 40)
    ], descuento: 0, impuesto: 0);
    final carga = anterior.restaurarCarrito();
    anterior.clearCart();
    lento.continuar.complete();
    await carga;
    expect(anterior.cartItems, isEmpty);
    expect(await lento.leer(), isNull);
    anterior.onClose();
  });

  test('la primera lectura espera la restauración y suma al carrito guardado',
      () async {
    final venta = _Venta(almacen());
    await venta.addProductToCart(producto('Agua'), quantity: 2);
    await venta.guardarCarrito();
    final regreso = _Venta(almacen());
    await regreso.addProductToCart(producto('Agua'));
    expect(regreso.totalUnidades, 3);
    venta.onClose();
    regreso.onClose();
  });

  for (final falla in [false, true]) {
    test('el cobro ${falla ? 'fallido conserva' : 'exitoso borra'} el borrador',
        () async {
      final ventas = _Ventas()..falla = falla;
      final venta = _Venta(almacen(), ventas: ventas);
      await venta.addProductToCart(producto('Agua'));
      venta.setReceivedAmount(20);
      expect(await venta.processSale(), !falla);
      final regreso = _Venta(almacen());
      await regreso.restaurarCarrito();
      expect(regreso.totalUnidades, falla ? 1 : 0);
      venta.onClose();
      regreso.onClose();
    });
  }

  test('un borrador dañado no rompe Venta', () async {
    SharedPreferences.setMockInitialValues({
      'pos_cart_${jsonEncode(['gym', 'sucursal', 'usuario'])}': '{roto',
    });
    final venta = _Venta(almacen());
    await venta.restaurarCarrito();
    expect(venta.cartItems, isEmpty);
    await venta.addProductToCart(producto('Agua'));
    await venta.guardarCarrito();
    expect((await almacen().leer())!.items.single.productId, 'Agua');
    venta.onClose();
  });
}
