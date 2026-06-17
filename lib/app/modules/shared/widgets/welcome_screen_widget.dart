import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../../../core/widgets/cached_user_image.dart';

class WelcomeScreenWidget extends StatefulWidget {
  final String userName;
  final String userPhotoUrl;
  final int daysLeft;
  final DateTime? expirationDate;
  final bool isVisible;
  final bool isExpired;
  final bool isNotFound;
  final VoidCallback? onClose;
  final VoidCallback? onAbonar;
  final VoidCallback? onEditar;
  final VoidCallback? onRegister; // Para cuando no se encuentra tarjeta

  const WelcomeScreenWidget({
    super.key,
    required this.userName,
    required this.userPhotoUrl,
    required this.daysLeft,
    this.expirationDate,
    required this.isVisible,
    this.isExpired = false,
    this.isNotFound = false,
    this.onClose,
    this.onAbonar,
    this.onEditar,
    this.onRegister,
  });

  @override
  State<WelcomeScreenWidget> createState() => _WelcomeScreenWidgetState();
}

class _WelcomeScreenWidgetState extends State<WelcomeScreenWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    if (widget.isVisible) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(WelcomeScreenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _animationController.repeat();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    // Determinar si es una tableta basado en el ancho de la pantalla
    final bool isTabletSize = MediaQuery.of(context).size.width > 600;
    final bool isSmallPhone = MediaQuery.of(context).size.width < 360;

    return _buildWelcomeScreen(context, isTabletSize, isSmallPhone);
  }

  Widget _buildWelcomeScreen(BuildContext context, bool isTabletSize, bool isSmallPhone) {
    // Tamaños responsivos para pantalla de bienvenida
    final titleSize = isTabletSize
        ? 60.0
        : (isSmallPhone ? 36.0 : 48.0);
    
    final nameSize = isTabletSize
        ? 42.0
        : (isSmallPhone ? 28.0 : 36.0);
    
    final infoTextSize = isTabletSize
        ? 24.0
        : (isSmallPhone ? 18.0 : 20.0);
    
    // Tamaño del círculo con foto
    final photoSize = isTabletSize
        ? 320.0
        : (isSmallPhone ? 180.0 : 250.0);

    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            // Valor fijo para la escala
            final scale = 1.0;
            
            // Ligero movimiento ondulante
            final animValue = _animationController.value * pi * 2;
            final sinValue = sin(animValue).clamp(-1.0, 1.0);
            final breathingEffect = 1.0 + 0.005 * sinValue;
            
            return Transform.scale(
              scale: scale * breathingEffect,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: isTabletSize ? 40 : 24
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Título de bienvenida con efecto de aparición
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          final safeOpacity = value.clamp(0.0, 1.0);
                          return Opacity(
                            opacity: safeOpacity,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Text(
                                widget.isNotFound 
                                    ? 'Tarjeta No Registrada' 
                                    : (widget.isExpired ? 'Membresía Vencida' : '¡Bienvenido!'),
                                style: TextStyle(
                                  fontSize: widget.isNotFound ? (isTabletSize ? 50.0 : (isSmallPhone ? 30.0 : 40.0)) : titleSize,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isNotFound ? Colors.redAccent : (widget.isExpired ? Colors.redAccent : Colors.white),
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      offset: const Offset(2, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      ),
                      SizedBox(height: isTabletSize ? 40 : 32),
                      
                      // Foto del usuario con efecto de aura
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          final safeOpacity = value.clamp(0.0, 1.0);
                          return Opacity(
                            opacity: safeOpacity,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Aura exterior
                                Container(
                                  width: (photoSize + 20) * value,
                                  height: (photoSize + 20) * value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (widget.isNotFound || widget.isExpired ? Colors.red : AppColors.primary).withOpacity(0.2),
                                  ),
                                ),
                                // Aura interior
                                Container(
                                  width: (photoSize + 10) * value,
                                  height: (photoSize + 10) * value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (widget.isNotFound || widget.isExpired ? Colors.redAccent : AppColors.accent).withOpacity(0.3),
                                  ),
                                ),
                                // Foto
                                Container(
                                  width: photoSize * value,
                                  height: photoSize * value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (widget.isNotFound || widget.isExpired ? Colors.red : AppColors.primary).withOpacity(0.5),
                                        spreadRadius: 5,
                                        blurRadius: 15,
                                      ),
                                    ],
                                  ),
                                  child: widget.isNotFound
                                      ? CircleAvatar(
                                          radius: photoSize/2 * value,
                                          backgroundColor: Colors.red,
                                          child: Icon(
                                            Icons.contactless_outlined,
                                            size: photoSize/2.5 * value,
                                            color: Colors.white,
                                          ),
                                        )
                                      : (widget.userPhotoUrl.isNotEmpty
                                          ? CachedUserImage(
                                              imageUrl: widget.userPhotoUrl,
                                              userName: widget.userName,
                                              size: photoSize * value,
                                              isCircular: true,
                                              fit: BoxFit.cover,
                                            )
                                          : CircleAvatar(
                                              radius: photoSize/2 * value,
                                              backgroundColor: widget.isExpired ? Colors.red : AppColors.primary,
                                              child: Icon(
                                                Icons.person,
                                                size: photoSize/3 * value,
                                                color: Colors.white,
                                              ),
                                            )),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                      SizedBox(height: isSmallPhone ? 20 : 24),
                      
                      // Nombre del usuario con animación de entrada
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutQuart,
                        builder: (context, value, child) {
                          final safeOpacity = value.clamp(0.0, 1.0);
                          return Opacity(
                            opacity: safeOpacity,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Text(
                                widget.isNotFound ? 'ID: ${widget.userName}' : widget.userName,
                                style: TextStyle(
                                  fontSize: widget.isNotFound ? (nameSize * 0.7) : nameSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                      ),
                      SizedBox(height: isSmallPhone ? 12 : 16),
                      
                      if (!widget.isNotFound)
                      // Días restantes con animación de entrada
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1600),
                        curve: Curves.easeOutQuart,
                        builder: (context, value, child) {
                          final safeOpacity = value.clamp(0.0, 1.0);
                          return Opacity(
                            opacity: safeOpacity,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTabletSize ? 20 : 16, 
                                  vertical: isTabletSize ? 12 : 8
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.event_available,
                                          color: Colors.white,
                                          size: isTabletSize ? 28 : 24,
                                        ),
                                        SizedBox(width: isTabletSize ? 12 : 8),
                                        Text(
                                          widget.isExpired ? '0 días restantes' : '${widget.daysLeft} días restantes',
                                          style: TextStyle(
                                            fontSize: infoTextSize,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (widget.expirationDate != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          'Hasta qué fecha puede entrar: ${DateFormat('dd/MM/yyyy').format(widget.expirationDate!)}',
                                          style: TextStyle(
                                            fontSize: infoTextSize * 0.85,
                                            color: Colors.white.withOpacity(0.9),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      ),
                      
                      // Indicador de progreso
                      SizedBox(height: isSmallPhone ? 16 : 24),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1800),
                        curve: Curves.easeOutQuart,
                        builder: (context, value, child) {
                          final safeOpacity = value.clamp(0.0, 1.0);
                          return Opacity(
                            opacity: safeOpacity,
                              child: Text(
                                widget.isNotFound 
                                    ? 'Acude a recepción para registrar tu acceso'
                                    : (widget.isExpired ? '¡Por favor pasa a recepción!' : '¡Que tengas un excelente entrenamiento!'),
                                style: TextStyle(
                                  fontSize: isTabletSize
                                      ? 20.0
                                      : (isSmallPhone ? 14.0 : 16.0),
                                  color: Colors.white.withOpacity(0.8),
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          );
                        }
                      ),
                      
                      // Botones de acción
                      SizedBox(height: isSmallPhone ? 24 : 32),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 2000),
                        curve: Curves.easeOutQuart,
                        builder: (context, value, child) {
                          final safeOpacity = value.clamp(0.0, 1.0);
                          return Opacity(
                            opacity: safeOpacity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (widget.isNotFound && widget.onRegister != null)
                                  ElevatedButton.icon(
                                    onPressed: widget.onRegister,
                                    icon: const Icon(Icons.person_add, color: Colors.white),
                                    label: const Text('Registrar', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                if (!widget.isNotFound && widget.onAbonar != null)
                                  ElevatedButton.icon(
                                    onPressed: widget.onAbonar,
                                    icon: const Icon(Icons.payment, color: Colors.white),
                                    label: const Text('Abonar', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                if (!widget.isNotFound && widget.onAbonar != null && widget.onEditar != null)
                                  const SizedBox(width: 16),
                                if (!widget.isNotFound && widget.onEditar != null)
                                  ElevatedButton.icon(
                                    onPressed: widget.onEditar,
                                    icon: const Icon(Icons.edit, color: Colors.white),
                                    label: const Text('Editar', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
