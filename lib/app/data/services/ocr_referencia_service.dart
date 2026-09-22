import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/utils/app_logger.dart';

/// Lee la referencia de pago de la foto de un comprobante.
///
/// Corre sobre la foto ya tomada, no sobre el vídeo en vivo: una imagen fija
/// y encuadrada por la persona se reconoce mucho mejor que fotogramas en
/// movimiento. La foto solo se usa para leerla; no se guarda.
///
/// **Sugiere, no decide.** Una referencia bancaria es una cadena larga sobre
/// letra pequeña, muchas veces en una captura de pantalla: el reconocimiento
/// falla a veces. Por eso devuelve una lista de candidatos para que la
/// persona elija, y el campo de texto sigue siendo editable.
///
/// Todo ocurre en el teléfono: no hace falta conexión y la imagen no sale
/// del dispositivo para analizarse.
class OcrReferenciaService {
  OcrReferenciaService._();

  /// Palabras que suelen preceder a la referencia en un comprobante. Una
  /// línea que las contenga sube de prioridad.
  static const List<String> _pistas = [
    'referencia',
    'folio',
    'autorizacion',
    'autorización',
    'clave de rastreo',
    'rastreo',
    'operacion',
    'operación',
    'no. de',
    'num',
  ];

  /// Extrae los candidatos a referencia de la imagen de [archivo].
  ///
  /// Vienen ordenados: primero los que estaban en una línea que mencionaba
  /// "referencia" o "folio", después el resto por longitud (las referencias
  /// suelen ser largas). Lista vacía si no reconoce nada aprovechable.
  static Future<List<String>> extraerCandidatos(File archivo) async {
    final lector = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final reconocido =
          await lector.processImage(InputImage.fromFilePath(archivo.path));

      final conPista = <String>[];
      final sinPista = <String>[];

      for (final bloque in reconocido.blocks) {
        for (final linea in bloque.lines) {
          final texto = linea.text;
          final esPista = _tienePista(texto);

          for (final candidato in _candidatosDeLinea(texto)) {
            if (esPista) {
              conPista.add(candidato);
            } else {
              sinPista.add(candidato);
            }
          }
        }
      }

      // Los más largos primero dentro de cada grupo: entre "12" y
      // "0123456789012", la referencia es casi siempre la segunda.
      sinPista.sort((a, b) => b.length.compareTo(a.length));

      final resultado = <String>[];
      for (final c in [...conPista, ...sinPista]) {
        if (!resultado.contains(c)) resultado.add(c);
      }

      return resultado.take(6).toList();
    } catch (e) {
      AppLogger.error(
          'OcrReferenciaService', 'Error al leer el comprobante', e);
      return const [];
    } finally {
      // Libera el modelo nativo. Sin esto se filtra memoria en cada foto.
      await lector.close();
    }
  }

  static bool _tienePista(String texto) {
    final enMinusculas = texto.toLowerCase();
    return _pistas.any(enMinusculas.contains);
  }

  /// Saca de una línea los trozos que podrían ser una referencia.
  ///
  /// Se piden al menos 6 caracteres y que haya algún dígito: así se descartan
  /// las palabras sueltas del comprobante ("TRANSFERENCIA", "BANCO") sin
  /// perder las referencias alfanuméricas, que existen.
  static List<String> _candidatosDeLinea(String linea) {
    final trozos = linea.split(RegExp(r'[\s:;,|]+'));
    final candidatos = <String>[];

    for (final trozo in trozos) {
      final limpio = trozo.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
      if (limpio.length < 6) continue;
      if (!RegExp(r'[0-9]').hasMatch(limpio)) continue;

      // Un importe no es una referencia.
      if (RegExp(r'^\d{1,3}([.,]\d{3})*[.,]\d{2}$').hasMatch(trozo)) continue;

      candidatos.add(limpio);
    }

    return candidatos;
  }
}
