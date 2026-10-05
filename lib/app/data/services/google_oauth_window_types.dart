/// Una ventana de autenticación: entrega el retorno o null al cancelarse.
abstract interface class GoogleOAuthWindow {
  Future<String> prepare();
  Future<Uri?> authenticate(String url);
  void cancel();
  Future<void> dispose();
}

class GoogleOAuthFailure implements Exception {
  const GoogleOAuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
