import '../models/ingreso_model.dart';
import '../providers/ingreso_provider.dart';

/// Servicio para gestionar la lógica de ingresos
class IngresoService {
  final IngresoProvider _ingresoProvider;

  IngresoService({required IngresoProvider ingresoProvider})
      : _ingresoProvider = ingresoProvider;

  /// Registra un abono libre en el sistema
  Future<bool> registrarAbono({
    required String clienteId,
    required String clienteNombre,
    required double monto,
    required String metodoPago,
    required String descripcion,
    required String usuarioStaff,
    String? notas,
  }) async {
    try {
      final ingreso = IngresoModel(
        clienteId: clienteId,
        clienteNombre: clienteNombre,
        concepto: 'abono',
        tipoMembresia: descripcion, // Usamos este campo para la descripción del abono
        montoBase: monto,
        cuotaRegistro: 0.0,
        descuento: 0.0,
        montoFinal: monto,
        metodoPago: metodoPago,
        fecha: DateTime.now(),
        usuarioStaff: usuarioStaff,
        notas: notas,
      );

      print('💰 Registrando abono:');
      print('   - Cliente: $clienteNombre (ID: $clienteId)');
      print('   - Monto: \$${monto.toStringAsFixed(2)}');
      print('   - Descripción: $descripcion');
      
      return await _ingresoProvider.createIngreso(ingreso);
    } catch (e) {
      print('❌ Error al registrar abono: $e');
      return false;
    }
  }

  /// Calcula y registra el ingreso por registro de nuevo cliente
  Future<bool> registrarIngresoNuevoCliente({
    required String clienteId,
    required String clienteNombre,
    required String tipoMembresia,
    required double precioRegistro,
    required double precioMembresia,
    required String metodoPago,
    required String usuarioStaff,
    String? notas,
  }) async {
    try {
      double montoBase = precioRegistro + precioMembresia;
      double montoFinal = montoBase;

      final ingreso = IngresoModel(
        clienteId: clienteId,
        clienteNombre: clienteNombre,
        concepto: 'registro',
        tipoMembresia: tipoMembresia,
        montoBase: precioMembresia,
        cuotaRegistro: precioRegistro,
        descuento: 0.0,
        montoFinal: montoFinal,
        metodoPago: metodoPago,
        fecha: DateTime.now(),
        usuarioStaff: usuarioStaff,
        notas: notas,
      );

      final result = await _ingresoProvider.createIngreso(ingreso);
      return result;
    } catch (e) {
      print('❌ Error al registrar ingreso nuevo cliente: $e');
      return false;
    }
  }

  /// Obtiene estadísticas de ingresos
  Future<EstadisticasIngresos> getEstadisticas({
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    return await _ingresoProvider.getEstadisticas(
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
    );
  }

  /// Obtiene lista de ingresos con filtros
  Future<List<IngresoModel>> getIngresos({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? concepto,
    String? metodoPago,
    int limit = 100,
  }) async {
    return await _ingresoProvider.getIngresos(
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      concepto: concepto,
      metodoPago: metodoPago,
      limit: limit,
    );
  }

  /// Obtiene datos para gráficas por período
  Future<Map<String, double>> getIngresosPorPeriodo({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required String agrupacion,
  }) async {
    return await _ingresoProvider.getIngresosPorPeriodo(
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      agrupacion: agrupacion,
    );
  }

  /// Elimina un ingreso (solo para casos especiales de corrección)
  Future<bool> eliminarIngreso(String id) async {
    return await _ingresoProvider.deleteIngreso(id);
  }
}
