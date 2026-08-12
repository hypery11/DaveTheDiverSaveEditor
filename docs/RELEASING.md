# Releasing

**Today releases are built on this Mac.** `.github/workflows/release.yml` can do the whole
job — build, sign, notarize, staple, DMG, checksum, build-provenance attestation and the
GitHub Release — but it is `workflow_dispatch`-only and the repository currently has **no
signing secrets set**, so triggering it produces a failed run rather than a release. Until
the secrets below exist, use the local script:

```bash
App/scripts/release-local.sh 1.0.1        # signs, notarizes, staples, verifies, prints the SHA-256
git tag v1.0.1 && git push origin v1.0.1
gh release create v1.0.1 dist/DiveSaveEd-macOS-v1.0.1.dmg
```

The script needs a Developer ID Application certificate in the login keychain and a
notarytool keychain profile (`AC_PASSWORD` by default — see the header of the script). It
writes nothing secret into the repo.

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
2. Regenerate screenshots if the UI changed: `./App/scripts/screenshots.sh`. It writes
   `docs/images/` and syncs the subset `site/images/` uses, so both stay current; CI
   fails if they diverge.
3. Bump `MARKETING_VERSION` — the workflow sets it from the tag, so just tag correctly.
4. Tag, push, then confirm the release page shows the SHA-256 and the attestation.

## The website

`site/` is deployed to GitHub Pages by `.github/workflows/pages.yml` on any push to
`main` that touches it. Enable it once under **Settings ▸ Pages ▸ Source: GitHub Actions**.

Absolute URLs (canonical, Open Graph, JSON-LD, sitemap, robots) currently point at the
default Pages URL. If you move to a custom domain — which is worth doing, since
`github.io` is on the Public Suffix List and can't have its own Search Console domain
property — swap them in one command and add a `CNAME` file:

```bash
sed -i '' 's|https://hypery11.github.io/DaveTheDiverSaveEditor|https://YOUR-DOMAIN|g' \
  site/robots.txt site/sitemap.xml site/llms.txt site/404.html site/index.html site/*/index.html
echo "YOUR-DOMAIN" > site/CNAME
```
