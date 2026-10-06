import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../controllers/abono_prices_controller.dart';

/// Pantalla de Precios de Abonos: precio fijo por día, semana, mes y año,
/// inscripción para clientes nuevos y el código del encargado para el abono
/// libre. En el asistente con abono libre solo pregunta la inscripción
/// ([AbonoPricesController.soloInscripcion]); con costos fijos, pide ahí
/// mismo el código ([AbonoPricesController.pideCodigoInicial]).
///
/// Con pocas palabras: títulos cortos y cada campo dice qué es.
///
/// Acostada (tableta o teléfono de lado): los precios a la izquierda y la
/// inscripción y el código a la derecha.
class AbonoPricesView extends GetView<AbonoPricesController> {
  const AbonoPricesView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final acostada = pantallaAcostada(context);
    return ScaffoldAdaptable(
      anchoMaximo: acostada ? 1100 : 800,
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
                if (controller.soloInscripcion)
                  _inscripcion(context)
                else if (acostada)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _seccionPrecios(context)),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _inscripcion(context),
                            const SizedBox(height: 32),
                            ..._seccionCodigo(context),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _seccionPrecios(context),
                  const SizedBox(height: 32),
                  _inscripcion(context),
                  const SizedBox(height: 32),
                  ..._seccionCodigo(context),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _seccionPrecios(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloSeccion('Precios',
              detalle: 'Deja vacío el que no ofrezcas.'),
          _precios(context),
        ],
      );

  /// Al configurar el gimnasio se crea; en Configuración se cambia.
  List<Widget> _seccionCodigo(BuildContext context) => [
        if (controller.pideCodigoInicial)
          _codigoInicial(context)
        else if (!controller.isOnboarding)
          _codigo(context),
      ];

  /// Día, semana, mes y año. En pantalla grande y de lado, dos por fila.
  Widget _precios(BuildContext context) {
    final campos = [
      _priceField(context,
          controller: controller.dayController,
          label: 'Por día',
          icon: Icons.today),
      _priceField(context,
          controller: controller.weekController,
          label: 'Por semana',
          icon: Icons.date_range),
      _priceField(context,
          controller: controller.monthController,
          label: 'Por mes',
          icon: Icons.calendar_month),
      _priceField(context,
          controller: controller.yearController,
          label: 'Por año',
          icon: Icons.event_repeat),
    ];
    // De lado van en media pantalla: caben dos por fila desde más angostos.
    if (pantallaAcostada(context)) {
      return ResumenAdaptable(anchoMinimo: 180, espacio: 16, children: campos);
    }
    if (PlataformaApp.pantallaGrande) {
      return ResumenAdaptable(anchoMinimo: 300, espacio: 16, children: campos);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < campos.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          campos[i],
        ],
      ],
    );
  }

  /// La inscripción: una vez, a los clientes nuevos, junto con su primer
  /// pago. Al cobrar no se puede cambiar el monto, solo quitarla.
  Widget _inscripcion(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloSeccion('Inscripción',
              detalle: controller.soloInscripcion
                  ? '¿Cobras inscripción a los clientes nuevos?'
                  : 'Solo para clientes nuevos.'),
          _angosto(_priceField(
            context,
            controller: controller.inscripcionController,
            label: 'Costo de inscripción',
            icon: Icons.how_to_reg_outlined,
          )),
        ],
      );

  /// Al configurar el gimnasio con costos fijos: el código del encargado,
  /// escrito dos veces. Opcional.
  Widget _codigoInicial(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloSeccion('Código para abono libre',
              detalle: 'Lo pide el mostrador para cobrar sin precio fijo. '
                  'Puedes crearlo después.'),
          _angosto(_campoCodigo(
            context,
            controller.codigoNuevoController,
            'Código (4 a 6 números)',
            llave: const Key('codigo_inicial'),
          )),
          const SizedBox(height: 16),
          _angosto(_campoCodigo(
            context,
            controller.codigoRepetidoController,
            'Repite el código',
            llave: const Key('codigo_inicial_repetido'),
          )),
        ],
      );

  /// En Configuración: si hay código (nunca se muestra), y crearlo,
  /// cambiarlo o quitarlo.
  Widget _codigo(BuildContext context) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Código para abono libre',
            detalle: 'Lo pide el mostrador para cobrar sin precio fijo.'),
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
                        false => 'Sin código',
                        null => 'No se pudo revisar',
                      },
                      style: TextStyle(color: c.textPrimary, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Botones de ancho natural: los dos caben en el teléfono.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
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

  /// En pantalla grande, un campo solo no va de lado a lado.
  Widget _angosto(Widget campo) => PlataformaApp.pantallaGrande
      ? Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: campo,
          ),
        )
      : campo;

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

/// Un campo para el código: solo números, oculto, de 4 a 6.
Widget _campoCodigo(
  BuildContext context,
  TextEditingController controlador,
  String etiqueta, {
  Key? llave,
  bool autofocus = false,
  String? error,
  ValueChanged<String>? alTerminar,
}) =>
    TextField(
      key: llave,
      controller: controlador,
      autofocus: autofocus,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction:
          alTerminar == null ? TextInputAction.next : TextInputAction.done,
      onSubmitted: alTerminar,
      style: const TextStyle(fontSize: 22, letterSpacing: 6),
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: const Icon(Icons.lock_outline),
        counterText: '',
        errorText: error,
        errorMaxLines: 2,
      ),
    );

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
    final error =
        AbonoPricesController.errorDeCodigo(codigo, _repetido.text.trim());
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Get.back(result: codigo);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Código para abono libre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _campoCodigo(context, _codigo, 'Código (4 a 6 números)',
                llave: const Key('codigo_nuevo'), autofocus: true),
            const SizedBox(height: 12),
            _campoCodigo(context, _repetido, 'Repite el código',
                llave: const Key('codigo_repetido'),
                error: _error,
                alTerminar: (_) => _listo()),
          ],
        ),
        actions: [
          BotonCancelar(onPressed: () => Get.back()),
          BotonGuardar(texto: 'Guardar', compacto: true, onPressed: _listo),
        ],
      );
}
