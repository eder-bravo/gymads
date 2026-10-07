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
/// En tableta se agrupan los importes y se reserva espacio para el código;
/// en horizontal van lado a lado y en vertical, uno debajo del otro.
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
            key: const Key('formulario_precios'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: PlataformaApp.tableta
                ? const EdgeInsets.all(12)
                : const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: _contenidoFormulario(context, dosColumnas: acostada),
          );
        }),
      ),
    );
  }

  Widget _contenidoFormulario(BuildContext context,
      {required bool dosColumnas}) {
    if (controller.soloInscripcion) return _inscripcion(context);
    if (PlataformaApp.tableta) {
      return _contenidoTableta(context, acostada: dosColumnas);
    }
    if (!dosColumnas) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _seccionPrecios(context),
          const SizedBox(height: 18),
          _inscripcion(context),
          const SizedBox(height: 18),
          ..._seccionCodigo(context),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _seccionPrecios(context)),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _inscripcion(context),
              const SizedBox(height: 18),
              ..._seccionCodigo(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contenidoTableta(BuildContext context, {required bool acostada}) {
    final c = context.colores;
    final precios = _tarjetaSeccion(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion(
              context, 'Precios', 'Deja vacío el periodo que no ofrezcas.'),
          _precios(context,
              compactoTableta: true, incluirInscripcion: !acostada),
          const SizedBox(height: 8),
          Text(
              'El precio por día también se usa para cobrar una visita de un día.',
              style: TextStyle(color: c.textSecondary, fontSize: 14)),
          if (acostada) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: c.borde),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, limits) {
              final etiqueta = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Inscripción',
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Solo para clientes nuevos. Deja vacío si no cobras.',
                      style: TextStyle(color: c.textSecondary, fontSize: 14)),
                ],
              );
              final campo = _entradaPrecio(context,
                  controller: controller.inscripcionController,
                  label: 'Costo de inscripción',
                  icon: Icons.how_to_reg_outlined,
                  llave: const Key('precio_inscripcion'));
              if (limits.maxWidth <
                  340 * MediaQuery.textScalerOf(context).scale(14) / 14) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [etiqueta, const SizedBox(height: 8), campo],
                );
              }
              return Row(children: [
                Expanded(child: etiqueta),
                const SizedBox(width: 12),
                Expanded(child: campo),
              ]);
            }),
          ] else ...[
            const SizedBox(height: 6),
            Text('Inscripción: solo clientes nuevos. Deja vacío si no cobras.',
                style: TextStyle(color: c.textSecondary, fontSize: 14)),
          ],
        ],
      ),
    );
    final codigo = controller.pideCodigoInicial
        ? _codigoInicial(context, tableta: true)
        : _codigo(context);
    if (!acostada) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [precios, const SizedBox(height: 16), codigo],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: precios),
        const SizedBox(width: 16),
        Expanded(child: codigo),
      ],
    );
  }

  Widget _tarjetaSeccion(BuildContext context, Widget child) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.borde),
      ),
      child: child,
    );
  }

  Widget _tituloSeccion(BuildContext context, String titulo, String detalle) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(detalle,
              style: TextStyle(
                  color: c.textSecondary, fontSize: 15, height: 1.35)),
        ],
      ),
    );
  }

  Widget _seccionPrecios(BuildContext context) => _tarjetaSeccion(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion(context, 'Precios',
              'Escribe el precio de cada periodo. Deja vacío el que no ofrezcas.'),
          _precios(context),
        ],
      ));

  /// Al configurar el gimnasio se crea; en Configuración se cambia.
  List<Widget> _seccionCodigo(BuildContext context) => [
        if (controller.pideCodigoInicial)
          _codigoInicial(context)
        else if (!controller.isOnboarding)
          _codigo(context),
      ];

  /// Los periodos y, en tableta vertical, la inscripción. La cuadrícula
  /// usa el ancho disponible y crece en alto cuando se amplía el texto.
  Widget _precios(BuildContext context,
      {bool compactoTableta = false, bool incluirInscripcion = false}) {
    final campos = [
      _priceField(context,
          controller: controller.dayController,
          label: 'Por día',
          detalle: compactoTableta
              ? null
              : 'También se usa para cobrar una visita de un día.',
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
      if (incluirInscripcion)
        _priceField(context,
            controller: controller.inscripcionController,
            label: 'Costo de inscripción',
            icon: Icons.how_to_reg_outlined,
            llave: const Key('precio_inscripcion')),
    ];
    if (compactoTableta) {
      return ResumenAdaptable(anchoMinimo: 170, espacio: 14, children: campos);
    }
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
  Widget _inscripcion(BuildContext context) => _tarjetaSeccion(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion(
              context,
              'Inscripción',
              controller.soloInscripcion
                  ? '¿Cobras inscripción a los clientes nuevos?'
                  : 'Solo para clientes nuevos.'),
          _angosto(_priceField(
            context,
            controller: controller.inscripcionController,
            label: 'Costo de inscripción',
            icon: Icons.how_to_reg_outlined,
            llave: const Key('precio_inscripcion'),
          )),
          const SizedBox(height: 10),
          Text('Deja vacío si no cobras inscripción.',
              style: TextStyle(
                  color: context.colores.textSecondary, fontSize: 14)),
        ],
      ));

  /// Al configurar el gimnasio con costos fijos: el código del encargado,
  /// escrito dos veces. Opcional.
  Widget _codigoInicial(BuildContext context, {bool tableta = false}) =>
      _tarjetaSeccion(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tituloSeccion(context, '¿También cobrarás abonos libres?',
                  'Cobra otra cantidad con un abono libre. Usa un código para autorizarlo.'),
              Obx(() {
                final activar = controller.configurarCodigoInicial.value;
                final opciones = [
                  _opcionCodigo(
                    context,
                    llave: const Key('codigo_no_ahora'),
                    texto: 'No, usar solo estos precios',
                    detalle: 'Puedes crear el código más adelante.',
                    elegida: !activar,
                    alElegir: () =>
                        controller.configurarCodigoInicial.value = false,
                  ),
                  _opcionCodigo(
                    context,
                    llave: const Key('codigo_activar'),
                    texto: 'Sí, crear un código',
                    detalle:
                        'El mostrador lo usará para cobrar un abono libre.',
                    elegida: activar,
                    alElegir: () =>
                        controller.configurarCodigoInicial.value = true,
                  ),
                ];
                final campos = [
                  _campoCodigo(context, controller.codigoNuevoController,
                      tableta ? 'Código' : 'Escribe el código',
                      conIcono: !tableta, llave: const Key('codigo_inicial')),
                  _campoCodigo(context, controller.codigoRepetidoController,
                      tableta ? 'Repite el código' : 'Repítelo para confirmar',
                      conIcono: !tableta,
                      llave: const Key('codigo_inicial_repetido')),
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tableta)
                      ResumenAdaptable(
                          anchoMinimo: 240, espacio: 10, children: opciones)
                    else ...[
                      opciones.first,
                      const SizedBox(height: 10),
                      opciones.last,
                    ],
                    if (activar) ...[
                      const SizedBox(height: 20),
                      Text('Elige un código de 4 a 6 números',
                          style: TextStyle(
                              color: context.colores.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                          'Guárdalo: autoriza al mostrador a cobrar un abono libre.',
                          style: TextStyle(
                              color: context.colores.textSecondary,
                              fontSize: 14)),
                      const SizedBox(height: 14),
                      if (tableta)
                        ResumenAdaptable(
                            anchoMinimo: 170, espacio: 10, children: campos)
                      else ...[
                        campos.first,
                        const SizedBox(height: 10),
                        campos.last,
                      ],
                    ],
                  ],
                );
              }),
            ],
          ));

  Widget _opcionCodigo(
    BuildContext context, {
    required Key llave,
    required String texto,
    required String detalle,
    required bool elegida,
    required VoidCallback alElegir,
  }) {
    final c = context.colores;
    return Semantics(
      selected: elegida,
      child: Material(
        color: elegida ? AppColors.accent.withOpacity(0.1) : c.superficie,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: llave,
          onTap: alElegir,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: elegida ? AppColors.accent : c.borde,
                  width: elegida ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(
                  elegida ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: elegida ? AppColors.accent : c.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(texto,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text(detalle,
                          style:
                              TextStyle(color: c.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// En Configuración: si hay código (nunca se muestra), y crearlo,
  /// cambiarlo o quitarlo.
  Widget _codigo(BuildContext context) {
    final c = context.colores;
    return _tarjetaSeccion(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tituloSeccion(context, 'Código para abono libre',
                'Permite cobrar una cantidad distinta a los precios fijos. El mostrador debe escribir el código para autorizar el cobro.'),
            Obx(() {
              final hay = controller.hayCodigo.value;
              final guardando = controller.guardandoCodigo.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        hay == true
                            ? Icons.lock_outline
                            : Icons.lock_open_outlined,
                        color:
                            hay == true ? AppColors.success : c.textSecondary,
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
                          onPressed: guardando
                              ? null
                              : () => _pedirCodigoNuevo(context),
                          icon: const Icon(Icons.pin_outlined),
                          label: Text(hay ? 'Cambiar código' : 'Crear código'),
                        ),
                        if (hay)
                          TextButton.icon(
                            onPressed:
                                guardando ? null : controller.quitarCodigo,
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
        ));
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
    String? detalle,
    Key? llave,
  }) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _entradaPrecio(context,
            controller: controller,
            label: label,
            icon: icon,
            detalle: detalle,
            llave: llave),
        if (detalle != null) ...[
          const SizedBox(height: 8),
          Text(detalle,
              style: TextStyle(
                  color: c.textSecondary, fontSize: 14, height: 1.35)),
        ],
      ],
    );
  }

  Widget _entradaPrecio(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? detalle,
    Key? llave,
  }) {
    final c = context.colores;
    return Semantics(
      label: label,
      hint: detalle,
      child: TextField(
        key: llave,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: '0.00',
          // prefixText se oculta cuando el campo está vacío y sin foco.
          // En prefixIcon el símbolo permanece visible en todo momento.
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 10),
                Text('\$',
                    style: TextStyle(
                      color: c.titleColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
          ),
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
  bool conIcono = true,
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
        prefixIcon: conIcono ? const Icon(Icons.lock_outline) : null,
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
            const Text(
                'Elige de 4 a 6 números. El mostrador usará este código para autorizar el cobro de un abono libre.'),
            const SizedBox(height: 16),
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
