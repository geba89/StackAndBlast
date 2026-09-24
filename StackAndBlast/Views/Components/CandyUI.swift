import SwiftUI
import UIKit

// The "Candy Pop" look: shared SwiftUI building blocks for every screen.
// SpriteKit's side (block textures, palette, rounded labels) is in CandyTextures.swift.

// MARK: - Colors

extension Color {
    /// A color from a hex literal: `Color(hex: 0xFF6A4D)`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    // Background gradient and panels (UIKit versions: CandyPalette)
    static let candyTop = Color(uiColor: CandyPalette.backgroundTop)
    static let candyMid = Color(uiColor: CandyPalette.backgroundMid)
    static let candyBottom = Color(uiColor: CandyPalette.backgroundBottom)
    static let candyInk = Color(uiColor: CandyPalette.ink)
    static let candyGold = Color(uiColor: CandyPalette.gold)
    /// Dark brown used for text on gold.
    static let candyCocoa = Color(hex: 0x6B3A00)
    /// Secondary text on the Candy background (the system gray looks muddy on purple).
    static let candyMuted = Color.white.opacity(0.65)
}

/// Colors of a chunky 3D button: a face gradient and the darker "edge" under it.
struct CandyButtonColors {
    let top: Color
    let bottom: Color
    let edge: Color

    static let green = CandyButtonColors(top: Color(hex: 0x5BE38F), bottom: Color(hex: 0x1FBF6B), edge: Color(hex: 0x128A4B))
    static let blue = CandyButtonColors(top: Color(hex: 0x5DB6FF), bottom: Color(hex: 0x2F86F0), edge: Color(hex: 0x1C5DB0))
    static let orange = CandyButtonColors(top: Color(hex: 0xFF8A6B), bottom: Color(hex: 0xFF5A3C), edge: Color(hex: 0xB83A22))
    static let purple = CandyButtonColors(top: Color(hex: 0x8E6CFF), bottom: Color(hex: 0x5A3DE0), edge: Color(hex: 0x3B24A8))
    static let gold = CandyButtonColors(top: Color(hex: 0xFFE27A), bottom: Color(hex: 0xFFB21C), edge: Color(hex: 0xB86E00))
    /// Translucent white, for secondary buttons on the dark background.
    static let glass = CandyButtonColors(top: .white.opacity(0.22), bottom: .white.opacity(0.10), edge: Color.candyInk.opacity(0.55))
}

// MARK: - Background

/// The Candy Pop background: a purple-to-navy gradient with soft pink and blue
/// glows and a few sparkles. Fills the whole screen, safe areas included.
struct CandyBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                LinearGradient(colors: [.candyTop, .candyMid, .candyBottom], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color(hex: 0xFF5FA8, opacity: 0.30), .clear],
                               center: UnitPoint(x: 0.12, y: 0.08), startRadius: 0, endRadius: width * 0.9)
                RadialGradient(colors: [Color(hex: 0x2F9BFF, opacity: 0.30), .clear],
                               center: UnitPoint(x: 0.95, y: 0.88), startRadius: 0, endRadius: width * 0.95)
                Canvas { context, size in
                    for sparkle in Self.sparkles {
                        let rect = CGRect(x: sparkle.x * size.width - sparkle.radius,
                                          y: sparkle.y * size.height - sparkle.radius,
                                          width: sparkle.radius * 2, height: sparkle.radius * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(sparkle.opacity)))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// Fixed sparkle spots (fractions of the screen), so they never jump around.
    private static let sparkles: [(x: CGFloat, y: CGFloat, radius: CGFloat, opacity: Double)] = [
        (0.10, 0.14, 1.6, 0.45), (0.82, 0.10, 1.4, 0.40), (0.30, 0.34, 1.2, 0.35), (0.90, 0.42, 1.6, 0.40),
        (0.15, 0.62, 1.3, 0.35), (0.62, 0.70, 1.2, 0.30), (0.40, 0.88, 1.5, 0.35), (0.86, 0.80, 1.1, 0.30),
        (0.55, 0.20, 1.0, 0.30), (0.05, 0.90, 1.2, 0.30),
    ]
}

// MARK: - Buttons

/// A chunky "pressable" 3D button, like a candy: a glossy face on a darker edge.
/// Pressing pushes the face down onto the edge.
struct ChunkyButtonStyle: ButtonStyle {
    var colors: CandyButtonColors
    var cornerRadius: CGFloat = 22
    /// How far the edge shows below the face (points).
    var depth: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        ChunkyButtonBody(configuration: configuration, colors: colors, cornerRadius: cornerRadius, depth: depth)
    }
}

