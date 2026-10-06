import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/core/theme/app_theme.dart';

import '../../core/utils/hora_formato.dart';
import '../../data/services/pantalla_clientes.dart';
import '../abonar/vigencia.dart';
import '../shared/widgets/welcome_screen_widget.dart';

/// Arranca la ventana para clientes (monitor extra). La llama `main` cuando
/// la abre desktop_multi_window: es otro motor de Flutter, ligero, sin
/// Supabase, GetX ni el lector. Los pases le llegan de la ventana principal.
Future<void> correrPantallaClientes(String idVentana) async {
  WidgetsFlutterBinding.ensureInitialized();
  final avisos = ValueNotifier<AvisoParaClientes?>(null);
  await WindowController.fromWindowId(idVentana)
      .setWindowMethodHandler((llamada) async {
    switch (llamada.method) {
      case 'aviso':
        avisos.value = AvisoParaClientes.fromJson(
            llamada.arguments as Map<dynamic, dynamic>);
      case 'quitar':
        avisos.value = null;
    }
    return null;
  });
  runApp(PantallaClientesApp(avisos: avisos));
}

class PantallaClientesApp extends StatelessWidget {
  const PantallaClientesApp({super.key, required this.avisos});

  final ValueListenable<AvisoParaClientes?> avisos;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'GymOne · Pantalla para clientes',
        theme: AppTheme.oscuro,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: PantallaClientesVista(avisos: avisos),
      );
}

/// En espera: logo, "Pasa tu tarjeta" y la hora. Al pasar una tarjeta, el
/// aviso de siempre pero solo con información, y luego vuelve a la espera.
///
/// Todo se dibuja a 1024×768 y se escala a la ventana: en un monitor grande
/// en pantalla completa se ve grande, sin cambiar el diseño.
class PantallaClientesVista extends StatefulWidget {
  const PantallaClientesVista({super.key, required this.avisos, this.ahora});

  final ValueListenable<AvisoParaClientes?> avisos;

  /// La hora que se muestra (las pruebas fijan una).
  final DateTime Function()? ahora;

  static const tamanoBase = Size(1024, 768);

  @override
  State<PantallaClientesVista> createState() => _PantallaClientesVistaState();
}

class _PantallaClientesVistaState extends State<PantallaClientesVista> {
  AvisoParaClientes? _aviso;
  Timer? _quitar;
  late final Timer _reloj;

  DateTime get _ahora => (widget.ahora ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    widget.avisos.addListener(_alLlegar);
    // La hora cambia cada minuto; revisarla cada 15 s basta.
    _reloj = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.avisos.removeListener(_alLlegar);
    _quitar?.cancel();
    _reloj.cancel();
    super.dispose();
  }

  void _alLlegar() {
    final aviso = widget.avisos.value;
    _quitar?.cancel();
    setState(() => _aviso = aviso);
    if (aviso == null) return;
    _quitar = Timer(aviso.duracion, () {
      if (mounted) setState(() => _aviso = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final aviso = _aviso;
    const base = PantallaClientesVista.tamanoBase;
    return Scaffold(
      backgroundColor: c.backgroundColor,
      body: SizedBox.expand(
        child: FittedBox(
          child: SizedBox.fromSize(
            size: base,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(size: base),
              child: aviso == null ? _espera(context) : _avisoDe(aviso),
            ),
          ),
        ),
      ),
    );
  }

  Widget _espera(BuildContext context) {
    final c = context.colores;
    final ahora = _ahora;
    final fecha = fechaLarga(ahora, conDia: true, hoy: ahora);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.asset('assets/images/logo_app.png',
                width: 140, height: 140, filterQuality: FilterQuality.medium),
          ),
          const SizedBox(height: 36),
          Text('Pasa tu tarjeta',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 56,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 40),
          Text(HoraFormato.deFecha(ahora),
              key: const Key('hora'),
              style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 88,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 8),
          Text(fecha[0].toUpperCase() + fecha.substring(1),
              style: TextStyle(color: c.textSecondary, fontSize: 26)),
        ],
      ),
    );
  }

  Widget _avisoDe(AvisoParaClientes aviso) {
    final url = aviso.fotoUrl;
    return WelcomeScreenWidget(
      // Un pase nuevo vuelve a animarse desde el principio.
      key: ValueKey(aviso.id),
      userName: aviso.nombre,
      userPhotoUrl: url ?? '',
      daysLeft: aviso.diasRestantes,
      expirationDate: aviso.vence,
      isVisible: true,
      isExpired: aviso.tipo == TipoAviso.vencida,
      isNotFound: aviso.tipo == TipoAviso.noRegistrada,
      isSalida: aviso.tipo == TipoAviso.salida,
      paraClientes: true,
      foto: url == null || url.isEmpty
          ? null
          : (tamano) => ClipOval(
                child: Image.network(
                  url,
                  width: tamano,
                  height: tamano,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) =>
                      _Iniciales(nombre: aviso.nombre, tamano: tamano),
                ),
              ),
    );
  }
}

/// Si la foto no carga: las iniciales del cliente.
class _Iniciales extends StatelessWidget {
  const _Iniciales({required this.nombre, required this.tamano});

  final String nombre;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    final iniciales = partes
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: tamano / 2,
      backgroundColor: AppColors.accent,
      child: Text(iniciales,
          style: TextStyle(
              color: Colors.white,
              fontSize: tamano / 3,
              fontWeight: FontWeight.w700)),
    );
  }
}
