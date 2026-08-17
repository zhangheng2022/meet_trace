#include "flutter_window.h"

#include <shellapi.h>

#include <optional>
#include <variant>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {

constexpr char kDesktopLifecycleChannel[] =
    "com.meettrace.app/windows_desktop_lifecycle";
constexpr UINT kTrayCallbackMessage = WM_APP + 1;
constexpr UINT kConfirmExitMessage = WM_APP + 2;
constexpr UINT kTrayIconId = 1;
constexpr UINT kOpenWindowCommand = 1001;
constexpr UINT kStopAndExitCommand = 1002;

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

void FlutterWindow::ActivateExistingInstance() {
  RemoveTrayIcon();
  Activate();
}

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
  ConfigureDesktopLifecycleChannel();
  taskbar_created_message_ = RegisterWindowMessage(L"TaskbarCreated");
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
  RemoveTrayIcon();
  desktop_lifecycle_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (taskbar_created_message_ != 0 &&
      message == taskbar_created_message_ && tray_icon_visible_) {
    tray_icon_visible_ = false;
    AddTrayIcon(false);
    return 0;
  }

  switch (message) {
    case WM_POWERBROADCAST:
      if (recording_active_) {
        if (wparam == PBT_APMSUSPEND) {
          NotifyDart("systemSuspending");
        } else if (wparam == PBT_APMRESUMEAUTOMATIC ||
                   wparam == PBT_APMRESUMESUSPEND) {
          NotifyDart("systemResumed");
        }
      }
      return TRUE;
    case WM_QUERYENDSESSION:
      if (recording_active_) {
        NotifyDart("systemSessionEnding");
      }
      return TRUE;
    case WM_CLOSE:
      if (recording_active_) {
        HideRecordingToTray();
        return 0;
      }
      break;
    case kTrayCallbackMessage:
      if (lparam == WM_LBUTTONUP || lparam == WM_LBUTTONDBLCLK) {
        ActivateExistingInstance();
        return 0;
      }
      if (lparam == WM_RBUTTONUP || lparam == WM_CONTEXTMENU) {
        ShowTrayMenu();
        return 0;
      }
      break;
    case WM_COMMAND:
      switch (LOWORD(wparam)) {
        case kOpenWindowCommand:
          ActivateExistingInstance();
          return 0;
        case kStopAndExitCommand:
          RequestStopAndExit();
          return 0;
      }
      break;
    case kConfirmExitMessage:
      RemoveTrayIcon();
      DestroyWindow(hwnd);
      return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle other messages.
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

void FlutterWindow::ConfigureDesktopLifecycleChannel() {
  desktop_lifecycle_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kDesktopLifecycleChannel,
          &flutter::StandardMethodCodec::GetInstance());
  desktop_lifecycle_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setRecordingActive") {
          const auto* active =
              std::get_if<bool>(call.arguments());
          if (active == nullptr) {
            result->Error("invalid_argument", "Expected a boolean state");
            return;
          }
          recording_active_ = *active;
          result->Success();
          if (!recording_active_ && !exit_request_pending_ &&
              !IsWindowVisible(GetHandle())) {
            ActivateExistingInstance();
          }
          return;
        }
        if (call.method_name() == "confirmExit") {
          recording_active_ = false;
          exit_request_pending_ = false;
          result->Success();
          PostMessage(GetHandle(), kConfirmExitMessage, 0, 0);
          return;
        }
        if (call.method_name() == "cancelExit") {
          exit_request_pending_ = false;
          result->Success();
          ActivateExistingInstance();
          return;
        }
        result->NotImplemented();
      });
}

void FlutterWindow::HideRecordingToTray() {
  if (AddTrayIcon(true)) {
    ShowWindow(GetHandle(), SW_HIDE);
  }
}

bool FlutterWindow::AddTrayIcon(bool show_notification) {
  NOTIFYICONDATA icon_data{};
  icon_data.cbSize = sizeof(icon_data);
  icon_data.hWnd = GetHandle();
  icon_data.uID = kTrayIconId;
  icon_data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  icon_data.uCallbackMessage = kTrayCallbackMessage;
  icon_data.hIcon = LoadIcon(GetModuleHandle(nullptr),
                             MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(icon_data.szTip, L"\u4f1a\u8ff9\uff1a\u5f55\u97f3\u4ecd\u5728\u7ee7\u7eed");
  if (show_notification) {
    icon_data.uFlags |= NIF_INFO;
    icon_data.dwInfoFlags = NIIF_INFO | NIIF_NOSOUND;
    wcscpy_s(icon_data.szInfoTitle, L"\u4f1a\u8ff9\u5df2\u8f6c\u5165\u7cfb\u7edf\u6258\u76d8");
    wcscpy_s(icon_data.szInfo,
             L"\u4e8b\u5b9e\u5f55\u97f3\u4ecd\u5728\u7ee7\u7eed\uff0c\u8bf7\u4ece\u6258\u76d8\u505c\u6b62\u5e76\u9000\u51fa\u3002");
  }
  tray_icon_visible_ =
      Shell_NotifyIcon(tray_icon_visible_ ? NIM_MODIFY : NIM_ADD,
                       &icon_data) != FALSE;
  return tray_icon_visible_;
}

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_icon_visible_ || !GetHandle()) {
    return;
  }
  NOTIFYICONDATA icon_data{};
  icon_data.cbSize = sizeof(icon_data);
  icon_data.hWnd = GetHandle();
  icon_data.uID = kTrayIconId;
  Shell_NotifyIcon(NIM_DELETE, &icon_data);
  tray_icon_visible_ = false;
}

void FlutterWindow::ShowTrayMenu() {
  POINT cursor{};
  if (!GetCursorPos(&cursor)) {
    return;
  }
  HMENU menu = CreatePopupMenu();
  if (!menu) {
    return;
  }
  AppendMenu(menu, MF_STRING, kOpenWindowCommand,
             L"\u6253\u5f00\u4f1a\u8ff9");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu,
             MF_STRING | (exit_request_pending_ ? MF_GRAYED : MF_ENABLED),
             kStopAndExitCommand, L"\u505c\u6b62\u5e76\u9000\u51fa");
  SetForegroundWindow(GetHandle());
  TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN | TPM_LEFTALIGN,
                 cursor.x, cursor.y, 0, GetHandle(), nullptr);
  DestroyMenu(menu);
  PostMessage(GetHandle(), WM_NULL, 0, 0);
}

void FlutterWindow::RequestStopAndExit() {
  if (exit_request_pending_ || !recording_active_ ||
      !desktop_lifecycle_channel_) {
    return;
  }
  exit_request_pending_ = true;
  desktop_lifecycle_channel_->InvokeMethod(
      "stopAndExitRequested",
      std::make_unique<flutter::EncodableValue>());
}

void FlutterWindow::NotifyDart(const char* method) {
  if (!desktop_lifecycle_channel_) {
    return;
  }
  desktop_lifecycle_channel_->InvokeMethod(
      method, std::make_unique<flutter::EncodableValue>());
}
