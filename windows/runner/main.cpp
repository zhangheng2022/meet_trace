#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kSingleInstanceMutex[] =
    L"Local\\MeetTrace.SingleInstance.1";
constexpr wchar_t kActivateExistingEvent[] =
    L"Local\\MeetTrace.ActivateExisting.1";

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE activation_event =
      CreateEvent(nullptr, TRUE, FALSE, kActivateExistingEvent);
  HANDLE single_instance =
      CreateMutex(nullptr, TRUE, kSingleInstanceMutex);
  if (single_instance != nullptr && GetLastError() == ERROR_ALREADY_EXISTS) {
    if (activation_event != nullptr) {
      SetEvent(activation_event);
      CloseHandle(activation_event);
    }
    CloseHandle(single_instance);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  window.SetMinimumSize(Win32Window::Size(840, 640));
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"MeetTrace", origin, size)) {
    ::CoUninitialize();
    if (activation_event != nullptr) {
      CloseHandle(activation_event);
    }
    if (single_instance != nullptr) {
      CloseHandle(single_instance);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  if (activation_event == nullptr) {
    ::MSG msg;
    while (::GetMessage(&msg, nullptr, 0, 0)) {
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
    }
    ::CoUninitialize();
    if (single_instance != nullptr) {
      CloseHandle(single_instance);
    }
    return EXIT_SUCCESS;
  }

  bool running = true;
  while (running) {
    const DWORD wait_result = MsgWaitForMultipleObjects(
        1, &activation_event, FALSE, INFINITE, QS_ALLINPUT);
    if (wait_result == WAIT_OBJECT_0) {
      ResetEvent(activation_event);
      window.ActivateExistingInstance();
      continue;
    }
    if (wait_result != WAIT_OBJECT_0 + 1) {
      break;
    }
    ::MSG msg;
    while (::PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
      if (msg.message == WM_QUIT) {
        running = false;
        break;
      }
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
    }
  }

  ::CoUninitialize();
  if (activation_event != nullptr) {
    CloseHandle(activation_event);
  }
  if (single_instance != nullptr) {
    CloseHandle(single_instance);
  }
  return EXIT_SUCCESS;
}
