import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/services/ocr_referencia_service.dart';
import 'app_logger.dart';
import 'snackbar_helper.dart';
import 'plataforma_app.dart';

/// Métodos de pago que se pueden elegir al cobrar (Vender y Abonar), con el
/// valor que se guarda en `metodo_pago`.
const metodosDePago = [
  'efectivo',
  'tarjeta_debito',
  'tarjeta_credito',
  'transferencia',
];

/// Los que llevan folio o referencia de la operación.
const metodosConReferencia = {
  'tarjeta_debito',
  'tarjeta_credito',
  'transferencia',
};

String nombreMetodoDePago(String metodo) => switch (metodo) {
      'efectivo' => 'Efectivo',
      'tarjeta' => 'Tarjeta',
      'tarjeta_debito' => 'Tarjeta de débito',
      'tarjeta_credito' => 'Tarjeta de crédito',
      'transferencia' => 'Transferencia',
      'mixto' => 'Mixto',
      _ => metodo,
    };

IconData iconoMetodoDePago(String metodo) => switch (metodo) {
      'efectivo' => Icons.payments_outlined,
      'tarjeta' || 'tarjeta_debito' || 'tarjeta_credito' => Icons.credit_card,
      'transferencia' => Icons.account_balance_outlined,
      'mixto' => Icons.call_split,
      _ => Icons.payment,
    };

/// El folio o referencia de un pago con tarjeta o transferencia: se escribe
/// a mano o se lee de la foto del comprobante (cámara o galería).
///
/// Lo comparten Vender y Abonar, con el mismo campo en pantalla
/// (`CampoReferenciaPago`).
mixin ReferenciaDePago on GetxController {
  /// Lo escrito en el campo (o elegido de lo que leyó la foto).
  final referenciaTexto = ''.obs;

  /// Referencias que el OCR encontró en la foto, para que la persona elija.
  /// Se sugieren, nunca se dan por buenas: el campo sigue siendo editable.
  final RxList<String> referenciasSugeridas = <String>[].obs;

  final RxBool leyendoReferencia = false.obs;

  /// Si ya se leyó una foto. Distingue "no se reconoció nada" de "aún no se
  /// ha intentado".
  final RxBool referenciaEscaneada = false.obs;

  /// El campo de texto. Vive en el controlador porque el OCR necesita
  /// escribir en él y la vista se reconstruye.
  final TextEditingController referenciaCtrl = TextEditingController();

  /// Lo que se guarda: null si quedó vacío.
  String? get referenciaParaGuardar {
    final r = referenciaTexto.value.trim();
    return r.isEmpty ? null : r;
  }

  void setReferenciaPago(String valor) => referenciaTexto.value = valor;

  /// Toma o elige la foto del comprobante y le busca la referencia.
  ///
  /// La foto solo sirve para leerla: no se sube ni se guarda. La galería
  /// entra a propósito: muchos comprobantes llegan por mensajería y nunca
  /// pasan por la cámara.
  Future<void> escanearReferencia({required bool desdeCamara}) async {
    if (!PlataformaApp.ocrMovil) {
      SnackbarHelper.info('Referencia de pago',
          'Escribe el folio del comprobante en el campo de referencia.');
      return;
    }
    File? foto;
    try {
      final elegida = await ImagePicker().pickImage(
        source: desdeCamara ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        // Sin comprimir de más: la referencia suele ir en letra pequeña.
        maxWidth: 1600,
        imageQuality: 90,
        // Sin los metadatos, iPhone no pregunta por el acceso a Fotos.
        requestFullMetadata: false,
      );
      if (elegida == null) return;

      foto = File(elegida.path);
      leyendoReferencia.value = true;
      final candidatos = await OcrReferenciaService.extraerCandidatos(foto);
      referenciasSugeridas.assignAll(candidatos);
      referenciaEscaneada.value = true;

      // Una sola lectura clara se propone ya escrita. Sigue pudiendo
      // corregirse.
      if (candidatos.length == 1 && referenciaTexto.value.trim().isEmpty) {
        usarReferenciaSugerida(candidatos.first);
      }
    } catch (e) {
      AppLogger.error('ReferenciaDePago', 'Error al leer la referencia', e);
      SnackbarHelper.error('Error', 'No se pudo usar esa imagen.');
    } finally {
      leyendoReferencia.value = false;
      if (foto != null) await _borrarFotoTemporal(foto);
    }
  }

  /// Borra la copia que image_picker dejó en la caché de la app. Solo si
  /// está en el directorio temporal: nunca la foto original de la persona.
  Future<void> _borrarFotoTemporal(File foto) async {
    try {
      final temporal = await getTemporaryDirectory();
      if (foto.path.startsWith(temporal.path) && await foto.exists()) {
        await foto.delete();
      }
    } catch (_) {
      AppLogger.warning('ReferenciaDePago',
          'No se pudo borrar la foto temporal de la referencia');
    }
  }

  /// Pone en el campo una de las referencias que leyó el OCR.
  void usarReferenciaSugerida(String referencia) {
    referenciaTexto.value = referencia;
    referenciaCtrl.text = referencia;
    referenciaCtrl.selection =
        TextSelection.collapsed(offset: referencia.length);
  }

  /// Vacía el campo y lo que leyó el OCR (al cambiar de método o de cobro).
  void limpiarReferencia() {
    referenciaTexto.value = '';
    referenciaCtrl.clear();
    referenciasSugeridas.clear();
    referenciaEscaneada.value = false;
  }

  @override
  void onClose() {
    referenciaCtrl.dispose();
    super.onClose();
  }
}
