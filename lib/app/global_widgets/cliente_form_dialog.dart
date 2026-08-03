import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/services/rfid_reader_service.dart';
import 'package:gymads/app/data/services/background_rfid_service.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'app_header.dart';
import '../modules/shared/widgets/photo_capture_widget.dart';

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
  });

  @override
  State<ClienteFormDialog> createState() => _ClienteFormDialogState();
}

class _ClienteFormDialogState extends State<ClienteFormDialog> {
  Timer? _pollTimer;
  BackgroundRfidService? _rfidService;

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
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      try {
        final uid = await RfidReaderService.checkForCardSilent();
        if (uid != null && uid.isNotEmpty && uid != 'NO_CARD') {
          if (widget.rfidController.text != uid) {
            widget.rfidController.text = uid;
            // Ya no cancelamos el timer para permitir cambiar de tarjeta silenciosamente
          }
        }
      } catch (e) {
        // Ignorar
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _rfidService?.resumeScanning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullScreen) {
      return Scaffold(
        backgroundColor: AppColors.cardBackground,
        appBar: GymAppBar(
          title: widget.isEditing ? 'Editar Cliente' : 'Nuevo Cliente',
        ),
        body: SafeArea(
          child: contentBox(context, GlobalKey<FormState>(), Rx<File?>(null), isFullScreen: true),
        ),
      );
    }
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      backgroundColor: AppColors.cardBackground,
      surfaceTintColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: contentBox(context, GlobalKey<FormState>(), Rx<File?>(null), isFullScreen: false),
    );
  }

  Widget contentBox(
    BuildContext context,
    GlobalKey<FormState> formKey,
    Rx<File?> photoFile, {
    bool isFullScreen = false,
  }) {
    PhoneNumber initialPhoneNumber;
    if (widget.isEditing && widget.phoneController.text.isNotEmpty) {
      try {
        final phone = widget.phoneController.text.trim();
        if (phone.startsWith('+52')) {
          final phoneWithoutCountryCode = phone.substring(3);
          initialPhoneNumber = PhoneNumber(phoneNumber: phoneWithoutCountryCode, isoCode: 'MX');
        } else if (phone.startsWith('+')) {
          initialPhoneNumber = PhoneNumber(phoneNumber: phone);
        } else {
          initialPhoneNumber = PhoneNumber(phoneNumber: phone, isoCode: 'MX');
        }
      } catch (e) {
        initialPhoneNumber = PhoneNumber(isoCode: 'MX');
      }
    } else {
      initialPhoneNumber = PhoneNumber(isoCode: 'MX');
    }

    String formattedPhoneNumber = widget.phoneController.text;

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isFullScreen)
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Wrap(
                  spacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      widget.isEditing ? Icons.edit : Icons.person_add,
                      color: AppColors.accent,
                      size: 30,
                    ),
                    Text(
                      widget.isEditing ? 'Editar Cliente' : 'Nuevo Cliente',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, isFullScreen ? 16 : 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PhotoCaptureWidget(
                      currentPhotoUrl: widget.currentPhotoUrl,
                      onPhotoTaken: (file) {
                        photoFile.value = file;
                      },
                    ),
                    const SizedBox(height: 16),
                    // El "Número de Usuario" se sigue generando y guardando en
                    // el backend vía userNumberController, pero no se muestra.
                    AnimatedBuilder(
                      animation: widget.rfidController,
                      builder: (context, child) {
                        final hasRfid = widget.rfidController.text.isNotEmpty;
                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: hasRfid ? AppColors.accent : Colors.grey.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.nfc, color: hasRfid ? AppColors.accent : AppColors.textSecondary, size: 28),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hasRfid ? 'Tarjeta vinculada' : 'Acerca la tarjeta al lector...',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: hasRfid ? AppColors.textPrimary : AppColors.textSecondary,
                                          ),
                                        ),
                                        if (hasRfid) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'ID: ${widget.rfidController.text}',
                                            style: TextStyle(fontSize: 14, color: AppColors.accent, fontWeight: FontWeight.w500),
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                  Icon(hasRfid ? Icons.check_circle : Icons.nfc, color: hasRfid ? AppColors.accent : AppColors.textSecondary, size: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: widget.nombreController,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      style: TextStyle(color: AppColors.textPrimary),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    InternationalPhoneNumberInput(
                      onInputChanged: (PhoneNumber number) {
                        formattedPhoneNumber = number.phoneNumber ?? '';
                        widget.phoneController.text = formattedPhoneNumber;
                      },
                      selectorConfig: const SelectorConfig(
                        selectorType: PhoneInputSelectorType.DROPDOWN,
                        setSelectorButtonAsPrefixIcon: true,
                        useEmoji: true,
                      ),
                      initialValue: initialPhoneNumber,
                      textStyle: TextStyle(color: AppColors.textPrimary),
                      inputDecoration: InputDecoration(
                        labelText: 'Teléfono',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: widget.emailController,
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico (Opcional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      style: TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: widget.addressController,
                      decoration: InputDecoration(
                        labelText: 'Dirección (Opcional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      style: TextStyle(color: AppColors.textPrimary),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.containerBackground,
                border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => isFullScreen ? Get.back() : Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          final user = UserModel(
                            name: widget.nombreController.text.trim(),
                            phone: widget.phoneController.text,
                            email: widget.emailController.text.isEmpty ? null : widget.emailController.text.trim(),
                            address: widget.addressController.text.isEmpty ? null : widget.addressController.text.trim(),
                            joinDate: DateTime.now(),
                            userNumber: widget.userNumberController.text,
                            rfidCard: widget.rfidController.text.isEmpty ? null : widget.rfidController.text,
                          );
                          widget.onSave(user, photoFile.value);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(widget.isEditing ? 'Guardar' : 'Agregar', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
