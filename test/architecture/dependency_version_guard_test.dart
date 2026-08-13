import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

      expect(fvmConfig['flutter'], '3.47.0');
      expect(pubspec, contains('sdk: ^3.13.0'));
      expect(
        androidSettings,
        contains('id("com.android.application") version "9.1.0"'),
      );
      expect(
        androidSettings,
        contains('id("org.jetbrains.kotlin.android") version "2.4.10"'),
      );
      expect(gradleWrapper, contains('gradle-9.3.1-all.zip'));
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
    });
  });
}
