import SpriteKit
import UIKit

// MARK: - Palette

/// Colors of the "Candy Pop" look, shared by SwiftUI (see CandyUI.swift) and SpriteKit.
enum CandyPalette {
    /// Background gradient, top → middle → bottom (deep purple into navy).
    static let backgroundTop = UIColor(hex: 0x4A2AA6)
    static let backgroundMid = UIColor(hex: 0x2E2B8F)
    static let backgroundBottom = UIColor(hex: 0x1B2470)

    /// Deep "ink" navy. Used translucent for panels: the board, the tray, chips.
    static let ink = UIColor(hex: 0x0E0C3A)

    /// Gold for coins, highlights and score popups, and the dark amber under it.
    static let gold = UIColor(hex: 0xFFE27A)
    static let amber = UIColor(hex: 0xC25A00)

    /// Gold power-up blocks.
    static let powerUpGold = UIColor(hex: 0xF5B81C)
}

extension UIColor {
    /// A color from a hex literal: `UIColor(hex: 0xFF6A4D)`.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    /// This color blended toward `other` by `amount` (0 = unchanged, 1 = `other`).
    /// Like mixing paint: `.mixed(with: .white, 0.4)` is a lighter tint.
    func mixed(with other: UIColor, _ amount: CGFloat) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount,
                       green: g1 + (g2 - g1) * amount,
                       blue: b1 + (b2 - b1) * amount,
                       alpha: a1 + (a2 - a1) * amount)
    }

    /// Short text form of the color, for cache keys ("ff6a4dff").
    fileprivate var cacheKey: String {
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { String(format: "%02x", UInt32(($0 * 255).rounded())) }.joined()
    }
}

// MARK: - Fonts

enum CandyFont {
    /// SF Pro Rounded (the system's rounded font) at the given size and weight.
    static func rounded(_ size: CGFloat, weight: UIFont.Weight = .heavy) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

extension SKLabelNode {
    /// A label in the rounded game font. (SpriteKit's `fontName` can't pick the
    /// system's rounded font, but an attributed string can.)
    static func candy(_ text: String, size: CGFloat, color: UIColor,
                      weight: UIFont.Weight = .heavy) -> SKLabelNode {
        let label = SKLabelNode()
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: CandyFont.rounded(size, weight: weight),
            .foregroundColor: color,
        ])
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
    }
}

// MARK: - Textures

/// Pre-drawn textures for the Candy Pop look. Each is drawn once with Core
/// Graphics (per color and size) and cached, which is much cheaper than stacking
/// several shape nodes per block.
enum CandyTextures {

    private static var cache: [String: SKTexture] = [:]

    /// Retina renderer for small textures (uses the screen's scale).
    private static let format: UIGraphicsImageRendererFormat = {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        return format
    }()

    /// A glossy candy block: lighter at the top, darker at the bottom with a bevel
    /// edge, a soft gloss and a small shine dot. `size` is in points.
    static func block(color: UIColor, size requested: CGSize, cornerRadius: CGFloat) -> SKTexture {
        let size = drawable(requested)
        let key = "block|\(color.cacheKey)|\(size.width)x\(size.height)|\(cornerRadius)"
        if let cached = cache[key] { return cached }

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()

            // Body: light top → the color → a deeper shade at the bottom
            // (UIKit drawing: y = 0 is the top edge)
            drawLinearGradient(in: cg,
                               colors: [color.mixed(with: .white, 0.38), color, color.mixed(with: .black, 0.22)],
                               locations: [0, 0.48, 1],
                               from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: size.height))

            // Bevel: a dark band along the bottom makes the block look thick
            color.mixed(with: .black, 0.42).setFill()
            let bevel = max(2, (size.height * 0.1).rounded())
            UIRectFill(CGRect(x: 0, y: size.height - bevel, width: size.width, height: bevel))

            // Rim light along the top edge
            UIColor.white.withAlphaComponent(0.45).setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: size.width, height: max(1, size.height * 0.05)))

            // Gloss: a soft white glow toward the top-left
            cg.saveGState()
            cg.translateBy(x: size.width * 0.3, y: size.height * 0.24)
            cg.scaleBy(x: 1, y: 0.75)
            drawRadialGradient(in: cg,
                               colors: [UIColor.white.withAlphaComponent(0.55), UIColor.white.withAlphaComponent(0)],
                               radius: size.width * 0.55)
            cg.restoreGState()

            // Shine dot
            UIColor.white.withAlphaComponent(0.75).setFill()
            UIBezierPath(ovalIn: CGRect(x: size.width * 0.17, y: size.height * 0.13,
                                        width: size.width * 0.22, height: size.height * 0.15)).fill()
        }
        return store(SKTexture(image: image), key)
    }

    /// An empty board cell: a soft square that looks slightly pressed in (a shadow
    /// falls from its top edge). `fill` is the skin's grid color, if it has one.
    static func cell(size requested: CGSize, cornerRadius: CGFloat, fill: UIColor?) -> SKTexture {
        let size = drawable(requested)
        let base = fill ?? UIColor.white.withAlphaComponent(0.06)
        let key = "cell|\(base.cacheKey)|\(size.width)x\(size.height)|\(cornerRadius)"
        if let cached = cache[key] { return cached }

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
            base.setFill()
            UIRectFill(rect)
            // Inner shadow from the top edge
            drawLinearGradient(in: cg,
                               colors: [UIColor.black.withAlphaComponent(0.32), UIColor.black.withAlphaComponent(0)],
                               locations: [0, 1],
                               from: .zero, to: CGPoint(x: 0, y: size.height * 0.3))
        }
        return store(SKTexture(image: image), key)
    }

    // MARK: Drawing helpers

    /// Image renderers (and sprites) throw on zero or negative sizes — never ask for one.
    private static func drawable(_ size: CGSize) -> CGSize {
        CGSize(width: max(1, size.width), height: max(1, size.height))
    }

    private static func store(_ texture: SKTexture, _ key: String) -> SKTexture {
        cache[key] = texture
        return texture
    }

    private static func drawLinearGradient(in cg: CGContext, colors: [UIColor], locations: [CGFloat],
                                           from start: CGPoint, to end: CGPoint) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors.map(\.cgColor) as CFArray,
                                        locations: locations) else { return }
        cg.drawLinearGradient(gradient, start: start, end: end,
                              options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    /// Radial gradient centered on the current origin (translate the context first).
    private static func drawRadialGradient(in cg: CGContext, colors: [UIColor], radius: CGFloat) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors.map(\.cgColor) as CFArray,
                                        locations: [0, 1]) else { return }
        cg.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0,
                              endCenter: .zero, endRadius: radius, options: [])
    }
}
