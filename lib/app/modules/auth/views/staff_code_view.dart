import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/access_code_generator.dart';
import '../controllers/staff_code_controller.dart';
import 'package:gymads/core/theme/app_colors.dart';

/// Entrada del personal con su código de acceso.
///
/// Un único campo: ni correo ni contraseña. Comparte el fondo y el estilo del
/// login para que se lea como parte del mismo flujo.
class StaffCodeView extends GetView<StaffCodeController> {
  const StaffCodeView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: c.fondoAcceso),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(Icons.arrow_back, color: c.contraste),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 40),
                        _buildCard(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final c = context.colores;
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: c.contraste.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: c.contraste.withOpacity(0.2), width: 2),
          ),
          child: Icon(Icons.badge, size: 44, color: c.contraste),
        ),
        const SizedBox(height: 20),
        Text(
          'Entrar como staff',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: c.contraste,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Escribe el código que te dio el dueño del gimnasio',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: c.contraste.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    final c = context.colores;
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: c.tarjetaAcceso,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.contraste.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: c.sombra,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCodeField(context),
          const SizedBox(height: 24),
          Obx(() => controller.errorMessage.value != null
              ? _buildErrorMessage()
              : const SizedBox.shrink()),
          _buildEnterButton(),
          const SizedBox(height: 20),
          Text(
            'El código solo sirve una vez.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.contraste.withOpacity(0.5),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeField(BuildContext context) {
    final c = context.colores;
    return TextField(
      controller: controller.codigoController,
      autofocus: true,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.go,
      onSubmitted: (_) => controller.entrar(),
      onChanged: (_) => controller.clearError(),
      // El guion lo pone el formateador: el empleado solo teclea los 8
      // caracteres, y pegar el código completo también funciona. El largo lo
      // acota el propio formateador, así que no hace falta limitarlo aquí.
      inputFormatters: [CodigoAccesoFormatter()],
      style: TextStyle(
        color: c.contraste,
        fontSize: 26,
        fontWeight: FontWeight.bold,
        letterSpacing: 6,
        fontFamily: 'monospace',
      ),
      decoration: InputDecoration(
        hintText: 'XXXX-XXXX',
        hintStyle: TextStyle(
          color: c.contraste.withOpacity(0.25),
          fontSize: 24,
          letterSpacing: 6,
          fontWeight: FontWeight.bold,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              controller.errorMessage.value!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterButton() {
    return Obx(() => SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: controller.isLoading.value ? null : controller.entrar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: controller.isLoading.value
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Entrar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ));
  }
}

/// Da forma al código mientras se escribe.
///
/// Pone las mayúsculas, descarta lo que no puede formar parte de un código y
/// coloca el guion solo al llegar al quinto carácter. Así nadie tiene que
/// teclear el separador, y pegar el código entero —con guion o sin él, en
/// minúsculas, con espacios alrededor o incluso dentro del mensaje completo
/// que se comparte por WhatsApp— cae siempre en `XXXX-XXXX`.
class CodigoAccesoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = AccessCodeGenerator.formatearParcial(newValue.text);

    // Más de un carácter de golpe solo pasa al pegar (un tecleo normal, o
    // incluso reemplazar una selección con una tecla, nunca crece más de 1).
    // En ese caso no tiene sentido calcular "dónde iba el cursor": pudo
    // pegarse un mensaje entero mucho más largo que el código que queda, así
    // que se manda al final del resultado, listo para revisar o enviar.
    final fuePegado = newValue.text.length > oldValue.text.length + 1;

    final int posicion;
    if (fuePegado) {
      posicion = texto.length;
    } else {
      // El cursor se recoloca contando caracteres ÚTILES, no posiciones: el
      // guion que se acaba de insertar corre un sitio todo lo que va detrás,
      // y sin esto el cursor se quedaría encima de él o saltaría al final al
      // corregir algo en medio.
      final utilesAntesDelCursor = AccessCodeGenerator.normalizar(
        newValue.text.substring(
            0, newValue.selection.end.clamp(0, newValue.text.length)),
      ).length.clamp(0, AccessCodeGenerator.largo);

      posicion = utilesAntesDelCursor + (utilesAntesDelCursor > 4 ? 1 : 0);
    }

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(
        offset: posicion.clamp(0, texto.length),
      ),
    );
  }
}
