import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/auth_utils.dart';
import '../../../core/utils/fallo_al_guardar.dart';
import '../../../core/utils/referencia_de_pago.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/formulario.dart';
import '../../../core/widgets/metodo_de_pago.dart';
import '../../../global_widgets/app_header.dart';
import '../../ingresos/controllers/ingresos_controller.dart';

/// Lo que se manda al registrar una visita.
typedef DatosVisita = ({
  String? nombre,
  double monto,
  String metodoPago,
  String? referencia,
});

/// Registra la visita y devuelve null si salió bien, o el error para mostrar.
typedef RegistrarVisita = Future<String?> Function(DatosVisita datos);

/// Abre "Cobrar visita". [precioDia] es el precio por día configurado: llena
/// el monto, que se puede cambiar.
Future<void> abrirCobrarVisita({double? precioDia}) async {
  final double? cobrada;
  if (PlataformaApp.pantallaGrande) {
    // En una ventana no hay ruta que libere el controlador al cerrarse.
    Get.put(CobrarVisitaController(precioDia: precioDia));
    try {
      cobrada = await abrirFormulario<double>(() => const CobrarVisitaView());
    } finally {
      Get.delete<CobrarVisitaController>();
    }
  } else {
    cobrada = await Get.to<double>(
      () => const CobrarVisitaView(),
      binding: BindingsBuilder(() {
        Get.put(CobrarVisitaController(precioDia: precioDia));
      }),
    );
  }
  if (cobrada != null) {
    SnackbarHelper.success(
        'Visita cobrada', '${dinero(cobrada)} · entrada anotada');
  }
}

/// Registra la visita en la base de datos: su cobro en Ingresos y su entrada
/// en Entradas, en una sola operación (`registrar_visita`).
Future<String?> registrarVisitaEnSupabase(DatosVisita d) async {
  try {
    await Supabase.instance.client.rpc('registrar_visita', params: {
      'p_nombre': d.nombre,
      'p_monto': d.monto,
      'p_metodo_pago': d.metodoPago,
      'p_referencia': d.referencia,
      'p_staff': AuthUtils.getStaffIdentifier(),
    }).timeout(limiteAlGuardar);
    // Ingresos, si está abierto; Entradas y los demás teléfonos se enteran
    // solos por la actualización en vivo.
    unawaited(IngresosController.refreshIngresosGlobally());
    return null;
  } on PostgrestException catch (e) {
    AppLogger.error('CobrarVisita', 'No se registró la visita', e);
    if (e.message.contains('sin_permiso')) {
      return 'Tu rol no puede cobrar visitas.';
    }
    return mensajeDeFallo(e,
        generico: 'No se pudo cobrar la visita. Intenta de nuevo.');
  } catch (e) {
    AppLogger.error('CobrarVisita', 'No se registró la visita', e);
    return mensajeDeFallo(e,
        generico: 'No se pudo cobrar la visita. Intenta de nuevo.');
  }
}

/// Cobrar el día a quien viene a probar, sin registrarlo como cliente.
class CobrarVisitaController extends GetxController with ReferenciaDePago {
  CobrarVisitaController({this.precioDia, RegistrarVisita? registrar})
      : _registrar = registrar ?? registrarVisitaEnSupabase;

  final double? precioDia;
  final RegistrarVisita _registrar;

  final nombreCtrl = TextEditingController();
  late final montoCtrl = TextEditingController(
    text: precioDia == null || precioDia! <= 0 ? '' : _formatear(precioDia!),
  );

  final metodoPago = 'efectivo'.obs;
  final guardando = false.obs;
  final error = RxnString();

  bool get usaReferenciaPago => metodosConReferencia.contains(metodoPago.value);

  static String _formatear(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  double? get monto => double.tryParse(montoCtrl.text.trim());

  void setMetodoPago(String metodo) {
    metodoPago.value = metodo;
    limpiarReferencia();
  }

  /// Devuelve el monto cobrado si salió bien (para el aviso), o null.
  Future<double?> cobrar() async {
    error.value = null;
    final m = monto;
    if (m == null || m <= 0) {
      error.value = 'Escribe el monto de la visita';
      return null;
    }

    guardando.value = true;
    try {
      final nombre = nombreCtrl.text.trim();
      final fallo = await _registrar((
        nombre: nombre.isEmpty ? null : nombre,
        monto: m,
        metodoPago: metodoPago.value,
        referencia: usaReferenciaPago ? referenciaParaGuardar : null,
      ));
      if (fallo != null) {
        error.value = fallo;
        return null;
      }
      return m;
    } finally {
      guardando.value = false;
    }
  }

  @override
  void onClose() {
    nombreCtrl.dispose();
    montoCtrl.dispose();
    super.onClose();
  }
}

class CobrarVisitaView extends GetView<CobrarVisitaController> {
  const CobrarVisitaView({super.key});

  Future<void> _cobrar(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final cobrada = await controller.cobrar();
    if (cobrada != null) Get.back(result: cobrada);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Obx(() {
      final guardando = controller.guardando.value;
      return PopScope(
        canPop: !guardando,
        child: ScaffoldAdaptable(
          anchoMaximo: 760,
          backgroundColor: c.backgroundColor,
          appBar: GymAppBar(
            title: 'Cobrar visita',
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cerrar',
              onPressed: guardando ? null : () => Get.back(),
            ),
          ),
          body: SafeArea(
            bottom: false,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const TituloSeccion(
                  'Visita de un día',
                  detalle: 'No se registra como cliente.',
                ),
                TextField(
                  controller: controller.nombreCtrl,
                  enabled: !guardando,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: c.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Nombre (opcional)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('monto_visita'),
                  controller: controller.montoCtrl,
                  enabled: !guardando,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: TextStyle(color: c.textPrimary, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Monto *',
                    prefixIcon: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: Text('\$',
                          style: TextStyle(color: c.titleColor, fontSize: 18)),
                    ),
                    helperText: controller.precioDia == null ||
                            controller.precioDia! <= 0
                        ? 'Escribe cuánto cobrarás por esta visita.'
                        : 'Se usa el precio por día. Puedes cambiarlo para esta visita.',
                    helperMaxLines: 6,
                  ),
                ),
                const SizedBox(height: 20),
                Text('Método de pago',
                    style: TextStyle(color: c.textSecondary, fontSize: 14)),
                const SizedBox(height: 10),
                SelectorMetodoPago(
                  metodos: metodosDePago,
                  elegido: controller.metodoPago.value,
                  onElegir: guardando ? (_) {} : controller.setMetodoPago,
                ),
                if (controller.usaReferenciaPago) ...[
                  const SizedBox(height: 16),
                  CampoReferenciaPago(controlador: controller),
                ],
                if (controller.error.value != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(controller.error.value!,
                            style: const TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: PieDeFormulario(
            alCancelar: guardando ? null : () => Get.back(),
            child: BotonGuardar(
              texto: 'Cobrar visita',
              icono: Icons.confirmation_number_outlined,
              guardando: guardando,
              onPressed: () => _cobrar(context),
            ),
          ),
        ),
      );
    });
  }
}
