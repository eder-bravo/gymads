import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/onboarding_controller.dart';

/// Paso obligatorio de configuración inicial: cómo cobra el gimnasio sus
/// abonos. No se puede saltar (no hay botón atrás ni gesto de retroceso).
class PaymentModeView extends GetView<OnboardingController> {
  const PaymentModeView({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.width > 600;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: const GymAppBar(
          title: 'Configuración inicial',
          leading: SizedBox.shrink(),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isTablet ? 28 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¿Cómo cobras los abonos?',
                  style: TextStyle(
                    fontSize: isTablet ? 28 : 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige cómo quieres que funcione el cobro de membresías. '
                  'Puedes cambiarlo después desde Configuración.',
                  style: TextStyle(
                    fontSize: isTablet ? 15 : 14,
                    color: AppColors.textSecondary.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                Obx(() => _ChoiceCard(
                      icon: Icons.price_check,
                      title: 'Abonos fijos',
                      description:
                          'Defines un precio por día, semana, mes y año. '
                          'Al cobrar, el precio se llena solo.',
                      gradient: const [Color(0xFF667eea), Color(0xFF764ba2)],
                      isTablet: isTablet,
                      enabled: !controller.isSaving.value,
                      onTap: controller.chooseFijo,
                    )),
                const SizedBox(height: 14),
                Obx(() => _ChoiceCard(
                      icon: Icons.tune,
                      title: 'Abonos libres',
                      description:
                          'Escribes el precio en cada cobro. Ideal si tus '
                          'tarifas cambian según el cliente.',
                      gradient: const [Color(0xFF4facfe), Color(0xFF00f2fe)],
                      isTablet: isTablet,
                      enabled: !controller.isSaving.value,
                      isLoading: controller.isSaving.value,
                      onTap: controller.chooseLibre,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de elección, con el mismo lenguaje visual que los módulos de Inicio.
class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;
  final bool isTablet;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.isTablet,
    required this.enabled,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: EdgeInsets.all(isTablet ? 22 : 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradient[0].withOpacity(0.15),
                  gradient[1].withOpacity(0.08),
                ],
              ),
              border: Border.all(color: gradient[0].withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child:
                      Icon(icon, color: Colors.white, size: isTablet ? 30 : 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isTablet ? 19 : 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12.5,
                          color: AppColors.textSecondary.withOpacity(0.75),
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.25),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
