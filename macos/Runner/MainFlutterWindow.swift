import Cocoa
import FlutterMacOS
import desktop_multi_window
import AVFoundation
import CoreBluetooth
import UserNotifications

class MainFlutterWindow: NSWindow {
  private var permisos: PermisosEscritorio?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Tamaño del contenido en puntos; la barra de título queda fuera.
    self.contentMinSize = NSSize(width: 960, height: 600)
    // Primera apertura: 1280×800 centrada y dentro del área visible. Después
    // se recuerda el tamaño y la posición que dejó el usuario.
    if !self.setFrameUsingName("VentanaPrincipal") {
      self.setFrame(marcoInicial(), display: true)
    }
    self.setFrameAutosaveName("VentanaPrincipal")

    RegisterGeneratedPlugins(registry: flutterViewController)
    permisos = PermisosEscritorio(messenger: flutterViewController.engine.binaryMessenger)

    // La pantalla para clientes (monitor extra): otro motor de Flutter. No se
    // le registran plugins (solo usa los suyos de ventanas, que se registran
    // solos): Bluetooth, notificaciones o enlaces se duplicarían.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controlador in
      guard let ventana = controlador.view.window else { return }
      ventana.title = "GymOne · Pantalla para clientes"
      ventana.contentMinSize = NSSize(width: 480, height: 360)
      ventana.setContentSize(NSSize(width: 1024, height: 768))
      ventana.center()
    }

    // Al cerrar la ventana principal se cierra la app, aunque siga abierta
    // la pantalla para clientes: sin la principal ya no le llegan avisos.
    NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification, object: self, queue: .main
    ) { _ in
      NSApp.terminate(nil)
    }

    super.awakeFromNib()
  }

  // Una tecla que ni la app ni el campo de texto usaron llega hasta la
  // ventana, y macOS suena como tecla no válida (p. ej. el lector de códigos
  // fuera de Venta). Los atajos con ⌘ van por los menús y no pasan por aquí.
  override func keyDown(with event: NSEvent) {}

  private func marcoInicial() -> NSRect {
    guard let visible = (self.screen ?? NSScreen.main)?.visibleFrame else {
      return self.frame
    }
    var marco = self.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 1280, height: 800))
    let minimo = self.frameRect(forContentRect: NSRect(origin: .zero, size: self.contentMinSize))
    marco.size.width = max(min(marco.width, visible.width), minimo.width)
    marco.size.height = max(min(marco.height, visible.height), minimo.height)
    marco.origin.x = visible.midX - marco.width / 2
    marco.origin.y = visible.midY - marco.height / 2
    return marco
  }
}

/// Una respuesta por llamada, aunque el sistema conteste después del límite.
/// Tanto el temporizador como las respuestas se ejecutan en la cola principal.
final class RespuestaPermiso {
  private var resultado: FlutterResult?
  private var temporizador: DispatchWorkItem?
  var terminada: Bool { resultado == nil }

  init(_ resultado: @escaping FlutterResult, plazo: TimeInterval,
       alAgotar: @escaping () -> String) {
    self.resultado = resultado
    let tarea = DispatchWorkItem { self.enviar(alAgotar()) }
    temporizador = tarea
    DispatchQueue.main.asyncAfter(deadline: .now() + plazo, execute: tarea)
  }

  func enviar(_ estado: String) {
    guard let resultado = resultado else { return }
    self.resultado = nil
    temporizador?.cancel()
    temporizador = nil
    resultado(estado)
  }
}

/// TCC para macOS. Mantiene el canal y el central BLE mientras llega el aviso.
private final class PermisosEscritorio: NSObject, CBCentralManagerDelegate {
  private let channel: FlutterMethodChannel
  private var central: CBCentralManager?
  private var pendienteBluetooth: RespuestaPermiso?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "gymone/permisos_escritorio", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result("sinDato"); return }
      self.atender(call, result: result)
    }
  }

  private func estado(_ status: AVAuthorizationStatus) -> String {
    switch status {
    case .authorized: return "permitido"
    case .denied, .restricted: return "bloqueado"
    case .notDetermined: return "denegado"
    @unknown default: return "sinDato"
    }
  }

  private func estadoBluetooth() -> String {
    switch CBManager.authorization {
    case .allowedAlways: return "permitido"
    case .denied, .restricted: return "bloqueado"
    case .notDetermined: return "denegado"
    @unknown default: return "sinDato"
    }
  }

  private func estadoSinEsperar(_ permiso: String) -> String {
    switch permiso {
    case "camara":
      let status = AVCaptureDevice.authorizationStatus(for: .video)
      return status == .notDetermined ? "sinDato" : estado(status)
    case "bluetooth":
      return CBManager.authorization == .notDetermined ? "sinDato" : estadoBluetooth()
    default: return "sinDato"
    }
  }

  private func atender(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "estado" || call.method == "pedir",
          let permiso = call.arguments as? String else {
      result(FlutterMethodNotImplemented); return
    }
    let pedir = call.method == "pedir"
    let respuesta = RespuestaPermiso(result, plazo: pedir && permiso != "notificaciones" ? 45 : 5) { [weak self] in
      self?.estadoSinEsperar(permiso) ?? "sinDato"
    }
    if pedir { NSApp.activate(ignoringOtherApps: true) }
    switch permiso {
    case "camara":
      if pedir && AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
        AVCaptureDevice.requestAccess(for: .video) { _ in
          DispatchQueue.main.async {
            respuesta.enviar(self.estado(AVCaptureDevice.authorizationStatus(for: .video)))
          }
        }
      } else { respuesta.enviar(estado(AVCaptureDevice.authorizationStatus(for: .video))) }
    case "bluetooth":
      if pedir && CBManager.authorization == .notDetermined {
        if let pendiente = pendienteBluetooth, !pendiente.terminada {
          respuesta.enviar("sinDato"); return
        }
        pendienteBluetooth = respuesta
        central = CBCentralManager(delegate: self, queue: .main)
      } else { respuesta.enviar(estadoBluetooth()) }
    case "notificaciones":
      let centro = UNUserNotificationCenter.current()
      func consultar() {
        centro.getNotificationSettings { settings in
          let estado: String
          switch settings.authorizationStatus {
          case .authorized, .provisional: estado = "permitido"
          case .denied: estado = "bloqueado"
          case .notDetermined: estado = pedir ? "sinDato" : "denegado"
          @unknown default: estado = "sinDato"
          }
          DispatchQueue.main.async { respuesta.enviar(estado) }
        }
      }
      if pedir {
        // En macOS la autorización puede esperar al aviso de notificaciones
        // fuera de la ventana. Consultar el estado sin bloquear el arranque;
        // al volver a la app se actualizará desde Flutter.
        centro.requestAuthorization(options: [.alert, .sound]) { _, _ in consultar() }
      }
      consultar()
    default: respuesta.enviar("sinDato")
    }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    guard central === self.central, CBManager.authorization != .notDetermined,
          let pendiente = pendienteBluetooth else { return }
    pendienteBluetooth = nil
    pendiente.enviar(estadoBluetooth())
  }
}
