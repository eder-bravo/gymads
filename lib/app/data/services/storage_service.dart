import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Servicio centralizado para acceder a objetos de Supabase Storage con
/// **buckets privados + URLs firmadas**.
///
/// Reglas de diseño:
/// - El valor que la app guarda en la BD (p. ej. `user.photoUrl`) puede ser:
///     • una URL pública antigua  (`.../object/public/{bucket}/{path}`)
///     • una URL firmada          (`.../object/sign/{bucket}/{path}?token=`)
///     • o un path crudo          (`users/xxx.jpg`)
///   [signedUrl] extrae el path del objeto de cualquiera de esos formatos,
///   así **no hace falta migrar los datos existentes**.
/// - Las URLs firmadas se cachean en memoria por path (con margen antes de
///   expirar) para no llamar a `createSignedUrl` en cada rebuild.
/// - [stableKey] devuelve el path del objeto: úsalo como `cacheKey` en
///   `cached_network_image` para que la rotación de la URL firmada NO
///   invalide el caché de disco/memoria de la imagen.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Vigencia de la URL firmada.
  static const Duration _ttl = Duration(hours: 2);

  /// Margen para refrescar antes de que expire (evita usar una URL casi vencida).
  static const Duration _refreshMargin = Duration(minutes: 10);

  final Map<String, _SignedEntry> _cache = {};

  /// Path del objeto dentro del bucket, en formato `{bucket}/{path}`.
  /// Sirve como clave estable de caché para `cached_network_image`.
  String? stableKey(String? stored, {String? bucket}) {
    final parsed = _parse(stored, bucket ?? SupabaseConfig.bucketName);
    return parsed == null ? null : '${parsed.bucket}/${parsed.path}';
  }

  /// Devuelve una URL firmada válida para [stored], cacheada en memoria.
  /// Retorna null si no se puede resolver el path o falla la firma.
  Future<String?> signedUrl(
    String? stored, {
    String? bucket,
    Duration ttl = _ttl,
  }) async {
    final parsed = _parse(stored, bucket ?? SupabaseConfig.bucketName);
    if (parsed == null) return null;

    final key = '${parsed.bucket}/${parsed.path}';
    final now = DateTime.now();
    final cached = _cache[key];
    if (cached != null &&
        cached.expiresAt.subtract(_refreshMargin).isAfter(now)) {
      return cached.url;
    }

    try {
      final url = await _client.storage
          .from(parsed.bucket)
          .createSignedUrl(parsed.path, ttl.inSeconds);
      _cache[key] = _SignedEntry(url, now.add(ttl));
      return url;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [StorageService] No se pudo firmar "$key": $e');
      }
      return null;
    }
  }

  /// Invalida la URL firmada cacheada de [stored] (p. ej. tras re-subir la foto).
  void invalidate(String? stored, {String? bucket}) {
    final k = stableKey(stored, bucket: bucket);
    if (k != null) _cache.remove(k);
  }

  /// Extrae `{bucket, path}` de una URL pública/firmada/autenticada o un path crudo.
  ({String bucket, String path})? _parse(String? stored, String defaultBucket) {
    if (stored == null || stored.isEmpty) return null;

    const markers = [
      '/object/public/',
      '/object/sign/',
      '/object/authenticated/',
    ];
    for (final marker in markers) {
      final idx = stored.indexOf(marker);
      if (idx == -1) continue;
      var rest = stored.substring(idx + marker.length);
      final q = rest.indexOf('?'); // quitar query (?token=...)
      if (q != -1) rest = rest.substring(0, q);
      final slash = rest.indexOf('/');
      if (slash <= 0 || slash >= rest.length - 1) return null;
      return (bucket: rest.substring(0, slash), path: rest.substring(slash + 1));
    }

    // No es una URL de storage → asumir que ya es un path dentro del bucket por defecto.
    if (stored.startsWith('http')) return null; // URL externa desconocida
    return (bucket: defaultBucket, path: stored);
  }
}

class _SignedEntry {
  final String url;
  final DateTime expiresAt;
  const _SignedEntry(this.url, this.expiresAt);
}
