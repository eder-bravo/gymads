/// Diez dígitos sin lada se interpretan como México; otros requieren +país.
String? telefonoEscritorio(String texto) {
  final limpio = texto.trim().replaceAll(RegExp(r'[\s()\-]'), '');
  if (RegExp(r'^\d{10}$').hasMatch(limpio)) return '+52$limpio';
  if (RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(limpio)) return limpio;
  return null;
}