private struct ChunkyButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let colors: CandyButtonColors
    let cornerRadius: CGFloat
    let depth: CGFloat
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let pressed = configuration.isPressed && isEnabled
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .foregroundStyle(.white)
            .background {
                // Face: gradient plus a light rim along the top edge
                shape
                    .fill(LinearGradient(colors: [colors.top, colors.bottom], startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0)], startPoint: .top, endPoint: .center),
                        lineWidth: 2))
            }
            .background {
                // Edge: shows below the face; mostly hidden while pressed
                shape
                    .fill(colors.edge)
                    .offset(y: pressed ? depth * 0.35 : depth)
            }
            .offset(y: pressed ? depth * 0.65 : 0)
            .padding(.bottom, depth) // room for the edge, so nothing overlaps it
            .shadow(color: .black.opacity(0.25), radius: 10, y: 8)
            .opacity(isEnabled ? 1 : 0.55)
            .saturation(isEnabled ? 1 : 0.35)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
    }
}

/// Round glass icon button (pause, settings, store...).
struct CandyIconButton: View {
    let systemName: String
    var size: CGFloat = 40
    /// What VoiceOver reads for this icon-only button ("Pause", "Settings"...).
    var label: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .bold))
                .frame(width: size, height: size)
        }
        .buttonStyle(ChunkyButtonStyle(colors: .glass, cornerRadius: size / 2, depth: 3))
        .accessibilityLabel(label)
    }
}

/// Label of a big menu button: icon, title, a small subtitle and an optional tag ("NEW").
struct CandyMenuLabel: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var tag: String? = nil
    var big = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: big ? 26 : 22, weight: .black))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: big ? 28 : 21, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .opacity(0.88)
                }
            }
            .shadow(color: .black.opacity(0.18), radius: 0, y: 2)
            Spacer(minLength: 8)
            if let tag {
                Text(tag)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.candyCocoa)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.candyGold, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: big ? 78 : 64)
        .contentShape(Rectangle())
    }
}

// MARK: - Chips, coin, badge

extension View {
    /// A translucent dark capsule, for chips like the coin balance or the goal.
    func candyChip(height: CGFloat = 34) -> some View {
        self
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(Capsule().fill(Color.candyInk.opacity(0.45)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }

    /// A translucent dark rounded card (tutorial card, mission rows...).
    func candyCard(cornerRadius: CGFloat = 20, border: Color = .white.opacity(0.10)) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color.candyInk.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(border, lineWidth: 1.5))
    }
}

/// The game's coin: a gold disc with a star.
struct CoinIcon: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xF5A300)],
                                         startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(Color(hex: 0xC77A00), lineWidth: max(1, size * 0.06))
            Circle().inset(by: size * 0.18).stroke(Color(hex: 0xA05A00).opacity(0.55), lineWidth: max(0.8, size * 0.055))
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.38, weight: .black))
                .foregroundStyle(Color(hex: 0xFFF6D0))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Coin icon + amount, e.g. the price of a power-up.
struct CoinAmount: View {
    let amount: Int
    var size: CGFloat = 13
    var color: Color = .candyGold

    var body: some View {
        HStack(spacing: 3) {
            CoinIcon(size: size)
            Text("\(amount)")
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) coins")
    }
}

/// Small gold count badge ("1/3").
struct CandyBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.candyCocoa)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.candyGold, in: Capsule())
    }
}

// MARK: - Candy blocks

/// A glossy candy block, drawn like the blocks on the board (see CandyTextures).
struct CandyBlockView: View {
    let base: UIColor
    var size: CGFloat = 30

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(stops: [
                .init(color: Color(uiColor: base.mixed(with: .white, 0.38)), location: 0),
                .init(color: Color(uiColor: base), location: 0.48),
                .init(color: Color(uiColor: base.mixed(with: .black, 0.22)), location: 1),
            ], startPoint: .top, endPoint: .bottom))
            // Bevel along the bottom
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(Color(uiColor: base.mixed(with: .black, 0.42)))
                    .frame(height: max(2, size * 0.1))
            }
            // Gloss and shine dot
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.55), .white.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: size * 0.4))
                .frame(width: size * 0.9, height: size * 0.6)
                .offset(x: -size * 0.15, y: -size * 0.22)
            Ellipse()
                .fill(.white.opacity(0.75))
                .frame(width: size * 0.22, height: size * 0.15)
                .position(x: size * 0.28, y: size * 0.2)
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .shadow(color: Color(hex: 0x0A0528, opacity: 0.35), radius: 3, y: 3)
        .accessibilityHidden(true)
    }
}

/// Candy blocks drifting gently around the edges of a screen, for decoration.
struct FloatingCandyBlocks: View {
    /// (color, x and y as fractions of the screen, size, tilt in degrees)
    private let blocks: [(color: BlockColor, x: CGFloat, y: CGFloat, size: CGFloat, tilt: Double)] = [
        (.purple, 0.02, 0.20, 44, -18), (.blue, 0.97, 0.17, 44, 14), (.yellow, 0.90, 0.47, 32, -10),
        (.green, 0.12, 0.50, 28, 22), (.pink, 0.03, 0.66, 36, 12),
    ]
    @State private var isFloating = false

