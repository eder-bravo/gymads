import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/repositories/abono_prices_repository.dart';
import '../../../core/utils/snackbar_helper.dart';

/// Controlador de la pantalla de Precios de Abonos: un precio fijo por
/// unidad de periodo (día, semana, mes, año) para todo el gimnasio.
class AbonoPricesController extends GetxController {
  final AbonoPricesRepository repository = AbonoPricesRepository();

  final dayController = TextEditingController();
  final weekController = TextEditingController();
  final monthController = TextEditingController();
  final yearController = TextEditingController();

  final isLoading = false.obs;
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadPrices();
  }

  @override
  void onClose() {
    dayController.dispose();
    weekController.dispose();
    monthController.dispose();
    yearController.dispose();
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
    } finally {
      isLoading.value = false;
    }
  }

  /// Guarda los cuatro precios. Un campo vacío borra el precio de ese periodo.
  Future<bool> savePrices() async {
    isSaving.value = true;
    try {
      final success = await repository.savePrices(AbonoPricesModel(
        priceDay: _parse(dayController.text),
        priceWeek: _parse(weekController.text),
        priceMonth: _parse(monthController.text),
        priceYear: _parse(yearController.text),
      ));

      if (success) {
        SnackbarHelper.success('Guardado', 'Precios actualizados');
      } else {
        SnackbarHelper.error('Error', 'No se pudieron guardar los precios');
      }
      return success;
    } finally {
      isSaving.value = false;
    }
  }

  String _format(double? value) =>
      value == null ? '' : value.toStringAsFixed(2);

  double? _parse(String text) {
    final value = double.tryParse(text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }
}
