/// Los roles del personal, en orden de mando.
///
/// El `value` es el texto que viaja a Postgres: debe coincidir con el CHECK de
/// `staff_profiles.role` y con el CASE de `public.staff_puede()`.
enum StaffRole {
  /// Dueño del gimnasio. Único que puede borrarlo.
  ownerAdmin('owner_admin', 'Dueño', 100),

  /// Mano derecha del dueño: todo salvo borrar el gimnasio y tocar accesos de
  /// su mismo nivel o superior.
  encargado('encargado', 'Encargado', 80),

  /// El personal de siempre. Atiende clientes y vende, pero no fija precios
  /// ni da de alta productos.
  branchStaff('branch_staff', 'Staff', 50),

  /// Solo inventario: productos, precios de producto, categorías y stock.
  almacen('almacen', 'Almacén', 50),

  /// Recepción. El único que recibe las alertas del lector de tarjetas.
  mostrador('mostrador', 'Mostrador', 50);

  const StaffRole(this.value, this.label, this.rango);

  /// Texto que se guarda en la base.
  final String value;

  /// Nombre para mostrar.
  final String label;

  /// Quién manda sobre quién. Solo se puede asignar o modificar un rol de
  /// rango estrictamente menor al propio, así que dos roles con el mismo
  /// rango no pueden tocarse entre sí.
  final int rango;

  /// Una línea explicando qué hace este rol, para el selector de accesos.
  String get descripcion {
    switch (this) {
      case StaffRole.ownerAdmin:
        return 'Control total, incluido eliminar el gimnasio.';
      case StaffRole.encargado:
        return 'Todo menos eliminar el gimnasio.';
      case StaffRole.branchStaff:
        return 'Clientes, cobros y ventas. Ajusta stock, no precios.';
      case StaffRole.almacen:
        return 'Solo inventario: productos, precios y stock.';
      case StaffRole.mostrador:
        return 'Recepción. Recibe los avisos del lector de tarjetas.';
    }
  }

  /// Los roles que se pueden entregar con un código de acceso.
  ///
  /// El dueño nunca está aquí: se es dueño registrando el gimnasio, no
  /// canjeando un código.
  static const List<StaffRole> asignables = [
    StaffRole.encargado,
    StaffRole.branchStaff,
    StaffRole.almacen,
    StaffRole.mostrador,
  ];

  /// Traduce el texto de la base. Un valor desconocido cae en el rol más
  /// limitado que igual sirve para trabajar, nunca en uno con más permisos.
  static StaffRole fromString(String? value) {
    for (final rol in StaffRole.values) {
      if (rol.value == value) return rol;
    }
    return StaffRole.branchStaff;
  }

  /// Si este rol puede crear o modificar accesos con el rol [otro].
  ///
  /// Espeja a `public.puede_gestionar_rol()`: hace falta el permiso de
  /// gestionar accesos y, además, mandar sobre ese rol.
  bool mandaSobre(StaffRole otro) => rango > otro.rango;
}
