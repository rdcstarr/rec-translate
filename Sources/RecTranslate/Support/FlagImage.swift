import SwiftUI
import AppKit

/// Renders a language's flag. Uses the bundled PNG (rasterized from the rec-app SVG flags) loaded
/// by URL from `Bundle.module`; falls back to a globe for "auto" and to the emoji flag if the PNG
/// is missing (e.g. a local build that didn't run the rasterizer).
struct FlagImage: View {
    let code: String
    var width: CGFloat = 22
    var height: CGFloat = 16

    var body: some View {
        if code == Language.auto.code {
            Image(systemName: "globe")
                .foregroundStyle(.secondary)
                .frame(width: width, height: height)
        } else if let image = Self.flag(code) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        } else {
            Text(Languages.flag(for: code))
                .frame(width: width, height: height)
        }
    }

    private static func flag(_ code: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: code, withExtension: "png", subdirectory: "Flags") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
