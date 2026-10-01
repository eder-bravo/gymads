import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/escaner_fisico_service.dart';
import '../../../core/widgets/escaner_fisico_view.dart';

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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Escáner de códigos')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(padding: const EdgeInsets.all(24), children: [
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
                  FilledButton(
                      onPressed: _guardando ? null : () => _guardar(),
                      child: const Text('Guardar')),
                  OutlinedButton(
                      onPressed:
                          _guardando ? null : () => _guardar(probar: true),
                      child: const Text('Guardar y probar lector')),
                  if (_prueba != null) Text('Código recibido: $_prueba'),
                ]))),
      );
}
