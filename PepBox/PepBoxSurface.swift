//
//  PepBoxSurface.swift
//  PepBox
//
//  Panel backgrounds in one place: opaque, the transparent material, or
//  macOS 26 Liquid Glass (Settings > General > Liquid Glass).
//

import SwiftUI

enum PepBoxSurface {
    static let liquidGlassKey = "liquidGlassSurfaces"

    static var isLiquidGlassAvailable: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }
}

private struct PepBoxSurfaceModifier<S: Shape>: ViewModifier {
    let transparent: Bool
    let shape: S
    @AppStorage(PepBoxSurface.liquidGlassKey) private var liquidGlass = false

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), liquidGlass {
            if S.self == Rectangle.self {
                // A whole window: glass alone is see-through, so whatever is behind the window
                // shows through the title bar and empty areas. Back it with the solid panel colour.
                content
                    .glassEffect(.regular, in: shape)
                    .background(AdaptiveColors.panelBackgroundOpaqueStyle, in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
        } else {
            content.background(
                transparent ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle,
                in: shape
            )
        }
    }
}

extension View {
    /// The panel background: Liquid Glass when that's on (macOS 26+), otherwise the
    /// transparent material or the opaque panel colour, as before.
    func pepboxSurface(transparent: Bool) -> some View {
        modifier(PepBoxSurfaceModifier(transparent: transparent, shape: Rectangle()))
    }

    func pepboxSurface<S: Shape>(transparent: Bool, in shape: S) -> some View {
        modifier(PepBoxSurfaceModifier(transparent: transparent, shape: shape))
    }
}

extension Shape {
    /// A filled panel shape (for `.background { shape.pepboxSurfaceFill(...) }` call sites).
    func pepboxSurfaceFill(transparent: Bool) -> some View {
        Color.clear.pepboxSurface(transparent: transparent, in: self)
    }
}
