import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// El modo de la app (claro, oscuro o el del teléfono) elegido en
/// Configuración → Apariencia. Se guarda en este teléfono, no en la cuenta.
///
/// Por defecto sigue al teléfono: `GetMaterialApp` recibe el tema claro y el
/// oscuro y, con [ThemeMode.system], cambia solo cuando cambia el teléfono.
class TemaService extends GetxService {
  /// [leer] y [guardar] son para las pruebas; en la app, GetStorage.
  TemaService({String? Function()? leer, void Function(String)? guardar})
      : _leer = leer ?? (() => GetStorage().read<String>(_clave)),
        _guardar = guardar ?? ((valor) => GetStorage().write(_clave, valor));

  /// Se registra en `main()`; si aún no está (por ejemplo, tras un hot
  /// reload, que no vuelve a correr `main()`), se registra aquí.
  static TemaService get to => Get.isRegistered<TemaService>()
      ? Get.find<TemaService>()
      : Get.put(TemaService(), permanent: true);

  static const _clave = 'modo_tema';

  final String? Function() _leer;
  final void Function(String) _guardar;

  late final Rx<ThemeMode> modo = _desTexto(_leer()).obs;

  void cambiar(ThemeMode nuevo) {
    if (nuevo == modo.value) return;
    modo.value = nuevo;
    _guardar(_aTexto(nuevo));
    Get.changeThemeMode(nuevo);
  }

  static String _aTexto(ThemeMode modo) => switch (modo) {
        ThemeMode.light => 'claro',
        ThemeMode.dark => 'oscuro',
        ThemeMode.system => 'sistema',
      };

  static ThemeMode _desTexto(String? texto) => switch (texto) {
        'claro' => ThemeMode.light,
        'oscuro' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
