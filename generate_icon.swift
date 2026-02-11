#!/usr/bin/env swift

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let scale = CGFloat(size)

// Create bitmap context
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Failed to create context")
    exit(1)
}

// Helper to create CGColor from RGB
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

// --- BACKGROUND ---
// Dark gradient background matching the game (#1E272E)
let bgColors = [
    color(0.10, 0.13, 0.16),
    color(0.14, 0.18, 0.21)
] as CFArray

if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0.0, 1.0]) {
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: scale), end: CGPoint(x: scale, y: 0), options: [])
}

// --- GRID BACKGROUND ---
// Subtle grid lines
let gridCols = 5
let gridRows = 5
let padding: CGFloat = 120
let gridSize = scale - padding * 2
let cellSize = gridSize / CGFloat(gridCols)
let gridOriginX = padding
let gridOriginY = padding

// Draw subtle grid cells
for row in 0..<gridRows {
    for col in 0..<gridCols {
        let x = gridOriginX + CGFloat(col) * cellSize
        let y = gridOriginY + CGFloat(row) * cellSize
        let isLight = (row + col) % 2 == 0
        let cellColor = isLight ? color(0.18, 0.21, 0.23, 0.5) : color(0.15, 0.18, 0.20, 0.5)

        let cellRect = CGRect(x: x + 2, y: y + 2, width: cellSize - 4, height: cellSize - 4)
        let cellPath = CGPath(roundedRect: cellRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        context.setFillColor(cellColor)
        context.addPath(cellPath)
        context.fillPath()
    }
}

// --- COLORED BLOCKS ---
// Block colors matching the game's palette
let blockColors: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
    (0.882, 0.439, 0.333),  // coral
    (0.035, 0.518, 0.890),  // blue
    (0.424, 0.361, 0.906),  // purple
    (0.0,   0.722, 0.580),  // green
    (0.992, 0.796, 0.431),  // yellow
    (0.992, 0.475, 0.659),  // pink
]

// Block layout — represents a partial grid with some colored blocks
// (row, col, colorIndex) — placed to look like mid-game with a color group
let blocks: [(row: Int, col: Int, ci: Int)] = [
    // Blue group (connected 4) — top-left area
    (0, 0, 1), (0, 1, 1), (1, 0, 1), (1, 1, 1),
    // Coral group — top-right
    (0, 3, 0), (0, 4, 0), (1, 4, 0),
    // Green scattered
    (2, 0, 3), (3, 0, 3), (4, 0, 3),
    // Purple cluster — center-right
    (2, 3, 2), (2, 4, 2), (3, 3, 2), (3, 4, 2),
    // Yellow — bottom
    (4, 1, 4), (4, 2, 4), (4, 3, 4),
    // Pink accent
    (1, 2, 5), (2, 2, 5),
    // More scattered for visual richness
    (3, 1, 0), (3, 2, 3),
]

let blockInset: CGFloat = 4
let blockCornerRadius: CGFloat = 12

for block in blocks {
    let x = gridOriginX + CGFloat(block.col) * cellSize + blockInset
    let y = gridOriginY + CGFloat(block.row) * cellSize + blockInset
    let w = cellSize - blockInset * 2
    let h = cellSize - blockInset * 2

    let bc = blockColors[block.ci]

    // Main block
    let blockRect = CGRect(x: x, y: y, width: w, height: h)
    let blockPath = CGPath(roundedRect: blockRect, cornerWidth: blockCornerRadius, cornerHeight: blockCornerRadius, transform: nil)
    context.setFillColor(color(bc.r, bc.g, bc.b))
    context.addPath(blockPath)
    context.fillPath()

    // Highlight strip (top 30% — lighter)
    let highlightH = h * 0.28
    let highlightRect = CGRect(x: x + 4, y: y + h - highlightH - 4, width: w - 8, height: highlightH)
    let highlightPath = CGPath(roundedRect: highlightRect, cornerWidth: blockCornerRadius - 2, cornerHeight: blockCornerRadius - 2, transform: nil)
    context.setFillColor(color(1, 1, 1, 0.15))
    context.addPath(highlightPath)
    context.fillPath()

    // Subtle border
    context.setStrokeColor(color(bc.r * 0.7, bc.g * 0.7, bc.b * 0.7, 0.6))
    context.setLineWidth(1.5)
    context.addPath(blockPath)
    context.strokePath()
}

