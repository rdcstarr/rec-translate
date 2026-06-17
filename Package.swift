// swift-tools-version: 6.2
import PackageDescription

// RecTranslate — a menu-bar macOS app with a ChatGPT "Chat Bar"-style translation popup.
//
// SwiftPM-only (no .xcodeproj). The executable target is hand-assembled into a
// signed/notarized .app by Scripts/bundle.sh + the GitHub Actions release workflow.
//
// Deployment target is macOS 26. The string form `.macOS("26.0")` is used so the
// manifest does not depend on a specific PackageDescription enum case being present.
let package = Package(
    name: "RecTranslate",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        // Global, re-bindable hotkey via Carbon RegisterEventHotKey — no Accessibility
        // permission required, ships a SwiftUI Recorder, persists to UserDefaults.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.0"),
        // Auto-update is handled in-app by GitHubUpdater (watches GitHub Releases), so there is
        // no Sparkle / signing-key dependency.
    ],
    targets: [
        .executableTarget(
            name: "RecTranslate",
            dependencies: [
                "KeyboardShortcuts",
            ],
            path: "Sources/RecTranslate",
            resources: [
                // Flag PNGs are produced from Resources/Flags-src by Scripts/rasterize-flags.sh
                // before the build (macOS has no runtime SVG decoder).
                .copy("Resources/Flags"),
            ]
        )
    ]
)
