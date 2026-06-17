import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';

import '../../../data/services/branding_service.dart';
import '../../../routes/app_pages.dart';
import '../controllers/home_controller.dart';
import '../widgets/background_welcome_dialog.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header con gradiente ───
              _buildHeader(context, isTablet),

              const SizedBox(height: 8),

              // ─── Módulos principales ───
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 28 : 20),
                child: Text(
                  'Selecciona una opción',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildMainModules(context, isTablet),

              const SizedBox(height: 16),

              // ─── Más opciones ───
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 28 : 20),
                child: Text(
                  'Más opciones',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActions(context, isTablet),

              const SizedBox(height: 16),
              _buildSettingsTile(context, isTablet),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      // Diálogo de bienvenida RFID en segundo plano
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const BackgroundWelcomeDialog(),
    );
  }

  // ─────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isTablet) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Obx(() {
      final brandColor = BrandingService.to.brandColor;

      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          isTablet ? 32 : 24,
          topPadding + (isTablet ? 18 : 14),
          isTablet ? 32 : 24,
          isTablet ? 16 : 14,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.55, 1.0],
            colors: [
              const Color(0xFF11151F),
              const Color(0xFF1A2332),
              brandColor.withOpacity(0.28),
            ],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: brandColor.withOpacity(0.12),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.dashboard_rounded,
                color: brandColor,
                size: isTablet ? 26 : 22,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Inicio',
              style: TextStyle(
                fontSize: isTablet ? 26 : 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────
  // MAIN MODULES (cards grandes con iconos)
  // ─────────────────────────────────────────────────────────
  Widget _buildMainModules(BuildContext context, bool isTablet) {
    final modules = [
      _ModuleItem(
        icon: Icons.people_alt_outlined,
        label: 'Clientes',
        subtitle: 'Gestión de miembros',
        gradient: const [Color(0xFF667eea), Color(0xFF764ba2)],
        onTap: controller.goToClientes,
      ),
      _ModuleItem(
        icon: Icons.payments_outlined,
        label: 'Abonar',
        subtitle: 'Cobrar membresías',
        gradient: const [Color(0xFFf093fb), Color(0xFFf5576c)],
        onTap: controller.goToAbonar,
      ),
      _ModuleItem(
        icon: Icons.storefront_outlined,
        label: 'Vender',
        subtitle: 'Punto de venta',
        gradient: const [Color(0xFF4facfe), Color(0xFF00f2fe)],
        onTap: controller.goToPointOfSale,
      ),
      _ModuleItem(
        icon: Icons.inventory_2_outlined,
        label: 'Inventario',
        subtitle: 'Productos y stock',
        gradient: const [Color(0xFF43e97b), Color(0xFF38f9d7)],
        onTap: controller.goToInventario,
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTablet ? 4 : 2,
          crossAxisSpacing: isTablet ? 16 : 12,
          mainAxisSpacing: isTablet ? 16 : 12,
          childAspectRatio: isTablet ? 1.1 : 1.05,
        ),
        itemCount: modules.length,
        itemBuilder: (context, index) {
          return _ModuleCard(module: modules[index]);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // QUICK ACTIONS (tiles horizontales)
  // ─────────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, bool isTablet) {
    final actions = [
      _QuickAction(
        icon: Icons.receipt_long_outlined,
        label: 'Ingresos',
        subtitle: 'Historial de pagos',
        color: const Color(0xFFFFB74D),
        onTap: controller.goToPaymentRegistration,
      ),
      _QuickAction(
        icon: Icons.door_sliding_outlined,
        label: 'Entradas',
        subtitle: 'Registro de accesos',
        color: const Color(0xFF81C784),
        onTap: controller.goToAccessLogs,
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      child: Column(
        children: actions.map((action) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _QuickActionTile(action: action),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // SETTINGS (acceso a configuración en la zona inferior)
  // ─────────────────────────────────────────────────────────
  Widget _buildSettingsTile(BuildContext context, bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Get.toNamed(Routes.CONFIGURACION),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Configuración',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.2),
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

// ═════════════════════════════════════════════════════════════
// DATA MODELS
// ═════════════════════════════════════════════════════════════

class _ModuleItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ModuleItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

// ═════════════════════════════════════════════════════════════
// MODULE CARD (tarjeta principal con gradiente)
// ═════════════════════════════════════════════════════════════

class _ModuleCard extends StatefulWidget {
  final _ModuleItem module;
  const _ModuleCard({required this.module});

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          m.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                m.gradient[0].withOpacity(0.15),
                m.gradient[1].withOpacity(0.08),
              ],
            ),
            border: Border.all(
              color: m.gradient[0].withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: m.gradient[0].withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 18 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: m.gradient,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: m.gradient[0].withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    m.icon,
                    color: Colors.white,
                    size: isTablet ? 26 : 24,
                  ),
                ),
                const Spacer(),
                // Text
                Text(
                  m.label,
                  style: TextStyle(
                    fontSize: isTablet ? 17 : 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  m.subtitle,
                  style: TextStyle(
                    fontSize: isTablet ? 13 : 11,
                    color: AppColors.textSecondary.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// QUICK ACTION TILE (fila horizontal)
// ═════════════════════════════════════════════════════════════

class _QuickActionTile extends StatefulWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        a.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: a.color.withOpacity(0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: a.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(a.icon, color: a.color, size: 24),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.2),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
