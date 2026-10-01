import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../utils/referencia_de_pago.dart';
import '../utils/plataforma_app.dart';

/// Los métodos de pago como botones: el elegido en naranja. Lo usan Vender
/// y Abonar, para que cobrar se vea y funcione igual en los dos.
class SelectorMetodoPago extends StatelessWidget {
  const SelectorMetodoPago({
    super.key,
    required this.metodos,
    required this.elegido,
    required this.onElegir,
  });

  final List<String> metodos;
  final String elegido;
  final ValueChanged<String> onElegir;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final metodo in metodos)
          Builder(builder: (context) {
            final selected = metodo == elegido;
            return GestureDetector(
              onTap: () => onElegir(metodo),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : c.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.accent
                        : AppColors.accent.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      iconoMetodoDePago(metodo),
                      size: 16,
                      color: selected ? Colors.white : c.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    // Con letra grande en el teléfono, el nombre se parte en
                    // dos renglones en vez de salirse de la pantalla.
                    Flexible(
                      child: Text(
                        nombreMetodoDePago(metodo),
                        style: TextStyle(
                          color: selected ? Colors.white : c.textSecondary,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// El folio o referencia de un pago con tarjeta o transferencia: se escribe
/// o se escanea de la foto del comprobante (cámara o galería). Lo que lee la
/// foto se SUGIERE: el campo sigue mandando, porque el reconocimiento falla
/// a veces.
class CampoReferenciaPago extends StatelessWidget {
  const CampoReferenciaPago({super.key, required this.controlador});

  final ReferenciaDePago controlador;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final r = controlador;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: r.referenciaCtrl,
          style: TextStyle(color: c.textPrimary),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(50)],
          decoration: const InputDecoration(
            labelText: 'Folio o referencia (opcional)',
            hintText: 'Ej: 004521',
            prefixIcon: Icon(Icons.receipt_long, color: AppColors.accent),
          ),
          onChanged: r.setReferenciaPago,
        ),
        const SizedBox(height: 10),
        if (PlataformaApp.ocrMovil) Obx(() {
          if (r.leyendoReferencia.value) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Text('Leyendo la referencia...',
                      style: TextStyle(color: c.textSecondary)),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          r.escanearReferencia(desdeCamara: true),
                      icon: const Icon(Icons.document_scanner_outlined,
                          size: 18),
                      label: const Text('Escanear referencia'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: BorderSide(
                            color: AppColors.accent.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () =>
                        r.escanearReferencia(desdeCamara: false),
                    icon: const Icon(Icons.photo_library_outlined),
                    color: AppColors.accent,
                    tooltip: 'Elegir de la galería',
                  ),
                ],
              ),
              if (r.referenciasSugeridas.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Referencias encontradas — toca la correcta:',
                    style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final referencia in r.referenciasSugeridas)
                      ActionChip(
                        label: Text(referencia,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12.5)),
                        backgroundColor: c.containerBackground,
                        labelStyle: TextStyle(color: c.textPrimary),
                        onPressed: () => r.usarReferenciaSugerida(referencia),
                      ),
                  ],
                ),
              ] else if (r.referenciaEscaneada.value) ...[
                const SizedBox(height: 8),
                Text(
                  'No se reconoció ninguna referencia en la foto. '
                  'Escríbela arriba.',
                  style: TextStyle(
                      color: c.textSecondary.withOpacity(0.8), fontSize: 12.5),
                ),
              ],
            ],
          );
        }),
      ],
    );
  }
}
