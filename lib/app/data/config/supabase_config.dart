import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración para Supabase
///
/// Esta clase proporciona acceso a los valores de configuración de Supabase
/// utilizando las variables de entorno definidas en el archivo .env
class SupabaseConfig {
  /// URL base de Supabase
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';

  /// Clave anónima para autenticación pública
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Nombre del bucket para almacenamiento de archivos
  static String get bucketName => dotenv.env['SUPABASE_BUCKET_NAME'] ?? 'users';

  /// URL base para acceso al almacenamiento
  static String get storageUrl => '$url/storage/v1/object/public';

  /// Modo de depuración
  static bool get debugMode =>
      dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';
}
