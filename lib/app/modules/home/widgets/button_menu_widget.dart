import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_utils.dart';

class ButtonMenuWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const ButtonMenuWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Utilizamos utilidades responsivas
    final bool isSmallPhone = MediaQuery.sizeOf(context).shortestSide < 360;
    final iconSize = ResponsiveValues.getIconSize(context,
      mobile: 34,
      smallPhone: 28,
      tablet: 40
    );
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.black45, // Cambia esto si tienes un color específico
            borderRadius: BorderRadius.circular(16),
            // boxShadow: [
            //   BoxShadow(
            //     color: color.withOpacity(0.2),
            //     blurRadius: 8,
            //     spreadRadius: 1,
            //     offset: const Offset(0, 2),
            //   ),
            // ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallPhone ? 8.0 : 10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Asegura que la columna use solo el espacio necesario
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveValues.getSpacing(context,
                    mobile: 8,
                    smallPhone: 6,
                    tablet: 10
                  )),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: iconSize, color: color),
                ),
                SizedBox(height: isSmallPhone ? 3 : 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: ResponsiveValues.getFontSize(context,
                      mobile: 15,
                      smallPhone: 13,
                      tablet: 17
                    ),
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isSmallPhone ? 1 : 2),
                Flexible(
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: ResponsiveValues.getFontSize(context,
                        mobile: 10,
                        smallPhone: 9,
                        tablet: 12
                      ), 
                      color: Colors.grey.shade600
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
