const mensajeLectorOcupado = 'Otro dispositivo está configurando este lector. '
    'Espera a que termine o cierra la configuración en ese dispositivo '
    'y vuelve a buscar.';

class LectorOcupadoException implements Exception {
  const LectorOcupadoException();

  @override
  String toString() => mensajeLectorOcupado;
}

/// Datos de fabricante del anuncio GymOne: compañía reservada 0xFFFF,
/// firma GO, versión del formato y bandera de reserva. No expone identidad
/// del teléfono, del gimnasio ni el token de la sesión.
bool lectorOcupadoEnAnuncio(Map<int, List<int>> fabricante) {
  final datos = fabricante[0xffff];
  return datos != null &&
      datos.length == 4 &&
      datos[0] == 0x47 &&
      datos[1] == 0x4f &&
      datos[2] == 1 &&
      datos[3] == 1;
}
