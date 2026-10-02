import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/cached_user_image.dart';
import 'package:gymads/app/data/services/fotos_de_clientes.dart';

void main() {
  // El bucket de las fotos sale de .env; en las pruebas, el de siempre.
  setUpAll(() => dotenv.testLoad(fileInput: 'SUPABASE_BUCKET_NAME=users'));
  tearDown(Get.reset);

  testWidgets('con la foto ya descargada se dibuja al instante, sin carga',
      (tester) async {
    final fotos = Get.put(FotosDeClientes());
    fotos.registrar('users/cliente_1.jpg', File('/tmp/cliente_1.jpg'));

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CachedUserImage(imageUrl: 'users/cliente_1.jpg', size: 120),
      ),
    ));

    // Sin esperar a nada: ni círculo de carga ni iniciales.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final caja = tester.widget<Container>(find.descendant(
        of: find.byType(CachedUserImage), matching: find.byType(Container)));
    final imagen = (caja.decoration! as BoxDecoration).image!.image;
    expect(imagen, FotosDeClientes.proveedor(File('/tmp/cliente_1.jpg')));
  });

  test('una foto que no se ha descargado no se inventa', () {
    final fotos = Get.put(FotosDeClientes());
    expect(fotos.archivo('users/otra.jpg'), isNull);
    expect(fotos.archivo(null), isNull);
  });

  test('la misma foto con distinto formato de enlace es la misma', () {
    final fotos = Get.put(FotosDeClientes());
    fotos.registrar('users/c.jpg', File('/tmp/c.jpg'));
    expect(fotos.archivo('users/c.jpg')?.path, '/tmp/c.jpg');
  });
}
