#!/usr/bin/env python3
"""Fail-closed LockIn build, signing, validation, and upload pipeline."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
VERSION_FILE = ROOT / "release/version.json"
PROJECT = ROOT / "FocusApp.xcodeproj"
SCHEME = "FocusApp"
TEST_SCHEME = "FocusAppTests"
APP_NAME = "LockIn.app"
APP_BUNDLE_ID = "com.dash1971.focusapp"
APP_GROUP = "group.com.dash1971.focusapp"
REPORT_POINT = "com.apple.deviceactivityui.report-extension"
EXPECTED_BUNDLES = {
    "LockIn.app": APP_BUNDLE_ID,
    "LockIn.app/PlugIns/DeviceActivityMonitorExtension.appex": "com.dash1971.focusapp.deviceactivity",
    "LockIn.app/Extensions/DeviceActivityReportExtension.appex": "com.dash1971.focusapp.deviceactivityreport",
    "LockIn.app/PlugIns/ShieldConfigurationExtension.appex": "com.dash1971.focusapp.shieldconfiguration",
    "LockIn.app/PlugIns/ShieldActionExtension.appex": "com.dash1971.focusapp.shieldaction",
    "LockIn.app/PlugIns/LockInWidgets.appex": "com.dash1971.focusapp.widgets",
}
FAMILY_CONTROLS_IDS = set(EXPECTED_BUNDLES.values()) - {"com.dash1971.focusapp.widgets"}


class ReleaseError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise ReleaseError(message)


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def run(
    command: list[str],
    *,
    cwd: Path = ROOT,
    env: dict[str, str] | None = None,
    capture: bool = False,
    log: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    shown = " ".join(command)
    print(f"+ {shown}", flush=True)
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    if capture:
        result = subprocess.run(command, cwd=cwd, env=merged_env, text=True, capture_output=True)
        if result.returncode:
            detail = (result.stdout + result.stderr).strip()
            fail(f"Command failed ({result.returncode}): {shown}\n{detail}")
        return result
    if log:
        log.parent.mkdir(parents=True, exist_ok=True)
        with log.open("w", encoding="utf-8") as handle:
            process = subprocess.Popen(
                command,
                cwd=cwd,
                env=merged_env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
            )
            assert process.stdout is not None
            for line in process.stdout:
                sys.stdout.write(line)
                handle.write(line)
            returncode = process.wait()
        if returncode:
            fail(f"Command failed ({returncode}): {shown}. See {log}")
        return subprocess.CompletedProcess(command, returncode, "", "")
    result = subprocess.run(command, cwd=cwd, env=merged_env, text=True)
    if result.returncode:
        fail(f"Command failed ({result.returncode}): {shown}")
    return result


def captured(command: list[str], *, cwd: Path = ROOT) -> str:
    return run(command, cwd=cwd, capture=True).stdout.strip()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_plist(path: Path) -> dict[str, Any]:
    try:
        with path.open("rb") as handle:
            value = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException) as exc:
        fail(f"Cannot read plist {path}: {exc}")
    if not isinstance(value, dict):
        fail(f"Expected dictionary plist at {path}")
    return value


def plist_from_output(data: bytes, label: str) -> dict[str, Any]:
    xml_start = data.find(b"<?xml")
    binary_start = data.find(b"bplist00")
    if xml_start >= 0:
        data = data[xml_start : data.rfind(b"</plist>") + len(b"</plist>")]
    elif binary_start >= 0:
        data = data[binary_start:]
    else:
        fail(f"No plist found in {label} output")
    try:
        value = plistlib.loads(data)
    except plistlib.InvalidFileException as exc:
        fail(f"Invalid plist in {label} output: {exc}")
    if not isinstance(value, dict):
        fail(f"Expected dictionary plist in {label} output")
    return value


def git(*args: str) -> str:
    return captured(["git", *args])


def source_preflight(*, allow_non_main: bool) -> dict[str, str]:
    if git("status", "--porcelain"):
        fail("Release source is dirty. Commit or remove changes before releasing.")
    head = git("rev-parse", "HEAD")
    remote = git("remote", "get-url", "origin")
    if not allow_non_main:
        run(["git", "fetch", "--quiet", "origin", "main"])
        main = git("rev-parse", "origin/main")
        if head != main:
            fail(f"HEAD {head[:12]} is not exact origin/main {main[:12]}")
    return {"commit": head, "remote": remote}


def build_settings() -> tuple[str, str]:
    expected_targets = {
        "FocusApp", "DeviceActivityMonitorExtension", "DeviceActivityReportExtension",
        "ShieldConfigurationExtension", "ShieldActionExtension", "LockInWidgetsExtension",
    }
    seen: dict[str, tuple[str, str]] = {}
    for target in sorted(expected_targets):
        raw = captured([
            "xcodebuild", "-project", str(PROJECT), "-target", target,
            "-configuration", "Release", "-showBuildSettings", "-json",
        ])
        try:
            records = json.loads(raw)
        except json.JSONDecodeError as exc:
            fail(f"Could not parse Xcode build settings for {target}: {exc}")
        if len(records) != 1:
            fail(f"Expected one build-settings record for {target}, found {len(records)}")
        settings = records[0].get("buildSettings", {})
        seen[target] = (
            str(settings.get("MARKETING_VERSION", "")),
            str(settings.get("CURRENT_PROJECT_VERSION", "")),
        )
    missing = expected_targets - set(seen)
    if missing:
        fail(f"Missing Xcode build settings for: {', '.join(sorted(missing))}")
    versions = set(seen.values())
    if len(versions) != 1:
        fail(f"Version/build mismatch across targets: {seen}")
    version, build = versions.pop()
    if not version or not build:
        fail("Version or build number is empty")
    declared = read_version_file()
    if version != declared["version"] or build != str(declared["build"]):
        fail(f"Xcode version/build {version} ({build}) does not match release/version.json {declared}")
    return version, build


def read_version_file() -> dict[str, Any]:
    try:
        value = json.loads(VERSION_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"Cannot read {VERSION_FILE}: {exc}")
    if not isinstance(value, dict) or not isinstance(value.get("version"), str) or not isinstance(value.get("build"), int):
        fail("release/version.json must contain a string version and integer build")
    if value["build"] <= 0 or not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,2}", value["version"]):
        fail("Invalid release version/build")
    return value


def set_version(*, version: str | None, build: int) -> None:
    current = read_version_file()
    next_version = version or current["version"]
    if build <= 0:
        fail("Build number must be positive")
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,2}", next_version):
        fail("Version must contain two or three numeric components")
    project_file = PROJECT / "project.pbxproj"
    project_text = project_file.read_text(encoding="utf-8")
    build_pattern = re.compile(r"(CURRENT_PROJECT_VERSION = )[^;]+;")
    version_pattern = re.compile(r"(MARKETING_VERSION = )[^;]+;")
    build_matches = len(build_pattern.findall(project_text))
    version_matches = len(version_pattern.findall(project_text))
    if build_matches < 12 or build_matches != version_matches:
        fail(f"Unexpected version-setting counts in Xcode project: build={build_matches}, version={version_matches}")
    updated = build_pattern.sub(rf"\g<1>{build};", project_text)
    updated = version_pattern.sub(rf"\g<1>{next_version};", updated)
    version_payload = {"build": build, "version": next_version}
    VERSION_FILE.write_text(json.dumps(version_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    project_file.write_text(updated, encoding="utf-8")
    print(f"Set LockIn version/build to {next_version} ({build}). Commit these source changes before release.")


def xcode_version() -> str:
    return captured(["xcodebuild", "-version"]).replace("\n", "; ")


def require_current_wwdr() -> str:
    result = subprocess.run(
        [
            "security", "find-certificate", "-a", "-p",
            "-c", "Apple Worldwide Developer Relations Certification Authority",
            "/Library/Keychains/System.keychain",
        ],
        capture_output=True,
    )
    if result.returncode:
        fail("Could not inspect Apple WWDR certificates in the System keychain")
    marker = b"-----END CERTIFICATE-----"
    for fragment in result.stdout.split(marker):
        if b"-----BEGIN CERTIFICATE-----" not in fragment:
            continue
        certificate = fragment + marker + b"\n"
        check = subprocess.run(
            ["/usr/bin/openssl", "x509", "-noout", "-checkend", "0", "-subject"],
            input=certificate,
            capture_output=True,
        )
        text = (check.stdout + check.stderr).decode(errors="replace")
        if check.returncode == 0 and re.search(r"OU\s*=\s*G3(?:\b|/)", text):
            return text.strip()
    fail("A current Apple WWDR G3 intermediate is not installed in the System keychain")


def app_relative_paths(app: Path) -> dict[str, Path]:
    result = {"LockIn.app": app}
    for appex in sorted(app.rglob("*.appex")):
        result[f"LockIn.app/{appex.relative_to(app)}"] = appex
    return result


def audit_structure(app: Path, *, expected_version: str | None, expected_build: str | None) -> dict[str, Any]:
    if not app.is_dir():
        fail(f"App bundle not found: {app}")
    paths = app_relative_paths(app)
    if set(paths) != set(EXPECTED_BUNDLES):
        missing = sorted(set(EXPECTED_BUNDLES) - set(paths))
        extra = sorted(set(paths) - set(EXPECTED_BUNDLES))
        fail(f"Unexpected extension layout. Missing={missing}; extra={extra}")
    bundles: list[dict[str, str]] = []
    found_versions: set[tuple[str, str]] = set()
    for relative, path in paths.items():
        info = read_plist(path / "Info.plist")
        bundle_id = str(info.get("CFBundleIdentifier", ""))
        if bundle_id != EXPECTED_BUNDLES[relative]:
            fail(f"Wrong bundle ID for {relative}: {bundle_id}")
        version = str(info.get("CFBundleShortVersionString", ""))
        build = str(info.get("CFBundleVersion", ""))
        found_versions.add((version, build))
        bundles.append({"path": relative, "bundle_id": bundle_id, "version": version, "build": build})
    if len(found_versions) != 1:
        fail(f"Version/build mismatch inside app: {sorted(found_versions)}")
    version, build = found_versions.pop()
    if expected_version and version != expected_version:
        fail(f"Expected version {expected_version}, found {version}")
    if expected_build and build != expected_build:
        fail(f"Expected build {expected_build}, found {build}")
    report = paths["LockIn.app/Extensions/DeviceActivityReportExtension.appex"]
    report_info = read_plist(report / "Info.plist")
    if "NSExtension" in report_info:
        fail("Device Activity Report is incorrectly built as an NSExtension")
    attributes = report_info.get("EXAppExtensionAttributes")
    if not isinstance(attributes, dict) or attributes.get("EXExtensionPointIdentifier") != REPORT_POINT:
        fail("Device Activity Report is missing the required ExtensionKit metadata")
    for relative, path in paths.items():
        if relative == "LockIn.app" or relative.endswith("DeviceActivityReportExtension.appex"):
            continue
        if "NSExtension" not in read_plist(path / "Info.plist"):
            fail(f"Traditional app extension is missing NSExtension metadata: {relative}")
    return {"version": version, "build": build, "bundles": bundles}


def decode_profile(bundle: Path) -> dict[str, Any]:
    profile_path = bundle / "embedded.mobileprovision"
    if not profile_path.is_file():
        fail(f"Missing embedded profile: {profile_path}")
    result = subprocess.run(
        ["/usr/bin/openssl", "smime", "-inform", "der", "-verify", "-noverify", "-in", str(profile_path)],
        cwd=ROOT,
        capture_output=True,
    )
    if result.returncode:
        fail(f"Could not decode CMS profile for {bundle}: {result.stderr.decode(errors='replace').strip()}")
    return plist_from_output(result.stdout, f"profile {bundle.name}")


def signed_entitlements(bundle: Path) -> dict[str, Any]:
    result = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(bundle)],
        cwd=ROOT,
        capture_output=True,
    )
    if result.returncode:
        fail(f"Could not read signed entitlements for {bundle}")
    return plist_from_output(result.stdout + result.stderr, f"entitlements {bundle.name}")


def audit_signing(app: Path, structure: dict[str, Any], expected_team_id: str | None) -> dict[str, Any]:
    run(["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app)])
    paths = app_relative_paths(app)
    teams: set[str] = set()
    signing: list[dict[str, Any]] = []
    now = dt.datetime.now(dt.timezone.utc)
    for relative, bundle in paths.items():
        details = subprocess.run(["codesign", "-d", "--verbose=4", str(bundle)], capture_output=True)
        if details.returncode:
            fail(f"Could not inspect signature: {relative}")
        detail_text = (details.stdout + details.stderr).decode(errors="replace")
        if "Authority=Apple Distribution:" not in detail_text:
            fail(f"Bundle is not signed by Apple Distribution: {relative}")
        profile = decode_profile(bundle)
        entitlements = profile.get("Entitlements", {})
        if not isinstance(entitlements, dict):
            fail(f"Profile entitlements missing: {relative}")
        team_values = profile.get("TeamIdentifier", [])
        if not isinstance(team_values, list) or len(team_values) != 1:
            fail(f"Unexpected TeamIdentifier in profile: {relative}")
        team_id = str(team_values[0])
        teams.add(team_id)
        bundle_id = EXPECTED_BUNDLES[relative]
        if entitlements.get("application-identifier") != f"{team_id}.{bundle_id}":
            fail(f"Profile application identifier mismatch: {relative}")
        if entitlements.get("get-task-allow") is not False:
            fail(f"Profile is not App Store distribution: {relative}")
        if profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices"):
            fail(f"Profile is device-scoped or enterprise, not App Store: {relative}")
        expiration = profile.get("ExpirationDate")
        if not isinstance(expiration, dt.datetime):
            fail(f"Profile expiration missing: {relative}")
        if expiration.replace(tzinfo=expiration.tzinfo or dt.timezone.utc) <= now:
            fail(f"Profile is expired: {relative}")
        profile_groups = entitlements.get("com.apple.security.application-groups", [])
        if APP_GROUP not in profile_groups:
            fail(f"App Group missing from profile: {relative}")
        signed = signed_entitlements(bundle)
        signed_groups = signed.get("com.apple.security.application-groups", [])
        if APP_GROUP not in signed_groups:
            fail(f"App Group missing from signed entitlements: {relative}")
        if bundle_id in FAMILY_CONTROLS_IDS:
            if "com.apple.developer.family-controls" not in entitlements:
                fail(f"Family Controls missing from profile: {relative}")
            if "com.apple.developer.family-controls" not in signed:
                fail(f"Family Controls missing from signed entitlements: {relative}")
        signing.append({
            "path": relative,
            "team_id": team_id,
            "profile_uuid": str(profile.get("UUID", "")),
            "profile_expiration": expiration.isoformat(),
        })
    if len(teams) != 1:
        fail(f"Bundles use multiple teams: {sorted(teams)}")
    team_id = next(iter(teams))
    if expected_team_id and team_id != expected_team_id:
        fail(f"Expected team {expected_team_id}, found {team_id}")
    return {"team_id": team_id, "bundles": signing, "version": structure["version"], "build": structure["build"]}


def unpack_ipa(ipa: Path, destination: Path) -> Path:
    if not ipa.is_file() or ipa.suffix.lower() != ".ipa":
        fail(f"IPA not found: {ipa}")
    try:
        with zipfile.ZipFile(ipa) as archive:
            bad = archive.testzip()
            if bad:
                fail(f"IPA contains a corrupt entry: {bad}")
            for name in archive.namelist():
                candidate = (destination / name).resolve()
                if destination.resolve() not in candidate.parents and candidate != destination.resolve():
                    fail(f"Unsafe IPA entry: {name}")
            archive.extractall(destination)
    except zipfile.BadZipFile as exc:
        fail(f"Invalid IPA zip: {exc}")
    apps = list((destination / "Payload").glob("*.app"))
    if len(apps) != 1:
        fail(f"Expected exactly one app in IPA, found {len(apps)}")
    return apps[0]


def audit_ipa(
    ipa: Path,
    *,
    expected_version: str | None,
    expected_build: str | None,
    expected_team_id: str | None,
    signed: bool,
) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="lockin-ipa-audit-") as temp:
        app = unpack_ipa(ipa, Path(temp))
        structure = audit_structure(app, expected_version=expected_version, expected_build=expected_build)
        signing = audit_signing(app, structure, expected_team_id) if signed else None
    return {
        "ipa": str(ipa.resolve()),
        "sha256": sha256(ipa),
        "size_bytes": ipa.stat().st_size,
        "structure": structure,
        "signing": signing,
    }


def audit_app(app: Path, *, expected_version: str | None, expected_build: str | None, signed: bool, team_id: str | None) -> dict[str, Any]:
    structure = audit_structure(app, expected_version=expected_version, expected_build=expected_build)
    signing = audit_signing(app, structure, team_id) if signed else None
    return {"app": str(app.resolve()), "structure": structure, "signing": signing}


def strict_secret_file(path: Path, label: str) -> None:
    if path.is_symlink():
        fail(f"{label} must not be a symlink: {path}")
    if not path.is_file():
        fail(f"{label} not found: {path}")
    mode = stat.S_IMODE(path.stat().st_mode)
    if mode & 0o077:
        fail(f"{label} must not be group/world accessible (mode {mode:o}): {path}")


def load_config(path: Path) -> dict[str, Any]:
    strict_secret_file(path, "Release config")
    try:
        config = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"Cannot read release config: {exc}")
    required = {"team_id", "api_key_id", "api_issuer_id", "api_key_path", "output_root"}
    missing = sorted(key for key in required if not config.get(key))
    if missing:
        fail(f"Release config is missing: {', '.join(missing)}")
    key_path = Path(config["api_key_path"]).expanduser().resolve()
    strict_secret_file(key_path, "App Store Connect private key")
    if key_path.name != f"AuthKey_{config['api_key_id']}.p8":
        fail(f"API key must be named AuthKey_{config['api_key_id']}.p8")
    config["api_key_path"] = str(key_path)
    config["output_root"] = str(Path(config["output_root"]).expanduser().resolve())
    return config


def bootstrap_config(
    config_path: Path,
    source_key: Path,
    *,
    team_id: str,
    api_key_id: str,
    api_issuer_id: str,
    output_root: Path,
) -> None:
    """Install a team API key and config without placing secrets in the repository."""
    if config_path.exists():
        fail(f"Refusing to overwrite release config: {config_path}")
    if not source_key.is_file() or source_key.is_symlink():
        fail(f"Source API key is not a regular file: {source_key}")
    if source_key.name != f"AuthKey_{api_key_id}.p8":
        fail(f"Source API key must be named AuthKey_{api_key_id}.p8")
    config_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    config_path.parent.chmod(0o700)
    private_keys = config_path.parent / "focus_app_store_connect_keys"
    private_keys.mkdir(mode=0o700, exist_ok=True)
    private_keys.chmod(0o700)
    installed_key = private_keys / source_key.name
    if installed_key.exists():
        fail(f"Refusing to overwrite installed API key: {installed_key}")
    with source_key.open("rb") as source, installed_key.open("xb") as destination:
        shutil.copyfileobj(source, destination)
    installed_key.chmod(0o600)
    config = {
        "team_id": team_id,
        "api_key_id": api_key_id,
        "api_issuer_id": api_issuer_id,
        "api_key_path": str(installed_key.resolve()),
        "output_root": str(output_root.expanduser().resolve()),
        "minimum_free_gb": 6,
    }
    descriptor = os.open(config_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        json.dump(config, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print(f"Installed release config: {config_path}")
    print(f"Installed API key copy: {installed_key}")
    print(f"Original key remains at: {source_key}")


def auth_args(config: dict[str, Any]) -> list[str]:
    return [
        "-allowProvisioningUpdates",
        "-authenticationKeyPath", config["api_key_path"],
        "-authenticationKeyID", config["api_key_id"],
        "-authenticationKeyIssuerID", config["api_issuer_id"],
    ]


def altool_env(config: dict[str, Any]) -> dict[str, str]:
    return {"API_PRIVATE_KEYS_DIR": str(Path(config["api_key_path"]).parent)}


def check_free_space(output_root: Path, minimum_gb: float) -> None:
    output_root.mkdir(parents=True, exist_ok=True)
    output_root.chmod(0o755)
    free = shutil.disk_usage(output_root).free
    required = int(minimum_gb * 1024**3)
    if free < required:
        fail(f"Only {free / 1024**3:.1f} GB free; {minimum_gb:.1f} GB is required before release work starts")


def choose_simulator() -> str:
    raw = captured(["xcrun", "simctl", "list", "devices", "available", "-j"])
    devices = json.loads(raw).get("devices", {})
    for runtime_devices in devices.values():
        for device in runtime_devices:
            if "iPhone" in device.get("name", "") and device.get("isAvailable", True):
                return str(device["udid"])
    fail("No available iPhone simulator found")


def run_checks(
    derived_root: Path,
    *,
    expected_version: str | None = None,
    expected_build: str | None = None,
) -> dict[str, Any]:
    if derived_root.exists():
        fail(f"Refusing to overwrite existing check directory: {derived_root}")
    derived_root.mkdir(parents=True)
    run(["swift", "test"], log=derived_root / "swift-test.log")
    device_data = derived_root / "device"
    run([
        "xcodebuild", "-quiet", "-project", str(PROJECT), "-scheme", SCHEME,
        "-configuration", "Release", "-destination", "generic/platform=iOS",
        "-derivedDataPath", str(device_data), "CODE_SIGNING_ALLOWED=NO", "build",
    ], log=derived_root / "device-build.log")
    app = device_data / "Build/Products/Release-iphoneos" / APP_NAME
    if expected_version is None or expected_build is None:
        version, build = build_settings()
    else:
        version, build = expected_version, expected_build
    audit = audit_app(app, expected_version=version, expected_build=build, signed=False, team_id=None)
    simulator = choose_simulator()
    run([
        "xcodebuild", "-quiet", "-project", str(PROJECT), "-scheme", TEST_SCHEME,
        "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={simulator}",
        "-derivedDataPath", str(derived_root / "simulator"), "CODE_SIGNING_ALLOWED=NO", "test",
    ], log=derived_root / "simulator-tests.log")
    return {"version": version, "build": build, "unsigned_bundle_audit": audit}


def write_manifest(path: Path, manifest: dict[str, Any]) -> None:
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    path.chmod(0o644)


def prepare(config_path: Path, *, allow_non_main: bool) -> Path:
    os.umask(0o022)
    config = load_config(config_path)
    source = source_preflight(allow_non_main=allow_non_main)
    version, build = build_settings()
    wwdr = require_current_wwdr()
    output_root = Path(config["output_root"])
    check_free_space(output_root, float(config.get("minimum_free_gb", 6)))
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    release_id = f"LockIn-{version}-{build}-{source['commit'][:8]}-{stamp}"
    run_dir = output_root / release_id
    if run_dir.exists():
        fail(f"Release directory already exists: {run_dir}")
    run_dir.mkdir(parents=True, exist_ok=False)
    run_dir.chmod(0o755)
    for child in (run_dir / "logs", run_dir / "artifacts"):
        child.mkdir()
        child.chmod(0o755)
    manifest_path = run_dir / "manifest.json"
    manifest: dict[str, Any] = {
        "schema": 1,
        "release_id": release_id,
        "state": "preflight_passed",
        "created_at": utc_now(),
        "source": source,
        "toolchain": xcode_version(),
        "wwdr": wwdr,
        "version": version,
        "build": build,
        "events": [{"state": "preflight_passed", "at": utc_now()}],
    }
    write_manifest(manifest_path, manifest)
    checks = run_checks(run_dir / "checks", expected_version=version, expected_build=build)
    manifest["checks"] = checks
    manifest["state"] = "checks_passed"
    manifest["events"].append({"state": "checks_passed", "at": utc_now()})
    write_manifest(manifest_path, manifest)

    archive = run_dir / "artifacts" / f"{release_id}.xcarchive"
    run([
        "xcodebuild", "-quiet", "-project", str(PROJECT), "-scheme", SCHEME,
        "-configuration", "Release", "-destination", "generic/platform=iOS",
        "-archivePath", str(archive), f"DEVELOPMENT_TEAM={config['team_id']}",
        *auth_args(config), "archive",
    ], log=run_dir / "logs/archive.log")
    archived_app = archive / "Products/Applications" / APP_NAME
    archive_audit = audit_app(
        archived_app,
        expected_version=version,
        expected_build=build,
        signed=True,
        team_id=config["team_id"],
    )
    manifest["archive"] = {"path": str(archive), "audit": archive_audit}
    manifest["state"] = "archive_audited"
    manifest["events"].append({"state": "archive_audited", "at": utc_now()})
    write_manifest(manifest_path, manifest)

    export_options = {
        "method": "app-store-connect",
        "destination": "export",
        "signingStyle": "automatic",
        "teamID": config["team_id"],
        "manageAppVersionAndBuildNumber": False,
        "stripSwiftSymbols": True,
        "uploadSymbols": True,
    }
    export_options_path = run_dir / "ExportOptions.plist"
    with export_options_path.open("wb") as handle:
        plistlib.dump(export_options, handle)
    export_options_path.chmod(0o644)
    export_dir = run_dir / "export"
    run([
        "xcodebuild", "-quiet", "-exportArchive", "-archivePath", str(archive),
        "-exportPath", str(export_dir), "-exportOptionsPlist", str(export_options_path),
        *auth_args(config),
    ], log=run_dir / "logs/export.log")
    exported = list(export_dir.glob("*.ipa"))
    if len(exported) != 1:
        fail(f"Expected exactly one exported IPA, found {len(exported)}")
    final_ipa = run_dir / "artifacts" / f"LockIn-{version}-{build}-{source['commit'][:8]}.ipa"
    if final_ipa.exists():
        fail(f"Refusing to overwrite immutable IPA: {final_ipa}")
    exported[0].replace(final_ipa)
    final_ipa.chmod(0o644)
    ipa_audit = audit_ipa(
        final_ipa,
        expected_version=version,
        expected_build=build,
        expected_team_id=config["team_id"],
        signed=True,
    )
    manifest["ipa"] = ipa_audit
    manifest["state"] = "local_audit_passed"
    manifest["events"].append({"state": "local_audit_passed", "at": utc_now(), "sha256": ipa_audit["sha256"]})
    write_manifest(manifest_path, manifest)

    run([
        "xcrun", "altool", "--validate-app", "-f", str(final_ipa), "-t", "ios",
        "--api-key", config["api_key_id"], "--api-issuer", config["api_issuer_id"],
        "--output-format", "json",
    ], env=altool_env(config), log=run_dir / "logs/apple-validation.log")
    manifest["state"] = "apple_validation_passed"
    manifest["events"].append({"state": "apple_validation_passed", "at": utc_now()})
    write_manifest(manifest_path, manifest)
    print(f"APPLE VALIDATION PASSED\nManifest: {manifest_path}\nIPA: {final_ipa}\nSHA-256: {ipa_audit['sha256']}")
    return manifest_path


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"Cannot read manifest: {exc}")
    if not isinstance(value, dict) or value.get("schema") != 1:
        fail("Unsupported release manifest")
    return value


def approved_upload_artifact(manifest: dict[str, Any], confirmation: str) -> tuple[Path, str]:
    if manifest.get("state") != "apple_validation_passed":
        fail(f"Upload requires apple_validation_passed; manifest state is {manifest.get('state')}")
    ipa_record = manifest.get("ipa", {})
    if not isinstance(ipa_record, dict):
        fail("Manifest IPA record is missing")
    ipa = Path(str(ipa_record.get("ipa", "")))
    expected_hash = str(ipa_record.get("sha256", ""))
    if not re.fullmatch(r"[0-9a-f]{64}", expected_hash) or confirmation != expected_hash:
        fail("Upload approval must exactly match the manifest SHA-256")
    if not ipa.is_file():
        fail(f"Manifest IPA is missing: {ipa}")
    actual_hash = sha256(ipa)
    if actual_hash != expected_hash:
        fail(f"IPA changed after validation: expected {expected_hash}, found {actual_hash}")
    return ipa, expected_hash


def upload(config_path: Path, manifest_path: Path, confirmation: str) -> None:
    config = load_config(config_path)
    manifest = load_manifest(manifest_path)
    ipa, expected_hash = approved_upload_artifact(manifest, confirmation)
    fresh_audit = audit_ipa(
        ipa,
        expected_version=str(manifest["version"]),
        expected_build=str(manifest["build"]),
        expected_team_id=config["team_id"],
        signed=True,
    )
    if fresh_audit["sha256"] != expected_hash:
        fail("Fresh audit hash does not match manifest")
    log = manifest_path.parent / "logs/upload.log"
    run([
        "xcrun", "altool", "--upload-app", "-f", str(ipa), "-t", "ios",
        "--api-key", config["api_key_id"], "--api-issuer", config["api_issuer_id"],
        "--output-format", "json",
    ], env=altool_env(config), log=log)
    manifest["state"] = "uploaded"
    manifest.setdefault("events", []).append({"state": "uploaded", "at": utc_now(), "sha256": expected_hash})
    write_manifest(manifest_path, manifest)
    print("UPLOAD ACCEPTED BY APP STORE CONNECT; processing is a separate state.")


def credentials_report(config_path: Path) -> dict[str, Any]:
    config = load_config(config_path)
    identities = subprocess.run(["security", "find-identity", "-v", "-p", "codesigning"], capture_output=True, text=True)
    return {
        "config": str(config_path.resolve()),
        "api_key_file": config["api_key_path"],
        "output_root": config["output_root"],
        "team_id_configured": bool(config["team_id"]),
        "local_codesigning_identities": identities.stdout.strip(),
        "signing_mode": "Xcode automatic signing with team API key; cloud-managed certificate attempted first",
        "wwdr": require_current_wwdr(),
    }


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    sub = result.add_subparsers(dest="command", required=True)
    preflight = sub.add_parser("preflight", help="Verify immutable release source and version consistency")
    preflight.add_argument("--allow-non-main", action="store_true")
    ci = sub.add_parser("ci", help="Run core tests, unsigned device build/audit, and simulator tests")
    ci.add_argument("--derived-root", type=Path, default=ROOT / "build/release-ci")
    version_parser = sub.add_parser("set-version", help="Update the canonical version and every Xcode target")
    version_parser.add_argument("--version")
    version_parser.add_argument("--build", type=int, required=True)
    audit_app_parser = sub.add_parser("audit-app", help="Audit a built app bundle")
    audit_app_parser.add_argument("--app", type=Path, required=True)
    audit_app_parser.add_argument("--version")
    audit_app_parser.add_argument("--build")
    audit_app_parser.add_argument("--signed", action="store_true")
    audit_app_parser.add_argument("--team-id")
    audit_ipa_parser = sub.add_parser("audit-ipa", help="Audit an exported IPA")
    audit_ipa_parser.add_argument("--ipa", type=Path, required=True)
    audit_ipa_parser.add_argument("--version")
    audit_ipa_parser.add_argument("--build")
    audit_ipa_parser.add_argument("--unsigned", action="store_true")
    audit_ipa_parser.add_argument("--team-id")
    bootstrap = sub.add_parser("bootstrap", help="Install a team API key and machine-local release config")
    bootstrap.add_argument("--config", type=Path, required=True)
    bootstrap.add_argument("--api-key-file", type=Path, required=True)
    bootstrap.add_argument("--team-id", required=True)
    bootstrap.add_argument("--api-key-id", required=True)
    bootstrap.add_argument("--api-issuer-id", required=True)
    bootstrap.add_argument("--output-root", type=Path, default=Path("/Users/Shared/LockInReleases"))
    check = sub.add_parser("credentials", help="Check unattended release credentials without using them")
    check.add_argument("--config", type=Path, required=True)
    prepare_parser = sub.add_parser("prepare", help="Test, sign, export, audit, and Apple-validate without uploading")
    prepare_parser.add_argument("--config", type=Path, required=True)
    prepare_parser.add_argument("--allow-non-main", action="store_true", help=argparse.SUPPRESS)
    upload_parser = sub.add_parser("upload", help="Upload one Apple-validated immutable IPA")
    upload_parser.add_argument("--config", type=Path, required=True)
    upload_parser.add_argument("--manifest", type=Path, required=True)
    upload_parser.add_argument("--confirm-sha256", required=True)
    return result


def main(argv: Iterable[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        if args.command == "preflight":
            result = source_preflight(allow_non_main=args.allow_non_main)
            version, build = build_settings()
            result.update({"version": version, "build": build, "toolchain": xcode_version()})
            print(json.dumps(result, indent=2, sort_keys=True))
        elif args.command == "ci":
            print(json.dumps(run_checks(args.derived_root.resolve()), indent=2, sort_keys=True))
        elif args.command == "set-version":
            set_version(version=args.version, build=args.build)
        elif args.command == "audit-app":
            print(json.dumps(audit_app(args.app.resolve(), expected_version=args.version, expected_build=args.build, signed=args.signed, team_id=args.team_id), indent=2, sort_keys=True))
        elif args.command == "audit-ipa":
            print(json.dumps(audit_ipa(args.ipa.resolve(), expected_version=args.version, expected_build=args.build, expected_team_id=args.team_id, signed=not args.unsigned), indent=2, sort_keys=True))
        elif args.command == "bootstrap":
            bootstrap_config(
                args.config.expanduser().resolve(),
                args.api_key_file.expanduser().resolve(),
                team_id=args.team_id,
                api_key_id=args.api_key_id,
                api_issuer_id=args.api_issuer_id,
                output_root=args.output_root,
            )
        elif args.command == "credentials":
            print(json.dumps(credentials_report(args.config.resolve()), indent=2, sort_keys=True))
        elif args.command == "prepare":
            prepare(args.config.resolve(), allow_non_main=args.allow_non_main)
        elif args.command == "upload":
            upload(args.config.resolve(), args.manifest.resolve(), args.confirm_sha256)
        return 0
    except ReleaseError as exc:
        print(f"RELEASE BLOCKED: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
