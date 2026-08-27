import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

({int major, int minor, int patch}) _versionFrom(
  String source,
  RegExp pattern,
) {
  final match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: '未找到受控工具链版本');
  return (
    major: int.parse(match!.group(1)!),
    minor: int.parse(match.group(2)!),
    patch: int.parse(match.group(3)!),
  );
}

void _expectPatchLine(
  ({int major, int minor, int patch}) actual, {
  required int major,
  required int minor,
  required int minimumPatch,
}) {
  expect(actual.major, major);
  expect(actual.minor, minor);
  expect(actual.patch, greaterThanOrEqualTo(minimumPatch));
}

void main() {
  group('依赖与工具链版本守卫', () {
    test('Flutter、Dart、Android 与 iOS 使用已验证的统一版本', () async {
      final fvmConfig = jsonDecode(
        await File('.fvmrc').readAsString(),
      ) as Map<String, Object?>;
      final pubspec = await File('pubspec.yaml').readAsString();
      final androidSettings = await File('android/settings.gradle.kts')
          .readAsString();
      final gradleWrapper = await File(
        'android/gradle/wrapper/gradle-wrapper.properties',
      ).readAsString();
      final iosProject = await File('ios/Runner.xcodeproj/project.pbxproj')
          .readAsString();
      final iosInspector = await File('tool/benchmarks/inspect_ios_app.sh')
          .readAsString();

      expect(fvmConfig['flutter'], '3.47.1');
      expect(pubspec, contains('sdk: ^3.13.0'));
      expect(pubspec, contains('forui: ^0.26.0'));
      expect(pubspec, contains('forui_cli: ^0.26.0'));
      expect(pubspec, contains('material_ui: ^1.1.0'));
      _expectPatchLine(
        _versionFrom(
          androidSettings,
          RegExp(
            r'id\("com\.android\.application"\) version "(\d+)\.(\d+)\.(\d+)"',
          ),
        ),
        major: 9,
        minor: 1,
        minimumPatch: 0,
      );
      _expectPatchLine(
        _versionFrom(
          androidSettings,
          RegExp(
            r'id\("org\.jetbrains\.kotlin\.android"\) version "(\d+)\.(\d+)\.(\d+)"',
          ),
        ),
        major: 2,
        minor: 4,
        minimumPatch: 10,
      );
      _expectPatchLine(
        _versionFrom(
          gradleWrapper,
          RegExp(r'gradle-(\d+)\.(\d+)\.(\d+)-all\.zip'),
        ),
        major: 9,
        minor: 3,
        minimumPatch: 1,
      );
      expect(
        RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;').allMatches(iosProject),
        hasLength(3),
      );
      expect(iosProject, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;')));
      expect(
        iosInspector,
        contains('normalized_minimum_version[:2] == (15, 0)'),
      );
    });

    test('Patrol 包、CLI 与工具子项目保持兼容版本', () async {
      final pubspec = await File('pubspec.yaml').readAsString();
      final toolLock = await File('tool/patrol_mcp/pubspec.lock')
          .readAsString();
      final workflowFiles = await Directory('.github/workflows')
          .list()
          .where((entry) => entry is File && entry.path.endsWith('.yml'))
          .cast<File>()
          .toList();
      final workflows = (await Future.wait(
        workflowFiles.map((file) => file.readAsString()),
      )).join('\n');

      expect(pubspec, contains('patrol: 4.9.0'));
      expect(
        toolLock,
        matches(RegExp(r'patrol_cli:\s+.*?version: "4\.7\.0"', dotAll: true)),
      );
      expect(
        RegExp(r'dart pub global activate patrol_cli ([^\s]+)')
            .allMatches(workflows)
            .map((match) => match.group(1))
            .toSet(),
        {'4.7.0'},
      );
    });

    test('自动更新覆盖仓库内全部依赖生态', () async {
      final dependabot = await File('.github/dependabot.yml').readAsString();

      for (final ecosystem in ['pub', 'github-actions', 'bundler', 'gradle']) {
        expect(dependabot, contains('package-ecosystem: $ecosystem'));
      }
      expect(dependabot, contains('directory: "/tool/patrol_mcp"'));
      expect(dependabot, contains('dependency-name: com.android.application'));
      expect(dependabot, contains('dependency-name: gradle-wrapper'));
      expect(
        dependabot,
        contains('dependency-name: org.jetbrains.kotlin.android'),
      );
      expect(
        RegExp(r'version-update:semver-patch').allMatches(dependabot),
        hasLength(3),
      );
      expect(dependabot, isNot(contains('version-update:semver-minor')));
      expect(dependabot, isNot(contains('version-update:semver-major')));
    });
  });
}
