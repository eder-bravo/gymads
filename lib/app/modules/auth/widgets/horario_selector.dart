import 'package:flutter/material.dart';

import '../../../data/models/gym_settings_model.dart';

/// Horario de apertura del gimnasio, para el alta.
///
/// Viene relleno con 06:00–22:00, que es lo más común: quien esté de acuerdo
/// no toca nada y el registro no se alarga. Cambiarlo es un toque y el
/// selector de reloj del sistema; no hay nada que escribir.
///
/// El botón de 24 horas existe porque en ese caso apertura y cierre coinciden,
/// y ponerlo a mano con dos relojes es justo lo lento que hay que evitar.
class HorarioSelector extends StatelessWidget {
  const HorarioSelector({
    super.key,
    required this.apertura,
    required this.cierre,
    required this.onChanged,
  });

  final HoraDelDia apertura;
  final HoraDelDia cierre;
  final void Function(HoraDelDia apertura, HoraDelDia cierre) onChanged;

  /// Abrir y cerrar a la misma hora significa jornada continua.
  bool get _esVeinticuatroHoras => apertura == cierre;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule, color: Colors.white54, size: 20),
            const SizedBox(width: 8),
            Text(
              'Horario',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const Spacer(),
            _buildVeinticuatroHoras(),
          ],
        ),
        const SizedBox(height: 10),
        if (_esVeinticuatroHoras)
          _buildAbiertoSiempre()
        else
          Row(
            children: [
              Expanded(
                child: _buildHoraPill(
                  context,
                  etiqueta: 'Abre',
                  hora: apertura,
                  onPick: (h) => onChanged(h, cierre),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHoraPill(
                  context,
                  etiqueta: 'Cierra',
                  hora: cierre,
                  onPick: (h) => onChanged(apertura, h),
                ),
              ),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          'Lo usamos para el reporte de entradas. Puedes cambiarlo después.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildVeinticuatroHoras() {
    return GestureDetector(
      onTap: () => _esVeinticuatroHoras
          // Al desmarcar se vuelve al horario habitual, no a un estado raro.
          ? onChanged(const HoraDelDia(6, 0), const HoraDelDia(22, 0))
          : onChanged(const HoraDelDia(0, 0), const HoraDelDia(0, 0)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _esVeinticuatroHoras
              ? Colors.blueAccent.withOpacity(0.25)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _esVeinticuatroHoras
                ? Colors.blueAccent
                : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Text(
          '24 horas',
          style: TextStyle(
            color: _esVeinticuatroHoras ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight:
                _esVeinticuatroHoras ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAbiertoSiempre() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: const Text(
        'Abierto todo el día',
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHoraPill(
    BuildContext context, {
    required String etiqueta,
    required HoraDelDia hora,
    required void Function(HoraDelDia) onPick,
  }) {
    return GestureDetector(
      onTap: () => _elegirHora(context, hora, onPick),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiqueta,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hora.etiqueta,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _elegirHora(
    BuildContext context,
    HoraDelDia actual,
    void Function(HoraDelDia) onPick,
  ) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: actual.hora, minute: actual.minuto),
      helpText: 'Selecciona la hora',
      // El reloj sale en 12 h por MaterialLocalizations12h (ver main.dart);
      // el idioma por sí solo lo daría en 24 h.
      builder: (context, child) => Theme(
        data: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: Colors.blueAccent,
            onPrimary: Colors.white,
            surface: Color(0xFF1E1E24),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (elegida != null) {
      onPick(HoraDelDia(elegida.hour, elegida.minute));
    }
  }
}
