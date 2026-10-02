/// Validar el correo al crear una cuenta: solo se aceptan correos de
/// proveedores reales (Gmail, Outlook, Yahoo, iCloud…) y de escuelas o
/// gobierno (.edu, .edu.mx, .gob.mx). Cualquier otro no pasa.
///
/// Es al revés que una lista de correos temporales, que siempre va detrás
/// porque salen dominios nuevos todos los días. Esta lista es corta y casi no
/// cambia.
///
/// La misma regla está en la base de datos (`correo_permitido`, migración
/// solo_correos_reales), que rechaza la cuenta aunque se cree desde fuera de
/// la app: si cambia una, cambia la otra.
library;

final _formato = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$");

/// El dominio del correo, en minúsculas ("juan@Gmail.com" → "gmail.com").
String? dominioDe(String correo) {
  final t = correo.trim().toLowerCase();
  final arroba = t.lastIndexOf('@');
  if (arroba < 1 || arroba == t.length - 1) return null;
  return t.substring(arroba + 1);
}

/// Proveedores de correo que se aceptan.
const dominiosPermitidos = <String>{
  // Google
  'gmail.com', 'googlemail.com',
  // Microsoft
  'outlook.com', 'outlook.es', 'outlook.com.mx',
  'hotmail.com', 'hotmail.es', 'hotmail.com.mx',
  'live.com', 'live.com.mx', 'msn.com',
  // Yahoo
  'yahoo.com', 'yahoo.com.mx', 'yahoo.es', 'ymail.com',
  // Apple
  'icloud.com', 'me.com', 'mac.com',
  // Otros conocidos
  'proton.me', 'protonmail.com', 'aol.com', 'prodigy.net.mx',
};

/// Escuelas y gobierno: .edu, .edu.xx (edu.mx…), .gob.mx y .gov los da solo el
/// registro oficial a instituciones, no se compran como cualquier dominio.
final _institucional = RegExp(r'\.(edu(\.[a-z]{2})?|gob\.mx|gov)$');

/// Si el correo es de un proveedor real o de una escuela o gobierno.
bool esCorreoPermitido(String correo) {
  final dominio = dominioDe(correo);
  if (dominio == null) return false;
  return dominiosPermitidos.contains(dominio) ||
      _institucional.hasMatch(dominio);
}

/// El mensaje cuando el correo no es de un proveedor aceptado.
const mensajeCorreoNoPermitido = 'Usa un correo válido';

/// El error para mostrar bajo el campo, o null si el correo sirve.
String? validarCorreoDeRegistro(String? valor) {
  final correo = (valor ?? '').trim();
  if (correo.isEmpty) return 'El correo es requerido';
  if (!_formato.hasMatch(correo)) return 'Ingresa un correo válido';
  if (!esCorreoPermitido(correo)) return mensajeCorreoNoPermitido;
  return null;
}

/// Errores de dedo frecuentes en los dominios más usados.
const _correcciones = {
  'gmial.com': 'gmail.com',
  'gmal.com': 'gmail.com',
  'gamil.com': 'gmail.com',
  'gmai.com': 'gmail.com',
  'gmaill.com': 'gmail.com',
  'gnail.com': 'gmail.com',
  'gmail.co': 'gmail.com',
  'gmail.con': 'gmail.com',
  'gmail.cm': 'gmail.com',
  'gmail.om': 'gmail.com',
  'hotmial.com': 'hotmail.com',
  'hotmal.com': 'hotmail.com',
  'hotmai.com': 'hotmail.com',
  'hotmil.com': 'hotmail.com',
  'hotmail.con': 'hotmail.com',
  'hotmail.co': 'hotmail.com',
  'outlok.com': 'outlook.com',
  'outloo.com': 'outlook.com',
  'outlook.con': 'outlook.com',
  'outlook.co': 'outlook.com',
  'yaho.com': 'yahoo.com',
  'yahooo.com': 'yahoo.com',
  'yahoo.con': 'yahoo.com',
  'yahoo.com.mz': 'yahoo.com.mx',
  'icloud.con': 'icloud.com',
  'iclod.com': 'icloud.com',
  'live.con': 'live.com',
};

/// "¿Quisiste decir juan@gmail.com?": el correo corregido si el dominio
/// parece un error de dedo, o null si se ve bien. No bloquea: solo sugiere.
String? sugerenciaDeCorreo(String? valor) {
  final correo = (valor ?? '').trim();
  final dominio = dominioDe(correo);
  if (dominio == null) return null;
  var corregido = _correcciones[dominio];
  if (corregido == null && dominio.endsWith('.con')) {
    corregido = '${dominio.substring(0, dominio.length - 4)}.com';
  }
  if (corregido == null) return null;
  final usuario = correo.substring(0, correo.lastIndexOf('@'));
  return '$usuario@$corregido';
}
