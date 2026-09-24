/// Acepta un código de barras solo cuando la cámara lo leyó IGUAL varias
/// veces seguidas.
///
/// Antes se aceptaba el primer cuadro que se leía, y en un cuadro el código
/// puede estar a medio enfocar o chueco: el lector confunde un par de barras
/// y entrega otro número. Esos errores a veces pasan hasta el dígito
/// verificador (quedaron guardados productos con 7503002196526, 2544002796526
/// y 8503062726526, que son el mismo envase). Un error así casi nunca se
/// repite idéntico, así que pedir varias lecturas iguales lo descarta.
class ConfirmadorCodigo {
  ConfirmadorCodigo({this.ventana = const Duration(milliseconds: 1500)});

  /// Cuánto tiempo cuentan las lecturas de un mismo código.
  final Duration ventana;

  final _lecturas = <String, List<DateTime>>{};

  /// Registra una lectura de [codigo]. Devuelve el código cuando ya se leyó
  /// [necesarias] veces dentro de [ventana]; si no, null. Tras confirmar se
  /// empieza de cero.
  String? registrar(String codigo, {int necesarias = 3, DateTime? ahora}) {
    final momento = ahora ?? DateTime.now();

    // Se olvidan las lecturas viejas, de este y de los demás códigos.
    _lecturas.removeWhere((_, veces) {
      veces.removeWhere((vez) => momento.difference(vez) > ventana);
      return veces.isEmpty;
    });

    final veces = _lecturas.putIfAbsent(codigo, () => [])..add(momento);
    if (veces.length < necesarias) return null;

    _lecturas.clear();
    return codigo;
  }

  void reiniciar() => _lecturas.clear();
}

/// Si el dígito verificador de un EAN-13, EAN-8 o UPC-A (12 dígitos) cuadra.
/// Con otro largo, o con algo que no son dígitos, false.
bool digitoVerificadorValido(String codigo) {
  if (!RegExp(r'^\d+$').hasMatch(codigo)) return false;
  if (codigo.length != 8 && codigo.length != 12 && codigo.length != 13) {
    return false;
  }

  final digitos = codigo.split('').map(int.parse).toList();
  final verificador = digitos.removeLast();

  // De derecha a izquierda (sin el verificador): pesos 3, 1, 3, 1...
  var suma = 0;
  for (var i = 0; i < digitos.length; i++) {
    final desdeLaDerecha = digitos.length - 1 - i;
    suma += digitos[i] * (desdeLaDerecha.isEven ? 3 : 1);
  }
  return (10 - suma % 10) % 10 == verificador;
}
