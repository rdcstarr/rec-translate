# RecTranslate

A menu-bar macOS app with a **ChatGPT "Chat Bar"-style translation popup**. Hit a global
hotkey, a Spotlight-like panel appears **on the display under your mouse**, type or paste
text, press **Return** to translate, the result shows below, **Esc** closes it.

- Menu-bar only (no Dock icon), built with **SwiftUI + AppKit**, **Swift 6**, **SwiftPM only**.
- Non-activating floating `NSPanel` that works over fullscreen apps and on any Space.
- Global trigger: a **re-bindable shortcut** (default ⌥Space) **and** an optional **double-tap Shift**.
- Translations go through the existing **rec-app** API (`/api/translate/{source}/{target}`),
  which translates Google-via-proxy123 server-side. The app stores only your API key (in the **Keychain**).
- Extras: **auto-detect source** (on-device `NLLanguageRecognizer`), **auto-copy**, **Copy (⌘C)**, **recent history**.
- Ships as a **Developer ID-signed + notarized DMG** with **in-app updates via Sparkle**.

Target OS: **macOS 26+**. Build toolchain: **Xcode 26 / Swift 6.2**.

> ⚠️ This repo is developed on Linux but **cannot be compiled there** — building a macOS
> AppKit/SwiftUI app needs macOS. Use the GitHub Actions macOS runner (recommended) or a Mac.

---

## How translation works

The app calls rec-app:

```
POST {baseURL}/api/translate/{source}/{target}
Authorization: Bearer <API key with the "translate" ability>
Content-Type: application/json

{ "text": "Hello world" }
```

Response: `{ "source", "target", "text", "translation" }`. Default `baseURL` is
`https://rec-app.recweb.app` (editable in Settings). "Detect language" is resolved
**on-device** before the request (the endpoint validates concrete language codes).

**Get an API key:** in rec-app, create an `ApiKey` with the `translate` ability and paste it
into RecTranslate → Settings → Translation → *Translate API key*.

---

## First-run setup (on your Mac)

1. Open the app (it appears in the menu bar — the speech-bubble icon).
2. Menu → **Settings…**
   - **Translation:** confirm the base URL, paste your API key, pick default source/target.
   - **Shortcuts:** record a global shortcut (default ⌥Space). Optionally enable **double-tap Shift**
     — this asks for **Accessibility permission** (System Settings → Privacy & Security →
     Accessibility), because a global key monitor requires it. The recorded combo needs no permission.
3. Trigger the popup, type, press Return.

---

## Building locally on a Mac

```bash
# Debug run (no bundle):
swift run

# Build a universal release .app:
./Scripts/bundle.sh 1.0.0 1     # -> build/RecTranslate.app  (unsigned)
```

Open `Package.swift` in Xcode 26 to develop with the IDE.

---

## Releasing + auto-update (GitHub Actions)

Pushing a tag like `v1.0.0` runs `.github/workflows/release.yml` on a macOS runner, which:
**builds → Developer ID signs (hardened runtime) → notarizes + staples → DMG → Sparkle appcast → GitHub Release**.
`.github/workflows/ci.yml` builds on every push to `main` as a fast compile check.

### Required GitHub repository secrets

| Secret | What it is |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Your *Developer ID Application* cert+key exported as `.p12`, base64-encoded (`base64 -i cert.p12 \| pbcopy`). |
| `DEVELOPER_ID_P12_PASSWORD` | Password you set on that `.p12`. |
| `KEYCHAIN_PASSWORD` | Any throwaway password for the temporary CI keychain. |
| `SIGN_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)`. |
| `APPLE_ID` | Apple ID email used for notarization. |
| `APPLE_TEAM_ID` | Your 10-char Apple Team ID. |
| `APPLE_APP_PASSWORD` | App-specific password (appleid.apple.com → Sign-In & Security). |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key from Sparkle's `generate_keys` (the value, not the public key). |

> Alternatively to the `APPLE_ID`/`APPLE_APP_PASSWORD` trio, use an App Store Connect API key
> (`AC_API_KEY_PATH`, `AC_API_KEY_ID`, `AC_API_ISSUER`) — `Scripts/sign-notarize.sh` supports both.

### One-time Sparkle setup

1. On a Mac, get Sparkle's tools (`Sparkle-2.6.4.tar.xz` from the Sparkle releases) and run
   `./bin/generate_keys`. It prints a **public** key and stores the **private** key.
2. Put the **public** key into `Resources/Info.plist` → `SUPublicEDKey`.
3. Export the **private** key (`./bin/generate_keys -x private.key`) and store its contents in the
   `SPARKLE_PRIVATE_KEY` GitHub secret.
4. Set `Resources/Info.plist` → `SUFeedURL` to where you publish `appcast.xml` (a GitHub Pages
   URL, or the Release asset URL). The release workflow attaches `appcast.xml`; uncomment the
   Pages step to publish it at a stable URL.

### Installing

**Via Homebrew** (personal tap — works once a signed release is published):

```sh
brew install --cask rdcstarr/tap/rec-translate
```

This installs the latest notarized DMG; the app then self-updates via Sparkle, so Homebrew does
not manage upgrades (the cask uses `auto_updates true`). Tap: https://github.com/rdcstarr/homebrew-tap

**Or manually:** download `RecTranslate.dmg` from the GitHub Release, open it, drag the app to
Applications. Because it's signed + notarized, it opens with **no Gatekeeper warning**, and updates
arrive in-app (Settings → Updates, or automatically).

---

## Project layout

```
Package.swift                     SwiftPM manifest (deps: KeyboardShortcuts, Sparkle)
Sources/RecTranslate/
  App/        RecTranslateApp, AppDelegate, AppEnvironment, HiddenWindowView
  Popup/      FloatingPanel, PanelController, PopupView, PopupViewModel
  Settings/   SettingsView
  Hotkey/     HotkeyManager (combo), DoubleShiftMonitor (double-tap Shift)
  Translation/ TranslationService (+protocol), RecAppTranslationProvider, LanguageDetector, Models
  Storage/    KeychainStore, Preferences, HistoryStore
  Updates/    UpdaterController (Sparkle)
  Support/    NSScreen+Mouse, Languages, Notifications
Resources/    Info.plist, RecTranslate.entitlements, AppIcon.icns (optional)
Scripts/      bundle.sh, sign-notarize.sh, make-appcast.sh
.github/workflows/  ci.yml, release.yml
```

---

## Verification checklist (on macOS 26)

- [ ] CI build is green (compiles + signs + notarizes).
- [ ] DMG installs with no Gatekeeper warning.
- [ ] ⌥Space and double-tap Shift both open the popup on the monitor with the mouse, centered, field focused.
- [ ] Type/paste → Return translates; Shift+Return inserts a newline; Esc closes.
- [ ] Works over a fullscreen app and on a second monitor.
- [ ] Auto-detect labels the detected language; auto-copy + Copy (⌘C) work; history persists and reloads.
- [ ] Settings: re-bind shortcut, toggle double-Shift (Accessibility prompt), change languages/base URL, save/remove API key.
- [ ] Missing/invalid key → clear error; >5000 chars guarded; 502 shows a retryable message.
- [ ] Sparkle "Check for Updates…" finds the appcast; a bumped release installs in-app.
