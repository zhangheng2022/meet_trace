import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path


SCRIPT = Path(__file__).parents[3] / "tool/release/android_candidate_manifest.py"
SPEC = importlib.util.spec_from_file_location("android_candidate_manifest", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(MODULE)


class AndroidCandidateManifestTest(unittest.TestCase):
    def test_builds_and_verifies_exact_four_apk_set(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            artifacts = {}
            release_id = "v1.2.0-alpha.1"
            for variant, abis in MODULE.VARIANTS.items():
                path = directory / (
                    f"meettrace-{release_id}-android-{MODULE.SUFFIXES[variant]}.apk"
                )
                with zipfile.ZipFile(path, "w") as archive:
                    for abi in abis:
                        archive.writestr(f"lib/{abi}/libapp.so", b"native")
                artifacts[variant] = path

            manifest = MODULE.build_manifest(
                release_id=release_id,
                marketing_version="1.2.0",
                build_number=2011,
                commit_sha="a" * 40,
                run_id=12,
                run_attempt=1,
                repository="example/meettrace",
                signing_identity_sha256="B" * 64,
                artifacts=artifacts,
            )
            MODULE.verify_manifest(
                manifest,
                release_id=release_id,
                build_number=2011,
                commit_sha="a" * 40,
                artifact_directory=directory,
            )
            self.assertEqual(manifest["schemaVersion"], 3)
            self.assertEqual(set(manifest["artifacts"]), set(MODULE.VARIANTS))

            manifest["artifacts"]["arm64-v8a"]["versionCode"] = 2012
            with self.assertRaises(ValueError):
                MODULE.verify_manifest(
                    manifest,
                    release_id=release_id,
                    build_number=2011,
                    commit_sha="a" * 40,
                    artifact_directory=directory,
                )

            manifest["artifacts"]["arm64-v8a"]["versionCode"] = 2011
            artifacts["x86_64"].unlink()
            with self.assertRaisesRegex(ValueError, "Missing Android x86_64"):
                MODULE.verify_manifest(
                    manifest,
                    release_id=release_id,
                    build_number=2011,
                    commit_sha="a" * 40,
                    artifact_directory=directory,
                )


if __name__ == "__main__":
    unittest.main()
