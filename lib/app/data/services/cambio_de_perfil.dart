import '../models/staff_profile_model.dart';

/// Qué cambió en el perfil de quien usa la app, visto desde su teléfono.
enum CambioDePerfil {
  sinCambios,

  /// Nombre, sucursal o datos del gimnasio: se actualiza en silencio.
  datos,

  /// El dueño le cambió el rol: otro menú, otros permisos y, si nunca usó
  /// ese rol, sus recorridos guiados.
  rol,

  /// Le retiraron el acceso (revocado) o lo eliminaron.
  sinAcceso,
}

/// Compara el perfil con el que trabaja la app ([actual]) con el que hay
/// ahora en la base ([nuevo], null si la fila ya no existe).
CambioDePerfil cambioDePerfil(
  StaffProfileModel actual,
  StaffProfileModel? nuevo,
) {
  if (nuevo == null || !nuevo.isActive) return CambioDePerfil.sinAcceso;
  if (nuevo.role != actual.role) return CambioDePerfil.rol;

  final mismosDatos = nuevo.displayName == actual.displayName &&
      nuevo.firstName == actual.firstName &&
      nuevo.lastName == actual.lastName &&
      nuevo.branchId == actual.branchId &&
      nuevo.gymName == actual.gymName &&
      nuevo.paymentMode == actual.paymentMode;
  return mismosDatos ? CambioDePerfil.sinCambios : CambioDePerfil.datos;
}
