//
//  DropClipIcons.swift
//  DropClip, inside Droppy
//
//  DropClip's tiles in Droppy's icon style: Icon Composer renders, never a squircle drawn by
//  hand. Droppy's own Settings icons are made the same way.
//

import AppKit
import DropClipCore
import SwiftUI

// MARK: - Page icons

/// The icons of DropClip's own pages (`Art/make_settings_icons.swift`): Icon Composer documents in
/// Droppy's Settings recipe, exported at a page link's 28 points and, for a page that opens on a
/// hero, at the hero's 42, each at 1x and 2x so an icon is drawn at its own resolution on every
/// display. The link and the page it opens wear the same icon.
@MainActor
enum DropClipSettingsIcons {
    private static var cache: [String: NSImage] = [:]

    /// `key`'s icon at `points` (28 or 42), or nil when the droplet does not ship that size.
    static func image(_ key: String, points: CGFloat = 28) -> NSImage? {
        let stem = points == 28 ? key : "\(key)-\(Int(points))"
        if let cached = cache[stem] { return cached }
        let size = NSSize(width: points, height: points)
        let image = NSImage(size: size)
        for name in [stem, stem + "@2x"] {
            guard let url = Bundle.module.url(
                forResource: name, withExtension: "png", subdirectory: "Assets/SettingsPages"),
                let data = try? Data(contentsOf: url),
                let rep = NSBitmapImageRep(data: data)
            else { continue }
            rep.size = size
            image.addRepresentation(rep)
        }
        guard !image.representations.isEmpty else { return nil }
        cache[stem] = image
        return image
    }

    /// The icon of one of DropClip's pages.
    static func key(for page: SettingsPage) -> String? {
        switch page {
        case .general: return "General"
        case .appearance: return "Customize"
        case .customize: return "Actions"
        case .customActions: return "CustomActions"
        case .ai: return "AI"
        case .store: return "Store"
        case .appRules: return "AppRules"
        case .about: return "About"
        default: return nil
        }
    }
}

/// One of DropClip's page icons as a view, at its size.
struct DropClipSettingsIcon: View {
    let key: String
    var points: CGFloat = 28

    var body: some View {
        Group {
            if let image = DropClipSettingsIcons.image(key, points: points) {
                Image(nsImage: image)
            } else {
                Color.clear
            }
        }
        .frame(width: points, height: points)
        .accessibilityHidden(true)
    }
}

// MARK: - Symbol tiles

/// The plates DropClip's symbol tiles sit on inside Droppy (`Art/make_icon_plates.swift`): Icon
/// Composer's own tile, its automatic gradient, squircle, rim and shadow, one per hue. An action,
/// an extension or a rule names its symbol and its colour at runtime, so the glyph cannot be baked
/// into a file per tile; the part that makes an icon look like an Icon Composer icon is the tile,
/// and that is the real render. Droppy's plates, the same palette.
@MainActor
enum DropClipIconPlates {
    /// Each plate's own colour, the fill its Icon Composer document was rendered from.
    private static let palette: [(key: String, red: Double, green: Double, blue: Double)] = [
        ("red", 1.00, 0.27, 0.23), ("maroon", 0.62, 0.24, 0.24), ("rose", 1.00, 0.45, 0.53),
        ("pink", 1.00, 0.22, 0.37), ("purple", 0.75, 0.35, 0.95), ("indigo", 0.37, 0.36, 0.90),
        ("blue", 0.04, 0.52, 1.00), ("cyan", 0.39, 0.82, 1.00), ("teal", 0.25, 0.78, 0.88),
        ("mint", 0.40, 0.83, 0.81), ("green", 0.20, 0.84, 0.29), ("lime", 0.64, 0.86, 0.24),
        ("yellow", 1.00, 0.84, 0.04), ("orange", 1.00, 0.62, 0.04), ("tan", 0.84, 0.70, 0.52),
        ("brown", 0.67, 0.53, 0.38), ("slate", 0.44, 0.50, 0.58),
    ]

    private static var sources: [String: NSImage] = [:]
    private static var drawn: [String: NSImage] = [:]

    /// The plate nearest `tint`, at `points`. Drawn from the 128 pixel render with high quality
    /// interpolation, at the display's own scale when AppKit draws it: a layer shrinking the big
    /// bitmap itself skips pixels and leaves the squircle's edge jagged.
    static func plate(for tint: Color, points: CGFloat) -> NSImage? {
        let key = nearestKey(to: tint)
        let cacheKey = "\(key)@\(points)"
        if let hit = drawn[cacheKey] { return hit }
        guard let source = source(key) ?? source("neutral") else { return nil }
        let image = scaled(source, to: points)
        drawn[cacheKey] = image
        return image
    }

