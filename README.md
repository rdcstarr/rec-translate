# RecTranslate

A menu-bar macOS app with a **ChatGPT "Chat Bar"-style translation popup**. Hit a global
hotkey, a Spotlight-like panel appears **on the display under your mouse**, type or paste
text, press **Return** to translate, the result shows below, **Esc** closes it.

- Menu-bar only (no Dock icon), built with **SwiftUI + AppKit**, **Swift 6**, **SwiftPM only**.
- Non-activating floating `NSPanel` that works over fullscreen apps and on any Space.
- Global trigger: a **re-bindable shortcut** (default ⌥Space) **and** an optional **double-tap Shift**.
- Translations go through the **`/translate` endpoint hosted on proxy123.click**, which translates
  via its own rotating proxy pool (Google under the hood) and supports server-side language
  auto-detect. The app stores only the proxy123 API token (in the **Keychain**).
- **In-app auto-update** that watches this repo's **GitHub Releases** — no Sparkle, no signing
  keys, no manual steps.
- Extras: **auto-detect source**, **auto-copy**, **Copy (⌘C)**, **recent history**.

Target OS: **macOS 26+**. Build toolchain: **Xcode 26 / Swift 6.2**.

> ⚠️ Developed on Linux but **cannot be compiled there** — building a macOS AppKit/SwiftUI app
> needs macOS. The GitHub Actions macOS runner builds it; you just install and run.

## Install (free — one command)

On your Mac (macOS 26):

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/rdcstarr/rec-translate/main/install.sh)"
```

Downloads the latest build, installs it to Applications, clears the Gatekeeper quarantine, and
launches it (speech-bubble icon in the menu bar). Then open **Settings…** and paste your proxy123
**API token** (`API_BEARER_TOKEN`); the base URL defaults to `https://proxy123.click`.

Builds are **ad-hoc signed, not notarized** (free), which is why the installer clears the
quarantine. Once installed, the app **updates itself** from GitHub Releases — you won't run this
command again unless you want to.

## How translation works

The app calls proxy123.click directly:

```
POST {baseURL}/translate/{source}/{target}
Authorization: Bearer <proxy123 API_BEARER_TOKEN>
Content-Type: application/json

{ "text": "Hello world" }
```

Response: `{ "success", "source", "target", "text", "translation", "detected" }`. Default `baseURL`
is `https://proxy123.click` (editable in Settings). The server (a Laravel `TranslateController` +
`GoogleTranslateService` added to proxy123) translates through its own rotating proxy pool and
resolves **`source = auto`** server-side (Google detects the language and returns it as `detected`).

**Token:** use your proxy123 `API_BEARER_TOKEN` (the same one that authorizes `/fetch`). Paste it
into Settings — it's stored in your Keychain, never on disk.

## Auto-update (how it works)

`GitHubUpdater` checks `api.github.com/repos/rdcstarr/rec-translate/releases/latest` a few seconds
after launch and every 6 hours (and from **Settings → Updates → Check for Updates…**). When a newer
release exists it offers to install; on accept it re-runs `install.sh` (download → install →
relaunch). No Sparkle, no EdDSA keys, no Apple account needed.

## First-run setup

1. Run the install command above; the app appears in the menu bar.
2. Menu → **Settings…**
   - **Translation:** confirm the base URL, paste your proxy123 token, pick default source/target.
   - **Shortcuts:** record a global shortcut (default ⌥Space). Optionally enable **double-tap Shift**
     (asks for Accessibility permission — a global key monitor requires it; the recorded combo does not).
3. Trigger the popup, type, press Return.

## Building locally on a Mac

```sh
swift run                          # debug run
./Scripts/bundle.sh 0.1.0 1        # -> build/RecTranslate.app (unsigned)
```

Open `Package.swift` in Xcode 26 to develop with the IDE.

## Releases (GitHub Actions)

- `.github/workflows/ci.yml` — compile check on every push to `main`.
- `.github/workflows/release-free.yml` — **default**: on a `v*` tag, build a universal app, ad-hoc
  sign it, zip it, and publish `RecTranslate.zip` to a GitHub Release. No secrets. This is what the
  installer and the in-app updater download.
- `.github/workflows/test-build.yml` — manual ad-hoc build artifact for quick testing.
- `.github/workflows/release.yml` — **optional, manual**: Developer ID sign + notarize + DMG, if you
  ever add an Apple Developer account (secrets: `DEVELOPER_ID_P12_BASE64`, `DEVELOPER_ID_P12_PASSWORD`,
  `KEYCHAIN_PASSWORD`, `SIGN_IDENTITY`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`). Not required —
  the free path + in-app updater work without it.

Cut a release: `git tag v0.1.1 && git push origin v0.1.1`.

## Project layout

```
Package.swift                     SwiftPM manifest (dep: KeyboardShortcuts)
Sources/RecTranslate/
  App/        RecTranslateApp, AppDelegate, AppEnvironment, HiddenWindowView
  Popup/      FloatingPanel, PanelController, PopupView, PopupViewModel
  Settings/   SettingsView
  Hotkey/     HotkeyManager (combo), DoubleShiftMonitor (double-tap Shift)
  Translation/ TranslationService (+protocol), ProxyTranslateProvider, Models
  Storage/    KeychainStore, Preferences, HistoryStore
  Updates/    GitHubUpdater (watches GitHub Releases)
  Support/    NSScreen+Mouse, Languages, Notifications
Resources/    Info.plist, RecTranslate.entitlements
Scripts/      bundle.sh (+ sign-notarize.sh for the optional notarized path)
install.sh    one-command installer
.github/workflows/  ci.yml, release-free.yml, test-build.yml, release.yml
```

## Verification checklist (on macOS 26)

- [ ] Installer runs; app appears in the menu bar.
- [ ] ⌥Space and double-tap Shift open the popup on the monitor with the mouse, centered, field focused.
- [ ] Type/paste → Return translates via proxy123; Shift+Return = newline; Esc closes.
- [ ] Auto-detect labels the detected language; auto-copy + Copy (⌘C) work; history persists and reloads.
- [ ] Works over a fullscreen app and on a second monitor.
- [ ] Settings: re-bind shortcut, toggle double-Shift (Accessibility prompt), change base URL, save/remove token.
- [ ] Bad/missing token → clear error; >5000 chars guarded; upstream failure shows a retryable message.
- [ ] **Updates:** Settings → Check for Updates… finds a newer release and updates in place.
