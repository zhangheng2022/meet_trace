import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<Object?> _buildReceipt(Map<String, Object?> payload) async {
  final directory = await Directory.systemTemp.createTemp(
    'meettrace-android-receipt-',
  );
  addTearDown(() => directory.delete(recursive: true));
  final payloadFile = File('${directory.path}/payload.json');
  await payloadFile.writeAsString(jsonEncode(payload));
  final executable = Platform.isWindows ? 'python' : 'python3';
  final result = await Process.run(executable, [
    '-c',
    '''
import importlib.util
import json
import sys

spec = importlib.util.spec_from_file_location("receipt", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with open(sys.argv[2], encoding="utf-8") as source:
    print(json.dumps(module.build_reused_receipt(**json.load(source))))
''',
    'tool/release/reuse_android_distribution_receipt.py',
    payloadFile.path,
  ]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return jsonDecode(result.stdout.toString());
}

Future<Map<String, Object?>> _reuseFixture(Map<String, Object?> fixture) async {
  final directory = await Directory.systemTemp.createTemp(
    'meettrace-android-reuse-',
  );
  addTearDown(() => directory.delete(recursive: true));
  final fixtureFile = File('${directory.path}/fixture.json');
  await fixtureFile.writeAsString(jsonEncode(fixture));
  final executable = Platform.isWindows ? 'python' : 'python3';
  final result = await Process.run(executable, [
    '-c',
    '''
import importlib.util
import hashlib
import json
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("receipt", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with open(sys.argv[2], encoding="utf-8") as source:
    fixture = json.load(source)
root = Path(sys.argv[3])
manifest = root / "manifest.json"
manifest.write_text(json.dumps({"artifact": {"sha256": "b" * 64}}))
manifest_digest = hashlib.sha256(manifest.read_bytes()).hexdigest()
for receipt in fixture["receipts"].values():
    if isinstance(receipt, dict):
        receipt["candidateManifestSha256"] = manifest_digest

def fake_gh(arguments):
    if arguments[0] == "api":
        return {"artifacts": fixture["artifacts"]}
    return fixture["runs"][arguments[2]]

def fake_download(repository, run_id, name, destination):
    destination.joinpath("receipt.json").write_text(
        json.dumps(fixture["receipts"][str(run_id)]), encoding="utf-8"
    )
    destination.joinpath("firebase-output.txt").write_text("passed")
    destination.joinpath("emulator-output.txt").write_text("passed")
    destination.joinpath("firebase-model-arm64.json").write_text("{}")
    destination.joinpath("firebase-model-arm32.json").write_text("{}")
    return True

module._gh_json = fake_gh
module._download_artifact = fake_download
output = root / "output"
run_id = module.reuse_prior_receipt(
    repository="owner/repo",
    release_id="v1.0.0-alpha.10",
    candidate_sha="a" * 40,
    source_run_id=200,
    manifest_path=manifest,
    output_directory=output,
)
print(json.dumps({
    "runId": run_id,
    "receipt": json.loads(output.joinpath("receipt.json").read_text()),
}))
''',
    'tool/release/reuse_android_distribution_receipt.py',
    fixtureFile.path,
    directory.path,
  ]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return (jsonDecode(result.stdout.toString()) as Map).cast<String, Object?>();
}

Map<String, Object?> _payload() => <String, Object?>{
  'run_details': <String, Object?>{
    'workflowName': 'Alpha Release',
    'event': 'workflow_dispatch',
    'headBranch': 'master',
    'jobs': <Object?>[
      <String, Object?>{
        'name': 'Validate complete signed Android candidate set',
        'conclusion': 'success',
      },
    ],
  },
  'artifact': <String, Object?>{
    'id': 4321,
    'name': 'meettrace-android-distribution-v1.0.0-alpha.10',
    'expired': false,
  },
  'prior_receipt': <String, Object?>{
    'schemaVersion': 3,
    'validation': 'androidCandidateDistribution',
    'releaseId': 'v1.0.0-alpha.10',
    'candidateCommitSha': 'a' * 40,
    'sourceRunId': 100,
    'validationRunId': 100,
    'runtimeValidation': <String, Object?>{
      'universalArm64Firebase': 'passed',
      'arm64Firebase': 'passed',
      'armeabiV7aFirebase': 'passed',
      'x86_64Emulator': 'passed',
    },
    'candidateManifestSha256': 'b' * 64,
    'reused': false,
    'validatedAtUtc': '2026-08-26T07:27:23Z',
  },
  'release_id': 'v1.0.0-alpha.10',
  'candidate_sha': 'a' * 40,
  'candidate_manifest_sha256': 'b' * 64,
  'source_run_id': 200,
  'prior_run_id': 100,
  'original_receipt_sha256': 'c' * 64,
};

void main() {
  test('把原始成功回执转为可追溯 schema 3 复用回执', () async {
    final receipt = await _buildReceipt(_payload()) as Map<String, Object?>;

    expect(receipt['schemaVersion'], 3);
    expect(receipt['sourceRunId'], 200);
    expect(receipt['validationRunId'], 100);
    expect(receipt['reused'], true);
    expect(receipt['reusedFromRunId'], 100);
    expect(receipt['reusedFromArtifactId'], 4321);
    expect(
      receipt['reusedFromArtifactName'],
      'meettrace-android-distribution-v1.0.0-alpha.10',
    );
    expect(receipt['originalReceiptSha256'], 'c' * 64);
  });

  test('接受未复用的 schema 3 原始成功回执', () async {
    final payload = _payload();
    (payload['prior_receipt']! as Map<String, Object?>)
      ..['schemaVersion'] = 3
      ..['reused'] = false;

    final receipt = await _buildReceipt(payload) as Map<String, Object?>;

    expect(receipt['reused'], true);
    expect(receipt['validationRunId'], 100);
  });

  test('拒绝复用失败 Job、摘要不匹配或未来运行的回执', () async {
    final failedJob = _payload();
    ((failedJob['run_details']! as Map<String, Object?>)['jobs']! as List)
            .cast<Map<String, Object?>>()
            .single['conclusion'] =
        'failure';
    expect(await _buildReceipt(failedJob), isNull);

    final wrongDigest = _payload();
    wrongDigest['candidate_manifest_sha256'] = 'd' * 64;
    expect(await _buildReceipt(wrongDigest), isNull);

    final futureRun = _payload();
    futureRun['prior_run_id'] = 201;
    expect(await _buildReceipt(futureRun), isNull);

    final failedRuntime = _payload();
    final receipt = failedRuntime['prior_receipt']! as Map<String, Object?>;
    (receipt['runtimeValidation']! as Map<String, Object?>)['x86_64Emulator'] =
        'failed';
    expect(await _buildReceipt(failedRuntime), isNull);
  });

  test('复用回执不能充当原始 Firebase 验证回执', () async {
    final payload = _payload();
    (payload['prior_receipt']! as Map<String, Object?>)
      ..['schemaVersion'] = 3
      ..['reused'] = true;

    expect(await _buildReceipt(payload), isNull);
  });

  test('精确 Artifact 选择会跳过较新的失败运行并复用原始成功运行', () async {
    final original = _payload();
    final failedRun = Map<String, Object?>.from(
      original['run_details']! as Map<String, Object?>,
    );
    failedRun['jobs'] = <Object?>[
      <String, Object?>{
        'name': 'Validate complete signed Android candidate set',
        'conclusion': 'cancelled',
      },
    ];
    final artifactName = 'meettrace-android-distribution-v1.0.0-alpha.10';
    final result = await _reuseFixture(<String, Object?>{
      'artifacts': <Object?>[
        <String, Object?>{
          'id': 5000,
          'name': artifactName,
          'expired': false,
          'workflow_run': <String, Object?>{'id': 150},
        },
        <String, Object?>{
          'id': 4321,
          'name': artifactName,
          'expired': false,
          'workflow_run': <String, Object?>{'id': 100},
        },
      ],
      'runs': <String, Object?>{
        '150': failedRun,
        '100': original['run_details'],
      },
      'receipts': <String, Object?>{
        '150': original['prior_receipt'],
        '100': original['prior_receipt'],
      },
    });

    expect(result['runId'], 100);
    expect(
      (result['receipt']! as Map<String, Object?>)['reusedFromArtifactId'],
      4321,
    );
  });

  test('精确 Artifact 选择会跳过非对象 JSON 回执', () async {
    final original = _payload();
    final artifactName = 'meettrace-android-distribution-v1.0.0-alpha.10';
    final result = await _reuseFixture(<String, Object?>{
      'artifacts': <Object?>[
        <String, Object?>{
          'id': 5000,
          'name': artifactName,
          'expired': false,
          'workflow_run': <String, Object?>{'id': 150},
        },
        <String, Object?>{
          'id': 4321,
          'name': artifactName,
          'expired': false,
          'workflow_run': <String, Object?>{'id': 100},
        },
      ],
      'runs': <String, Object?>{
        '150': original['run_details'],
        '100': original['run_details'],
      },
      'receipts': <String, Object?>{
        '150': <Object?>[],
        '100': original['prior_receipt'],
      },
    });

    expect(result['runId'], 100);
  });
}