    /// Nonisolated, so the drawing handler is too: AppKit may draw an image off the main thread,
    /// and a handler formed on the main actor would trap there.
    private nonisolated static func scaled(_ source: NSImage, to points: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: points, height: points), flipped: false) { rect in
            let context = NSGraphicsContext.current
            let interpolation = context?.imageInterpolation
            context?.imageInterpolation = .high
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            if let interpolation { context?.imageInterpolation = interpolation }
            return true
        }
    }

    private static func source(_ key: String) -> NSImage? {
        if let hit = sources[key] { return hit }
        guard let url = Bundle.module.url(forResource: key, withExtension: "png", subdirectory: "Assets/IconPlates"),
              let image = NSImage(contentsOf: url)
        else { return nil }
        sources[key] = image
        return image
    }

    /// The plate whose colour is nearest `tint`; a grey tint (DropClip's neutral tile, the system
    /// grey) is the neutral plate, the grey of Droppy's General icon.
    static func nearestKey(to tint: Color) -> String {
        guard let color = NSColor(tint).usingColorSpace(.sRGB) else { return "neutral" }
        if color.saturationComponent < 0.15 { return "neutral" }
        let red = Double(color.redComponent)
        let green = Double(color.greenComponent)
        let blue = Double(color.blueComponent)
        let nearest = palette.min { lhs, rhs in
            distance(lhs, red, green, blue) < distance(rhs, red, green, blue)
        }
        return nearest?.key ?? "neutral"
    }

    private static func distance(
        _ plate: (key: String, red: Double, green: Double, blue: Double),
        _ red: Double, _ green: Double, _ blue: Double
    ) -> Double {
        // Weighted for the eye, which tells greens apart best and blues worst.
        let dr = plate.red - red
        let dg = plate.green - green
        let db = plate.blue - blue
        return 0.30 * dr * dr + 0.59 * dg * dg + 0.11 * db * db
    }
}

/// A symbol tile inside Droppy: the Icon Composer plate nearest `tint`, the glyph on it in white
/// the way Droppy's Settings icons wear theirs, 70% of the tile, with the soft neutral shadow and
/// the slight translucency Icon Composer gives a glyph layer. `glyph` is handed the box to fill.
struct DropClipPlateTile<Glyph: View>: View {
    let tint: Color
    let size: CGFloat
    @ViewBuilder var glyph: (_ box: CGFloat) -> Glyph

    var body: some View {
        ZStack {
            if let plate = DropClipIconPlates.plate(for: tint, points: size) {
                Image(nsImage: plate)
            }
            glyph(size * 0.70)
                .foregroundStyle(Color.white.opacity(0.85))
                .shadow(color: .black.opacity(0.25), radius: size * 6 / 128, y: size * 3 / 128)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// An action's or an extension's own icon filling a tile's glyph box: an SF Symbol as Droppy's
/// icons draw one, letters in the rounded face upstream uses, and a picture (an extension's
/// image, a custom icon) as it comes, a little inside the box.
struct DropClipPlateActionIcon: View {
    let icon: ActionIcon
    let box: CGFloat

    var body: some View {
        switch icon {
        case .symbol(let name)
            where !name.isEmpty && !name.contains(":")
                && NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil:
            DropClipPlateSymbol(systemImage: name, box: box)
        case .text(let text):
            Text(String(text.trimmingCharacters(in: .whitespaces).prefix(2)))
                .font(.system(size: box * 0.62, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: box, height: box)
        default:
            ActionIconView(icon: icon, size: box * 0.8)
                .frame(width: box, height: box)
                .clipped()
        }
    }
}

/// An SF Symbol filling a tile's glyph box: its fill variant when it has one, as Droppy's icons
/// use, its longer side the box.
struct DropClipPlateSymbol: View {
    let systemImage: String
    let box: CGFloat

    /// Symbol name to the one drawn, asked of AppKit once per name.
    @MainActor private static var drawnNames: [String: String] = [:]

    @MainActor private static func drawnName(for systemImage: String) -> String {
        if let hit = drawnNames[systemImage] { return hit }
        var name = systemImage
        if !systemImage.hasSuffix(".fill"),
           NSImage(systemSymbolName: systemImage + ".fill", accessibilityDescription: nil) != nil {
            name = systemImage + ".fill"
        }
        drawnNames[systemImage] = name
        return name
    }

    var body: some View {
        Image(systemName: Self.drawnName(for: systemImage))
            .resizable()
            .scaledToFit()
            .frame(width: box, height: box)
    }
}
