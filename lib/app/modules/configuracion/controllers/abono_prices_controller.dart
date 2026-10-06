import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/repositories/abono_prices_repository.dart';
import 'package:gymads/app/data/repositories/codigo_abono_libre_repository.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../routes/app_pages.dart';
import '../../onboarding/controllers/onboarding_controller.dart';

/// Controlador de la pantalla de Precios de Abonos: un precio fijo por
/// unidad de periodo (día, semana, mes, año) para todo el gimnasio, y la
/// inscripción para clientes nuevos (vale también con abono libre).
class AbonoPricesController extends GetxController {
  /// [repository] es para las pruebas; en la app, el de siempre.
  AbonoPricesController(
      {AbonoPricesRepository? repository,
      CodigoAbonoLibreRepository? codigoRepository,
      Future<bool> Function(String modo)? guardarModo})
      : repository = repository ?? AbonoPricesRepository(),
        codigoRepository = codigoRepository ?? CodigoAbonoLibreRepository(),
        _guardarModo =
            guardarModo ?? OnboardingController.savePaymentModeAndSyncProfile;

  /// Guarda el modo de cobro al terminar el asistente (en pruebas, otro).
  final Future<bool> Function(String modo) _guardarModo;

  final AbonoPricesRepository repository;
  final CodigoAbonoLibreRepository codigoRepository;

  /// Si el gimnasio ya tiene código para el abono libre. Null: no se pudo
  /// saber (sin conexión) o aún no se pregunta.
  final hayCodigo = RxnBool();
  final guardandoCodigo = false.obs;

  final dayController = TextEditingController();
  final weekController = TextEditingController();
  final monthController = TextEditingController();
  final yearController = TextEditingController();
  final inscripcionController = TextEditingController();

  /// Código para abono libre al configurar el gimnasio (costos fijos):
  /// opcional, se escribe dos veces.
  final codigoNuevoController = TextEditingController();
  final codigoRepetidoController = TextEditingController();

  final isLoading = false.obs;
  final isSaving = false.obs;

  /// True cuando se llega desde el asistente de configuración inicial. Se lee
  /// una sola vez en onInit porque `Get.arguments` cambia al navegar fuera.
  late final bool isOnboarding;

  /// En el asistente, con "Abonos libres": solo se pregunta la inscripción y
  /// al continuar se guarda el modo libre.
  late final bool soloInscripcion;

  /// En el asistente con costos fijos se pide aquí el código del encargado,
  /// junto con los precios: es cuando se decide cobrar con costos fijos.
  bool get pideCodigoInicial => isOnboarding && !soloInscripcion;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    isOnboarding = args is Map && args['fromOnboarding'] == true;
    soloInscripcion = args is Map && args['soloInscripcion'] == true;
    loadPrices();
    // En el asistente no se configura: se hace después, en Configuración.
    if (!isOnboarding) cargarCodigo();
  }

  @override
  void onClose() {
    dayController.dispose();
    weekController.dispose();
    monthController.dispose();
    yearController.dispose();
    inscripcionController.dispose();
    codigoNuevoController.dispose();
    codigoRepetidoController.dispose();
    super.onClose();
  }

  Future<void> loadPrices() async {
    isLoading.value = true;
    try {
      final prices = await repository.getPrices();
      dayController.text = _format(prices.priceDay);
      weekController.text = _format(prices.priceWeek);
      monthController.text = _format(prices.priceMonth);
      yearController.text = _format(prices.priceYear);
      inscripcionController.text = _format(prices.priceInscripcion);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> cargarCodigo() async =>
      hayCodigo.value = await codigoRepository.hayCodigo();

  /// Crea o cambia el código del encargado para el abono libre.
  Future<bool> guardarCodigo(String pin) => _cambiarCodigo(pin,
      listo: hayCodigo.value == true ? 'Código cambiado' : 'Código creado');

  /// Quita el código: el mostrador ya no podrá cobrar abonos libres.
  Future<bool> quitarCodigo() => _cambiarCodigo(null, listo: 'Código quitado');

  Future<bool> _cambiarCodigo(String? pin, {required String listo}) async {
    guardandoCodigo.value = true;
    try {
      final ok = await codigoRepository.guardar(pin);
      if (!ok) {
        SnackbarHelper.error('Error', 'No se pudo guardar el código');
        return false;
      }
      hayCodigo.value = pin != null;
      SnackbarHelper.success('Listo', listo);
      return true;
    } finally {
      guardandoCodigo.value = false;
    }
  }

  /// En el asistente con abono libre: "No cobro inscripción".
  Future<bool> sinInscripcion() {
    inscripcionController.clear();
    return savePrices();
  }

  /// Guarda los cuatro precios y la inscripción. Un campo vacío borra ese
  /// precio (la inscripción vacía: no se cobra).
  Future<bool> savePrices() async {
    final prices = AbonoPricesModel(
      priceDay: _parse(dayController.text),
      priceWeek: _parse(weekController.text),
      priceMonth: _parse(monthController.text),
      priceYear: _parse(yearController.text),
      priceInscripcion: _parse(inscripcionController.text),
    );

    // En el asistente inicial elegir "abonos fijos" sin ningún precio dejaría
    // el modo fijo sin nada que ofrecer, así que se exige al menos uno.
    if (isOnboarding && !soloInscripcion && !prices.hasAnyPrice) {
      SnackbarHelper.error(
          'Falta un precio', 'Configura al menos un periodo para continuar');
      return false;
    }

    // El código del encargado (opcional) se revisa antes de guardar nada.
    final codigo = pideCodigoInicial ? codigoNuevoController.text.trim() : '';
    if (pideCodigoInicial) {
      final error = errorDeCodigo(codigo, codigoRepetidoController.text.trim(),
          opcional: true);
      if (error != null) {
        SnackbarHelper.error('Revisa el código', error);
        return false;
      }
    }

    isSaving.value = true;
    try {
      final success = await repository.savePrices(prices);

      if (!success) {
        SnackbarHelper.error('Error', 'No se pudieron guardar los precios');
        return false;
      }

      if (codigo.isNotEmpty && !await codigoRepository.guardar(codigo)) {
        SnackbarHelper.error('Error', 'No se pudo guardar el código');
        return false;
      }

      if (isOnboarding) {
        final modeSaved = await _guardarModo(
            soloInscripcion ? PaymentModes.libre : PaymentModes.fijo);
        if (!modeSaved) {
          SnackbarHelper.error('Error',
              'No se pudo guardar el modo de cobro. Intenta de nuevo.');
          return false;
        }
        Get.offAllNamed(Routes.HOME);
        return true;
      }

      SnackbarHelper.success('Guardado', 'Precios actualizados');
      return true;
    } finally {
      isSaving.value = false;
    }
  }

  /// Qué tiene mal el código, o null si está bien. Con [opcional], los dos
  /// vacíos también están bien (no se crea).
  static String? errorDeCodigo(String codigo, String repetido,
      {bool opcional = false}) {
    if (opcional && codigo.isEmpty && repetido.isEmpty) return null;
    if (!RegExp(r'^\d{4,6}$').hasMatch(codigo)) {
      return 'El código lleva de 4 a 6 números.';
    }
    if (codigo != repetido) return 'Los dos códigos no coinciden.';
    return null;
  }

  String _format(double? value) =>
      value == null ? '' : value.toStringAsFixed(2);

  double? _parse(String text) {
    final value = double.tryParse(text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }
}
