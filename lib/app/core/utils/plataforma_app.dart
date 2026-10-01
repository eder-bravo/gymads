import 'package:flutter/foundation.dart';

abstract final class PlataformaApp {
  static bool get escritorio =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);
  static bool get escanerFisico => kIsWeb || escritorio;
  static bool get ocrMovil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
