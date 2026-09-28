import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cuánto se espera a que un guardado (cliente, producto, foto) termine. Sin
/// límite, con mala señal la petición podía quedarse colgada hasta un minuto
/// sin que en pantalla pasara nada.
const limiteAlGuardar = Duration(seconds: 25);

/// Un guardado que no se pudo hacer, con un mensaje para quien usa la app
/// (sin términos técnicos).
class GuardadoFallido implements Exception {
  const GuardadoFallido(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

const _mensajeTardo =
    'No se pudo completar el guardado. Revisa tu conexión e intenta de nuevo.';
const _mensajeSinConexion =
    'No hay conexión a internet. Revisa tu conexión e intenta de nuevo.';

/// El mensaje para [e]: el propio si es un [GuardadoFallido]; uno de
/// conexión si fue la red o se agotó [limiteAlGuardar]; si no, [generico].
String mensajeDeFallo(Object e, {required String generico}) {
  if (e is GuardadoFallido) return e.mensaje;
  if (e is TimeoutException) return _mensajeTardo;
  if (esFalloDeConexion(e)) return _mensajeSinConexion;
  return generico;
}

/// Si [e] es porque no hay internet (o se cortó a medio camino).
bool esFalloDeConexion(Object e) {
  if (e is SocketException || e is http.ClientException) return true;
  final texto = e.toString().toLowerCase();
  return texto.contains('socketexception') ||
      texto.contains('failed host lookup') ||
      texto.contains('network is unreachable') ||
      texto.contains('connection closed') ||
      texto.contains('connection reset') ||
      texto.contains('clientexception');
}

/// El índice único que [e] violó (código 23505 de Postgres), o null si [e]
/// no es eso. Sirve para distinguir "esa tarjeta ya es de otro cliente" de
/// "ese número ya existe".
String? restriccionUnicaViolada(Object e) {
  if (e is! PostgrestException || e.code != '23505') return null;
  final texto = '${e.message} ${e.details ?? ''}';
  final nombre = RegExp(r'"([a-z0-9_]+)"').firstMatch(texto)?.group(1);
  return nombre ?? '';
}
