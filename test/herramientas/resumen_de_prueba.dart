import 'package:gymads/app/data/models/access_log_model.dart';
import 'package:gymads/app/data/models/ingreso_model.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/modules/home/controllers/resumen_del_dia.dart';

/// Lo de hoy para Inicio: $4,350 cobrados en 3 cobros, 38 entradas y 5
/// membresías que vencen esta semana.
ResumenDelDia resumenDePrueba() {
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day, 9);
  IngresoModel cobro(String nombre, String concepto, double monto,
          String metodo, int minutos) =>
      IngresoModel(
        clienteNombre: nombre,
        concepto: concepto,
        tipoMembresia: concepto == 'renovacion' ? 'Mensual' : '',
        montoBase: monto,
        montoFinal: monto,
        metodoPago: metodo,
        fecha: hoy.add(Duration(minutes: minutos)),
        usuarioStaff: 'Recepción',
      );
  const nombres = ['Ana López', 'Carlos Ruiz', 'María Pérez', 'Jorge Díaz'];
  UserModel cliente(String nombre, int dias) => UserModel(
        id: nombre,
        name: nombre,
        phone: '5512345678',
        joinDate: DateTime(2026),
        // Al final de su día: "vence hoy" sigue siendo hoy a cualquier hora
        // en que corran las pruebas.
        expirationDate:
            DateTime(ahora.year, ahora.month, ahora.day + dias, 23, 59, 59),
        userNumber: '1',
      );
  return ResumenDelDia(
    cobrosDeHoy: () async => [
      cobro('Ana López', 'renovacion', 3500, 'efectivo', 15),
      cobro('', 'producto', 500, 'tarjeta', 95),
      cobro('Visitante', 'visita', 350, 'transferencia', 140),
    ],
    accesosDeHoy: () async => [
      for (var i = 0; i < 42; i++)
        AccessLogModel(
          id: '$i',
          userId: '$i',
          userName: nombres[i % nombres.length],
          userNumber: '$i',
          // Las salidas no cuentan como entradas.
          accessType: i < 38 ? 'entrada' : 'salida',
          method: i.isEven ? 'rfid' : 'qr',
          staffUser: 'Recepción',
          accessTime: hoy.add(Duration(minutes: i * 7)),
          createdAt: hoy,
        ),
    ],
    clientes: () async => [
      cliente('Laura Gómez', 0),
      cliente('Pedro Sánchez', 1),
      cliente('Sofía Torres', 3),
      cliente('Diego Herrera', 5),
      cliente('Valeria Castro', 6),
      cliente('Andrés Molina', 40),
      cliente('Lucía Vargas', -3),
    ],
    precioDelDia: () async => 50,
  );
}
