# Releasing

Tag and push — `.github/workflows/release.yml` does the rest: build, sign, notarize,
staple, DMG, checksum, build-provenance attestation, and a GitHub Release.

```bash
git tag v1.0.0 && git push origin v1.0.0
```

## One-time setup: repository secrets

Signing and notarization need an Apple Developer Program membership ($99/yr) and these
secrets under **Settings ▸ Secrets and variables ▸ Actions**:

| Secret | What it is |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | Developer ID **Application** certificate exported as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `P12_PASSWORD` | The password you set when exporting that `.p12` |
| `KEYCHAIN_PASSWORD` | Any random string — it only protects the runner's throwaway keychain |
| `APPLE_TEAM_ID` | Your 10-character Team ID (Apple Developer ▸ Membership) |
| `AC_API_KEY_BASE64` | App Store Connect API key `.p8`, base64-encoded |
| `AC_API_KEY_ID` | The key's ID |
| `AC_API_ISSUER_ID` | The issuer ID shown above the key list |

An App Store Connect API key is used rather than an app-specific password because it
doesn't expire when the account password changes, and it can be scoped and revoked.

## Why notarization is not optional

- Homebrew removes casks that fail Gatekeeper checks, so a cask needs it.
- Without it, users get "cannot be opened" and must dig through System Settings ▸
  Privacy & Security. The old Control-click ▸ Open bypass was removed in macOS 15.
- Unsigned apps also run under App Translocation from a randomized read-only path,
  which breaks reading the bundled item database and writing backups.

## Checklist

1. `swift test` and the app tests pass locally (CI also gates this).
2. Regenerate screenshots if the UI changed: `./App/scripts/screenshots.sh`.
3. Bump `MARKETING_VERSION` — the workflow sets it from the tag, so just tag correctly.
4. Tag, push, then confirm the release page shows the SHA-256 and the attestation.
