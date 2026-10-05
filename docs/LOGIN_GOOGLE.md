# Inicio con Google en la app instalada

## Qué cambió

Android con Google Play Services e iOS conservan el inicio nativo de Google.
Huawei sin esos servicios usa una sesión de autenticación del navegador
del sistema mediante `flutter_web_auth_2`. Esa sesión devuelve éxito o
cancelación; ya no se espera cualquier evento `signedIn` de Supabase.

macOS y Windows usan el navegador predeterminado externo con un retorno local de un solo uso, protegido
por PKCE. El puerto se elige automáticamente. No se incrusta Google en un WebView.

Mientras se espera a Google, el botón permite cancelar y el acceso por correo
sigue disponible. Entrar por correo invalida el intento pendiente de Google.
El registro también permite cancelar. Se conserva `prompt=select_account` para
poder elegir otra cuenta.

## Configuración que debes repetir en otro proyecto

1. En Supabase, abre **Authentication → URL Configuration → Redirect URLs**.
2. Conserva el retorno de Android/iOS:
   `com.googleusercontent.apps.161338034924-4kfeihb6hgt7hf8f3ritrb1v6lukodv5://`
3. Añade el retorno de macOS/Windows: `http://127.0.0.1:*/auth/callback`.
   El asterisco permite el puerto local aleatorio. No cambies el Site URL por esto.
4. En Google Cloud se conserva el callback de Supabase:
   `https://olhbhnjhducfxkffercu.supabase.co/auth/v1/callback`.
   No añadas el retorno local de la app a Google Cloud.
5. En Android, el esquema de retorno debe tener un solo receptor:
   `com.linusu.flutter_web_auth_2.CallbackActivity` en `AndroidManifest.xml`.
6. Ejecuta `flutter pub get` y recompila la app completa. Un hot reload no
   incorpora un plugin nativo nuevo.

En macOS, ambos archivos de entitlements (DebugProfile y Release) deben permitir
`com.apple.security.network.server` para recibir el retorno local dentro del
sandbox. El cambio a navegador externo evita que `ASWebAuthenticationSession`
recurra a Safari cuando el navegador predeterminado no admite ese mecanismo.

Estos valores pertenecen al proyecto actual. En otro proyecto, usa su esquema y
su referencia de Supabase. Documentación: [Redirect URLs de Supabase](https://supabase.com/docs/guides/auth/redirect-urls).

## Cómo comprobarlo

Ejecuta `flutter test test/google_browser_auth_test.dart`. En un dispositivo real:

- Abre Google y cierra/cancela la ventana: debe permitir reintentar.
- Abre Google y elige entrar por correo: el intento de Google queda invalidado.
- Completa Google: vuelve a la app y termina la espera.
- Repite el inicio y elige otra cuenta.

En macOS y Windows, cerrar una pestaña externa no notifica de forma fiable a la app:
usa **Cancelar inicio con Google** o entra por correo. Al recibir el retorno,
la app intenta volver al frente y la página intenta cerrarse. Si el navegador
impide el cierre, muestra que puedes cerrar la pestaña manualmente. Una espera
abandonada también termina tras cinco minutos.

## Verificación realizada

Análisis de los archivos modificados, 11 pruebas automatizadas y compilaciones
debug de Android y macOS. No se ha probado físicamente en Huawei ni Windows.
El ajuste al navegador predeterminado de macOS también pasó las 11 pruebas
(incluida la apertura externa sin Safari/WebView) y la compilación release de
macOS. Falta comprobar el inicio real con Google en esa compilación nueva.
No se modificó la configuración de Google Cloud ni el Site URL de Supabase;
solo se añadió el retorno local a la lista permitida de Supabase.
