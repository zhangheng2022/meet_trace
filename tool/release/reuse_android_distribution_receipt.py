"""Reuse the original successful Firebase ARM receipt for a release candidate."""

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


ANDROID_JOB_NAME = "Validate signed Android candidate once on Firebase ARM64"
GH_ATTEMPTS = 3


def _positive_int(value: object) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) and value > 0 else None


def build_reused_receipt(
    *,
    run_details: dict[str, Any],
    artifact: dict[str, Any],
    prior_receipt: dict[str, Any],
    release_id: str,
    candidate_sha: str,
    artifact_sha256: str,
    source_run_id: int,
    prior_run_id: int,
    original_receipt_sha256: str,
) -> dict[str, Any] | None:
    """Return a schema-2 receipt only when every immutable identity matches."""
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

    schema_version = prior_receipt.get("schemaVersion")
    original_is_fresh = schema_version == 1 or (
        schema_version == 2 and prior_receipt.get("reused") is False
    )
    if not (
        original_is_fresh
        and prior_receipt.get("validation") == "androidCandidateDistribution"
        and prior_receipt.get("releaseId") == release_id
        and prior_receipt.get("candidateCommitSha") == candidate_sha
        and prior_receipt.get("sourceRunId") == prior_run_id
        and prior_receipt.get("validationRunId") == prior_run_id
        and prior_receipt.get("androidFirebaseArm") == "passed"
        and prior_receipt.get("artifactSha256") == artifact_sha256
        and isinstance(prior_receipt.get("validatedAtUtc"), str)
        and prior_receipt["validatedAtUtc"].strip()
        and len(original_receipt_sha256) == 64
        and all(char in "0123456789abcdef" for char in original_receipt_sha256)
    ):
        return None

    return {
        "schemaVersion": 2,
        "validation": "androidCandidateDistribution",
        "releaseId": release_id,
        "candidateCommitSha": candidate_sha,
        "sourceRunId": source_run_id,
        "validationRunId": prior_run_id,
        "androidFirebaseArm": "passed",
        "artifactSha256": artifact_sha256,
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


def reuse_prior_receipt(
    *,
    repository: str,
    release_id: str,
    candidate_sha: str,
    source_run_id: int,
    manifest_path: Path,
    output_directory: Path,
) -> int | None:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    artifact_sha256 = manifest["artifact"]["sha256"]
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

    saw_candidate_evidence = bool(artifacts)
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
            if receipt_path is None or firebase_output is None:
                continue
            receipt_bytes = receipt_path.read_bytes()
            try:
                prior_receipt = json.loads(receipt_bytes)
            except json.JSONDecodeError:
                continue
            reused = build_reused_receipt(
                run_details=run_details,
                artifact=artifact,
                prior_receipt=prior_receipt,
                release_id=release_id,
                candidate_sha=candidate_sha,
                artifact_sha256=artifact_sha256,
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
            return prior_run_id
    if saw_candidate_evidence:
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
    args = parser.parse_args()

    reused_from = reuse_prior_receipt(
        repository=args.repository,
        release_id=args.release_id,
        candidate_sha=args.candidate_sha,
        source_run_id=args.source_run_id,
        manifest_path=args.manifest,
        output_directory=args.output_directory,
    )
    with args.github_output.open("a", encoding="utf-8") as output:
        output.write(f"reuse={'true' if reused_from is not None else 'false'}\n")
        if reused_from is not None:
            output.write(f"validation_run_id={reused_from}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
