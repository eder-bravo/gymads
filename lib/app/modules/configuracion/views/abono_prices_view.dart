import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../controllers/abono_prices_controller.dart';

/// Pantalla de Precios de Abonos: precio fijo por día, semana, mes y año, e
/// inscripción para clientes nuevos. En el asistente con abono libre solo
/// pregunta la inscripción ([AbonoPricesController.soloInscripcion]).
class AbonoPricesView extends GetView<AbonoPricesController> {
  const AbonoPricesView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ScaffoldAdaptable(
      anchoMaximo: 800,
      backgroundColor: c.backgroundColor,
      appBar: GymAppBar(
          title:
              controller.soloInscripcion ? 'Inscripción' : 'Precios de abonos'),
      // Como en los demás formularios: el botón para guardar, fijo abajo.
      bottomNavigationBar: Obx(() => controller.isLoading.value
          ? const SizedBox.shrink()
          : PieDeFormulario(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BotonGuardar(
                    texto: controller.isOnboarding
                        ? 'Continuar'
                        : 'Guardar precios',
                    guardando: controller.isSaving.value,
                    onPressed: () => controller.savePrices(),
                  ),
                  if (controller.soloInscripcion)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: controller.isSaving.value
                            ? null
                            : () => controller.sinInscripcion(),
                        child: const Text('No cobro inscripción',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                ],
              ),
            )),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.soloInscripcion) ...[
                  _inscripcion(context),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_money,
                            color: AppColors.accent, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Al cobrar, el precio se llena solo según el periodo.',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: legible(13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const TituloSeccion('Precio por periodo',
                      detalle: 'Deja vacío el periodo que no ofrezcas.'),
                  // En escritorio, dos por fila: un precio no necesita un
                  // campo de lado a lado de la ventana.
                  if (PlataformaApp.pantallaGrande)
                    ResumenAdaptable(anchoMinimo: 300, espacio: 16, children: [
                      _priceField(context,
                          controller: controller.dayController,
                          label: 'Precio por día',
                          icon: Icons.today),
                      _priceField(context,
                          controller: controller.weekController,
                          label: 'Precio por semana',
                          icon: Icons.date_range),
                      _priceField(context,
                          controller: controller.monthController,
                          label: 'Precio por mes',
                          icon: Icons.calendar_month),
                      _priceField(context,
                          controller: controller.yearController,
                          label: 'Precio por año',
                          icon: Icons.event_repeat),
                    ])
                  else ...[
                    _priceField(
                      context,
                      controller: controller.dayController,
                      label: 'Precio por día',
                      icon: Icons.today,
                    ),
                    const SizedBox(height: 16),
                    _priceField(
                      context,
                      controller: controller.weekController,
                      label: 'Precio por semana',
                      icon: Icons.date_range,
                    ),
                    const SizedBox(height: 16),
                    _priceField(
                      context,
                      controller: controller.monthController,
                      label: 'Precio por mes',
                      icon: Icons.calendar_month,
                    ),
                    const SizedBox(height: 16),
                    _priceField(
                      context,
                      controller: controller.yearController,
                      label: 'Precio por año',
                      icon: Icons.event_repeat,
                    ),
                  ],
                  const SizedBox(height: 32),
                  _inscripcion(context),
                  if (!controller.isOnboarding) ...[
                    const SizedBox(height: 32),
                    _codigo(context),
                  ],
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  /// El código del encargado para el abono libre. Nunca se muestra: solo si
  /// existe, y se crea, cambia o quita.
  Widget _codigo(BuildContext context) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Código para abono libre',
            detalle: 'El mostrador lo pide para cobrar un abono libre cuando '
                'tienes costos fijos. Tú y el encargado no lo necesitan.'),
        Obx(() {
          final hay = controller.hayCodigo.value;
          final guardando = controller.guardandoCodigo.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    hay == true ? Icons.lock_outline : Icons.lock_open_outlined,
                    color: hay == true ? AppColors.success : c.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      switch (hay) {
                        true => 'Código creado',
                        false => 'Sin código: el mostrador no puede cobrar '
                            'abonos libres',
                        null => 'No se pudo revisar el código',
                      },
                      style: TextStyle(color: c.textPrimary, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilaDeBotones(
                alineacion: WrapAlignment.start,
                children: [
                  if (hay == null)
                    OutlinedButton.icon(
                      onPressed: controller.cargarCodigo,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Intentar de nuevo'),
                    )
                  else ...[
                    OutlinedButton.icon(
                      key: const Key('crear_codigo'),
                      onPressed:
                          guardando ? null : () => _pedirCodigoNuevo(context),
                      icon: const Icon(Icons.pin_outlined),
                      label: Text(hay ? 'Cambiar código' : 'Crear código'),
                    ),
                    if (hay)
                      TextButton.icon(
                        onPressed: guardando ? null : controller.quitarCodigo,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Quitar código'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error),
                      ),
                  ],
                ],
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Escribir el código dos veces (4 a 6 números) para crearlo o cambiarlo.
  Future<void> _pedirCodigoNuevo(BuildContext context) async {
    final codigo = await Get.dialog<String>(const _DialogoCodigoNuevo());
    if (codigo != null) await controller.guardarCodigo(codigo);
  }

  Widget _campoInscripcion(BuildContext context) => _priceField(
        context,
        controller: controller.inscripcionController,
        label: 'Costo de inscripción',
        icon: Icons.how_to_reg_outlined,
      );

  /// La inscripción: una vez, a los clientes nuevos, junto con su primer
  /// pago. Al cobrar no se puede cambiar el monto, solo quitarla.
  Widget _inscripcion(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloSeccion('Inscripción',
              detalle: controller.soloInscripcion
                  ? '¿Cobras inscripción a los clientes nuevos? Se cobra una '
                      'vez, junto con su primer pago.'
                  : 'Solo a clientes nuevos, una vez, junto con su primer '
                      'pago. Déjalo vacío si no cobras inscripción.'),
          // En pantalla grande, del ancho de un campo de precio.
          if (PlataformaApp.pantallaGrande)
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _campoInscripcion(context),
              ),
            )
          else
            _campoInscripcion(context),
        ],
      );

  Widget _priceField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    final c = context.colores;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: '\$ ',
        prefixStyle: const TextStyle(
          color: AppColors.accent,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DialogoCodigoNuevo extends StatefulWidget {
  const _DialogoCodigoNuevo();

  @override
  State<_DialogoCodigoNuevo> createState() => _DialogoCodigoNuevoState();
}

class _DialogoCodigoNuevoState extends State<_DialogoCodigoNuevo> {
  final _codigo = TextEditingController();
  final _repetido = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    _repetido.dispose();
    super.dispose();
  }

  void _listo() {
    final codigo = _codigo.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(codigo)) {
      setState(() => _error = 'El código lleva de 4 a 6 números.');
      return;
    }
    if (codigo != _repetido.text.trim()) {
      setState(() => _error = 'Los dos códigos no coinciden.');
      return;
    }
    Get.back(result: codigo);
  }

  Widget _campo(TextEditingController controlador, String etiqueta,
          {Key? key, bool ultimo = false, String? error}) =>
      TextField(
        key: key,
        controller: controlador,
        autofocus: !ultimo,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
        onSubmitted: ultimo ? (_) => _listo() : null,
        style: const TextStyle(fontSize: 22, letterSpacing: 6),
        decoration: InputDecoration(
          labelText: etiqueta,
          counterText: '',
          errorText: error,
          errorMaxLines: 2,
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Código para abono libre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'De 4 a 6 números. Dáselo solo a quien pueda autorizar abonos '
              'libres.',
              style: TextStyle(height: 1.35),
            ),
            const SizedBox(height: 16),
            _campo(_codigo, 'Código nuevo', key: const Key('codigo_nuevo')),
            const SizedBox(height: 12),
            _campo(_repetido, 'Repite el código',
                key: const Key('codigo_repetido'), ultimo: true, error: _error),
          ],
        ),
        actions: [
          BotonCancelar(onPressed: () => Get.back()),
          BotonGuardar(texto: 'Guardar', compacto: true, onPressed: _listo),
        ],
      );
}
