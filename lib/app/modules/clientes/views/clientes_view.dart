import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/global_widgets/cliente_card.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/core/utils/responsive_utils.dart';
import 'cliente_detail_view.dart';
import '../controllers/clientes_controller.dart';

class ClientesView extends GetView<ClientesController> {
  const ClientesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Clientes'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.fetchClientes(),
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(),
            tooltip: 'add',
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.accent),
                  SizedBox(height: 20),
                  Text(
                    'Cargando clientes...',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.all(ResponsiveValues.getSpacing(context,
                    mobile: 16, smallPhone: 12, tablet: 24)),
                child: Column(
                  children: [
                    TextField(
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Buscar cliente...',
                        hintStyle: const TextStyle(color: AppColors.textHint),
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.containerBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (value) =>
                          controller.searchQuery.value = value,
                    ),
                    SizedBox(
                        height: ResponsiveValues.getSpacing(context,
                            mobile: 12, smallPhone: 8, tablet: 16)),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  final filteredClientes = controller.filteredClientes;

                  if (filteredClientes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: ResponsiveValues.getIconSize(context,
                                mobile: 80, smallPhone: 60, tablet: 100),
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(
                              height: ResponsiveValues.getSpacing(context,
                                  mobile: 20, smallPhone: 16, tablet: 24)),
                          Text(
                            controller.clientes.isEmpty
                                ? 'No hay clientes registrados'
                                : 'No hay resultados para tu búsqueda',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredClientes.length,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemBuilder: (context, index) {
                      final cliente = filteredClientes[index];

                      return ClienteCard(
                        cliente: cliente,
                        onTap: () => _showClienteDetails(cliente),
                      );
                    },
                  );
                }),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _showClienteDetails(UserModel cliente) {
    Get.to(() => ClienteDetailView(cliente: cliente));
  }

  void _showAddDialog() {
    controller.showAddDialog();
  }
}
