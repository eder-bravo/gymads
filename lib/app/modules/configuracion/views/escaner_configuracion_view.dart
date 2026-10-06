import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/widgets/diseno_escritorio.dart';
import '../../../core/widgets/formulario.dart';
import '../../../core/widgets/escaner_fisico_view.dart';
import '../../../global_widgets/app_header.dart';

class EscanerConfiguracionView extends StatefulWidget {
  const EscanerConfiguracionView({super.key});
  @override
  State<EscanerConfiguracionView> createState() =>
      _EscanerConfiguracionViewState();
}

class _EscanerConfiguracionViewState extends State<EscanerConfiguracionView> {
  String? _prueba;

  /// Abre la lectura de prueba y muestra lo que llegó.
  Future<void> _probar() async {
    final codigo = await Get.to<String>(
        () => const EscanerFisicoView(titulo: 'Probar escáner'));
    if (mounted && codigo != null) setState(() => _prueba = codigo);
  }

  @override
  Widget build(BuildContext context) => ScaffoldAdaptable(
        anchoMaximo: 720,
        backgroundColor: context.colores.backgroundColor,
        appBar: const GymAppBar(title: 'Escáner de códigos'),
        body: _contenido(context),
      );

  /// Tres pasos para conectar el lector y una prueba. No hay nada que
  /// ajustar: la app acepta la tecla final que traiga el lector (Enter o
  /// Tab). Antes había "Ajuste" y "Opciones avanzadas" (prefijo y sufijo)
  /// que nadie entendía.
  Widget _contenido(BuildContext context) {
    final c = context.colores;
    Widget paso(IconData icono, String titulo, String texto) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(texto,
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 15, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const TituloSeccion('Conecta tu lector',
            detalle: 'Elige la forma que corresponde a tu lector.'),
        const SizedBox(height: 8),
        paso(
            Icons.usb,
            'Con cable USB',
            'Conéctalo a la computadora. Si no escribe nada, ponlo en modo '
                '"teclado" (HID) con el manual del lector.'),
        paso(
            Icons.bluetooth,
            'Por Bluetooth',
            'Emparéjalo desde los ajustes de Bluetooth de la computadora, '
                'como si fuera un teclado.'),
        paso(
            Icons.settings_input_antenna,
            'Con receptor inalámbrico',
            'Conecta el receptor USB que trae el lector. Solo funciona con '
                'los lectores de su misma marca.'),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
              onPressed: _probar,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Probar mi lector'),
              style: estiloBotonEscritorio(
                  fondo: AppColors.accent, texto: Colors.white)),
        ),
        if (_prueba != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: 12),
              Expanded(
                child: Text('El lector funciona. Leyó: $_prueba',
                    style: TextStyle(color: c.textPrimary, fontSize: 15)),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}
