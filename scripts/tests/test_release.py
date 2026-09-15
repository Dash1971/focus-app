#!/usr/bin/env python3

import importlib.util
import plistlib
import hashlib
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "release.py"
SPEC = importlib.util.spec_from_file_location("lockin_release", MODULE_PATH)
assert SPEC and SPEC.loader
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class BundleAuditTests(unittest.TestCase):
    def make_app(self, root: Path, *, report_under_plugins: bool = False, report_as_nsextension: bool = False) -> Path:
        app = root / "LockIn.app"
        for relative, bundle_id in release.EXPECTED_BUNDLES.items():
            if relative == "LockIn.app":
                bundle = app
            else:
                inner = relative.removeprefix("LockIn.app/")
                if report_under_plugins and "DeviceActivityReportExtension" in inner:
                    inner = inner.replace("Extensions/", "PlugIns/")
                bundle = app / inner
            bundle.mkdir(parents=True, exist_ok=True)
            info = {
                "CFBundleIdentifier": bundle_id,
                "CFBundleShortVersionString": "0.4.0",
                "CFBundleVersion": "7",
            }
            if bundle_id.endswith("deviceactivityreport"):
                if report_as_nsextension:
                    info["NSExtension"] = {"NSExtensionPointIdentifier": release.REPORT_POINT}
                else:
                    info["EXAppExtensionAttributes"] = {"EXExtensionPointIdentifier": release.REPORT_POINT}
            elif bundle_id != release.APP_BUNDLE_ID:
                info["NSExtension"] = {"NSExtensionPointIdentifier": "example"}
            with (bundle / "Info.plist").open("wb") as handle:
                plistlib.dump(info, handle)
        return app

    def test_correct_extensionkit_layout_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            result = release.audit_structure(
                self.make_app(Path(temp)),
                expected_version="0.4.0",
                expected_build="7",
            )
            self.assertEqual(result["version"], "0.4.0")
            self.assertEqual(result["build"], "7")
            self.assertEqual(len(result["bundles"]), 6)

    def test_report_under_plugins_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(release.ReleaseError, "Unexpected extension layout"):
                release.audit_structure(
                    self.make_app(Path(temp), report_under_plugins=True),
                    expected_version="0.4.0",
                    expected_build="7",
                )

    def test_report_with_nsextension_metadata_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(release.ReleaseError, "NSExtension"):
                release.audit_structure(
                    self.make_app(Path(temp), report_as_nsextension=True),
                    expected_version="0.4.0",
                    expected_build="7",
                )

    def test_version_mismatch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(release.ReleaseError, "Expected build 8"):
                release.audit_structure(
                    self.make_app(Path(temp)),
                    expected_version="0.4.0",
                    expected_build="8",
                )


class UploadApprovalTests(unittest.TestCase):
    def test_only_validated_exact_immutable_artifact_is_approved(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            ipa = Path(temp) / "LockIn-0.4.0-7-deadbeef.ipa"
            ipa.write_bytes(b"immutable ipa")
            digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
            manifest = {"state": "apple_validation_passed", "ipa": {"ipa": str(ipa), "sha256": digest}}
            self.assertEqual(release.approved_upload_artifact(manifest, digest), (ipa, digest))

    def test_wrong_state_is_rejected(self) -> None:
        with self.assertRaisesRegex(release.ReleaseError, "apple_validation_passed"):
            release.approved_upload_artifact({"state": "local_audit_passed"}, "0" * 64)

    def test_wrong_confirmation_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            ipa = Path(temp) / "LockIn.ipa"
            ipa.write_bytes(b"ipa")
            digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
            manifest = {"state": "apple_validation_passed", "ipa": {"ipa": str(ipa), "sha256": digest}}
            with self.assertRaisesRegex(release.ReleaseError, "approval"):
                release.approved_upload_artifact(manifest, "0" * 64)

    def test_changed_artifact_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            ipa = Path(temp) / "LockIn.ipa"
            ipa.write_bytes(b"original")
            digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
            manifest = {"state": "apple_validation_passed", "ipa": {"ipa": str(ipa), "sha256": digest}}
            ipa.write_bytes(b"changed")
            with self.assertRaisesRegex(release.ReleaseError, "changed after validation"):
                release.approved_upload_artifact(manifest, digest)

if __name__ == "__main__":
    unittest.main()
