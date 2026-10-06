#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <flutter_windows.h>

namespace {

// La pantalla para clientes (monitor extra): otro motor de Flutter. Solo se
// le pone título y tamaño; no se le registran plugins (Bluetooth,
// notificaciones o enlaces se duplicarían).
void AlCrearVentana(void* controlador) {
  auto* vista = static_cast<flutter::FlutterViewController*>(controlador);
  if (!vista || !vista->view()) return;
  HWND ventana = ::GetAncestor(vista->view()->GetNativeWindow(), GA_ROOT);
  if (!ventana) return;
  ::SetWindowTextW(ventana, L"GymOne \u00B7 Pantalla para clientes");
  const UINT dpi = FlutterDesktopGetDpiForMonitor(
      ::MonitorFromWindow(ventana, MONITOR_DEFAULTTONEAREST));
  const int ancho = ::MulDiv(1024, dpi, 96);
  const int alto = ::MulDiv(768, dpi, 96);
  RECT area;
  ::SystemParametersInfoW(SPI_GETWORKAREA, 0, &area, 0);
  ::SetWindowPos(ventana, nullptr,
                 area.left + ((area.right - area.left) - ancho) / 2,
                 area.top + ((area.bottom - area.top) - alto) / 2, ancho, alto,
                 SWP_NOZORDER | SWP_NOACTIVATE);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  DesktopMultiWindowSetWindowCreatedCallback(AlCrearVentana);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
