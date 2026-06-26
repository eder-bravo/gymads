import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ingreso_model.dart';
import '../services/tenant_query_helper.dart';

class IngresoProvider {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtiene todos los ingresos
  Future<List<IngresoModel>> getIngresos({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? concepto,
    String? metodoPago,
    int limit = 100,
  }) async {
    try {
      // Ya no necesitamos JOIN porque eliminamos las foreign keys
      // Los nombres de cliente están en cliente_nombre
      var query = _supabase
          .from('ingresos')
          .select('*')
          .eq('branch_id', TenantQueryHelper.branchIdOrNull ?? '');

      // Aplicar filtros
      if (fechaInicio != null) {
        query = query.gte('fecha', fechaInicio.toIso8601String());
      }
      if (fechaFin != null) {
        query = query.lte('fecha', fechaFin.toIso8601String());
      }
      if (concepto != null && concepto.isNotEmpty) {
        query = query.eq('concepto', concepto);
      }
      if (metodoPago != null && metodoPago.isNotEmpty) {
        query = query.eq('metodo_pago', metodoPago);
      }

      final response =
          await query.order('fecha', ascending: false).limit(limit);

      return (response as List)
          .map((json) => IngresoModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error al obtener ingresos: $e');
      throw Exception('Error al cargar ingresos: $e');
    }
  }

  /// Crea un nuevo ingreso
  Future<bool> createIngreso(IngresoModel ingreso) async {
    try {
      final data = TenantQueryHelper.withTenant(ingreso.toJson());
      data.remove('id'); // Remover ID para que sea auto-generado
      data['created_at'] = DateTime.now().toIso8601String();

      print('🔍 DEBUG: Datos a insertar en ingresos:');
      print('   - cliente_id: ${data['cliente_id']}');
      print('   - cliente_nombre: ${data['cliente_nombre']}');
      print('   - concepto: ${data['concepto']}');
      print('   - tipo_membresia: ${data['tipo_membresia']}');
      print('   - monto_base: ${data['monto_base']}');
      print('   - cuota_registro: ${data['cuota_registro']}');
      print('   - monto_final: ${data['monto_final']}');
      print('   - metodo_pago: ${data['metodo_pago']}');
      print('   - usuario_staff: ${data['usuario_staff']}');
      print('   - fecha: ${data['fecha']}');

      final response = await _supabase.from('ingresos').insert(data).select();
      print('✅ Ingreso creado exitosamente');
      print('📋 Respuesta de inserción: $response');
      return true;
    } catch (e) {
      print('❌ Error al crear ingreso: $e');
      print('📊 Tipo de error: ${e.runtimeType}');
      return false;
    }
  }

  /// Obtiene estadísticas de ingresos
  Future<EstadisticasIngresos> getEstadisticas({
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      final now = DateTime.now();
      final inicioMes = DateTime(now.year, now.month, 1);
      final inicioSemana = now.subtract(Duration(days: now.weekday - 1));
      final inicioDia = DateTime(now.year, now.month, now.day);

      // Obtener todos los ingresos del período
      final ingresos = await getIngresos(
        fechaInicio: fechaInicio ?? inicioMes,
        fechaFin: fechaFin,
        limit: 1000,
      );

      // Calcular estadísticas
      final totalIngresos =
          ingresos.fold<double>(0, (sum, ingreso) => sum + ingreso.montoFinal);

      final ingresosDiarios = ingresos
          .where((ingreso) => ingreso.fecha.isAfter(inicioDia))
          .fold<double>(0, (sum, ingreso) => sum + ingreso.montoFinal);

      final ingresosSemanales = ingresos
          .where((ingreso) => ingreso.fecha.isAfter(inicioSemana))
          .fold<double>(0, (sum, ingreso) => sum + ingreso.montoFinal);

      final ingresosMensuales = ingresos
          .where((ingreso) => ingreso.fecha.isAfter(inicioMes))
          .fold<double>(0, (sum, ingreso) => sum + ingreso.montoFinal);

      final registrosNuevos =
          ingresos.where((ingreso) => ingreso.concepto == 'registro').length;

      final renovaciones =
          ingresos.where((ingreso) => ingreso.concepto == 'renovacion').length;

      final promedioTransaccion =
          ingresos.isNotEmpty ? totalIngresos / ingresos.length : 0.0;

      // Ingresos por método de pago
      final ingresosPorMetodo = <String, double>{};
      for (final ingreso in ingresos) {
        ingresosPorMetodo[ingreso.metodoPago] =
            (ingresosPorMetodo[ingreso.metodoPago] ?? 0) + ingreso.montoFinal;
      }

      // Ingresos por concepto
      final ingresosPorConcepto = <String, double>{};
      for (final ingreso in ingresos) {
        ingresosPorConcepto[ingreso.concepto] =
            (ingresosPorConcepto[ingreso.concepto] ?? 0) + ingreso.montoFinal;
      }

      return EstadisticasIngresos(
        totalIngresos: totalIngresos,
        ingresosDiarios: ingresosDiarios,
        ingresosSemanales: ingresosSemanales,
        ingresosMensuales: ingresosMensuales,
        totalTransacciones: ingresos.length,
        registrosNuevos: registrosNuevos,
        renovaciones: renovaciones,
        promedioTransaccion: promedioTransaccion,
        ingresosPorMetodo: ingresosPorMetodo,
        ingresosPorConcepto: ingresosPorConcepto,
        ultimosIngresos: ingresos.take(10).toList(),
      );
    } catch (e) {
      print('❌ Error al obtener estadísticas: $e');
      return EstadisticasIngresos.empty();
    }
  }

  /// Obtiene ingresos por período específico para gráficas
  Future<Map<String, double>> getIngresosPorPeriodo({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required String agrupacion, // 'dia', 'semana', 'mes'
  }) async {
    try {
      final ingresos = await getIngresos(
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        limit: 1000,
      );

      final Map<String, double> resultado = {};

      for (final ingreso in ingresos) {
        String clave;

        switch (agrupacion) {
          case 'dia':
            clave = '${ingreso.fecha.day}/${ingreso.fecha.month}';
            break;
          case 'semana':
            final inicioSemana = ingreso.fecha
                .subtract(Duration(days: ingreso.fecha.weekday - 1));
            clave = '${inicioSemana.day}/${inicioSemana.month}';
            break;
          case 'mes':
            clave = '${ingreso.fecha.month}/${ingreso.fecha.year}';
            break;
          default:
            clave = ingreso.fecha.toIso8601String().split('T')[0];
        }

        resultado[clave] = (resultado[clave] ?? 0) + ingreso.montoFinal;
      }

      return resultado;
    } catch (e) {
      print('❌ Error al obtener ingresos por período: $e');
      return {};
    }
  }

  /// Obtiene el total de ingresos del mes actual
  Future<double> getIngresosMesActual() async {
    try {
      final now = DateTime.now();
      final inicioMes = DateTime(now.year, now.month, 1);
      final finMes = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final ingresos = await getIngresos(
        fechaInicio: inicioMes,
        fechaFin: finMes,
        limit: 1000,
      );

      return ingresos.fold<double>(
          0, (sum, ingreso) => sum + ingreso.montoFinal);
    } catch (e) {
      print('❌ Error al obtener ingresos del mes: $e');
      return 0;
    }
  }

  /// Elimina un ingreso (solo para casos especiales)
  Future<bool> deleteIngreso(String id) async {
    try {
      await _supabase.from('ingresos').delete().eq('id', id);
      print('✅ Ingreso eliminado exitosamente');
      return true;
    } catch (e) {
      print('❌ Error al eliminar ingreso: $e');
      return false;
    }
  }
}
