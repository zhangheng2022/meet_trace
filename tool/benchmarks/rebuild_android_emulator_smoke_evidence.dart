import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const _recordingMarker = 'MEETTRACE_STEP07_RECORDING:';
const _meetingFlowMarker = 'MEETTRACE_ANDROID_EMULATOR_FLOW:';
const _asrLifecycleMarker = 'MEETTRACE_ANDROID_NATIVE_CYCLES:';
const _vadLifecycleMarker = 'MEETTRACE_ANDROID_NATIVE_VAD:';
const _recordingLifecycleMarker = 'MEETTRACE_ANDROID_RECORDING_CYCLES:';

Future<void> main(List<String> arguments) async {
  final inputPath = _valueOf(arguments, '--input');
  final repositoryRoot = _valueOf(arguments, '--repository-root');
  final outputPath = _valueOf(arguments, '--output');
  final apiLevel = int.tryParse(_valueOf(arguments, '--api-level') ?? '');
  final abi = _valueOf(arguments, '--abi');
  if (inputPath == null ||
      repositoryRoot == null ||
      outputPath == null ||
      apiLevel == null ||
      abi == null) {
    stderr.writeln(
      '用法：dart run tool/benchmarks/rebuild_android_emulator_smoke_evidence.dart '
      '--input <中断报告.json> --repository-root <仓库根目录> '
      '--api-level <API> --abi <ABI> --output <证据.json>',
    );
    exitCode = 64;
    return;
  }

  try {
    final input = await _readObject(File(inputPath));
    final evidence = await rebuildAndroidEmulatorSmokeEvidence(
      interruptedReport: input,
      repositoryRoot: Directory(repositoryRoot),
      apiLevel: apiLevel,
      abi: abi,
    );
    final output = File(outputPath);
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(evidence)}\n',
      flush: true,
    );
    stdout.writeln('已从完整通过日志重建 Android 模拟器证据：${output.absolute.path}');
  } on FormatException catch (error) {
    stderr.writeln('无法重建 Android 模拟器证据：${error.message}');
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln('无法读取 Android 模拟器日志：${error.message}');
    exitCode = 66;
  }
}

