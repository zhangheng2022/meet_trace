import 'dart:io';

Future<void> main() async {
  final projectRoot = Directory.current.absolute.path;
  final separator = Platform.pathSeparator;
  final serverRoot = '$projectRoot${separator}tool${separator}patrol_mcp';
  final environment = Map<String, String>.of(Platform.environment)
    ..['PROJECT_ROOT'] = projectRoot
    ..putIfAbsent('PATROL_FLAGS', () => '')
    ..putIfAbsent('SHOW_TERMINAL', () => 'false');

  final process = await Process.start(
    Platform.resolvedExecutable,
    const ['run', 'patrol_mcp'],
    workingDirectory: serverRoot,
    environment: environment,
  );

  await Future.wait<void>([
    stdin.pipe(process.stdin),
    process.stdout.pipe(stdout),
    process.stderr.pipe(stderr),
  ]);
  exitCode = await process.exitCode;
}
