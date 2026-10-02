import 'package:get/get.dart';

import '../models/gym_settings_model.dart';
import '../repositories/gym_settings_repository.dart';

/// Caché en memoria de la configuración de accesos del gimnasio.
///
/// La necesitan sitios que no pueden esperar a una consulta: el lector RFID
/// tiene que decidir entrada o salida en el momento del pase. Se carga una
/// vez y se vuelve a leer solo cuando Configuración la guarda.
///
/// Mientras no esté cargada devuelve los valores por defecto, que son los
/// conservadores: solo entradas, como se comportaba la app hasta ahora.
class GymSettingsService extends GetxService {
  static GymSettingsService get to => Get.find();

  /// Configuración actual, sin exigir que el servicio esté registrado.
  ///
  /// El registro de accesos por RFID no puede caerse por esto: si el servicio
  /// no está, se sigue con los valores por defecto (solo entradas).
  static Future<GymSettingsModel> current() async {
    if (!Get.isRegistered<GymSettingsService>()) {
      return const GymSettingsModel();
    }
    return to.ensureLoaded();
  }

  final _repository = GymSettingsRepository();

  final Rx<GymSettingsModel> settings = const GymSettingsModel().obs;

  bool _cargada = false;

  bool get registrarSalidas => settings.value.registrarSalidas;
  HoraDelDia get horaApertura => settings.value.horaApertura;
  HoraDelDia get horaCierre => settings.value.horaCierre;

  /// Carga la configuración si aún no está en memoria.
  Future<GymSettingsModel> ensureLoaded() async {
    if (_cargada) return settings.value;
    return refresh();
  }

  /// Vuelve a leerla de la base.
  Future<GymSettingsModel> refresh() async {
    settings.value = await _repository.getSettings();
    _cargada = true;
    return settings.value;
  }

  /// Guarda y deja la caché al día en la misma operación, para que el lector
  /// RFID no siga con el valor viejo.
  Future<bool> save(GymSettingsModel nuevos) async {
    final ok = await _repository.saveSettings(nuevos);
    if (ok) {
      settings.value = nuevos;
      _cargada = true;
    }
    return ok;
  }

  /// Al cerrar sesión: el siguiente gimnasio no debe heredar esta caché.
  void clear() {
    settings.value = const GymSettingsModel();
    _cargada = false;
  }
}
