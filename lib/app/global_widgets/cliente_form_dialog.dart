import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/config/rfid_config.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/services/background_rfid_service.dart';
import 'package:gymads/app/data/services/rfid_reader_service.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import '../core/widgets/formulario.dart';
import '../modules/shared/widgets/photo_capture_widget.dart';
import 'app_header.dart';

/// Alta y edición de un cliente.
///
/// La foto arriba (obligatoria), luego nombre y teléfono, la tarjeta y,
/// plegado, lo opcional. Pocos textos y un solo botón para guardar, fijo
/// abajo.
///
/// Sin foto no se guarda: la pantalla de bienvenida del lector la necesita
/// para reconocer al cliente.
class ClienteFormDialog extends StatefulWidget {
  final TextEditingController nombreController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final TextEditingController userNumberController;
  final TextEditingController rfidController;
  final bool isEditing;
  final Function(UserModel, File?) onSave;
  final String? currentPhotoUrl;
  final bool fullScreen;

  /// Si hay un guardado en curso: el botón se desactiva y dice "Guardando…",
  /// para que no se vuelva a picar (cada toque mandaba otro guardado).
  final RxBool? guardando;

  const ClienteFormDialog({
    super.key,
    required this.nombreController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
    required this.userNumberController,
    required this.rfidController,
    this.isEditing = false,
    required this.onSave,
    this.currentPhotoUrl,
    this.fullScreen = false,
    this.guardando,
  });

  @override
  State<ClienteFormDialog> createState() => _ClienteFormDialogState();
}

class _ClienteFormDialogState extends State<ClienteFormDialog> {
  Timer? _pollTimer;
  BackgroundRfidService? _rfidService;

  /// Del State y no de `build`: creados en `build`, un redibujo de la
  /// pantalla (el teclado, por ejemplo) los reemplazaba y se perdía la foto
  /// tomada.
  final _formKey = GlobalKey<FormState>();
  File? _foto;

  /// Una consulta al lector a la vez: si no contesta, cada una tarda hasta
  /// 3 s y se iban acumulando.
  bool _consultandoLector = false;

  /// El de quien abrió el formulario, o uno propio (Obx necesita leer uno).
  late final RxBool _guardando = widget.guardando ?? false.obs;

  /// El teléfono se arma con la lada del país que se elija.
  late final PhoneNumber _telefonoInicial = _telefonoDe(widget.phoneController.text);

  @override
  void initState() {
    super.initState();
    _rfidService = Get.isRegistered<BackgroundRfidService>()
        ? Get.find<BackgroundRfidService>()
        : null;
    _startSilentPolling();
  }

  void _startSilentPolling() {
    _rfidService?.pauseScanning();
    _pollTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_consultandoLector) return;
      _consultandoLector = true;
      try {
        final uid = await RfidReaderService.checkForCardSilent();
        if (uid != null && uid.isNotEmpty && uid != 'NO_CARD') {
          if (widget.rfidController.text != uid) {
            widget.rfidController.text = uid;
          }
        }
      } catch (e) {
        // Ignorar
      } finally {
        _consultandoLector = false;
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _rfidService?.resumeScanning();
    super.dispose();
  }

  static PhoneNumber _telefonoDe(String texto) {
    final telefono = texto.trim();
    if (telefono.isEmpty) return PhoneNumber(isoCode: 'MX');
    try {
      if (telefono.startsWith('+52')) {
        return PhoneNumber(phoneNumber: telefono.substring(3), isoCode: 'MX');
      }
      if (telefono.startsWith('+')) return PhoneNumber(phoneNumber: telefono);
      return PhoneNumber(phoneNumber: telefono, isoCode: 'MX');
    } catch (_) {
      return PhoneNumber(isoCode: 'MX');
    }
  }

  /// La foto es obligatoria: la tomada ahora o, al editar, la que ya tenía.
  bool get _tieneFoto =>
      _foto != null || (widget.currentPhotoUrl?.isNotEmpty ?? false);

  /// Se tocó "Guardar" sin foto: se marca en rojo hasta que se tome.
  bool _faltaFoto = false;

  void _guardar() {
    final camposBien = _formKey.currentState?.validate() ?? false;
    setState(() => _faltaFoto = !_tieneFoto);
    if (!camposBien || _faltaFoto) return;
    final user = UserModel(
      name: widget.nombreController.text.trim(),
      phone: widget.phoneController.text,
      email: widget.emailController.text.trim().isEmpty
          ? null
          : widget.emailController.text.trim(),
      address: widget.addressController.text.trim().isEmpty
          ? null
          : widget.addressController.text.trim(),
      joinDate: DateTime.now(),
      userNumber: widget.userNumberController.text,
      rfidCard:
          widget.rfidController.text.isEmpty ? null : widget.rfidController.text,
    );
    widget.onSave(user, _foto);
  }

