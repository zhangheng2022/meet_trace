import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model.dart';

void main() {
  group('AsrModelDescriptor', () {
    test('防御性复制语言与能力集合', () {
      final languages = ['zh', 'en'];
      final capabilities = {'offline'};
      final descriptor = AsrModelDescriptor(
        modelId: 'paraformer',
        displayName: '测试模型',
        version: '1',
        supportedLanguages: languages,
        installationType: AsrInstallationType.bundled,
        requiredBytes: 80,
        capabilities: capabilities,
      );

      languages.add('ja');
      capabilities.add('timestamps');

      expect(descriptor.supportedLanguages, ['zh', 'en']);
      expect(descriptor.capabilities, {'offline'});
      expect(
        () => descriptor.supportedLanguages.add('ja'),
        throwsUnsupportedError,
      );
      expect(
        () => descriptor.capabilities.add('timestamps'),
        throwsUnsupportedError,
      );
    });

    test('拒绝空模型 ID 和非正资源大小', () {
      expect(
        () => AsrModelDescriptor(
          modelId: '',
          displayName: '模型',
          version: '1',
          supportedLanguages: const ['zh'],
          installationType: AsrInstallationType.bundled,
          requiredBytes: 0,
          capabilities: const {'offline'},
        ),
        throwsArgumentError,
      );
    });
  });
}
