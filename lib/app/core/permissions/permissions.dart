import 'staff_role.dart';

/// Lo que cada rol puede hacer.
///
/// Es la fuente única del lado de la app. Su espejo en la base es
/// `public.staff_puede(text)`: las dos tablas se editan JUNTAS, porque ocultar
/// un botón sin cerrar la política RLS no protege nada, y cerrar la política
/// sin ocultar el botón deja al empleado chocando contra un error.
enum Permission {
  /// Alta, edición y baja de clientes.
  gestionarClientes('gestionar_clientes'),

  /// Cobrar y renovar membresías.
  cobrarAbonos('cobrar_abonos'),

  /// Punto de venta.
  vender('vender'),

  /// Entrar al inventario y ver existencias.
  verInventario('ver_inventario'),

  /// Crear, editar (incluido el precio) y dar de baja productos.
  gestionarProductos('gestionar_productos'),

  /// Sumar o restar existencias. No incluye tocar el precio.
  ajustarStock('ajustar_stock'),

  /// Categorías de producto.
  gestionarCategorias('gestionar_categorias'),

  /// Historial de pagos y ventas.
  verIngresos('ver_ingresos'),

  /// Registro de entradas y salidas.
  verAccesos('ver_accesos'),

  /// Recibir el aviso del lector cuando alguien pasa una tarjeta.
  recibirAlertasNfc('recibir_alertas_nfc'),

  /// Precio por día, semana, mes y año.
  gestionarPreciosAbonos('gestionar_precios_abonos'),

  /// Horario del gimnasio y registro de salidas.
  gestionarControlAccesos('gestionar_control_accesos'),

  /// Nombre del gimnasio y de la sucursal.
  editarGimnasio('editar_gimnasio'),

  /// Crear, renombrar, revocar y eliminar accesos del personal.
  gestionarAccesosStaff('gestionar_accesos_staff'),

  /// Borrar el gimnasio y todos sus datos. Solo el dueño.
  eliminarGimnasio('eliminar_gimnasio');

  const Permission(this.value);

  /// El nombre que entiende `public.staff_puede()`.
  final String value;
}

/// El permiso que exige cada rol.
///
/// `mostrador` es el único con [Permission.recibirAlertasNfc]: antes el aviso
/// del lector llegaba a todos los dispositivos a la vez.
const Map<StaffRole, Set<Permission>> kPermisosPorRol = {
  StaffRole.ownerAdmin: {
    Permission.gestionarClientes,
    Permission.cobrarAbonos,
    Permission.vender,
    Permission.verInventario,
    Permission.gestionarProductos,
    Permission.ajustarStock,
    Permission.gestionarCategorias,
    Permission.verIngresos,
    Permission.verAccesos,
    Permission.gestionarPreciosAbonos,
    Permission.gestionarControlAccesos,
    Permission.editarGimnasio,
    Permission.gestionarAccesosStaff,
    Permission.eliminarGimnasio,
  },
  StaffRole.encargado: {
    Permission.gestionarClientes,
    Permission.cobrarAbonos,
    Permission.vender,
    Permission.verInventario,
    Permission.gestionarProductos,
    Permission.ajustarStock,
    Permission.gestionarCategorias,
    Permission.verIngresos,
    Permission.verAccesos,
    Permission.gestionarPreciosAbonos,
    Permission.gestionarControlAccesos,
    Permission.editarGimnasio,
    Permission.gestionarAccesosStaff,
  },
  StaffRole.branchStaff: {
    Permission.gestionarClientes,
    Permission.cobrarAbonos,
    Permission.vender,
    Permission.verInventario,
    Permission.ajustarStock,
    Permission.verIngresos,
    Permission.verAccesos,
  },
  StaffRole.almacen: {
    Permission.verInventario,
    Permission.gestionarProductos,
    Permission.ajustarStock,
    Permission.gestionarCategorias,
  },
  StaffRole.mostrador: {
    Permission.gestionarClientes,
    Permission.cobrarAbonos,
    Permission.vender,
    Permission.verIngresos,
    Permission.verAccesos,
    Permission.recibirAlertasNfc,
  },
};
