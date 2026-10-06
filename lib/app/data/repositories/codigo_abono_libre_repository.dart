import '../../core/utils/app_logger.dart';
import '../services/supabase_service.dart';

/// Qué pasó al escribir el código del encargado.
enum ResultadoAutorizacion {
  ok,
  incorrecto,

  /// 5 fallos en 10 minutos: hay que esperar.
  demasiadosIntentos,

  /// El gimnasio aún no tiene código.
  sinCodigo,
  sinConexion,
}

/// El código del encargado para el abono libre: uno por gimnasio (PIN de 4 a
/// 6 números). Lo crean el dueño o el encargado; el mostrador lo pide para
/// cobrar un abono libre cuando hay costos fijos.
///
/// Nunca se lee ni se guarda en el dispositivo: todo pasa por funciones del
/// servidor que comparan contra un hash que la app no puede ver, y limitan
/// los intentos (migración `codigo_abono_libre`).
class CodigoAbonoLibreRepository {
  /// Si el gimnasio ya tiene código. Null si no se pudo saber.
  Future<bool?> hayCodigo() async {
    try {
      final hay = await SupabaseService.client.rpc('hay_codigo_abono_libre');
      return hay == true;
    } catch (e) {
      AppLogger.warning('CodigoAbonoLibre', 'No se pudo consultar: $e');
      return null;
    }
  }

  /// Crea o cambia el código ([pin]), o lo quita (null). Solo dueño y
  /// encargado: el servidor lo vuelve a comprobar.
  Future<bool> guardar(String? pin) async {
    try {
      await SupabaseService.client
          .rpc('guardar_codigo_abono_libre', params: {'p_pin': pin});
      return true;
    } catch (e) {
      AppLogger.error('CodigoAbonoLibre', 'No se pudo guardar', e);
      return false;
    }
  }

  /// Comprueba el código para un cobro.
  Future<ResultadoAutorizacion> autorizar(String pin) async {
    try {
      final ok = await SupabaseService.client
          .rpc('autorizar_abono_libre', params: {'p_pin': pin});
      return ok == true
          ? ResultadoAutorizacion.ok
          : ResultadoAutorizacion.incorrecto;
    } catch (e) {
      final texto = '$e';
      if (texto.contains('demasiados_intentos')) {
        return ResultadoAutorizacion.demasiadosIntentos;
      }
      if (texto.contains('sin_codigo')) return ResultadoAutorizacion.sinCodigo;
      AppLogger.warning('CodigoAbonoLibre', 'No se pudo autorizar: $e');
      return ResultadoAutorizacion.sinConexion;
    }
  }
}
