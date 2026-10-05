import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let permisoRedLocal = PermisoRedLocal()

  /// Para avisarle a Flutter cuánto espacio ocupan los botones de la ventana
  /// en iPad (`VentanaEscritorio.margenDeControles` en Dart).
  static var canalDeVentana: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VentanaDeTableta") {
      AppDelegate.canalDeVentana = FlutterMethodChannel(
        name: "gymone/ventana", binaryMessenger: registrar.messenger())
    }

    // Pantalla "Permisos de la app" (lib/app/data/services/permisos_app.dart).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PermisoRedLocal") {
      let canal = FlutterMethodChannel(
        name: "gymone/red_local", binaryMessenger: registrar.messenger())
      canal.setMethodCallHandler { [weak self] llamada, responder in
        guard llamada.method == "comprobar", let self = self else {
          responder(FlutterMethodNotImplemented)
          return
        }
        self.permisoRedLocal.comprobar { concedido in
          responder(concedido.map { NSNumber(value: $0) } ?? NSNull())
        }
      }
    }
  }
}

/// La escena de la app. Extiende la de Flutter (`Info.plist`,
/// UISceneDelegateClassName) para las ventanas de iPadOS 26+, que se pueden
/// achicar y mover como en la Mac.
class SceneDelegate: FlutterSceneDelegate {
  /// Ventana mínima en iPad, igual que en escritorio
  /// (`VentanaEscritorio.minimoTableta` en Dart): por debajo la app no
  /// cabría con su diseño de tableta.
  static let tamanoMinimo = CGSize(width: 720, height: 720)

  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    let esIPad = UIDevice.current.userInterfaceIdiom == .pad
    // Antes de que se cree la ventana: así lo pide Apple.
    if esIPad, let escena = scene as? UIWindowScene {
      escena.sizeRestrictions?.minimumSize = SceneDelegate.tamanoMinimo
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Los botones de la ventana (cerrar, minimizar, acomodar) van arriba a la
    // izquierda, encima del contenido. Una vista invisible mide cuánto ocupan.
    if esIPad, let vista = window?.rootViewController?.view {
      let observador = ObservadorDeControles(frame: vista.bounds)
      observador.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      observador.isUserInteractionEnabled = false
      observador.isHidden = true
      vista.addSubview(observador)
    }
  }
}

/// Mide la franja de arriba que ocupan los botones de la ventana en iPadOS
/// 26+ y se la manda a Flutter, que baja la barra superior para no quedar
/// tapada. Pantalla completa o versiones anteriores: 0.
final class ObservadorDeControles: UIView {
  private var ultimo: CGFloat = -1

  override func layoutSubviews() {
    super.layoutSubviews()
    informar()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    setNeedsLayout()
  }

  private func informar() {
    var franja: CGFloat = 0
    if #available(iOS 26.0, *) {
      let conControles = directionalEdgeInsets(
        for: .safeArea(cornerAdaptation: .vertical)
      ).top
      franja = max(0, conControles - safeAreaInsets.top)
    }
    guard franja != ultimo else { return }
    ultimo = franja
    AppDelegate.canalDeVentana?.invokeMethod("controles", arguments: Double(franja))
  }
}

/// Si la app tiene permiso de "red local" (para hablar con el lector de
/// tarjetas). iOS no tiene una forma de consultarlo: la única es intentarlo.
///
/// La app se anuncia a sí misma por Bonjour (`_gymonelan._tcp`, declarado en
/// NSBonjourServices) y se busca:
/// - si se encuentra, el permiso está concedido;
/// - si iOS bloquea la búsqueda (PolicyDenied), está negado.
/// La primera vez, intentarlo es lo que hace salir el aviso del sistema. Mientras
/// el aviso está en pantalla iOS también reporta "bloqueado", así que la
/// respuesta se da hasta que el aviso se cierra (la app vuelve a estar activa).
///
/// Responde true (concedido), false (negado) o nil (no se pudo saber, p. ej.
/// sin WiFi).
final class PermisoRedLocal: NSObject, NetServiceDelegate {
  private static let tipo = "_gymonelan._tcp"
  /// kDNSServiceErr_PolicyDenied: la red local está bloqueada para la app.
  private static let politicaNegada: Int32 = -65570

  private var browser: NWBrowser?
  private var servicio: NetService?
  private var nombre = ""
  private var responder: ((Bool?) -> Void)?
  private var bloqueada = false
  private var salioAviso = false
  private var observadores: [NSObjectProtocol] = []

  func comprobar(_ responder: @escaping (Bool?) -> Void) {
    terminar(nil)  // Si había una comprobación en curso, se descarta.
    self.responder = responder
    bloqueada = false
    salioAviso = false
    nombre = "GymOne-\(UUID().uuidString.prefix(8))"

    let parametros = NWParameters()
    parametros.includePeerToPeer = true
    let browser = NWBrowser(
      for: .bonjour(type: PermisoRedLocal.tipo, domain: nil), using: parametros)
    browser.stateUpdateHandler = { [weak self] estado in
      guard let self = self else { return }
      if case .waiting(let error) = estado, case .dns(let codigo) = error,
        codigo == PermisoRedLocal.politicaNegada
      {
        self.bloqueada = true
      } else if case .ready = estado {
        self.bloqueada = false
      }
    }
    browser.browseResultsChangedHandler = { [weak self] resultados, _ in
      guard let self = self else { return }
      let seEncontro = resultados.contains { resultado in
        if case .service(let nombre, _, _, _) = resultado.endpoint {
          return nombre == self.nombre
        }
        return false
      }
      if seEncontro { self.terminar(true) }
    }
    self.browser = browser

    let servicio = NetService(
      domain: "local.", type: "\(PermisoRedLocal.tipo).", name: nombre, port: 9)
    servicio.delegate = self
    self.servicio = servicio

    // El aviso del sistema deja la app inactiva; al cerrarse vuelve a estar
    // activa y entonces ya se sabe la respuesta.
    let centro = NotificationCenter.default
    observadores = [
      centro.addObserver(
        forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
      ) { [weak self] _ in self?.salioAviso = true },
      centro.addObserver(
        forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
      ) { [weak self] _ in self?.decidir(despuesDe: 1.5) },
    ]

    browser.start(queue: .main)
    servicio.publish()

    // Sin aviso (ya se había contestado) la respuesta llega enseguida.
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
      guard let self = self, !self.salioAviso else { return }
      self.decidir(despuesDe: 0)
    }
    // Tope, por si la persona deja el aviso abierto.
    decidir(despuesDe: 60)
  }

  private func decidir(despuesDe segundos: TimeInterval) {
    let esta = nombre
    DispatchQueue.main.asyncAfter(deadline: .now() + segundos) { [weak self] in
      guard let self = self, self.responder != nil, self.nombre == esta else { return }
      self.terminar(self.bloqueada ? false : nil)
    }
  }

  private func terminar(_ concedido: Bool?) {
    let responder = self.responder
    self.responder = nil
    browser?.cancel()
    browser = nil
    servicio?.stop()
    servicio = nil
    observadores.forEach(NotificationCenter.default.removeObserver)
    observadores = []
    responder?(concedido)
  }
}