Future<Map<String, Object?>> rebuildAndroidEmulatorSmokeEvidence({
  required Map<String, Object?> interruptedReport,
  required Directory repositoryRoot,
  required int apiLevel,
  required String abi,
}) async {
  if (apiLevel < 24 || abi != 'x86_64') {
    throw const FormatException('只允许重建 API 24+ x86_64 模拟器证据');
  }
  if (interruptedReport['status'] != 'failed' ||
      interruptedReport['error'] is! String ||
      (interruptedReport['error']! as String).trim().isEmpty) {
    throw const FormatException('只允许从后处理失败的中断报告重建证据');
  }
  final capturedAtUtc = interruptedReport['capturedAtUtc'];
  if (capturedAtUtc is! String ||
      capturedAtUtc.trim().isEmpty ||
      DateTime.tryParse(capturedAtUtc)?.isUtc != true) {
    throw const FormatException('中断报告必须包含有效的 UTC 捕获时间');
  }
  final rawResults = interruptedReport['results'];
  if (rawResults is! List<Object?>) {
    throw const FormatException('中断报告缺少 results');
  }
  final expectedNames = {
    'build-android-x64-debug',
    'whisper-base-native',
    'reliable-recording',
    'android-emulator-meeting-flow',
  };
  const expectedCommandFragments = {
    'build-android-x64-debug':
        'flutter build apk --debug --target-platform android-x64',
    'whisper-base-native':
        'integration_test/whisper_base_standard_asr_engine_test.dart',
    'reliable-recording': 'integration_test/reliable_recording_test.dart',
    'android-emulator-meeting-flow':
        'integration_test/android_emulator_meeting_flow_test.dart',
  };
  final results = <Map<String, Object?>>[];
  final logs = <String, String>{};
  for (final raw in rawResults) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('results 必须全部为 JSON 对象');
    }
    final name = raw['name'];
    final exitCode = raw['exitCode'];
    final logRef = raw['log'];
    final command = raw['command'];
    if (name is! String ||
        !expectedNames.remove(name) ||
        exitCode != 0 ||
        logRef is! String ||
        command is! String ||
        !command.contains(expectedCommandFragments[name]!)) {
      throw FormatException('步骤未完整通过或重复：$name');
    }
    final logFile = await _resolveRepositoryFile(repositoryRoot, logRef);
    final log = await logFile.readAsString();
    final isBuild = name == 'build-android-x64-debug';
    if (isBuild) {
      if (!log.contains(
            'Built build\\app\\outputs\\flutter-apk\\app-debug.apk',
          ) &&
          !log.contains('Built build/app/outputs/flutter-apk/app-debug.apk')) {
        throw const FormatException('Android x64 Debug APK 构建日志不完整');
      }
    } else if (!log.contains('All tests passed!')) {
      throw FormatException('$name 日志没有完整通过标记');
    }
    final digest = await sha256.bind(logFile.openRead()).first;
    results.add({...raw, 'logSha256': digest.toString()});
    logs[name] = log;
  }
  if (expectedNames.isNotEmpty) {
    throw FormatException('缺少步骤：${expectedNames.join(', ')}');
  }

  final recording = _readMarker(logs['reliable-recording']!, _recordingMarker);
  final flowLog = logs['android-emulator-meeting-flow']!;
  final meetingFlow = _readMarker(flowLog, _meetingFlowMarker);
  final asrLifecycle = _readMarker(flowLog, _asrLifecycleMarker);
  final vadLifecycle = _readMarker(flowLog, _vadLifecycleMarker);
  final recordingLifecycle = _readMarker(flowLog, _recordingLifecycleMarker);
  for (final marker in [
    recording,
    meetingFlow,
    asrLifecycle,
    vadLifecycle,
    recordingLifecycle,
  ]) {
    if (marker['schemaVersion'] != 1) {
      throw const FormatException('证据 marker schemaVersion 必须为 1');
    }
  }
  final recordingSeconds = _integer(recording, 'recordingSeconds');
  final nativeCycles = _integer(asrLifecycle, 'cycles');
  if (_integer(recordingLifecycle, 'cycles') != nativeCycles) {
    throw const FormatException('ASR 与录音生命周期次数不一致');
  }

  return {
    'schemaVersion': 1,
    'status': 'passed',
    'capturedAtUtc': capturedAtUtc,
    'platform': 'android-emulator',
    'abi': abi,
    'apiLevel': apiLevel,
    'recordingSeconds': recordingSeconds,
    'nativeLifecycleCycles': nativeCycles,
    'vadLifecycleCycles': _integer(vadLifecycle, 'cycles'),
    'results': results,
    'measurements': {
      'recording': recording,
      'meetingFlow': meetingFlow,
      'asrLifecycle': asrLifecycle,
      'vadLifecycle': vadLifecycle,
      'recordingLifecycle': recordingLifecycle,
    },
    'evidenceAssembly': {
      'source': 'completed-sanitized-logs',
      'assembledAtUtc': DateTime.now().toUtc().toIso8601String(),
      'allStepExitCodesPassed': true,
      'allLogSha256Captured': true,
    },
  };
}

Future<File> _resolveRepositoryFile(
  Directory repositoryRoot,
  String reference,
) async {
  if (p.isAbsolute(reference)) {
    throw const FormatException('日志引用必须为仓库相对路径');
  }
  final lexicalRoot = p.normalize(p.absolute(repositoryRoot.path));
  final lexicalResolved = p.normalize(
    p.absolute(p.join(lexicalRoot, reference)),
  );
  if (!p.isWithin(lexicalRoot, lexicalResolved)) {
    throw const FormatException('日志引用越过仓库根目录');
  }
  final canonicalRoot = p.normalize(
    await repositoryRoot.resolveSymbolicLinks(),
  );
  final file = File(lexicalResolved);
  final canonicalResolved = p.normalize(await file.resolveSymbolicLinks());
  if (!p.isWithin(canonicalRoot, canonicalResolved)) {
    throw const FormatException('日志引用符号链接越过仓库根目录');
  }
  return file;
}

Map<String, Object?> _readMarker(String log, String marker) {
  final lines = const LineSplitter().convert(log);
  final matches = lines.where((line) => line.startsWith(marker));
  if (matches.isEmpty) {
    throw FormatException('缺少证据 marker：$marker');
  }
  final value = jsonDecode(matches.last.substring(marker.length));
  if (value is! Map<String, Object?>) {
    throw FormatException('证据 marker 不是 JSON 对象：$marker');
  }
  return value;
}

int _integer(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) {
    throw FormatException('$key 必须为整数');
  }
  return value;
}

Future<Map<String, Object?>> _readObject(File file) async {
  final value = jsonDecode(await file.readAsString());
  if (value is! Map<String, Object?>) {
    throw FormatException('${file.path} 根节点必须为 JSON 对象');
  }
  return value;
}

String? _valueOf(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) {
    return null;
  }
  return arguments[index + 1];
}
