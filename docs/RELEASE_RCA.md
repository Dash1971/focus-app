# Release process RCA and corrective action

## Incident

LockIn `0.4.0 (6)` compiled, passed automated tests, archived, exported, and passed a
local signing/profile audit. App Store Connect then rejected it because the Device
Activity Report used an ExtensionKit extension point but was packaged as an
NSExtension under `PlugIns/`. A corrected build was subsequently confused with the
old IPA because both used mutable, generic artifact paths. Cross-user macOS keychain
and filesystem permissions introduced further failures and manual handoffs.

No rejected build was released. The source repository and signing assets were not
damaged.

## Root causes

1. **The validation contract was incomplete.** Tests proved compilation and behavior,
   while the release audit proved signatures, profiles, and entitlements. Neither
   encoded Apple's relationship between the extension point, metadata model, product
   type, and destination directory.
2. **Signing depended on another GUI user's session.** A privileged bridge launched
   Xcode across user/bootstrap boundaries. Xcode's distribution subprocesses and the
   login keychain did not behave reliably in that context.
3. **Artifacts were mutable and weakly identified.** Multiple builds were exported as
   `LockIn.ipa` into generic directories. The operator could select an obsolete IPA
   without an enforced version, commit, or checksum match.
4. **Release states were conflated.** “Build passed,” “archive signed,” “local audit
   passed,” “Apple validation passed,” “uploaded,” and “TestFlight ready” were treated
   too loosely. This produced premature completion claims.
5. **Prerequisites failed late.** Account access, profiles, certificate-chain health,
   free disk space, and path readability were discovered during export or delivery
   instead of before expensive work began.
6. **Expected negative checks looked like task failures.** Shell commands deliberately
   testing for absent metadata returned nonzero, and orchestration surfaced those
   expected results as alarming command failures.

## Corrective actions

The repository now contains a fail-closed release controller:
`scripts/release.py`.

- A single committed `release/version.json` is checked against every distributable
  Xcode target.
- CI runs regression tests for the release auditor and audits the complete unsigned
  bundle layout, including the ExtensionKit report location and metadata.
- `prepare` requires a clean commit equal to `origin/main`, runs all tests, archives,
  exports, performs a complete signed IPA audit, and submits the exact IPA for
  server-side Apple validation.
- Every run uses a unique directory and artifact name containing version, build,
  commit, and time. Nothing is overwritten.
- A manifest records each state and the exact IPA SHA-256.
- `prepare` cannot upload. `upload` accepts only a manifest in
  `apple_validation_passed` state and requires the exact 64-character SHA-256 as its
  approval token. It re-audits the IPA immediately before sending it.
- Output is created in a shared, traversable directory with the IPA and manifest mode
  `0644`, preventing the previous file-picker permission failure.
- Signing and App Store authentication use a machine-local team API key rather than a
  GUI session. Secrets never enter the repository or CI logs.
- Apple acceptance, upload acceptance, processing, and tester availability remain
  distinct states.

## Why signing remains local

The repository is public. Distribution credentials therefore remain on the controlled
release Mac, not in repository or GitHub Actions secrets. GitHub CI is deterministic
and unsigned; the local release runner performs credentialed operations after the
same checks pass.

## One-time human actions

An Account Holder or Admin must create a team App Store Connect API key, grant the
appropriate role and Certificates/Identifiers/Profiles access, and download the
private key once. Apple may also require a one-time approval for cloud-managed
distribution certificates. If cloud signing is unavailable, one distribution identity
must be installed once in a dedicated release keychain.

After that bootstrap, normal releases require only:

1. approval to merge the versioned source change; and
2. approval of the exact Apple-validated IPA hash before upload.

## Definition of done

A release is not “done” until its manifest records the required state:

- `checks_passed`: source tests and unsigned bundle audit passed;
- `archive_audited`: signed archive audit passed;
- `local_audit_passed`: exported IPA audit and hash passed;
- `apple_validation_passed`: Apple's server-side validation accepted the IPA;
- `uploaded`: App Store Connect accepted the upload; and
- TestFlight ready: confirmed separately after Apple processing.

The pipeline intentionally cannot infer the final TestFlight-ready state from a local
command.

## Apple references

- [Uploading builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Creating App Store Connect API keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)
- [Cloud-managed certificates](https://developer.apple.com/help/account/certificates/cloud-managed-certificates)
- [Provisioning with managed capabilities](https://developer.apple.com/help/account/reference/provisioning-with-managed-capabilities)
