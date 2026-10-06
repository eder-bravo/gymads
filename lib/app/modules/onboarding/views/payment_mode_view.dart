import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/plataforma_app.dart';
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
    final c = context.colores;
    final bool isTablet = !PlataformaApp.escritorio &&
        MediaQuery.sizeOf(context).shortestSide >= 600;
    final acostada = pantallaAcostada(context);
    final grande = acostada && PlataformaApp.tableta;
    final fijo = Obx(() => _ChoiceCard(
          icon: Icons.price_check,
          title: 'Costos fijos',
          description: 'Un precio fijo por día, semana, mes y año.',
          gradient: const [Color(0xFF667eea), Color(0xFF764ba2)],
          isTablet: isTablet,
          grande: grande,
          enabled: !controller.isSaving.value,
          onTap: controller.chooseFijo,
        ));
    final libre = Obx(() => _ChoiceCard(
          icon: Icons.tune,
          title: 'Abonos libres',
          description: 'Escribes el precio en cada cobro.',
          gradient: const [Color(0xFF4facfe), Color(0xFF00f2fe)],
          isTablet: isTablet,
          grande: grande,
          enabled: !controller.isSaving.value,
          isLoading: controller.isSaving.value,
          onTap: controller.chooseLibre,
        ));

    return PopScope(
      canPop: false,
      child: ScaffoldAdaptable(
        // Antes de terminar de configurar el gimnasio: sin barra lateral.
        conMenu: false,
        // De lado, las dos opciones una junto a la otra.
        anchoMaximo: acostada ? 1000 : 800,
        backgroundColor: c.backgroundColor,
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
                    color: c.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige cómo cobrar las membresías. Puedes cambiarlo después.',
                  style: TextStyle(
                    fontSize: isTablet ? 15 : 14,
                    color: c.textSecondary.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                if (acostada)
                  // Las dos del mismo alto.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: fijo),
                        const SizedBox(width: 16),
                        Expanded(child: libre),
                      ],
                    ),
                  )
                else ...[
                  fijo,
                  const SizedBox(height: 14),
                  libre,
                ],
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

  /// En la tableta acostada: tarjeta alta, con el ícono arriba y letra más
  /// grande, para usar el espacio y tocarla fácil.
  final bool grande;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.isTablet,
    required this.enabled,
    required this.onTap,
    this.isLoading = false,
    this.grande = false,
  });

  Widget _icono(double tamano, {double relleno = 14}) => Container(
        padding: EdgeInsets.all(relleno),
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
        child: Icon(icon, color: Colors.white, size: tamano),
      );

  Widget _flecha(ColoresTema c) => isLoading
      ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: c.textSecondary,
          ),
        )
      : Icon(
          Icons.arrow_forward_ios_rounded,
          color: c.contraste.withOpacity(0.25),
          size: 16,
        );

  Widget _contenidoGrande(ColoresTema c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _icono(40, relleno: 20),
              const Spacer(),
              _flecha(c),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 17,
              color: c.textSecondary.withOpacity(0.8),
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: EdgeInsets.all(grande ? 32 : (isTablet ? 22 : 18)),
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
            child: grande
                ? _contenidoGrande(c)
                : Row(
                    children: [
                      _icono(isTablet ? 30 : 26),
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
                                color: c.textPrimary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: isTablet ? 14 : legible(12.5),
                                color: c.textSecondary.withOpacity(0.75),
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _flecha(c),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
