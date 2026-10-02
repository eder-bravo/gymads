import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/models/staff_profile_model.dart';
import 'package:gymads/app/data/services/cambio_de_perfil.dart';

StaffProfileModel perfil({
  String rol = 'mostrador',
  String nombre = 'Gael',
  bool activo = true,
}) =>
    StaffProfileModel(
      id: 'p1',
      userId: 'u1',
      gymId: 'g1',
      branchId: 'b1',
      role: rol,
      displayName: nombre,
      firstName: nombre,
      isActive: activo,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      gymName: 'campus',
    );

void main() {
  group('Qué cambió en el perfil de quien usa la app', () {
    test('nada', () {
      expect(cambioDePerfil(perfil(), perfil()), CambioDePerfil.sinCambios);
    });

    test('solo el nombre: se actualiza en silencio', () {
      expect(cambioDePerfil(perfil(), perfil(nombre: 'Gael B.')),
          CambioDePerfil.datos);
    });

    test('el dueño le cambió el rol', () {
      expect(
          cambioDePerfil(perfil(), perfil(rol: 'almacen')), CambioDePerfil.rol);
    });

    test('le revocaron el acceso', () {
      expect(cambioDePerfil(perfil(), perfil(activo: false)),
          CambioDePerfil.sinAcceso);
    });

    test('lo eliminaron (la fila ya no existe)', () {
      expect(cambioDePerfil(perfil(), null), CambioDePerfil.sinAcceso);
    });
  });
}
