import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'recording_ports.dart';

const _recordingServiceId = 7001;

@pragma('vm:entry-point')
void meetilyRecordingForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_RecordingKeepAliveTaskHandler());
}

final class FlutterForegroundRecordingLifecycle
    implements RecordingForegroundLifecycle {
  bool _started = false;

  @override
  Future<void> start({required String meetingId}) async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'meetily_recording',
        channelName: '会议录音',
        channelDescription: '录音进行时保持麦克风采集和事实音频写入',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: false,
        stopWithTask: false,
      ),
    );

    if (Platform.isAndroid) {
      final permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    }
    if (await FlutterForegroundTask.isRunningService) {
      await _requireSuccess(FlutterForegroundTask.stopService());
    }
    await _requireSuccess(
      FlutterForegroundTask.startService(
        serviceId: _recordingServiceId,
        serviceTypes: const [ForegroundServiceTypes.microphone],
        notificationTitle: '会迹 · MeetTrace 正在录音',
        notificationText: '事实音频正在安全保存',
        callback: meetilyRecordingForegroundCallback,
      ),
    );
    _started = true;
  }

  @override
  Future<void> setPaused(bool paused) async {
    if (!_started) {
      return;
    }
    await _requireSuccess(
      FlutterForegroundTask.updateService(
        notificationTitle: paused
            ? '会迹 · MeetTrace 录音已暂停'
            : '会迹 · MeetTrace 正在录音',
        notificationText: paused ? '点击返回会议并继续录音' : '事实音频正在安全保存',
      ),
    );
  }

  @override
  Future<void> stop() async {
    if (!_started) {
      return;
    }
    _started = false;
    if (await FlutterForegroundTask.isRunningService) {
      await _requireSuccess(FlutterForegroundTask.stopService());
    }
  }
}

Future<void> _requireSuccess(Future<ServiceRequestResult> request) async {
  final result = await request;
  if (result case ServiceRequestFailure(:final error)) {
    throw StateError('Android 前台录音服务操作失败：$error');
  }
}

final class _RecordingKeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
