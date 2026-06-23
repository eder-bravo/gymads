import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/core/widgets/cached_user_image.dart';
import 'package:intl/intl.dart';

import '../controllers/abonar_controller.dart';

class AbonarView extends GetView<AbonarController> {
  const AbonarView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Abonar'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isSuccess.value) {
            return _buildSuccessState();
          }

          if (controller.selectedClient.value == null) {
            return _buildSearchState(context);
          }

          return _buildAbonarForm();
        }),
      ),
    );
  }

  Widget _buildSearchState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Buscar Cliente',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.titleColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Busca por nombre o teléfono celular.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller.searchController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ej: Juan Pérez, 551234...',
              prefixIcon: const Icon(Icons.search, color: AppColors.accent),
              filled: true,
              fillColor: AppColors.containerBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() {
              if (controller.isSearching.value) {
                return const Center(child: CircularProgressIndicator(color: AppColors.accent));
              }

              if (controller.searchResults.isEmpty && controller.searchController.text.length >= 3) {
                return const Center(
                  child: Text(
                    'No se encontraron resultados',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.builder(
                itemCount: controller.searchResults.length,
                itemBuilder: (context, index) {
                  final client = controller.searchResults[index];
                  return Card(
                    color: AppColors.cardBackground,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      onTap: () => controller.selectClient(client),
                      leading: UserThumbnail(
                        imageUrl: client.photoUrl,
                        userName: client.name,
                        size: 40,
                      ),
                      title: Text(
                        client.name,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Tel: ${client.phone}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.accent),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAbonarForm() {
    final client = controller.selectedClient.value!;
    
    return Column(
      children: [
        // Cabecera Cliente
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      client.isActive && client.daysRemaining > 0 
                        ? 'Activo - Le quedan ${client.daysRemaining} días'
                        : 'Inactivo o Vencido',
                      style: TextStyle(
                        color: client.isActive && client.daysRemaining > 0 ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: controller.clearSelection,
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                tooltip: 'Cambiar cliente',
              ),
            ],
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Detalles del Abono',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.titleColor,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Cantidad Monetaria
                TextField(
                  controller: controller.amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Cantidad a Pagar',
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(color: AppColors.accent, fontSize: 24, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: AppColors.containerBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Duración
                const Text(
                  'Duración',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.containerBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: controller.decrementDuration,
                              icon: const Icon(Icons.remove, color: AppColors.textPrimary),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                            GetBuilder<AbonarController>(
                              builder: (_) => Text(
                                controller.durationController.text.isEmpty ? '0' : controller.durationController.text,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: controller.incrementDuration,
                              icon: const Icon(Icons.add, color: AppColors.textPrimary),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Obx(() => DropdownButtonFormField<String>(
                        value: controller.durationType.value,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.containerBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        dropdownColor: AppColors.cardBackground,
                        style: const TextStyle(color: AppColors.textPrimary),
                        items: controller.durationTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            controller.durationType.value = val;
                            controller.update(); // Rebuild to update expiration
                          }
                        },
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Metodo de pago
                Obx(() => DropdownButtonFormField<String>(
                  value: controller.paymentMethod.value,
                  decoration: InputDecoration(
                    labelText: 'Método de Pago',
                    prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.accent),
                    filled: true,
                    fillColor: AppColors.containerBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  dropdownColor: AppColors.cardBackground,
                  style: const TextStyle(color: AppColors.textPrimary),
                  items: controller.paymentMethods.map((method) {
                    return DropdownMenuItem(value: method, child: Text(method));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) controller.paymentMethod.value = val;
                  },
                )),
                const SizedBox(height: 30),
                
                // Proyección de Fecha
                GetBuilder<AbonarController>(
                  builder: (ctrl) {
                    final newExp = ctrl.calculateNewExpirationDate();
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
                                const Text(
                                  'Hasta qué fecha puede entrar',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                  }
                ),
                const SizedBox(height: 40),
                
                // Botón Enviar
                Obx(() => ElevatedButton(
                  onPressed: controller.isLoading.value ? null : () => controller.procesarAbono(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: controller.isLoading.value
                    ? const SizedBox(
                        height: 24, width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Registrar Abono',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    final client = controller.selectedClient.value!;
    return Center(
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
              child: const Icon(Icons.check_circle, size: 80, color: AppColors.success),
            ),
            const SizedBox(height: 32),
            const Text(
              '¡Abono Registrado!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.titleColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Se registró el abono para ${client.name} correctamente.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: controller.clearSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Abonar a otro cliente',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