    var body: some View {
        GeometryReader { proxy in
            ForEach(blocks.indices, id: \.self) { index in
                let block = blocks[index]
                CandyBlockView(base: block.color.uiColor, size: block.size)
                    .rotationEffect(.degrees(block.tilt + (isFloating ? 4 : -4)))
                    .position(x: block.x * proxy.size.width, y: block.y * proxy.size.height)
                    .offset(y: isFloating ? -6 : 6)
                    .animation(.easeInOut(duration: 2.4 + Double(index) * 0.35).repeatForever(autoreverses: true),
                               value: isFloating)
            }
        }
        .onAppear { isFloating = true }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Logo

/// "STACK & BLAST!": white STACK over a golden, outlined BLAST!, with a slowly
/// turning sunburst behind and a row of candy blocks on top. Scales to its width.
struct CandyLogo: View {
    @State private var isFloating = false
    @State private var burstAngle: Double = 0

    /// Width the logo is designed at; it scales from there.
    private let designWidth: CGFloat = 380

    /// The little row of blocks on top: color, tilt (degrees), vertical nudge (points).
    private static let logoBlocks: [(color: BlockColor, tilt: Double, lift: CGFloat)] = [
        (.coral, -12, 2), (.yellow, 6, 8), (.blue, -4, -2), (.green, 10, 8), (.pink, -8, 2),
    ]

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            ZStack {
                Sunburst()
                    .frame(width: 380 * scale, height: 380 * scale)
                    .rotationEffect(.degrees(burstAngle))

                VStack(spacing: 0) {
                    HStack(spacing: 8 * scale) {
                        ForEach(Self.logoBlocks.indices, id: \.self) { index in
                            let block = Self.logoBlocks[index]
                            CandyBlockView(base: block.color.uiColor, size: 30 * scale)
                                .rotationEffect(.degrees(block.tilt))
                                .offset(y: block.lift * scale)
                        }
                    }
                    .padding(.bottom, 6 * scale)

                    (Text("STACK ") + Text("&").font(.system(size: 44 * scale, weight: .black, design: .rounded)))
                        .font(.system(size: 58 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: Color(hex: 0x2A1B7A), radius: 0, y: 5 * scale)
                        .shadow(color: .black.opacity(0.3), radius: 9 * scale, y: 10 * scale)

                    OutlinedTitle(text: "BLAST!", size: 88 * scale)
                        .padding(.top, -6 * scale)
                }
                .offset(y: isFloating ? -3 : 3)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(designWidth / 230, contentMode: .fit)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                burstAngle = 360
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stack and Blast")
    }
}

/// Big golden title text with a dark outline and a chunky drop shadow.
struct OutlinedTitle: View {
    let text: String
    let size: CGFloat
    var fill: [Color] = [Color(hex: 0xFFF3A8), Color(hex: 0xFFC53D), Color(hex: 0xFF7A1A)]
    var outline: Color = Color(hex: 0x7A2A00)
    var drop: Color = Color(hex: 0x5A1E00)

    var body: some View {
        let font = Font.system(size: size, weight: .black, design: .rounded)
        let width = max(1.5, size * 0.035)
        ZStack {
            // Outline: the text in dark brown, nudged in 8 directions
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * .pi / 4
                Text(text)
                    .font(font)
                    .foregroundStyle(outline)
                    .offset(x: cos(angle) * width, y: sin(angle) * width)
            }
            Text(text)
                .font(font)
                .foregroundStyle(LinearGradient(colors: fill, startPoint: .top, endPoint: .bottom))
        }
        .lineLimit(1)
        .fixedSize()
        .drawingGroup() // flatten into one layer before the shadows
        .shadow(color: drop, radius: 0, y: size * 0.065)
        .shadow(color: .black.opacity(0.3), radius: size * 0.1, y: size * 0.12)
    }
}

/// Soft light rays for behind the logo.
private struct Sunburst: View {
    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let rays = 18
                for index in 0..<rays {
                    let start = Double(index) * 2 * .pi / Double(rays)
                    let end = start + .pi / Double(rays)
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: center.x + cos(start) * radius, y: center.y + sin(start) * radius))
                    path.addLine(to: CGPoint(x: center.x + cos(end) * radius, y: center.y + sin(end) * radius))
                    path.closeSubpath()
                    context.fill(path, with: .color(.white.opacity(0.08)))
                }
            }
            .mask(RadialGradient(colors: [.black, .clear], center: .center,
                                 startRadius: radius * 0.15, endRadius: radius))
        }
        .allowsHitTesting(false)
    }
}