  String get _titulo => widget.isEditing ? 'Editar cliente' : 'Nuevo cliente';

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final formulario = Form(
      key: _formKey,
      child: ListView(
        // Deslizar cierra el teclado.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          PhotoCaptureWidget(
            currentPhotoUrl: widget.currentPhotoUrl,
            initialPhotoFile: _foto,
            obligatoria: true,
            mostrarFalta: _faltaFoto,
            onPhotoTaken: (archivo) => setState(() {
              _foto = archivo;
              _faltaFoto = false;
            }),
          ),
          const SizedBox(height: 16),
          _campoNombre(),
          const SizedBox(height: 14),
          _campoTelefono(),
          const SizedBox(height: 14),
          _tarjeta(),
          const SizedBox(height: 8),
          _masDatos(),
        ],
      ),
    );

    final boton = Obx(() => BotonGuardar(
          texto: widget.isEditing ? 'Guardar cambios' : 'Guardar cliente',
          guardando: _guardando.value,
          onPressed: _guardar,
        ));

    if (!widget.fullScreen) {
      return AlertDialog(
        backgroundColor: c.cardBackground,
        surfaceTintColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        title: Text(_titulo,
            style: TextStyle(color: c.textPrimary)),
        content: SizedBox(width: 420, height: 560, child: formulario),
        actions: [
          Obx(() => BotonCancelar(
              onPressed: _guardando.value
                  ? null
                  : () => Navigator.of(context).pop())),
          boton,
        ],
      );
    }

    return Obx(() {
      final guardando = _guardando.value;
      // Mientras guarda no se puede salir: se perdería lo escrito si falla.
      return PopScope(
        canPop: !guardando,
        child: Scaffold(
          backgroundColor: c.backgroundColor,
          appBar: GymAppBar(
            title: _titulo,
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cerrar',
              onPressed: guardando ? null : () => Get.back(),
            ),
          ),
          body: SafeArea(bottom: false, child: formulario),
          bottomNavigationBar: PieDeFormulario(child: boton),
        ),
      );
    });
  }

  Widget _campoNombre() {
    final c = context.colores;
    return TextFormField(
      controller: widget.nombreController,
      autofocus: !widget.isEditing,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      style: TextStyle(color: c.textPrimary, fontSize: 16),
      decoration: const InputDecoration(
        labelText: 'Nombre completo *',
        prefixIcon: Icon(Icons.person_outline),
      ),
      validator: (valor) => (valor == null || valor.trim().isEmpty)
          ? 'Escribe el nombre del cliente'
          : null,
    );
  }

  Widget _campoTelefono() {
    final c = context.colores;
    return InternationalPhoneNumberInput(
      initialValue: _telefonoInicial,
      onInputChanged: (numero) =>
          widget.phoneController.text = numero.phoneNumber ?? '',
      selectorConfig: const SelectorConfig(
        selectorType: PhoneInputSelectorType.DROPDOWN,
        setSelectorButtonAsPrefixIcon: true,
        useEmoji: true,
        leadingPadding: 12,
        trailingSpace: false,
      ),
      selectorTextStyle:
          TextStyle(color: c.textPrimary, fontSize: 16),
      textStyle: TextStyle(color: c.textPrimary, fontSize: 16),
      keyboardType: TextInputType.phone,
      inputDecoration: const InputDecoration(labelText: 'Teléfono *'),
      errorMessage: 'Escribe un teléfono válido',
      validator: (valor) =>
          (valor == null || valor.trim().isEmpty) ? 'Escribe el teléfono' : null,
    );
  }

  /// La tarjeta del lector: se asigna pasándola; nunca se muestra su número.
  Widget _tarjeta() {
    final c = context.colores;
    final hayLector = RfidConfig.isConfigured || RfidConfig.tieneLector;
    return AnimatedBuilder(
      animation: widget.rfidController,
      builder: (context, _) {
        final lista = widget.rfidController.text.isNotEmpty;
        final texto = lista
            ? 'Tarjeta lista'
            : hayLector
                ? 'Pasa la tarjeta por el lector'
                : 'Sin lector de tarjetas';

        return Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.only(left: 14, right: 6),
          decoration: BoxDecoration(
            color: lista
                ? AppColors.success.withOpacity(0.10)
                : c.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: lista
                  ? AppColors.success.withOpacity(0.6)
                  : c.borde,
            ),
          ),
          child: Row(
            children: [
              Icon(
                lista ? Icons.check_circle : Icons.contactless_outlined,
                color: lista ? AppColors.success : c.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ),
              if (lista)
                TextButton(
                  onPressed: () => widget.rfidController.clear(),
                  style: TextButton.styleFrom(
                    foregroundColor: c.textSecondary,
                  ),
                  child: const Text('Quitar'),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Correo y dirección: opcionales, plegados para no estorbar. Al editar se
  /// abren si ya tienen algo.
  Widget _masDatos() {
    final c = context.colores;
    final tieneAlgo = widget.emailController.text.trim().isNotEmpty ||
        widget.addressController.text.trim().isNotEmpty;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: widget.isEditing && tieneAlgo,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        iconColor: AppColors.accent,
        collapsedIconColor: c.textSecondary,
        title: Text(
          'Correo y dirección (opcional)',
          style: TextStyle(color: c.textSecondary, fontSize: 15),
        ),
        children: [
          TextFormField(
            controller: widget.emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: c.textPrimary, fontSize: 16),
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: widget.addressController,
            maxLines: 2,
            style: TextStyle(color: c.textPrimary, fontSize: 16),
            decoration: const InputDecoration(
              labelText: 'Dirección',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
        ],
      ),
    );
  }
}
