import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/storage_service.dart';

void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'SUPABASE_BUCKET_NAME=users'));

  final s = StorageService.instance;

  test('la foto de un cliente apunta a su objeto, con la carpeta users/', () {
    // Así se guarda en la base: bucket "users" y, dentro, la carpeta "users".
    const guardada =
        'https://olhbhnjhducfxkffercu.supabase.co/storage/v1/object/public/'
        'users/users/1790234893346_1790234893663.jpg';
    final o = s.objeto(guardada)!;
    expect(o.bucket, 'users');
    expect(o.path, 'users/1790234893346_1790234893663.jpg');
    // El corte por "users/" que había antes daba una ruta vacía.
    expect(guardada.split('users/')[1], isEmpty);
  });

  test('entiende enlaces firmados y rutas crudas', () {
    final firmada = s.objeto(
        'https://x.supabase.co/storage/v1/object/sign/users/users/a.jpg?token=abc')!;
    expect(firmada.path, 'users/a.jpg');
    expect(s.objeto('users/a.jpg')!.bucket, 'users');
  });

  test('sin foto o con enlace ajeno, no hay nada que borrar', () {
    expect(s.objeto(null), isNull);
    expect(s.objeto(''), isNull);
    expect(s.objeto('https://otro-sitio.com/foto.jpg'), isNull);
  });
}
