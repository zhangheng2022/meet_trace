#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // Activates the existing instance and removes the temporary tray icon.
  void ActivateExistingInstance();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      desktop_lifecycle_channel_;

  bool recording_active_ = false;
  bool exit_request_pending_ = false;
  bool tray_icon_visible_ = false;
  UINT taskbar_created_message_ = 0;

  void ConfigureDesktopLifecycleChannel();
  void HideRecordingToTray();
  bool AddTrayIcon(bool show_notification);
  void RemoveTrayIcon();
  void ShowTrayMenu();
  void RequestStopAndExit();
  void NotifyDart(const char* method);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
