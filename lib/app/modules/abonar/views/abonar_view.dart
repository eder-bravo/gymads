import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/core/widgets/cached_user_image.dart';
import 'package:gymads/app/core/widgets/tour_step.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/refrescable.dart';
import '../controllers/abonar_controller.dart';
import '../../../core/widgets/centrado_desplazable.dart';
import '../../../core/widgets/cabecera_con_lista.dart';
import 'package:gymads/app/core/widgets/formulario.dart';

class AbonarView extends GetView<AbonarController> {
  const AbonarView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Scaffold(
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
    );
  }

  Widget _buildSearchState(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TourStep(
            tourKey: controller.keyBuscar,
            title: 'Busca al cliente',
            description: 'Escribe su teléfono o su nombre para encontrarlo. '
                'También puedes pasar su tarjeta por el lector.',
            isFirstStep: true,
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
              description: 'Aquí están todos tus clientes en orden '
                  'alfabético. Toca a uno para elegir el periodo, el monto y '
                  'registrar el pago.',
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
                        child: ListTile(
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
                            style:
                                TextStyle(color: c.textSecondary),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16, color: AppColors.accent),
                        ),
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

  Widget _buildAbonarForm(BuildContext context) {
    final c = context.colores;
    final client = controller.selectedClient.value!;

    // La cabecera del cliente deja de estar fija cuando falta altura
    // (teléfono de lado, o el teclado abierto al escribir el monto).
    return CabeceraConLista(
      cabecera: [
        // Cabecera Cliente
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.backgroundColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Row(
            children: [
              UserThumbnail(
                imageUrl: client.photoUrl,
                userName: client.name,
                size: 60,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: c.titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      client.isActive && client.daysRemaining > 0
                          ? 'Activo - Le quedan ${client.daysRemaining} días'
                          : 'Inactivo o Vencido',
                      style: TextStyle(
                        color: client.isActive && client.daysRemaining > 0
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: controller.clearSelection,
                icon: Icon(Icons.close, color: c.textSecondary),
                tooltip: 'Cambiar cliente',
              ),
            ],
          ),
        ),
      ],
      lista: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Detalles del Abono',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: c.titleColor,
              ),
            ),
            const SizedBox(height: 20),

            // Selector de precio fijo / libre
            _buildModoToggle(context),
            const SizedBox(height: 20),

            // Cantidad, periodo y precio unitario
            _buildCamposAbono(context),

            // Total a pagar (solo lectura)
            Obx(() {
              final currency =
                  NumberFormat.currency(locale: 'es_MX', symbol: '\$');
              final total = controller.totalAmount;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total a Pagar',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      currency.format(total),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),

            // Metodo de pago
            Obx(() => DropdownButtonFormField<String>(
                  value: controller.paymentMethod.value,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  dropdownColor: c.cardBackground,
                  style: TextStyle(color: c.textPrimary),
                  items: controller.paymentMethods.map((method) {
                    return DropdownMenuItem(value: method, child: Text(method));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) controller.paymentMethod.value = val;
                  },
                )),
            const SizedBox(height: 30),

            // Proyección de Fecha
            Obx(() {
              final newExp = controller.calculateNewExpirationDate();
              final formattedDate = DateFormat('dd/MM/yyyy').format(newExp);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nueva Fecha de Expiración',
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 12),
                          ),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: AppColors.info,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 40),

            // Botón Enviar
            Obx(() => BotonGuardar(
                  texto: 'Registrar abono',
                  guardando: controller.isLoading.value,
                  onPressed: () => controller.procesarAbono(),
                )),
          ],
        ),
      ),
    );
  }

  // Toggle segmentado Precio fijo / Libre
  Widget _buildModoToggle(BuildContext context) {
    final c = context.colores;
    return Container(
      decoration: BoxDecoration(
        color: c.contraste.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.contraste.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.all(4),
      child: Obx(() {
        final fijo = controller.isPrecioFijo.value;
        return Row(
          children: [
            _modoButton(context, 'Precio fijo', true, fijo),
            _modoButton(context, 'Libre', false, fijo),
          ],
        );
      }),
    );
  }

  Widget _modoButton(BuildContext context, String label, bool value, bool fijoActivo) {
    final c = context.colores;
    final seleccionado = fijoActivo == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.setPrecioFijo(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
              color: seleccionado ? Colors.white : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // Cantidad de periodos, tipo de periodo y precio unitario
  Widget _buildCamposAbono(BuildContext context) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Periodo a pagar: cantidad + tipo
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: controller.durationController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  prefixIcon: IconButton(
                    onPressed: controller.decrementDuration,
                    icon: const Icon(Icons.remove, size: 18),
                    color: AppColors.accent,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    splashRadius: 18,
                    tooltip: 'Restar',
                  ),
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  suffixIcon: IconButton(
                    onPressed: controller.incrementDuration,
                    icon: const Icon(Icons.add, size: 18),
                    color: AppColors.accent,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    splashRadius: 18,
                    tooltip: 'Sumar',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Obx(() => DropdownButtonFormField<String>(
                    value: controller.durationType.value,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 18),
                    ),
                    dropdownColor: c.cardBackground,
                    style: TextStyle(color: c.textPrimary),
                    items: controller.durationTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) controller.setDurationType(val);
                    },
                  )),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Precio unitario
        Obx(() {
          final fijo = controller.isPrecioFijo.value;
          final sinPrecio = fijo && controller.configuredPrice == null;
          return TextField(
            controller: controller.unitPriceController,
            readOnly: fijo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Precio por ${controller.durationUnitLabel}',
              helperText: fijo ? 'Precio configurado' : 'Precio libre',
              helperStyle: TextStyle(color: c.textSecondary),
              errorText:
                  sinPrecio ? 'Sin precio configurado para este periodo' : null,
              suffixIcon: fijo
                  ? Icon(Icons.lock_outline,
                      size: 18, color: c.textSecondary)
                  : null,
              prefixText: '\$ ',
              prefixStyle: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
              // Bloqueado (precio fijo): más apagado que un campo normal.
              fillColor: fijo ? c.contraste.withOpacity(0.02) : null,
            ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    final c = context.colores;
    final client = controller.selectedClient.value!;
    return CentradoDesplazable(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  size: 80, color: AppColors.success),
            ),
            const SizedBox(height: 32),
            Text(
              '¡Abono Registrado!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: c.titleColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Se registró el abono para ${client.name} correctamente.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 16, color: c.textSecondary),
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
