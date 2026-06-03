# Releasing HomeBar

HomeBar ships via **Sparkle** auto-updates. Tagging `vX.Y.Z` builds the app, drafts a
GitHub Release, EdDSA-signs the build, and updates the `appcast.xml` the app polls.

## Each release

1. **Bump the version** in `Sources/HomeBar/Info.plist` — both keys:
   - `CFBundleShortVersionString` → marketing version, e.g. `0.1.1`
   - `CFBundleVersion` → **must increase every release** (Sparkle compares this to decide
     "newer"). Integers are simplest: `1`, `2`, `3`, …
2. Commit, then tag and push:
   ```sh
   git commit -am "chore: release 0.1.1"
   git tag v0.1.1 && git push origin main v0.1.1
   ```
3. The **Release** workflow builds, drafts the release, signs the zip, and commits the
   updated `appcast.xml` to `main`.
4. **Publish the draft release** on GitHub — the appcast's download URL points at the
   release asset, which only goes live once the release is published.

That's it. Installed copies pick up the update on their next check (or via the
"Check for Updates…" button in the menu footer).

## One-time setup (already done)

- **EdDSA signing key** generated with Sparkle's `generate_keys`. The private key lives in
  the **login Keychain**; the public key is in `Info.plist` (`SUPublicEDKey`). This is
  Sparkle's own update signing — independent of Apple code signing, so **no Apple Developer
  account is required**.
- The private key is also stored as the repo secret **`SPARKLE_PRIVATE_KEY`**, which the
  release workflow uses to sign builds. If that secret is ever missing, the workflow still
  drafts the release but skips the appcast (auto-updates stay inactive).

**Back up the private key.** If you lose it, you can't sign updates for existing installs.
Re-export any time (asks the Keychain for permission):
```sh
.build/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle-key-backup.txt
# store it somewhere safe, then delete the file — never commit it
```

## Caveats

- **The feed must be publicly reachable.** `SUFeedURL` points at
  `raw.githubusercontent.com/NorbertRop/homebar/main/appcast.xml`. While the repo is
  **private**, that URL 404s, so auto-updates won't fetch until the repo is public (or the
  appcast is hosted somewhere public). The plumbing is ready either way.
- **Un-notarized.** Builds are ad-hoc signed, so first launch needs a one-time
  right-click → Open (or System Settings → Privacy & Security → Open Anyway). Sparkle
  de-quarantines the updates it installs, so later updates are smooth. To remove the
  first-launch step entirely, add Developer ID + notarization (needs an Apple account).
- **Apple Silicon only.** `swift build` produces an arm64 binary, so the appcast marks the
  update `arm64`-only and Intel Macs won't be offered it. Build a universal binary
  (`arm64` + `x86_64`) to cover Intel.

## Optional: Homebrew tap

Let users `brew install --cask`. Create a repo named **`homebrew-tap`** and add
`Casks/homebar.rb`:

```ruby
cask "homebar" do
  version "0.1.1"
  sha256 "REPLACE_WITH: shasum -a 256 HomeBar-0.1.1.zip"

  url "https://github.com/NorbertRop/homebar/releases/download/v#{version}/HomeBar-#{version}.zip"
  name "HomeBar"
  desc "Menu-bar app for Home Assistant"
  homepage "https://github.com/NorbertRop/homebar"

  app "HomeBar.app"

  zap trash: [
    "~/Library/Application Support/HomeBar",
    "~/Library/Preferences/bot.homebar.app.plist",
  ]
end
```

Then: `brew install --cask --no-quarantine NorbertRop/tap/homebar` (the `--no-quarantine`
flag is needed only while builds are un-notarized; drop it once notarized).
