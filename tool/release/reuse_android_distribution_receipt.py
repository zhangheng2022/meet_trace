"""Reuse the original successful Android artifact-set validation receipt."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any
from urllib.parse import urlencode


ANDROID_JOB_NAME = "Validate complete signed Android candidate set"
GH_ATTEMPTS = 3
FIREBASE_REQUIRED_STEPS = {
    "Download immutable Draft APK set and manifest",
    "Verify Firebase targets are physical devices with required ABIs",
    "Install and launch ARM APKs on Firebase real devices",
}


def _positive_int(value: object) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) and value > 0 else None


def build_reused_receipt(
    *,
    run_details: dict[str, Any],
    artifact: dict[str, Any],
    prior_receipt: dict[str, Any],
    release_id: str,
    candidate_sha: str,
    candidate_manifest_sha256: str,
    source_run_id: int,
    prior_run_id: int,
    original_receipt_sha256: str,
) -> dict[str, Any] | None:
    """Return a schema-3 receipt only when every immutable identity matches."""
    if not (0 < prior_run_id < source_run_id):
        return None
    jobs = run_details.get("jobs")
    if not (
        run_details.get("workflowName") == "Alpha Release"
        and run_details.get("event") == "workflow_dispatch"
        and run_details.get("headBranch") == "master"
        and isinstance(jobs, list)
        and sum(
            1
            for job in jobs
            if isinstance(job, dict)
            and job.get("name") == ANDROID_JOB_NAME
            and job.get("conclusion") == "success"
        )
        == 1
    ):
        return None

    expected_artifact_name = f"meettrace-android-distribution-{release_id}"
    artifact_id = _positive_int(artifact.get("id"))
    if (
        artifact_id is None
        or artifact.get("name") != expected_artifact_name
        or artifact.get("expired") is not False
    ):
        return None

    runtime_validation = prior_receipt.get("runtimeValidation")
    if not (
        prior_receipt.get("schemaVersion") == 3
        and prior_receipt.get("reused") is False
        and prior_receipt.get("validation") == "androidCandidateDistribution"
        and prior_receipt.get("releaseId") == release_id
        and prior_receipt.get("candidateCommitSha") == candidate_sha
        and prior_receipt.get("sourceRunId") == prior_run_id
        and prior_receipt.get("validationRunId") == prior_run_id
        and runtime_validation == {
            "universalArm64Firebase": "passed",
            "arm64Firebase": "passed",
            "armeabiV7aFirebase": "passed",
            "x86_64Emulator": "passed",
        }
        and prior_receipt.get("candidateManifestSha256") == candidate_manifest_sha256
        and isinstance(prior_receipt.get("validatedAtUtc"), str)
        and prior_receipt["validatedAtUtc"].strip()
        and len(original_receipt_sha256) == 64
        and all(char in "0123456789abcdef" for char in original_receipt_sha256)
    ):
        return None

    return {
        "schemaVersion": 3,
        "validation": "androidCandidateDistribution",
        "releaseId": release_id,
        "candidateCommitSha": candidate_sha,
        "sourceRunId": source_run_id,
        "validationRunId": prior_run_id,
        "runtimeValidation": runtime_validation,
        "candidateManifestSha256": candidate_manifest_sha256,
        "validatedAtUtc": prior_receipt["validatedAtUtc"],
        "reused": True,
        "reusedFromRunId": prior_run_id,
        "reusedFromArtifactId": artifact_id,
        "reusedFromArtifactName": expected_artifact_name,
        "originalReceiptSha256": original_receipt_sha256,
    }


def _run_gh(arguments: list[str]) -> subprocess.CompletedProcess[str]:
    for attempt in range(GH_ATTEMPTS):
        result = subprocess.run(
            ["gh", *arguments],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode == 0:
            return result
        if attempt + 1 < GH_ATTEMPTS:
            time.sleep(2**attempt)
    return result


def _gh_json(arguments: list[str]) -> Any:
    result = _run_gh(arguments)
    result.check_returncode()
    return json.loads(result.stdout)


def _download_artifact(
    repository: str,
    run_id: int,
    name: str,
    destination: Path,
) -> bool:
    result = _run_gh(
        [
            "run",
            "download",
            str(run_id),
            "--repo",
            repository,
            "--name",
            name,
            "--dir",
            str(destination),
        ],
    )
    return result.returncode == 0


def _single_file(directory: Path, name: str) -> Path | None:
    matches = [path for path in directory.rglob(name) if path.is_file()]
    return matches[0] if len(matches) == 1 else None


def has_reusable_firebase_steps(run_details: dict[str, Any]) -> bool:
    """Accept only a failed run whose complete ARM validation already passed."""
    jobs = run_details.get("jobs")
    android_jobs = (
        [
            job
            for job in jobs
            if isinstance(job, dict) and job.get("name") == ANDROID_JOB_NAME
        ]
        if isinstance(jobs, list)
        else []
    )
    if not (
        run_details.get("workflowName") == "Alpha Release"
        and run_details.get("event") == "workflow_dispatch"
        and run_details.get("headBranch") == "master"
        and len(android_jobs) == 1
        and android_jobs[0].get("conclusion")
        in {"failure", "cancelled", "timed_out"}
    ):
        return False
    steps = android_jobs[0].get("steps")
    succeeded = (
        {
            step.get("name")
            for step in steps
            if isinstance(step, dict) and step.get("conclusion") == "success"
        }
        if isinstance(steps, list)
        else set()
    )
    return FIREBASE_REQUIRED_STEPS <= succeeded


def firebase_evidence_is_complete(
    *,
    directory: Path,
    release_id: str,
    arm64_model: str,
    arm64_version: str,
    arm32_model: str,
    arm32_version: str,
) -> bool:
    firebase_output = _single_file(directory, "firebase-output.txt")
    arm64_path = _single_file(directory, "firebase-model-arm64.json")
    arm32_path = _single_file(directory, "firebase-model-arm32.json")
    if None in (firebase_output, arm64_path, arm32_path):
        return False
    assert firebase_output is not None and arm64_path is not None and arm32_path is not None
    try:
        output = firebase_output.read_text(encoding="utf-8")
        arm64 = json.loads(arm64_path.read_text(encoding="utf-8"))
        arm32 = json.loads(arm32_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return False
    expected_apks = {
        f"meettrace-{release_id}-android-universal.apk",
        f"meettrace-{release_id}-android-arm64.apk",
        f"meettrace-{release_id}-android-armeabi-v7a.apk",
    }
    if (
        any(output.count(name) != 1 for name in expected_apks)
        or output.count("│ Passed  │") != 3
        or "ERROR:" in output
    ):
        return False

    def valid_model(model: object, expected_id: str, version: str, abi: str) -> bool:
        return (
            isinstance(model, dict)
            and model.get("id") == expected_id
            and model.get("form") == "PHYSICAL"
            and version in model.get("supportedVersionIds", [])
            and abi in model.get("supportedAbis", [])
        )

    return valid_model(arm64, arm64_model, arm64_version, "arm64-v8a") and valid_model(
        arm32, arm32_model, arm32_version, "armeabi-v7a"
    )


def reuse_prior_firebase_validation(
    *,
    repository: str,
    release_id: str,
    source_run_id: int,
    output_directory: Path,
    arm64_model: str,
    arm64_version: str,
    arm32_model: str,
    arm32_version: str,
) -> int | None:
    expected_name = f"meettrace-android-distribution-{release_id}"
    query = urlencode({"name": expected_name, "per_page": 100})
    payload = _gh_json(["api", f"repos/{repository}/actions/artifacts?{query}"])
    artifacts = payload.get("artifacts") if isinstance(payload, dict) else None
    if not isinstance(artifacts, list):
        raise RuntimeError("GitHub Artifact 列表格式无效")
    run_counts: dict[int, int] = {}
    for artifact in artifacts:
        workflow_run = artifact.get("workflow_run") if isinstance(artifact, dict) else None
        run_id = (
            _positive_int(workflow_run.get("id"))
            if isinstance(workflow_run, dict)
            else None
        )
        if run_id is not None and run_id < source_run_id:
            run_counts[run_id] = run_counts.get(run_id, 0) + 1

    for artifact in sorted(
        (item for item in artifacts if isinstance(item, dict)),
        key=lambda item: _positive_int(item.get("id")) or 0,
        reverse=True,
    ):
        workflow_run = artifact.get("workflow_run")
        prior_run_id = (
            _positive_int(workflow_run.get("id"))
            if isinstance(workflow_run, dict)
            else None
        )
        if (
            prior_run_id is None
            or prior_run_id >= source_run_id
            or run_counts.get(prior_run_id) != 1
            or artifact.get("name") != expected_name
            or artifact.get("expired") is not False
        ):
            continue
        run_details = _gh_json(
            [
                "run",
                "view",
                str(prior_run_id),
                "--repo",
                repository,
                "--json",
                "workflowName,event,headBranch,jobs",
            ]
        )
        if not isinstance(run_details, dict) or not has_reusable_firebase_steps(run_details):
            continue
        with tempfile.TemporaryDirectory(prefix="meettrace-android-firebase-") as temp:
            directory = Path(temp)
            if not _download_artifact(repository, prior_run_id, expected_name, directory):
                continue
            if not firebase_evidence_is_complete(
                directory=directory,
                release_id=release_id,
                arm64_model=arm64_model,
                arm64_version=arm64_version,
                arm32_model=arm32_model,
                arm32_version=arm32_version,
            ):
                continue
            output_directory.mkdir(parents=True, exist_ok=True)
            for name in (
                "firebase-output.txt",
                "firebase-model-arm64.json",
                "firebase-model-arm32.json",
            ):
                source = _single_file(directory, name)
                assert source is not None
                shutil.copyfile(source, output_directory / name)
            return prior_run_id
    return None


def reuse_prior_receipt(
    *,
    repository: str,
    release_id: str,
    candidate_sha: str,
    source_run_id: int,
    manifest_path: Path,
    output_directory: Path,
) -> int | None:
    candidate_manifest_sha256 = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    expected_name = f"meettrace-android-distribution-{release_id}"
    query = urlencode({"name": expected_name, "per_page": 100})
    artifacts_payload = _gh_json(
        [
            "api",
            f"repos/{repository}/actions/artifacts?{query}",
        ]
    )
    if not isinstance(artifacts_payload, dict):
        raise RuntimeError("GitHub Artifact 查询格式无效")
    raw_artifacts = artifacts_payload.get("artifacts")
    if not isinstance(raw_artifacts, list):
        raise RuntimeError("GitHub Artifact 列表格式无效")
    artifacts = [
        item
        for item in raw_artifacts
        if isinstance(item, dict) and item.get("name") == expected_name
    ]
    run_counts: dict[int, int] = {}
    for artifact in artifacts:
        workflow_run = artifact.get("workflow_run")
        run_id = (
            _positive_int(workflow_run.get("id"))
            if isinstance(workflow_run, dict)
            else None
        )
        if run_id is not None and run_id <= source_run_id:
            run_counts[run_id] = run_counts.get(run_id, 0) + 1

    saw_blocking_evidence = False
    for artifact in sorted(
        artifacts,
        key=lambda item: _positive_int(item.get("id")) or 0,
        reverse=True,
    ):
        workflow_run = artifact.get("workflow_run")
        prior_run_id = (
            _positive_int(workflow_run.get("id"))
            if isinstance(workflow_run, dict)
            else None
        )
        if (
            prior_run_id is None
            or prior_run_id >= source_run_id
            or run_counts.get(prior_run_id) != 1
            or artifact.get("expired") is not False
        ):
            saw_blocking_evidence = True
            continue
        try:
            run_details = _gh_json(
                [
                    "run",
                    "view",
                    str(prior_run_id),
                    "--repo",
                    repository,
                    "--json",
                    "workflowName,event,headBranch,jobs",
                ]
            )
        except (subprocess.CalledProcessError, json.JSONDecodeError) as error:
            raise RuntimeError(
                f"无法可靠检查历史发布运行 {prior_run_id}"
            ) from error
        if not isinstance(run_details, dict):
            raise RuntimeError(f"历史发布运行 {prior_run_id} 返回格式无效")
        jobs = run_details.get("jobs")
        android_jobs = [
            job
            for job in jobs
            if isinstance(job, dict) and job.get("name") == ANDROID_JOB_NAME
        ] if isinstance(jobs, list) else []
        if (
            len(android_jobs) == 1
            and android_jobs[0].get("conclusion")
            in {"failure", "cancelled", "timed_out"}
        ):
            continue
        saw_blocking_evidence = True

        with tempfile.TemporaryDirectory(prefix="meettrace-android-receipt-") as temp:
            directory = Path(temp)
            if not _download_artifact(
                repository,
                prior_run_id,
                expected_name,
                directory,
            ):
                continue
            receipt_path = _single_file(directory, "receipt.json")
            firebase_output = _single_file(directory, "firebase-output.txt")
            emulator_output = _single_file(directory, "emulator-output.txt")
            arm64_model = _single_file(directory, "firebase-model-arm64.json")
            arm32_model = _single_file(directory, "firebase-model-arm32.json")
            if None in (
                receipt_path,
                firebase_output,
                emulator_output,
                arm64_model,
                arm32_model,
            ):
                continue
            receipt_bytes = receipt_path.read_bytes()
            try:
                prior_receipt = json.loads(receipt_bytes)
            except json.JSONDecodeError:
                continue
            if not isinstance(prior_receipt, dict):
                continue
            reused = build_reused_receipt(
                run_details=run_details,
                artifact=artifact,
                prior_receipt=prior_receipt,
                release_id=release_id,
                candidate_sha=candidate_sha,
                candidate_manifest_sha256=candidate_manifest_sha256,
                source_run_id=source_run_id,
                prior_run_id=prior_run_id,
                original_receipt_sha256=hashlib.sha256(receipt_bytes).hexdigest(),
            )
            if reused is None:
                continue
            output_directory.mkdir(parents=True, exist_ok=True)
            (output_directory / "receipt.json").write_text(
                json.dumps(reused, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            shutil.copyfile(firebase_output, output_directory / "firebase-output.txt")
            shutil.copyfile(emulator_output, output_directory / "emulator-output.txt")
            shutil.copyfile(arm64_model, output_directory / "firebase-model-arm64.json")
            shutil.copyfile(arm32_model, output_directory / "firebase-model-arm32.json")
            return prior_run_id
    if saw_blocking_evidence:
        raise RuntimeError(
            "发现同一候选的既有 Android 分发证据，但无法验证原始成功回执；"
            "为避免重复执行 Firebase 验证，发布已失败关闭"
        )
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", required=True)
    parser.add_argument("--release-id", required=True)
    parser.add_argument("--candidate-sha", required=True)
    parser.add_argument("--source-run-id", required=True, type=int)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output-directory", required=True, type=Path)
    parser.add_argument("--github-output", required=True, type=Path)
    parser.add_argument("--arm64-model", required=True)
    parser.add_argument("--arm64-version", required=True)
    parser.add_argument("--arm32-model", required=True)
    parser.add_argument("--arm32-version", required=True)
    args = parser.parse_args()

    reused_from = reuse_prior_receipt(
        repository=args.repository,
        release_id=args.release_id,
        candidate_sha=args.candidate_sha,
        source_run_id=args.source_run_id,
        manifest_path=args.manifest,
        output_directory=args.output_directory,
    )
    firebase_reused_from = None
    if reused_from is None:
        firebase_reused_from = reuse_prior_firebase_validation(
            repository=args.repository,
            release_id=args.release_id,
            source_run_id=args.source_run_id,
            output_directory=args.output_directory,
            arm64_model=args.arm64_model,
            arm64_version=args.arm64_version,
            arm32_model=args.arm32_model,
            arm32_version=args.arm32_version,
        )
    with args.github_output.open("a", encoding="utf-8") as output:
        output.write(f"reuse={'true' if reused_from is not None else 'false'}\n")
        if reused_from is not None:
            output.write(f"validation_run_id={reused_from}\n")
        output.write(
            f"firebase_reuse={'true' if firebase_reused_from is not None else 'false'}\n"
        )
        if firebase_reused_from is not None:
            output.write(f"firebase_validation_run_id={firebase_reused_from}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
