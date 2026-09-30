import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/domain/models/app_language.dart';
import 'package:meettrace/domain/models/transcription_profile.dart';
import 'package:meettrace/domain/ports/transcription_profiles.dart';
import 'package:meettrace/l10n/l10n.dart';
import 'package:meettrace/ui/core/app_text_field.dart';
import 'package:meettrace/ui/features/settings/view_models/transcription_sources_view_model.dart';
import 'package:meettrace/ui/features/settings/views/transcription_sources_view.dart';

const _capture = bool.fromEnvironment('MEETTRACE_CAPTURE_SCREENSHOTS');
final _captureKey = GlobalKey();

void main() {
  setUpAll(() async {
    if (_capture) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/forui_lucide/ForuiLucideIcons')..addFont(
            rootBundle.load('packages/forui_lucide/assets/lucide.ttf'),
          ))
          .load();
      await (FontLoader('packages/forui/Inter')..addFont(
            rootBundle.load('packages/forui/assets/fonts/inter/Inter.ttf'),
          ))
          .load();
      final font = File('C:/Windows/Fonts/msyh.ttc');
      if (await font.exists()) {
        final bytes = ByteData.sublistView(await font.readAsBytes());
        for (final family in ['Microsoft YaHei UI', 'Microsoft YaHei']) {
          await (FontLoader(family)..addFont(Future.value(bytes))).load();
        }
      }
    }
  });

  for (final language in [
    AppLanguageMode.simplifiedChinese,
    AppLanguageMode.english,
  ]) {
    testWidgets('来源选择在 360 像素 ${language.name} 页面须明确点选', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profiles = _Profiles();
      final credentials = _Credentials();
      final vm = TranscriptionSourcesViewModel(
        profiles: profiles,
        credentials: credentials,
      );
      addTearDown(vm.dispose);
      final locale = ValueNotifier(language);
      addTearDown(locale.dispose);
      TranscriptionProfile? selected;
      late BuildContext routeContext;
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: Application(
            languageMode: locale,
            home: Builder(
              builder: (context) {
                routeContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final route = Navigator.of(routeContext).push<TranscriptionProfile>(
        PageRouteBuilder(
          pageBuilder: (_, _, _) =>
              TranscriptionSourcesView(viewModel: vm, selecting: true),
        ),
      );
      route.then((value) => selected = value);
      await tester.pumpAndSettle();
      final l10n = tester.element(find.byType(TranscriptionSourcesView)).l10n;
      expect(
        find.text('Team transcription · ${l10n.sourceDefault}'),
        findsOneWidget,
      );
      expect(selected, isNull);
      expect(credentials.reads, 0);
      expect(find.text(l10n.sourceLockedNotice), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _screenshot(tester, 'sources-${language.name}-360.png');

      final selectedId = language == AppLanguageMode.english
          ? TranscriptionProfile.localProfileId
          : 'team';
      await tester.tap(find.byKey(ValueKey('select-source-$selectedId')));
      await tester.pumpAndSettle();
      expect(selected, same(profiles.values[selectedId]));
      expect(profiles.defaultId, 'team');
      expect(find.byType(TranscriptionSourcesView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [360.0, 1100.0]) {
    testWidgets('英文来源管理在 ${width.toInt()} 像素宽度无溢出', (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = TranscriptionSourcesViewModel(
        profiles: _Profiles(),
        credentials: _Credentials(),
        probe: (_) async {},
      );
      final locale = ValueNotifier(AppLanguageMode.english);
      addTearDown(vm.dispose);
      addTearDown(locale.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: Application(
            languageMode: locale,
            home: TranscriptionSourcesView(viewModel: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = tester.element(find.byType(TranscriptionSourcesView)).l10n;
      expect(find.text(l10n.edit), findsOneWidget);
      expect(find.text(l10n.sourceProbeAction), findsOneWidget);
      expect(find.text(l10n.sourceSetDefault), findsNWidgets(2));
      expect(
        find.text('Team transcription · ${l10n.sourceDefault}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      if (width >= 1024) {
        await _screenshot(tester, 'sources-management-1100.png');
      }
    });
  }

  testWidgets('编辑来源不回显密钥，API key 和自定义认证头均遮蔽', (tester) async {
    tester.view.physicalSize = const Size(720, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profiles = _Profiles();
    final credentials = _Credentials();
    final vm = TranscriptionSourcesViewModel(
      profiles: profiles,
      credentials: credentials,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: Application(home: TranscriptionSourcesView(viewModel: vm)),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(TranscriptionSourcesView)).l10n;
    await tester.tap(find.text(l10n.edit));
    await tester.pumpAndSettle();
    final keyField = _editable(tester, l10n.sourceApiKey);
    expect(keyField.controller.text, isEmpty);
    expect(keyField.obscureText, isTrue);
    expect(credentials.reads, 0);
    expect(find.text('${l10n.sourceCredentialsHelp} {}'), findsOneWidget);
    await tester.enterText(
      _field(l10n.sourceEndpoint),
      'https://new-speech.example.test/transcribe',
    );
    final save = find.byKey(const ValueKey('save-transcription-source'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text(l10n.sourceCredentialsRequired), findsOneWidget);
    expect(profiles.values['team']!.revision, 1);
    expect(credentials.values, hasLength(1));
    await tester.ensureVisible(_field(l10n.sourceApiKey));
    await tester.enterText(_field(l10n.sourceApiKey), 'demo-key-hidden');
    await tester.tap(find.text(l10n.sourceAdvanced));
    await tester.pumpAndSettle();
    final headers = _editable(tester, l10n.sourceHeaders);
    expect(headers.controller.text, isEmpty);
    expect(headers.obscureText, isTrue);
    await tester.enterText(
      _field(l10n.sourceHeaders),
      '{"x-api-key":"demo-header-hidden"}',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'source-editor-masked-720.png');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.byType(TranscriptionSourcesView), findsOneWidget);
    final changed = profiles.values['team']!;
    expect(changed.revision, 2);
    expect(changed.endpoint!.host, 'new-speech.example.test');
    expect(changed.credentialRef, isNot('credential-old'));
    expect(credentials.values[changed.credentialRef], {
      'x-api-key': 'demo-header-hidden',
      'Authorization': 'Bearer demo-key-hidden',
    });
    expect(changed.toJson().toString(), isNot(contains('demo-key-hidden')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('列表失败不带入新编辑器，取消失败的保存不污染列表', (tester) async {
    final profiles = _Profiles()..failSetDefault = true;
    final vm = TranscriptionSourcesViewModel(
      profiles: profiles,
      credentials: _Credentials(),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      Application(home: TranscriptionSourcesView(viewModel: vm)),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(TranscriptionSourcesView)).l10n;
    await tester.tap(find.text(l10n.sourceSetDefault).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.sourceFailure), findsOneWidget);
    await tester.scrollUntilVisible(find.text(l10n.addOnlineSource), 300);
    await tester.tap(find.text(l10n.addOnlineSource));
    await tester.pumpAndSettle();
    expect(find.text(l10n.sourceFailure), findsNothing);
    await tester.enterText(_field(l10n.sourceName), 'New source');
    await tester.enterText(
      _field(l10n.sourceEndpoint),
      'https://new.example/asr',
    );
    await tester.enterText(_field(l10n.sourceModel), 'meeting-model');
    await tester.pumpAndSettle();
    profiles.failSave = true;
    final save = find.byKey(const ValueKey('save-transcription-source'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text(l10n.sourceFailure), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text(l10n.sourceFailure), findsNothing);
    expect(vm.failed, isFalse);
    expect(profiles.values, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('超时须为 1 到 3600 整数，纠正输入后清除字段错误并可保存', (tester) async {
    final profiles = _Profiles();
    final vm = TranscriptionSourcesViewModel(
      profiles: profiles,
      credentials: _Credentials(),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      Application(home: TranscriptionSourcesView(viewModel: vm)),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(TranscriptionSourcesView)).l10n;
    await tester.tap(find.text(l10n.edit));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(l10n.sourceAdvanced));
    await tester.tap(find.text(l10n.sourceAdvanced));
    await tester.pumpAndSettle();
    final timeout = _field(l10n.sourceTimeout);
    final save = find.byKey(const ValueKey('save-transcription-source'));
    for (final invalid in ['0', '-1', '3601', '1.5', 'invalid']) {
      await tester.ensureVisible(timeout);
      await tester.pumpAndSettle();
      await tester.tap(timeout);
      await tester.enterText(timeout, invalid);
      await tester.pumpAndSettle();
      expect(tester.widget<AppTextField>(timeout).controller.text, invalid);
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppTextField>(timeout).errorText,
        l10n.sourceTimeoutInvalid,
      );
      expect(profiles.values['team']!.revision, 1);
      expect(vm.failed, isFalse);
    }
    await tester.ensureVisible(timeout);
    await tester.pumpAndSettle();
    await tester.tap(timeout);
    await tester.enterText(timeout, '3600');
    await tester.pumpAndSettle();
    expect(tester.widget<AppTextField>(timeout).controller.text, '3600');
    expect(tester.widget<AppTextField>(timeout).errorText, isNull);
    final limit = _field(l10n.sourceUploadLimit);
    for (final invalid in ['invalid', '1e308', '0.0001']) {
      await tester.ensureVisible(limit);
      await tester.pumpAndSettle();
      await tester.tap(limit);
      await tester.enterText(limit, invalid);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text(l10n.sourceFailure), findsOneWidget);
      expect(profiles.values['team']!.revision, 1);
      expect(vm.failed, isFalse);
      expect(tester.takeException(), isNull);
    }
    await tester.ensureVisible(limit);
    await tester.pumpAndSettle();
    await tester.tap(limit);
    await tester.enterText(limit, '24');
    await tester.pumpAndSettle();
    expect(find.text(l10n.sourceFailure), findsNothing);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(profiles.values['team']!.revision, 2);
    expect(profiles.values['team']!.requestTimeoutSeconds, 3600);
    expect(profiles.values['team']!.maxUploadBytes, 24 * 1024 * 1024);
    expect(
      find.byKey(const ValueKey('save-transcription-source')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is AppTextField && widget.label == label,
);

EditableText _editable(WidgetTester tester, String label) =>
    tester.widget<EditableText>(
      find.descendant(of: _field(label), matching: find.byType(EditableText)),
    );

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.pumpAndSettle();
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = await Directory('build/screenshots')
        .create(recursive: true);
    await File('${directory.path}/$name')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

final class _Profiles implements TranscriptionProfileRepository {
  final values = <String, TranscriptionProfile>{
    TranscriptionProfile.localProfileId: TranscriptionProfile.local(),
    'team': TranscriptionProfile(
      id: 'team',
      name: 'Team transcription',
      revision: 1,
      protocol: TranscriptionProtocol.audioTranscriptions,
      endpoint: Uri.parse(
        'https://speech.example.test/v1/audio/transcriptions',
      ),
      modelId: 'meeting-model',
      credentialRef: 'credential-old',
    ),
  };
  String defaultId = 'team';
  bool failSetDefault = false;
  bool failSave = false;
  @override
  Future<List<TranscriptionProfile>> list() async => values.values.toList();
  @override
  Future<TranscriptionProfile?> getById(String id) async => values[id];
  @override
  Future<void> save(TranscriptionProfile profile) async {
    if (failSave) throw StateError('save failed');
    values[profile.id] = profile;
  }

  @override
  Future<void> delete(String id) async {
    values.remove(id);
  }

  @override
  Future<String> getDefaultProfileId() async => defaultId;
  @override
  Future<void> setDefaultProfileId(String id) async {
    if (failSetDefault) throw StateError('default failed');
    defaultId = id;
  }
}

final class _Credentials implements TranscriptionCredentialStore {
  final values = <String, Map<String, String>>{
    'credential-old': {'Authorization': 'Bearer previously-saved-secret'},
  };
  int reads = 0;
  @override
  Future<Map<String, String>?> read(String reference) async {
    reads++;
    return values[reference];
  }

  @override
  Future<void> write(String reference, Map<String, String> headers) async {
    values[reference] = Map.of(headers);
  }

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }
}
