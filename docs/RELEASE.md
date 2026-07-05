# Releasing WakieAI (auto-update pipeline)

Push a `vX.Y.Z` tag → GitHub Actions builds, Developer-ID signs, notarizes,
DMGs, Sparkle-signs, publishes a Release, and updates the appcast on GitHub
Pages. Installed apps then self-update via Sparkle. **Cost: $0** beyond the
Apple Developer membership you already pay for.

```
git tag → build → sign → notarize → DMG → sparkle-sign → Release → appcast(Pages) → users auto-update
```

Moving parts already in the repo:

| Piece | Where |
|---|---|
| In-app updater (Sparkle) | `apps/mac/lib/updater.dart`, wired in `main.dart` |
| Sparkle config keys | `apps/mac/macos/Runner/Info.plist` (`SU*`) |
| Update feed (seed) | `deploy/appcast.xml` → published to `gh-pages` |
| Appcast item generator | `deploy/append_appcast.py` |
| CI pipeline | `.github/workflows/release.yml` |
| curl installer | `deploy/install.sh` |

---

## One-time setup

### 1. Sparkle EdDSA signing key
Sparkle only installs updates whose signature matches the public key baked into
the app. Generate the pair once:

```bash
# Get Sparkle's tools (same version the CI pins):
curl -fsSL -o sparkle.tar.xz \
  https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz
mkdir sparkle && tar -xf sparkle.tar.xz -C sparkle
./sparkle/bin/generate_keys        # prints the PUBLIC key; stores PRIVATE in your login keychain
./sparkle/bin/generate_keys -x sparkle_private_key.pem   # export the PRIVATE key to a file
```

- **Public key** → paste into `Info.plist` `SUPublicEDKey` (replace the
  `REPLACE_WITH_…` placeholder).
- **Private key** (contents of `sparkle_private_key.pem`) → GitHub secret
  `SPARKLE_ED_PRIVATE_KEY`. Never commit it.

### 2. Developer ID certificate (for CI signing)
Export your "Developer ID Application: Gyujin Lee (8GJTN3VYTJ)" cert **with its
private key** from Keychain Access → `.p12`, then:

```bash
base64 -i cert.p12 | pbcopy    # → secret MACOS_CERT_P12
```

### 3. Notary credentials
Create an app-specific password at appleid.apple.com → secrets below.

### 4. Enable GitHub Pages
Repo → Settings → Pages → Source = **Deploy from branch**, branch = `gh-pages`.
(The workflow creates `gh-pages` on the first release; enable Pages after that
run, or pre-create an empty `gh-pages` branch.)

### 5. Secrets (Repo → Settings → Secrets and variables → Actions)

| Secret | Value |
|---|---|
| `MACOS_CERT_P12` | base64 of the Developer ID `.p12` |
| `MACOS_CERT_PASSWORD` | password you set when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | any throwaway string |
| `NOTARY_APPLE_ID` | your Apple ID email |
| `NOTARY_TEAM_ID` | `8GJTN3VYTJ` |
| `NOTARY_PASSWORD` | app-specific password |
| `SPARKLE_ED_PRIVATE_KEY` | contents of `sparkle_private_key.pem` |

### 6. URLs (if you fork / rename)
Three places hardcode `jinleegg.github.io/WakeyAI` and `JinLeeGG/WakeyAI`:
`Info.plist` (`SUFeedURL`), `lib/updater.dart` (`_feedUrl`), `deploy/appcast.xml`
(`<link>`). Keep them in sync with your Pages URL.

---

## Cutting a release

```bash
# 1. bump the marketing version in apps/mac/pubspec.yaml (e.g. version: 1.0.1+1)
# 2. commit, then tag + push:
git tag v1.0.1
git push origin v1.0.1
```

The build **number** Sparkle compares (`sparkle:version`) is set automatically
from the CI run number, so it always increases — you only bump the `version:`
string for the human-facing name.

Watch the run in the Actions tab. On success there's a new GitHub Release with
`WakieAI.dmg` and the appcast at `https://jinleegg.github.io/WakeyAI/appcast.xml`
gains an item. Existing installs pick it up on their next check (daily, or on
launch).

---

## The three install channels

**Direct download** — the notarized `WakieAI.dmg` on the Releases page.

**curl** —
```bash
curl -fsSL https://raw.githubusercontent.com/JinLeeGG/WakeyAI/main/deploy/install.sh | bash
```

**Homebrew cask** — in a tap repo (`JinLeeGG/homebrew-tap`), `Casks/wakieai.rb`:
```ruby
cask "wakieai" do
  version "1.0.1"
  sha256 "<shasum -a 256 WakieAI.dmg>"
  url "https://github.com/JinLeeGG/WakeyAI/releases/download/v#{version}/WakieAI.dmg"
  name "WakieAI"
  desc "Menu-bar tracker + auto-starter for AI CLI subscriptions"
  homepage "https://github.com/JinLeeGG/WakeyAI"
  auto_updates true   # ← Sparkle owns updates; brew won't fight it
  app "WakieAI.app"
end
```
`brew install jinleegg/tap/wakieai`. Because of `auto_updates true`, Homebrew
installs once and then **defers to Sparkle** for updates (no version drift).

> All three converge on the same Sparkle feed — however a user installs, updates
> arrive the same way.

---

## Verifying auto-update end-to-end

1. Install an **older** version (e.g. build a `v1.0.0` DMG, install it).
2. Release `v1.0.1`.
3. Launch the old app (or wait for the scheduled check). Sparkle should offer
   the update, verify the EdDSA signature against `SUPublicEDKey`, download,
   and relaunch into the new build.
4. If nothing happens: check `Console.app` filtered by `Sparkle`, confirm
   `SUPublicEDKey` matches the private key that signed the DMG, and that the
   appcast's `sparkle:version` is **higher** than the installed
   `CFBundleVersion`.

## Notes / gotchas

- **`sign_update` flag**: the workflow uses `sign_update <dmg> -f <keyfile>`. If a
  Sparkle version bump changes it, run `sign_update --help` and adjust the one
  line in `release.yml`.
- **Sparkle framework** is pulled in automatically by the `auto_updater_macos`
  pod during `flutter build macos` — no manual Xcode embedding needed.
- **Notarization is required every release** (Sparkle installs a Gatekeeper-valid
  build); it's inside the pipeline, so it's automatic once the secrets are set.
- **LaunchAgent survives updates**: Sparkle replaces the app in place at the same
  path, so the dark-wake plist's runner path stays valid.
