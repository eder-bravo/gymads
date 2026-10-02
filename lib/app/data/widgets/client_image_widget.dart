import 'dart:io';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/image_cache_service.dart';

/// Widget optimizado para mostrar imágenes de clientes con caché automático
/// 
/// Características:
/// - Carga automática desde caché local
/// - Fallback a Supabase Storage si no hay caché
/// - Optimización transparente de imágenes
/// - Placeholder mientras carga
/// - Manejo de errores elegante
class ClientImageWidget extends StatefulWidget {
  final String userId;
  final String? photoUrl;
  final bool isThumbnail;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  
  const ClientImageWidget({
    Key? key,
    required this.userId,
    this.photoUrl,
    this.isThumbnail = false,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);
  
  @override
  State<ClientImageWidget> createState() => _ClientImageWidgetState();
}

class _ClientImageWidgetState extends State<ClientImageWidget> {
  String? _cachedImagePath;
  bool _isLoading = true;
  bool _hasError = false;
  
  @override
  void initState() {
    super.initState();
    _loadImage();
  }
  
  @override
  void didUpdateWidget(ClientImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Recargar imagen si cambió el URL o el tipo
    if (oldWidget.photoUrl != widget.photoUrl ||
        oldWidget.isThumbnail != widget.isThumbnail ||
        oldWidget.userId != widget.userId) {
      _loadImage();
    }
  }
  
  Future<void> _loadImage() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _cachedImagePath = null;
    });
    
    try {
      if (widget.photoUrl == null || widget.photoUrl!.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        return;
      }
      
      final imagePath = await ImageCacheService.instance.getUserImage(
        widget.userId,
        widget.photoUrl,
        isThumbnail: widget.isThumbnail,
      );
      
      if (!mounted) return;
      
      if (imagePath != null) {
        setState(() {
          _cachedImagePath = imagePath;
          _isLoading = false;
          _hasError = false;
        });
        
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      
      AppLogger.error('ClientImageWidget', 'Error cargando imagen', e);
    }
  }
  
  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }
    
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.borderRadius,
        shape: widget.borderRadius != null && 
               widget.borderRadius!.topLeft.x == (widget.width ?? 50) / 2 
            ? BoxShape.circle 
            : BoxShape.rectangle,
      ),
      child: Center(
        child: _isLoading
            ? SizedBox(
                width: (widget.width ?? 50) * 0.3,
                height: (widget.height ?? 50) * 0.3,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                ),
              )
            : Icon(
                Icons.person,
                size: widget.isThumbnail ? (widget.width ?? 50) * 0.5 : (widget.width ?? 100) * 0.4,
                color: Colors.grey[600],
              ),
      ),
    );
  }
  
  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }
    
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: widget.borderRadius,
        shape: widget.borderRadius != null && 
               widget.borderRadius!.topLeft.x == (widget.width ?? 50) / 2 
            ? BoxShape.circle 
            : BoxShape.rectangle,
      ),
      child: Center(
        child: Icon(
          Icons.person_off,
          size: widget.isThumbnail ? (widget.width ?? 50) * 0.5 : (widget.width ?? 100) * 0.4,
          color: Colors.grey[600],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildPlaceholder();
    }
    
    if (_hasError || _cachedImagePath == null) {
      return _buildErrorWidget();
    }
    
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Image.file(
          File(_cachedImagePath!),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            AppLogger.error('ClientImageWidget', 'Error mostrando imagen desde archivo', error);
            return _buildErrorWidget();
          },
        ),
      ),
    );
  }
}

/// Widget específico para miniaturas en listas de clientes
class ClientThumbnailWidget extends StatelessWidget {
  final String userId;
  final String? photoUrl;
  final double size;
  final BorderRadius? borderRadius;
  final String? userName; // Para mostrar iniciales como fallback
  final Color? backgroundColor;
  final Color? textColor;
  
  const ClientThumbnailWidget({
    Key? key,
    required this.userId,
    this.photoUrl,
    this.size = 50.0,
    this.borderRadius,
    this.userName,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);
  
  Widget _buildFallback() {
    final initial = userName != null && userName!.isNotEmpty 
        ? userName![0].toUpperCase() 
        : '?';
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[300],
        shape: BoxShape.circle, // Asegurar forma circular
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4, // 40% del tamaño del contenedor
            fontWeight: FontWeight.bold,
            color: textColor ?? Colors.grey[700],
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Si no hay photoUrl, mostrar fallback directamente
    if (photoUrl == null || photoUrl!.isEmpty) {
      AppLogger.error('ClientImageWidget', 'ClientThumbnailWidget: No photoUrl para usuario mostrando fallback');
      return _buildFallback();
    }
    
    return ClipOval(
      child: ClientImageWidget(
        userId: userId,
        photoUrl: photoUrl,
        isThumbnail: true,
        width: size,
        height: size,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(size / 2),
        placeholder: _buildFallback(),
        errorWidget: _buildFallback(),
      ),
    );
  }
}

/// Widget específico para imágenes completas en perfiles de clientes
class ClientProfileImageWidget extends StatelessWidget {
  final String userId;
  final String? photoUrl;
  final double size;
  final BorderRadius? borderRadius;
  
  const ClientProfileImageWidget({
    Key? key,
    required this.userId,
    this.photoUrl,
    this.size = 200.0,
    this.borderRadius,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ClientImageWidget(
      userId: userId,
      photoUrl: photoUrl,
      isThumbnail: false,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: borderRadius ?? BorderRadius.circular(12),
    );
  }
}
