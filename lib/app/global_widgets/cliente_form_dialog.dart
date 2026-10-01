import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/config/rfid_config.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/services/background_rfid_service.dart';
import 'package:gymads/app/data/services/captura_de_tarjeta.dart';
import 'package:gymads/app/data/services/rfid_reader_service.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import '../core/widgets/formulario.dart';
import '../modules/shared/widgets/photo_capture_widget.dart';
import 'app_header.dart';
import 'tarjeta_del_formulario.dart';
import '../core/utils/plataforma_app.dart';
import '../core/utils/telefono_escritorio.dart';

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

  /// La tarjeta que tenía el cliente al abrir la edición, para mostrar si se
  /// cambió o se quitó. Null en un alta.
  final String? tarjetaOriginal;

  /// Busca qué cliente tiene una tarjeta, cuando el formulario lee el lector
  /// por su cuenta. Por defecto, en la base de datos.
  final Future<UserModel?> Function(String uid)? buscarDueno;

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
    this.tarjetaOriginal,
    this.buscarDueno,
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
  late final PhoneNumber _telefonoInicial =
      _telefonoDe(widget.phoneController.text);

  late final TarjetaDelFormulario _tarjeta = TarjetaDelFormulario(
    widget.rfidController,
    original: widget.tarjetaOriginal,
  );

  /// Suelta las tarjetas del lector al cerrar el formulario.
  VoidCallback? _soltarCaptura;

  /// Aviso pasajero bajo la tarjeta ("Es la misma tarjeta", "Es la tarjeta
  /// de…").
  String? _nota;
  Timer? _quitarNota;

  /// El borde se resalta un momento cuando la tarjeta cambia.
  bool _destello = false;
  Timer? _apagarDestello;

  /// Al leer el lector por su cuenta, `/uid_only` repite la última tarjeta
  /// en varias consultas: un mismo pase no cuenta dos veces.
  String? _ultimoUid;
  DateTime? _ultimoUidEn;

  @override
  void initState() {
    super.initState();
    _rfidService = Get.isRegistered<BackgroundRfidService>()
        ? Get.find<BackgroundRfidService>()
        : null;
    // El servicio de entradas sigue escuchando: si pasa un cliente mientras
    // se registra a otro, se registra su entrada. Las tarjetas libres nos las
    // pasa a nosotros.
    _soltarCaptura = CapturaDeTarjeta.tomar(_alPasarTarjeta);
    _startSilentPolling();
  }

  /// Respaldo: si este teléfono no está escuchando el lector (no le tocan
  /// los avisos, o el escaneo está apagado), el formulario lo lee él mismo.
  void _startSilentPolling() {
    _pollTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_consultandoLector) return;
      if (_rfidService?.atiendeAhora ?? false) return;
      _consultandoLector = true;
      try {
        final uid = await RfidReaderService.checkForCardSilent();
        if (uid == null || uid.isEmpty || uid == 'NO_CARD') return;
        if (_mismoPase(uid) || !mounted) return;
        _alPasarTarjeta(uid, await _dueno(uid));
      } catch (e) {
        // Ignorar
      } finally {
        _consultandoLector = false;
      }
    });
  }

  bool _mismoPase(String uid) {
    final ahora = DateTime.now();
    final repetido = uid == _ultimoUid &&
        _ultimoUidEn != null &&
        ahora.difference(_ultimoUidEn!) < const Duration(seconds: 3);
    _ultimoUid = uid;
    _ultimoUidEn = ahora;
    return repetido;
  }

  /// Sin internet no se sabe de quién es: se toma como libre y, si era de
  /// otro cliente, el guardado lo rechaza.
  Future<UserModel?> _dueno(String uid) async {
    try {
      final buscar = widget.buscarDueno ??
          (uid) => Get.find<UserRepository>().getUserByRfid(uid);
      return await buscar(uid);
    } catch (_) {
      return null;
    }
  }

  /// Una tarjeta pasó por el lector. Si es libre (o la que el cliente ya
  /// tenía) se la queda el formulario; si es de otro cliente no la toca y
  /// devuelve false, para que se registre su entrada.
  bool _alPasarTarjeta(String uid, UserModel? dueno) {
    if (!mounted) return false;
    if (dueno != null && !_tarjeta.esLaOriginal(uid)) {
      _mostrarNota('Es la tarjeta de ${dueno.name}. No se cambió.');
      return false;
    }
    switch (_tarjeta.pasar(uid)) {
      case ResultadoPase.misma:
        _mostrarNota(_tarjeta.estado == EstadoTarjeta.sinCambio
            ? 'Es su tarjeta actual'
            : 'Es la misma tarjeta');
      case ResultadoPase.asignada:
      case ResultadoPase.cambiada:
        _alCambiarTarjeta();
    }
    return true;
  }

  void _alCambiarTarjeta() {
    HapticFeedback.mediumImpact();
    _quitarNota?.cancel();
    _apagarDestello?.cancel();
    setState(() {
      _nota = null;
      _destello = true;
    });
    _apagarDestello = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _destello = false);
    });
  }

  void _mostrarNota(String texto) {
    _quitarNota?.cancel();
    setState(() => _nota = texto);
    _quitarNota = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _nota = null);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _quitarNota?.cancel();
    _apagarDestello?.cancel();
    _soltarCaptura?.call();
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
      phone: PlataformaApp.escritorio
          ? telefonoEscritorio(widget.phoneController.text)!
          : widget.phoneController.text,
      email: widget.emailController.text.trim().isEmpty
          ? null
          : widget.emailController.text.trim(),
      address: widget.addressController.text.trim().isEmpty
          ? null
          : widget.addressController.text.trim(),
      joinDate: DateTime.now(),
      userNumber: widget.userNumberController.text,
      rfidCard: widget.rfidController.text.isEmpty
          ? null
          : widget.rfidController.text,
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
          _recuadroTarjeta(),
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
        title: Text(_titulo, style: TextStyle(color: c.textPrimary)),
        content: SizedBox(width: 420, height: 560, child: formulario),
        actions: [
          Obx(() => BotonCancelar(
              onPressed:
                  _guardando.value ? null : () => Navigator.of(context).pop())),
          boton,
        ],
      );
    }

    return Obx(() {
      final guardando = _guardando.value;
      // Mientras guarda no se puede salir: se perdería lo escrito si falla.
      return PopScope(
        canPop: !guardando,
        child: ScaffoldAdaptable(
          anchoMaximo: 760,
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
    if (PlataformaApp.escritorio) {
      return TextFormField(
          controller: widget.phoneController,
          style: TextStyle(color: c.textPrimary, fontSize: 16),
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
              labelText: 'Teléfono *',
              hintText: '10 dígitos de México o +código de país',
              prefixIcon: Icon(Icons.phone_outlined)),
          validator: (v) => telefonoEscritorio(v ?? '') == null
              ? 'Escribe 10 dígitos o incluye +código de país'
              : null);
    }
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
      selectorTextStyle: TextStyle(color: c.textPrimary, fontSize: 16),
      textStyle: TextStyle(color: c.textPrimary, fontSize: 16),
      keyboardType: TextInputType.phone,
      inputDecoration: const InputDecoration(labelText: 'Teléfono *'),
      errorMessage: 'Escribe un teléfono válido',
      validator: (valor) => (valor == null || valor.trim().isEmpty)
          ? 'Escribe el teléfono'
          : null,
    );
  }

  /// La tarjeta del lector: se asigna pasándola; nunca se muestra su número.
  /// Lo que sí se ve es si cambió: "Tarjeta cambiada", "Tarjeta nueva · Se
  /// cambiará al guardar", con un destello del borde y una vibración.
  Widget _recuadroTarjeta() {
    final c = context.colores;
    final hayLector = RfidConfig.isConfigured || RfidConfig.tieneLector;
    return AnimatedBuilder(
      animation: widget.rfidController,
      builder: (context, _) {
        final quitar = (
          'Quitar',
          () {
            _tarjeta.quitar();
            _alCambiarTarjeta();
          }
        );
        final deshacer = (
          'Deshacer',
          () {
            _tarjeta.deshacer();
            _alCambiarTarjeta();
          }
        );

        final (titulo, detalle, icono, color, accion) =
            switch (_tarjeta.estado) {
          EstadoTarjeta.vacia => (
              hayLector
                  ? 'Pasa la tarjeta por el lector'
                  : 'Sin lector de tarjetas',
              null,
              Icons.contactless_outlined,
              null,
              null,
            ),
          EstadoTarjeta.lista => (
              'Tarjeta lista',
              null,
              Icons.check_circle,
              AppColors.success,
              quitar,
            ),
          EstadoTarjeta.cambiada => (
              'Tarjeta cambiada',
              'Se usará la última que pasaste',
              Icons.check_circle,
              AppColors.success,
              quitar,
            ),
          EstadoTarjeta.sinCambio => (
              'Tiene tarjeta',
              null,
              Icons.check_circle,
              AppColors.success,
              quitar,
            ),
          EstadoTarjeta.nueva => (
              'Tarjeta nueva',
              'Se cambiará al guardar',
              Icons.autorenew,
              AppColors.accent,
              deshacer,
            ),
          EstadoTarjeta.quitada => (
              'Sin tarjeta',
              'Se quitará al guardar',
              Icons.credit_card_off_outlined,
              AppColors.warning,
              deshacer,
            ),
        };
        final linea = _nota ?? detalle;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          decoration: BoxDecoration(
            color: color?.withOpacity(_destello ? 0.22 : 0.10) ?? c.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color?.withOpacity(_destello ? 1 : 0.6) ?? c.borde,
              width: _destello ? 2.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icono, color: color ?? c.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(color: c.textPrimary, fontSize: 16),
                    ),
                    if (linea != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        linea,
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              if (accion != null)
                TextButton(
                  onPressed: accion.$2,
                  style: TextButton.styleFrom(
                    foregroundColor: c.textSecondary,
                  ),
                  child: Text(accion.$1),
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
