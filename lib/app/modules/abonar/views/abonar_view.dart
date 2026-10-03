import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/core/widgets/cached_user_image.dart';
import 'package:gymads/app/core/widgets/tour_step.dart';
import 'package:gymads/app/global_widgets/app_header.dart';

import '../../../core/widgets/refrescable.dart';
import '../controllers/abonar_controller.dart';
import '../../../data/models/user_model.dart';
import '../vigencia.dart';
import 'cobrar_visita_view.dart';
import '../../../core/widgets/centrado_desplazable.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/core/widgets/metodo_de_pago.dart';
import 'package:gymads/app/core/utils/referencia_de_pago.dart';

class AbonarView extends GetView<AbonarController> {
  const AbonarView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ScaffoldAdaptable(
      anchoMaximo: 800,
      backgroundColor: c.backgroundColor,
      appBar: GymAppBar(
        title: 'Abonar',
        actions: [
          // Solo mientras se busca: con un cobro a medias o ya hecho, el botón
          // no recargaría nada de lo que hay en pantalla.
          Obx(() {
            final buscando = !controller.isSuccess.value &&
                controller.selectedClient.value == null;
            if (!buscando) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: controller.refrescar,
              tooltip: 'Actualizar',
            );
          }),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isSuccess.value) {
            return _buildSuccessState(context);
          }

          if (controller.selectedClient.value == null) {
            return _buildSearchState(context);
          }

          return _buildAbonarForm(context);
        }),
      ),
      // El botón de cobrar, fijo abajo y con el monto: siempre a la vista.
      bottomNavigationBar: Obx(() {
        final cobrando = !controller.isSuccess.value &&
            controller.selectedClient.value != null;
        return cobrando ? _botonCobrar(context) : const SizedBox.shrink();
      }),
    );
  }

  Widget _buildSearchState(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Visita de un día: se cobra sin registrarlo como cliente.
          TourStep(
            tourKey: controller.keyVisita,
            title: 'Cobrar una visita',
            description: 'Cobra un día a alguien que no es cliente.',
            isFirstStep: true,
            child: Obx(() {
              final precio = controller.prices.value?.priceDay;
              final boton = OutlinedButton.icon(
                onPressed: () => abrirCobrarVisita(precioDia: precio),
                icon: const Icon(Icons.confirmation_number_outlined, size: 20),
                label: Text(precio == null
                    ? 'Cobrar visita'
                    : 'Cobrar visita · ${pesos(precio)}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                  // En escritorio, del ancho de su texto y a la derecha:
                  // la búsqueda del cliente es lo principal de la pantalla.
                  minimumSize: PlataformaApp.pantallaGrande
                      ? const Size(0, 48)
                      : const Size.fromHeight(48),
                  padding: PlataformaApp.pantallaGrande
                      ? const EdgeInsets.symmetric(horizontal: 20)
                      : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              );
              return PlataformaApp.pantallaGrande
                  ? Align(alignment: Alignment.centerRight, child: boton)
                  : boton;
            }),
          ),
          const SizedBox(height: 16),
          TourStep(
            tourKey: controller.keyBuscar,
            title: 'Busca al cliente',
            description:
                'Busca por nombre o teléfono, o pasa su tarjeta por el lector.',
            child: AppSearchField(
              hintText: 'Buscar cliente...',
              controller: controller.searchController,
              keyboardType: TextInputType.phone,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TourStep(
              tourKey: controller.keyResultados,
              title: 'Cobra su membresía',
              description: '${PlataformaApp.toca} un cliente para cobrarle.',
              isLastStep: true,
              child: Obx(() {
                if (controller.isLoadingClients.value) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent));
                }

                if (controller.searchResults.isEmpty) {
                  return Refrescable.centrado(
                    onRefresh: controller.refrescar,
                    child: Text(
                      controller.searchController.text.trim().isEmpty
                          ? 'No hay clientes registrados'
                          : 'No se encontraron resultados',
                      style: TextStyle(color: c.textSecondary),
                    ),
                  );
                }

                return Refrescable(
                  onRefresh: controller.refrescar,
                  child: ListView.builder(
                    itemCount: controller.searchResults.length,
                    itemBuilder: (context, index) {
                      final client = controller.searchResults[index];
                      return Card(
                        color: c.cardBackground,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: LayoutBuilder(builder: (context, limites) {
                          final escala =
                              MediaQuery.textScalerOf(context).scale(14) / 14;
                          if (limites.maxWidth < 280 * escala) {
                            return InkWell(
                              onTap: () => controller.selectClient(client),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: UserThumbnail(
                                        imageUrl: client.photoUrl,
                                        userName: client.name,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(client.name,
                                        style: TextStyle(
                                            color: c.textPrimary,
                                            fontWeight: FontWeight.bold)),
                                    Text('Tel: ${client.phone}',
                                        style:
                                            TextStyle(color: c.textSecondary)),
                                  ],
                                ),
                              ),
                            );
                          }
                          return ListTile(
                            onTap: () => controller.selectClient(client),
                            leading: UserThumbnail(
                              imageUrl: client.photoUrl,
                              userName: client.name,
                              size: 40,
                            ),
                            title: Text(
                              client.name,
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Tel: ${client.phone}',
                              style: TextStyle(color: c.textSecondary),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                size: 16, color: AppColors.accent),
                          );
                        }),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// El cobro en tres pasos, de arriba abajo: cuánto tiempo, cómo paga y el
  /// resumen. Solo uno está abierto; los ya hechos se cierran y muestran lo
  /// elegido, con "Cambiar" para volver. El botón de abajo ([_botonCobrar])
  /// dice "Continuar" hasta el resumen, y ahí "Cobrar $…".
  Widget _buildAbonarForm(BuildContext context) {
    final client = controller.selectedClient.value!;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _cabeceraCliente(context, client),
        const SizedBox(height: 20),
        Obx(() => _seccionPaso(
              context,
              1,
              '¿Cuánto tiempo paga?',
              hecho: '${controller.periodoElegido} · '
                  '${pesos(controller.totalAmount)}',
              contenido: () => _pasoTiempo(context),
            )),
        Obx(() => _seccionPaso(
              context,
              2,
              '¿Cómo paga?',
              hecho: nombreMetodoDePago(controller.paymentMethod.value),
              contenido: () => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectorMetodoPago(
                    metodos: controller.paymentMethods,
                    elegido: controller.paymentMethod.value,
                    onElegir: controller.setPaymentMethod,
                  ),
                  if (controller.usaReferenciaPago)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: CampoReferenciaPago(controlador: controller),
                    ),
                ],
              ),
            )),
        Obx(() => _seccionPaso(
              context,
              3,
              'Resumen',
              hecho: '',
              contenido: () => _resumen(context),
            )),
      ],
    );
  }

  /// Un paso del cobro. Ya hecho: cerrado, con palomita, lo elegido y
  /// "Cambiar". Abierto: su título y su contenido. Por venir: solo el
  /// título, apagado, para que se vea qué sigue.
  Widget _seccionPaso(
    BuildContext context,
    int numero,
    String titulo, {
    required String hecho,
    required Widget Function() contenido,
  }) {
    final c = context.colores;
    final actual = controller.pasoActual.value;
    final Widget cuerpo;

    if (numero < actual) {
      cuerpo = Material(
        color: c.cardBackground,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => controller.irAPaso(numero),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.success, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                      Text(
                        hecho,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => controller.irAPaso(numero),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      final abierto = numero == actual;
      cuerpo = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _paso(context, numero, titulo, apagado: !abierto),
          if (abierto) contenido(),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: cuerpo,
      ),
    );
  }

  /// Quién paga: foto grande, nombre y cómo está su membresía en palabras.
  Widget _cabeceraCliente(BuildContext context, UserModel client) {
    final c = context.colores;
    final situacion = situacionDe(client, DateTime.now());
    final color = situacion.vencido ? AppColors.error : c.textSecondary;
    return Row(
      children: [
        UserThumbnail(
          imageUrl: client.photoUrl,
          userName: client.name,
          size: 72,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.name,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: c.titleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                situacion.texto,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight:
                      situacion.vencido ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (situacion.detalle != null)
                Text(
                  situacion.detalle!,
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
            ],
          ),
        ),
        if (PlataformaApp.pantallaGrande)
          TextButton.icon(
            onPressed: controller.clearSelection,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Cambiar cliente'),
            style: TextButton.styleFrom(
              foregroundColor: c.textSecondary,
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          )
        else
          IconButton(
            onPressed: controller.clearSelection,
            icon: Icon(Icons.close, color: c.textSecondary),
            tooltip: 'Cambiar cliente',
          ),
      ],
    );
  }

  /// "① ¿Cuánto tiempo paga?": el número en un círculo y el título grande.
  Widget _paso(BuildContext context, int numero, String titulo,
      {bool apagado = false}) {
    final c = context.colores;
    final color = apagado ? c.textSecondary.withOpacity(0.5) : AppColors.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                color: apagado ? c.textSecondary : c.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Paso 1. Con costo fijo, una tarjeta por periodo con su precio; con
  /// abono libre, el periodo y cuánto paga en total. En los dos, "¿Cuántos?".
  Widget _pasoTiempo(BuildContext context) {
    final c = context.colores;
    final fijo = controller.isPrecioFijo.value;
    final periodos =
        fijo ? controller.periodosConPrecio : controller.durationTypes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.hayCostosFijos) ...[
          _pestanasModo(context, fijo),
          const SizedBox(height: 14),
        ],
        LayoutBuilder(builder: (context, medidas) {
          final ancho = (medidas.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in periodos)
                SizedBox(
                    width: ancho, child: _tarjetaPeriodo(context, p, fijo)),
            ],
          );
        }),
        const SizedBox(height: 18),
        _cuantos(context),
        if (!fijo) ...[
          const SizedBox(height: 18),
          TextField(
            key: const Key('monto_libre'),
            controller: controller.montoLibreController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              labelText: '¿Cuánto paga en total?',
              prefixText: '\$ ',
              prefixStyle: TextStyle(
                color: AppColors.accent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// "Costo fijo | Abono libre", como dos botones grandes.
  Widget _pestanasModo(BuildContext context, bool fijo) {
    final c = context.colores;
    Widget pestana(String texto, bool valor) {
      final elegida = fijo == valor;
      return Expanded(
        child: Material(
          color: elegida ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => controller.setPrecioFijo(valor),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: elegida ? FontWeight.bold : FontWeight.w500,
                  color: elegida ? Colors.white : c.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.contraste.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.contraste.withOpacity(0.10)),
      ),
      child: Row(children: [
        pestana('Costo fijo', true),
        pestana('Abono libre', false),
      ]),
    );
  }

  /// Una opción de periodo: "1 mes" y, con costo fijo, su precio.
  Widget _tarjetaPeriodo(BuildContext context, String periodo, bool fijo) {
    final c = context.colores;
    final elegida = controller.durationType.value == periodo;
    final precio = controller.prices.value?.priceFor(periodo);
    return Material(
      color: elegida ? AppColors.accent.withOpacity(0.12) : c.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: elegida ? AppColors.accent : c.borde,
          width: elegida ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => controller.setDurationType(periodo),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodoEnPalabras(1, periodo),
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (fijo && precio != null)
                      Text(
                        pesos(precio),
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              if (elegida)
                const Icon(Icons.check_circle, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }

  /// "¿Cuántos?  [ − ]  2 meses  [ + ]", con botones grandes.
  Widget _cuantos(BuildContext context) {
    final c = context.colores;
    Widget boton(IconData icono, String ayuda, VoidCallback? accion) {
      return Material(
        color: c.cardBackground,
        shape: CircleBorder(side: BorderSide(color: c.borde)),
        child: IconButton(
          onPressed: accion,
          tooltip: ayuda,
          icon: Icon(icono, size: 26),
          color: AppColors.accent,
          constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            '¿Cuántos?',
            style: TextStyle(color: c.textSecondary, fontSize: 16),
          ),
        ),
        boton(
          Icons.remove,
          'Uno menos',
          controller.durationValue.value > 1
              ? controller.decrementDuration
              : null,
        ),
        SizedBox(
          width: 104,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              controller.periodoElegido,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        boton(Icons.add, 'Uno más', controller.incrementDuration),
      ],
    );
  }

  /// Paso 3: como un recibo. Qué paga, cuánto y hasta cuándo queda pagado.
  Widget _resumen(BuildContext context) {
    final c = context.colores;
    final fijo = controller.isPrecioFijo.value;
    final precio = controller.configuredPrice;
    final total = controller.totalAmount;
    final hasta = controller.calculateNewExpirationDate();

    Widget renglon(String izquierda, String derecha, {bool grande = false}) {
      final estilo = TextStyle(
        color: grande ? c.textPrimary : c.textSecondary,
        fontSize: grande ? 20 : 16,
        fontWeight: grande ? FontWeight.bold : FontWeight.normal,
      );
      return Row(
        children: [
          Expanded(child: Text(izquierda, style: estilo)),
          Text(derecha,
              style: grande
                  ? estilo.copyWith(color: AppColors.accent, fontSize: 24)
                  : estilo),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          renglon(
            fijo && precio != null
                ? '${controller.periodoElegido} × ${pesos(precio)}'
                : controller.periodoElegido,
            pesos(total),
          ),
          Divider(height: 24, color: c.divisor),
          renglon('Total', pesos(total), grande: true),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.event_available, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Pagado hasta: '),
                    TextSpan(
                      text: fechaLarga(hasta, conDia: true),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ]),
                  style: TextStyle(color: c.textPrimary, fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// El botón de abajo, siempre en el mismo lugar: "Continuar" mientras se
  /// llenan los pasos y "Cobrar $1,000" en el resumen. Si falta algo, apagado
  /// y diciendo qué.
  Widget _botonCobrar(BuildContext context) {
    final c = context.colores;
    final falta = controller.faltaParaCobrar;
    final enResumen = controller.pasoActual.value == 3;
    return PieDeFormulario(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: PlataformaApp.pantallaGrande
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.center,
        children: [
          if (falta != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                falta,
                style: TextStyle(color: c.textSecondary, fontSize: 15),
              ),
            ),
          BotonGuardar(
            texto: !enResumen
                ? 'Continuar'
                : falta == null
                    ? 'Cobrar ${pesos(controller.totalAmount)}'
                    : 'Cobrar',
            guardando: controller.isLoading.value,
            onPressed: falta != null
                ? null
                : enResumen
                    ? controller.procesarAbono
                    : controller.continuar,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    final c = context.colores;
    final client = controller.selectedClient.value!;
    final vence = client.expirationDate;
    return CentradoDesplazable(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserThumbnail(
                  imageUrl: client.photoUrl,
                  userName: client.name,
                  size: 110,
                ),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle,
                        size: 44, color: AppColors.success),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              '¡Listo!',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: c.titleColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              vence == null
                  ? 'Se registró el pago de ${client.name}.'
                  : '${client.name} quedó pagado hasta el '
                      '${fechaLarga(vence)}.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: c.textSecondary),
            ),
            const SizedBox(height: 40),
            BotonGuardar(
              texto: 'Abonar a otro cliente',
              onPressed: controller.clearSelection,
            ),
          ],
        ),
      ),
    );
  }
}
