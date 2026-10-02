# Guía de Diseño Responsivo en GymOne

Esta guía explica cómo utilizar las herramientas de diseño responsivo incluidas en el proyecto.

## Utilidades disponibles

### Extensiones de Contexto
```dart
// Obtener información del tamaño de pantalla
context.screenSize  // Tamaño completo
context.screenWidth  // Ancho
context.screenHeight  // Alto

// Verificar tipo de dispositivo
context.isTablet  // true si ancho > 600px
context.isSmallPhone  // true si ancho < 360px
context.isLandscape  // true si está en orientación horizontal

// Padding seguro
context.safePadding  // EdgeInsets con padding seguro para notch, etc.

// Cálculos adaptativos
context.adaptiveWidth(0.5)  // 50% del ancho de pantalla
context.adaptiveHeight(0.3)  // 30% de la altura de pantalla
```

### Widget ResponsiveLayout
Este widget permite mostrar diferentes layouts según el tamaño de pantalla:

```dart
ResponsiveLayout(
  mobile: MobileView(),  // Vista para teléfonos normales
  smallMobile: SmallPhoneView(),  // Vista para teléfonos pequeños
  tablet: TabletView(),  // Vista para tablets
  desktop: DesktopView(),  // Vista para pantallas grandes
)
```

### Widget AdaptivePadding
Aplica padding diferente según el tamaño de dispositivo:

```dart
AdaptivePadding(
  mobilePadding: EdgeInsets.all(16),
  tabletPadding: EdgeInsets.all(24),
  desktopPadding: EdgeInsets.all(32),
  smallMobilePadding: EdgeInsets.all(12),
  child: YourWidget(),
)
```

### Valores Responsivos Predefinidos
```dart
// Tamaño de fuente adaptativo
final fontSize = ResponsiveValues.getFontSize(
  context,
  mobile: 14,
  smallPhone: 12,
  tablet: 16,
  desktop: 18
);

// Espaciado adaptativo
final spacing = ResponsiveValues.getSpacing(
  context,
  mobile: 16,
  smallPhone: 12,
  tablet: 24,
  desktop: 32
);

// Tamaño de icono adaptativo
final iconSize = ResponsiveValues.getIconSize(
  context,
  mobile: 24,
  smallPhone: 20,
  tablet: 28,
  desktop: 32
);
```

## Ejemplos de Uso

### Ejemplo 1: Tamaño de Texto Responsivo
```dart
Text(
  'Título',
  style: TextStyle(
    fontSize: ResponsiveValues.getFontSize(
      context,
      mobile: 22,
      smallPhone: 18,
      tablet: 28
    ),
    fontWeight: FontWeight.bold,
  ),
)
```

### Ejemplo 2: Contenedor con Padding Adaptativo
```dart
Container(
  padding: EdgeInsets.all(
    ResponsiveValues.getSpacing(
      context,
      mobile: 16,
      smallPhone: 12,
      tablet: 24
    )
  ),
  child: YourWidget(),
)
```

### Ejemplo 3: GridView Responsivo
```dart
GridView.count(
  crossAxisCount: context.isTablet ? 3 : 2,
  mainAxisSpacing: ResponsiveValues.getSpacing(
    context,
    mobile: 16,
    smallPhone: 12,
    tablet: 24
  ),
  crossAxisSpacing: ResponsiveValues.getSpacing(
    context,
    mobile: 16,
    smallPhone: 12,
    tablet: 24
  ),
  children: [...],
)
```

## Recomendaciones

1. **Evita valores fijos**: Utiliza siempre las utilidades responsivas en lugar de valores fijos.
2. **Utiliza SizedBox con altura adaptativa**: Para espaciados verticales entre widgets.
3. **Utiliza Flexible y Expanded**: Para crear layouts que se adapten correctamente.
4. **Establece maxLines y overflow**: Para textos que podrían causar desbordamientos.
5. **Usa Wrap en lugar de Row**: Cuando tengas botones o iconos en fila que puedan desbordarse, utiliza `Wrap` con `spacing` y `crossAxisAlignment` para que los elementos se envuelvan automáticamente.
```dart
Wrap(
  spacing: 16,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Icon(Icons.sensor_door),
    Text('Editar Cliente'),
    // ...otros widgets
  ],
)
```
6. **Envuelve textos largos con Expanded**: Si el `Text` está dentro de un `Row`, ponlo en un `Expanded` y usa `overflow: TextOverflow.ellipsis`.
```dart
Row(
  children: [
    Icon(Icons.person),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        'Título largo que pudiera desbordar',
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
)
```
5. **Prueba en diferentes tamaños**: Verifica tu UI en dispositivos pequeños, medianos y grandes.

## 🛠 Notas de Futuras Actualizaciones

- Si se requieren nuevos breakpoints (por ejemplo, pantallas XL), agregar casos en `ResponsiveLayout` y valores en `ResponsiveValues`.
- Actualizar `getResponsiveValue` para manejar rangos de ancho adicionales.
- Revisar y actualizar ejemplos tras agregar nuevas utilidades responsivas.
- Mantener la consistencia en la nomenclatura y firma de métodos adaptativos.
- Ejecute pruebas manuales en diferentes tamaños de dispositivo para validar el comportamiento.
