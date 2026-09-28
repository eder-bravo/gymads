import 'package:flutter/material.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/core/widgets/formulario.dart';

class RfidReaderAnimation extends StatefulWidget {
  final bool isReading;
  final String? detectedUid;
  final VoidCallback onCancel;

  const RfidReaderAnimation({
    super.key,
    required this.isReading,
    this.detectedUid,
    required this.onCancel,
  });

  @override
  State<RfidReaderAnimation> createState() => _RfidReaderAnimationState();
}

class _RfidReaderAnimationState extends State<RfidReaderAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );

    if (widget.isReading) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RfidReaderAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isReading && !oldWidget.isReading) {
      _controller.repeat(reverse: true);
    } else if (!widget.isReading && oldWidget.isReading) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Text(
              widget.detectedUid == null 
                  ? 'Esperando Tarjeta RFID' 
                  : 'Tarjeta Detectada',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Animación del lector
            if (widget.detectedUid == null)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Transform.rotate(
                      angle: _rotateAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.contactless,
                            size: 70,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            else
              // Muestra el UID detectado
              Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green,
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle,
                        size: 70,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.containerBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      widget.detectedUid!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1.2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 16),
            
            // Mensaje instructivo
            Text(
              widget.detectedUid == null
                  ? 'Acerque la tarjeta RFID al lector...'
                  : 'Tarjeta leída correctamente',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.detectedUid == null)
                  BotonCancelar(onPressed: widget.onCancel)
                else
                  BotonGuardar(
                    texto: 'Aceptar',
                    compacto: true,
                    onPressed: widget.onCancel,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
