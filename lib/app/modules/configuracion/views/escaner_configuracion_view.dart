import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/escaner_fisico_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/widgets/diseno_escritorio.dart';
import '../../../core/widgets/formulario.dart';
import '../../../core/utils/plataforma_app.dart';
import '../../../core/widgets/escaner_fisico_view.dart';
import '../../../global_widgets/app_header.dart';

class EscanerConfiguracionView extends StatefulWidget {
  const EscanerConfiguracionView({super.key});
  @override
  State<EscanerConfiguracionView> createState() =>
      _EscanerConfiguracionViewState();
}

class _EscanerConfiguracionViewState extends State<EscanerConfiguracionView> {
  late TerminadorEscaner _terminador =
      EscanerFisicoService.configuracion.value.terminador;
  late final _prefijo = TextEditingController(
      text: EscanerFisicoService.configuracion.value.prefijo);
  late final _sufijo = TextEditingController(
      text: EscanerFisicoService.configuracion.value.sufijo);
  bool _guardando = false;
  String? _prueba;
  @override
  void dispose() {
    _prefijo.dispose();
    _sufijo.dispose();
    super.dispose();
  }

  Future<void> _guardar({bool probar = false}) async {
    setState(() => _guardando = true);
    try {
      await EscanerFisicoService.guardar(ConfiguracionEscaner(
          terminador: _terminador,
          prefijo: _prefijo.text,
          sufijo: _sufijo.text));
      if (!mounted) return;
      if (probar) {
        final codigo = await Get.to<String>(
            () => const EscanerFisicoView(titulo: 'Probar escáner'));
        if (mounted && codigo != null) setState(() => _prueba = codigo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Configuración guardada en este equipo')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo guardar la configuración')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => ScaffoldAdaptable(
        anchoMaximo: 720,
        backgroundColor: context.colores.backgroundColor,
        appBar: const GymAppBar(title: 'Escáner de códigos'),
        body: PlataformaApp.escritorio
            ? _escritorio(context)
            : ListView(padding: const EdgeInsets.all(24), children: [
                const Text('Conexión del lector',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                    'USB: conecta el cable y selecciona el modo HID o teclado en el manual del lector.\n\n'
                    'Bluetooth: empareja el lector desde los ajustes de macOS o Windows como teclado.\n\n'
                    'Sin Bluetooth: usa el cable, el receptor USB del fabricante o un adaptador Bluetooth USB compatible con tu sistema. '
                    'Un receptor de 2.4 GHz solo sirve para sus lectores compatibles.'),
                const SizedBox(height: 24),
                DropdownButtonFormField<TerminadorEscaner>(
                    initialValue: _terminador,
                    decoration: const InputDecoration(
                        labelText: 'Tecla al finalizar cada lectura'),
                    items: TerminadorEscaner.values
                        .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t == TerminadorEscaner.enter
                                ? 'Enter'
                                : 'Tab')))
                        .toList(),
                    onChanged: _guardando
                        ? null
                        : (v) => setState(() => _terminador = v!)),
                const SizedBox(height: 16),
                TextField(
                    controller: _prefijo,
                    maxLength: 32,
                    decoration: const InputDecoration(
                        labelText: 'Prefijo a quitar (opcional)')),
                TextField(
                    controller: _sufijo,
                    maxLength: 32,
                    decoration: const InputDecoration(
                        labelText: 'Sufijo a quitar (opcional)')),
                const Text(
                    'Estos ajustes adaptan GymOne a lo que envía el lector. Para cambiar su modo, idioma del teclado, '
                    'prefijo o terminador físico, escanea los códigos de programación de su manual. '
                    'Los lectores en modo serie/COM necesitan cambiarse a HID si el fabricante lo permite.'),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                        onPressed:
                            _guardando ? null : () => _guardar(probar: true),
                        child: const Text('Guardar y probar lector')),
                    FilledButton(
                        onPressed: _guardando ? null : () => _guardar(),
                        child: const Text('Guardar')),
                  ],
                ),
                if (_prueba != null) ...[
                  const SizedBox(height: 16),
                  Text('Código recibido: $_prueba'),
                ],
              ]),
      );

  /// En escritorio: tres pasos claros para conectar el lector, la única
  /// opción que suele hacer falta (la tecla final) y lo técnico (prefijo,
  /// sufijo, modo serie) guardado en "Opciones avanzadas".
  Widget _escritorio(BuildContext context) {
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
        const SizedBox(height: 8),
        const TituloSeccion('Ajuste',
            detalle: 'Casi siempre se deja en Enter.'),
        DropdownButtonFormField<TerminadorEscaner>(
            initialValue: _terminador,
            decoration: const InputDecoration(
                labelText: 'Tecla al finalizar cada lectura'),
            items: TerminadorEscaner.values
                .map((t) => DropdownMenuItem(
                    value: t,
                    child:
                        Text(t == TerminadorEscaner.enter ? 'Enter' : 'Tab')))
                .toList(),
            onChanged:
                _guardando ? null : (v) => setState(() => _terminador = v!)),
        const SizedBox(height: 16),
        Theme(
          // Sin las líneas que ExpansionTile pone arriba y abajo.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            title: Text('Opciones avanzadas',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            subtitle: Text('Solo si el lector agrega letras de más al código',
                style: TextStyle(color: c.textSecondary, fontSize: 14)),
            children: [
              TextField(
                  controller: _prefijo,
                  maxLength: 32,
                  decoration: const InputDecoration(
                      labelText: 'Quitar al inicio del código (prefijo)')),
              TextField(
                  controller: _sufijo,
                  maxLength: 32,
                  decoration: const InputDecoration(
                      labelText: 'Quitar al final del código (sufijo)')),
              Text(
                  'Para cambiar el idioma del teclado, el modo o la tecla '
                  'final del propio lector, escanea los códigos de su manual. '
                  'Los lectores en modo serie/COM deben cambiarse a modo '
                  'teclado (HID) si el fabricante lo permite.',
                  style: TextStyle(
                      color: c.textSecondary, fontSize: 14, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilaDeBotones(
          alineacion: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
                onPressed: _guardando ? null : () => _guardar(probar: true),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Guardar y probar'),
                style: estiloBotonEscritorio(
                    texto: AppColors.accent, contorno: true)),
            ElevatedButton.icon(
                onPressed: _guardando ? null : () => _guardar(),
                icon: const Icon(Icons.check),
                label: const Text('Guardar'),
                style: estiloBotonEscritorio(
                    fondo: AppColors.accent, texto: Colors.white)),
          ],
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