// --- EXPLOSION EFFECT ---
// Radial burst from center of the purple cluster (simulating a blast)
let burstCenterX = gridOriginX + 3.5 * cellSize
let burstCenterY = gridOriginY + 3.0 * cellSize

// Glow circle
let glowRadius: CGFloat = cellSize * 2.5
let glowColors = [
    color(1.0, 1.0, 1.0, 0.35),
    color(1.0, 0.8, 0.3, 0.15),
    color(1.0, 0.5, 0.2, 0.0)
] as CFArray

if let glowGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0.0, 0.4, 1.0]) {
    context.saveGState()
    context.drawRadialGradient(glowGradient,
        startCenter: CGPoint(x: burstCenterX, y: burstCenterY), startRadius: 0,
        endCenter: CGPoint(x: burstCenterX, y: burstCenterY), endRadius: glowRadius,
        options: [])
    context.restoreGState()
}

// Starburst rays
context.saveGState()
let numRays = 12
for i in 0..<numRays {
    let angle = CGFloat(i) * (2.0 * .pi / CGFloat(numRays)) + 0.15
    let rayLength: CGFloat = cellSize * 2.2
    let rayWidth: CGFloat = 8.0

    let endX = burstCenterX + cos(angle) * rayLength
    let endY = burstCenterY + sin(angle) * rayLength

    let perpX = -sin(angle) * rayWidth
    let perpY = cos(angle) * rayWidth

    context.move(to: CGPoint(x: burstCenterX, y: burstCenterY))
    context.addLine(to: CGPoint(x: endX + perpX, y: endY + perpY))
    context.addLine(to: CGPoint(x: endX - perpX, y: endY - perpY))
    context.closePath()

    context.setFillColor(color(1.0, 0.9, 0.5, 0.2))
    context.fillPath()
}
context.restoreGState()

// Particle dots around the burst
srand48(42) // deterministic seed
for _ in 0..<30 {
    let angle = CGFloat(drand48()) * 2.0 * .pi
    let dist = CGFloat(drand48()) * cellSize * 2.5 + cellSize * 0.5
    let px = burstCenterX + cos(angle) * dist
    let py = burstCenterY + sin(angle) * dist
    let particleSize = CGFloat(drand48()) * 10 + 4

    // Random warm color
    let particleColors = [
        color(1.0, 0.9, 0.3, 0.8),  // yellow
        color(1.0, 0.6, 0.2, 0.8),  // orange
        color(1.0, 1.0, 1.0, 0.7),  // white
        color(0.424, 0.361, 0.906, 0.7),  // purple (matching group)
    ]
    let pc = particleColors[Int(drand48() * Double(particleColors.count))]

    let particleRect = CGRect(x: px - particleSize/2, y: py - particleSize/2, width: particleSize, height: particleSize)
    let particlePath = CGPath(roundedRect: particleRect, cornerWidth: particleSize/2, cornerHeight: particleSize/2, transform: nil)
    context.setFillColor(pc)
    context.addPath(particlePath)
    context.fillPath()
}

// --- SHOCKWAVE RING ---
context.saveGState()
let ringRadius: CGFloat = cellSize * 1.8
context.setStrokeColor(color(0.424, 0.361, 0.906, 0.4))  // purple tinted
context.setLineWidth(3.0)
context.addEllipse(in: CGRect(
    x: burstCenterX - ringRadius,
    y: burstCenterY - ringRadius,
    width: ringRadius * 2,
    height: ringRadius * 2
))
context.strokePath()
context.restoreGState()

// --- SAVE IMAGE ---
guard let image = context.makeImage() else {
    print("Failed to create image")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"

let url = URL(fileURLWithPath: outputPath)
guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    print("Failed to create image destination")
    exit(1)
}

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    print("Failed to write image")
    exit(1)
}

print("Icon saved to \(outputPath) (\(size)x\(size))")
