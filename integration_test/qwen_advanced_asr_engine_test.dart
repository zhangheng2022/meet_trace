import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meetily_ai/data/repositories/sqflite_model_installation_repository.dart';
import 'package:meetily_ai/data/repositories/sqflite_model_usage_lease_repository.dart';
import 'package:meetily_ai/data/services/asr/asr_engine.dart';
import 'package:meetily_ai/data/services/asr/qwen_advanced_asr_engine.dart';
import 'package:meetily_ai/data/services/storage/app_database.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/domain/models/model_installation.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

const _modelRoot = String.fromEnvironment('MEETILY_QWEN_MODEL_ROOT');
const _prepareDelaySeconds = int.fromEnvironment(
  'MEETILY_QWEN_PREPARE_DELAY_SECONDS',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '真实 Qwen active version 完成初始化、窗口识别和资源释放',
    (_) async {
      if (_prepareDelaySeconds > 0) {
        await Future<void>.delayed(Duration(seconds: _prepareDelaySeconds));
      }
      final temporary = await getTemporaryDirectory();
      final root = Directory(
        p.join(
          temporary.path,
          'meetily-step10-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      final database = AppDatabase(
        databaseFactory: databaseFactory,
        path: p.join(root.path, 'meetily.db'),
      );
      final installations = SqfliteModelInstallationRepository(database);
      final leases = SqfliteModelUsageLeaseRepository(database);
      final descriptor = AsrModelRegistry.alpha.requireById(
        qwenAdvancedModelId,
      );

      try {
        await installations.saveInstalledAndActivate(
          ModelInstallation(
            modelId: descriptor.modelId,
            version: descriptor.version,
            installationType: descriptor.installationType,
            state: ModelInstallationState.installed,
            installedPath: _modelRoot,
            verifiedAt: DateTime.now(),
            bytes: descriptor.requiredBytes,
          ),
        );
        final engine = await QwenAdvancedAsrEngine.create(
          installations: installations,
          leases: leases,
          riskMonitor: const _SupportedRiskMonitor(),
          ownerId: 'device-meeting',
        );

        try {
          await engine.initialize();
          await engine.acceptAudio(
            Float32List(16000),
            sampleRate: qwenSampleRate,
            startMs: 0,
          );

          expect(engine.descriptor.modelId, qwenAdvancedModelId);
          expect(engine.metrics.totalWindowCount, 1);
          expect(engine.metrics.failedWindowCount, 0);
          expect(
            engine.metrics.totalInferenceDuration,
            greaterThan(Duration.zero),
          );
        } finally {
          await engine.dispose();
        }
        expect(
          await leases.listActive(
            modelId: descriptor.modelId,
            version: descriptor.version,
            now: DateTime.now(),
          ),
          isEmpty,
        );
      } finally {
        await installations.dispose();
        await database.close();
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      }
    },
    skip: _modelRoot.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

final class _SupportedRiskMonitor implements AsrDeviceRiskMonitor {
  const _SupportedRiskMonitor();

  @override
  Stream<AsrDeviceRiskState> get changes => const Stream.empty();

  @override
  Future<AsrDeviceRiskState> inspect() async {
    return const AsrDeviceRiskState.supported();
  }
}
