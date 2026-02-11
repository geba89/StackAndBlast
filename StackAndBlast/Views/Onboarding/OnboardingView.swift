import SwiftUI

// MARK: - Onboarding Container

/// 4-page animated onboarding shown on first launch.
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    private let pageCount = 4

    var body: some View {
        ZStack {
            // #1E272E — matches Color.background from theme
            Color(red: 0.118, green: 0.153, blue: 0.180).ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    OnboardingPage(
                        title: "PLACE PIECES",
                        subtitle: "Drag pieces from the tray onto the 9×9 grid",
                        animation: { PlacePieceAnimation() }
                    ).tag(0)

                    OnboardingPage(
                        title: "MATCH COLORS",
                        subtitle: "Connect 10+ same-color blocks to blast them",
                        animation: { ColorBlastAnimation() }
                    ).tag(1)

                    OnboardingPage(
                        title: "CHAIN PUSH",
                        subtitle: "Blasts push nearby blocks outward",
                        animation: { ChainPushAnimation() }
                    ).tag(2)

                    OnboardingPage(
                        title: "USE THE BOMB",
                        subtitle: "Game over? Watch an ad to clear a 6×6 area and keep playing",
                        animation: { BombAnimation() }
                    ).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.blockCoral : Color.gray.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 24)

                // Action button
                Button(action: {
                    if currentPage < pageCount - 1 {
                        currentPage += 1
                    } else {
                        onComplete()
                    }
                }) {
                    Text(currentPage < pageCount - 1 ? "NEXT" : "LET'S PLAY")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blockCoral, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)

                // Skip button on non-final pages
                if currentPage < pageCount - 1 {
                    Button("Skip") {
                        onComplete()
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.gray)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

// MARK: - Page Template

/// Single onboarding page with title, subtitle, and animated demo.
struct OnboardingPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let animation: () -> Content

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Animated demo area
            animation()
                .frame(height: 280)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)

            Spacer().frame(height: 24)

            // Title
            Text(title)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            // Subtitle
            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            Spacer()
        }
    }
}

// MARK: - Mini Grid View

/// Reusable 5×5 animated mini-grid for onboarding demos.
struct MiniGridView: View {
    let grid: [[Color?]]
    let gridSize: Int
    let cellSize: CGFloat

    init(grid: [[Color?]], cellSize: CGFloat = 40) {
        self.grid = grid
        self.gridSize = grid.count
        self.cellSize = cellSize
    }

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<gridSize, id: \.self) { col in
                        let color = (row < grid.count && col < grid[row].count) ? grid[row][col] : nil
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color ?? Color(red: 0.176, green: 0.204, blue: 0.216).opacity(0.5))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
    }
}

// MARK: - Page 1: Place Piece Animation

/// Shows an L-shaped piece sliding from below the grid into position.
struct PlacePieceAnimation: View {
    private let gridSize = 5
    private let cellSize: CGFloat = 40
    private let spacing: CGFloat = 2

    // L-shape piece: occupies (2,1), (3,1), (3,2)
    private let piecePositions: [(row: Int, col: Int)] = [(2, 1), (3, 1), (3, 2)]
    private let pieceColor = Color.blockCoral

    @State private var phase: Int = 0 // 0=empty, 1=sliding, 2=placed, 3=pause
    @State private var animationTimer: Timer?

    var body: some View {
        ZStack {
            // Base grid (empty)
            MiniGridView(grid: emptyGrid, cellSize: cellSize)

            // Animated piece blocks
            ForEach(0..<piecePositions.count, id: \.self) { i in
                let pos = piecePositions[i]
                RoundedRectangle(cornerRadius: 4)
                    .fill(pieceColor)
                    .frame(width: cellSize, height: cellSize)
                    .scaleEffect(phase >= 2 ? 1.0 : 0.9)
                    .offset(
                        x: CGFloat(pos.col - 2) * (cellSize + spacing),
                        y: phase >= 1
                            ? CGFloat(pos.row - 2) * (cellSize + spacing)
                            : CGFloat(pos.row - 2) * (cellSize + spacing) + 180
                    )
                    .opacity(phase >= 1 ? 1 : 0)
            }
        }
        .onAppear { startAnimation() }
        .onDisappear { animationTimer?.invalidate() }
    }

    private var emptyGrid: [[Color?]] {
        Array(repeating: Array(repeating: nil as Color?, count: gridSize), count: gridSize)
    }

    private func startAnimation() {
        phase = 0
        animationTimer?.invalidate()

        // Phase 1: piece appears and starts sliding up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) { phase = 1 }
        }
        // Phase 2: piece snaps into grid with bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { phase = 2 }
        }
        // Phase 3: pause, then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.2)) { phase = 0 }
        }

        // Loop the animation
        animationTimer = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
            DispatchQueue.main.async { startCycle() }
        }
    }

    private func startCycle() {
        phase = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) { phase = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { phase = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.2)) { phase = 0 }
        }
    }
}

// MARK: - Page 2: Color Blast Animation

/// Shows same-color blocks highlighting, then blasting away.
struct ColorBlastAnimation: View {
    private let gridSize = 5
    private let cellSize: CGFloat = 40
    private let spacing: CGFloat = 2

    // Pre-defined grid layout with a cluster of coral blocks + other colors
    private static let blue: Color? = Color.blockBlue
    private static let coral: Color? = Color.blockCoral
    private static let green: Color? = Color.blockGreen
    private static let purple: Color? = Color.blockPurple
    private static let yellow: Color? = Color.blockYellow
    private static let n: Color? = nil

    private let initialColors: [[Color?]] = [
        [n,     blue,  n,      green,  n],
        [coral, coral, coral,  n,      purple],
        [n,     coral, coral,  yellow, n],
        [green, coral, coral,  n,      blue],
        [n,     n,     coral,  coral,  n],
    ]

    // Coral positions (the "blast group")
    private let blastPositions: Set<String> = [
        "1-0", "1-1", "1-2", "2-1", "2-2", "3-1", "3-2", "4-2", "4-3"
    ]

    @State private var phase: Int = 0 // 0=visible, 1=highlight, 2=flash, 3=gone
    @State private var animationTimer: Timer?

    var body: some View {
        MiniGridView(grid: currentGrid, cellSize: cellSize)
            .overlay {
                // Flash overlay for blast
                if phase == 2 {
                    flashOverlay
                }
            }
            .onAppear { startAnimation() }
            .onDisappear { animationTimer?.invalidate() }
    }

    private var currentGrid: [[Color?]] {
        var grid = initialColors
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let key = "\(row)-\(col)"
                if blastPositions.contains(key) {
                    switch phase {
                    case 0:
                        break // normal
                    case 1:
                        // Pulse — make brighter
                        grid[row][col] = Color.white.opacity(0.8)
                    case 2:
                        grid[row][col] = Color.white
                    default:
                        grid[row][col] = nil // removed
                    }
                }
            }
        }
        return grid
    }

    private var flashOverlay: some View {
        VStack(spacing: spacing) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<gridSize, id: \.self) { col in
                        let key = "\(row)-\(col)"
                        RoundedRectangle(cornerRadius: 4)
                            .fill(blastPositions.contains(key) ? Color.white : Color.clear)
                            .frame(width: cellSize, height: cellSize)
                            .opacity(0.6)
                    }
                }
            }
        }
        .transition(.opacity)
    }

    private func startAnimation() {
        phase = 0
        animationTimer?.invalidate()
        runCycle()

        animationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            DispatchQueue.main.async { runCycle() }
        }
    }

    private func runCycle() {
        phase = 0

        // Phase 1: highlight / pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) { phase = 1 }
        }
        // Phase 2: flash white
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeIn(duration: 0.1)) { phase = 2 }
        }
        // Phase 3: blocks disappear
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation(.easeOut(duration: 0.3)) { phase = 3 }
        }
        // Reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeIn(duration: 0.2)) { phase = 0 }
        }
    }
}

// MARK: - Page 3: Chain Push Animation

/// Shows a cluster blasting and pushing surrounding blocks outward.
struct ChainPushAnimation: View {
    private let gridSize = 5
    private let cellSize: CGFloat = 40
    private let spacing: CGFloat = 2

    // Center cluster (coral) at (1,2), (2,1), (2,2), (2,3), (3,2)
    private let clusterPositions: Set<String> = ["1-2", "2-1", "2-2", "2-3", "3-2"]

    // Surrounding blocks that will be pushed
    private struct PushBlock: Identifiable {
        let id: String
        let row: Int
        let col: Int
        let pushRow: Int // destination after push
        let pushCol: Int
        let color: Color
    }

    private let pushBlocks: [PushBlock] = [
        PushBlock(id: "0-2", row: 0, col: 2, pushRow: 0, pushCol: 2, color: .blockBlue),   // already at edge, stays
        PushBlock(id: "1-1", row: 1, col: 1, pushRow: 0, pushCol: 0, color: .blockGreen),   // pushed up-left
        PushBlock(id: "1-3", row: 1, col: 3, pushRow: 0, pushCol: 4, color: .blockPurple),  // pushed up-right
        PushBlock(id: "3-1", row: 3, col: 1, pushRow: 4, pushCol: 0, color: .blockYellow),  // pushed down-left
        PushBlock(id: "3-3", row: 3, col: 3, pushRow: 4, pushCol: 4, color: .blockPink),    // pushed down-right
        PushBlock(id: "2-0", row: 2, col: 0, pushRow: 2, pushCol: 0, color: .blockBlue),    // at edge, stays
        PushBlock(id: "2-4", row: 2, col: 4, pushRow: 2, pushCol: 4, color: .blockGreen),   // at edge, stays
        PushBlock(id: "4-2", row: 4, col: 2, pushRow: 4, pushCol: 2, color: .blockPurple),  // at edge, stays
    ]

    @State private var phase: Int = 0 // 0=all visible, 1=cluster highlight, 2=blast (cluster gone), 3=pushed
    @State private var animationTimer: Timer?

    var body: some View {
        let totalSize = CGFloat(gridSize) * cellSize + CGFloat(gridSize - 1) * spacing

        ZStack {
            // Base empty grid
            MiniGridView(grid: emptyGrid, cellSize: cellSize)

            // Cluster blocks
            ForEach(Array(clusterPositions), id: \.self) { key in
                let parts = key.split(separator: "-")
                let row = Int(parts[0])!
                let col = Int(parts[1])!

                RoundedRectangle(cornerRadius: 4)
                    .fill(phase == 1 ? AnyShapeStyle(Color.white.opacity(0.8)) : AnyShapeStyle(Color.blockCoral))
                    .frame(width: cellSize, height: cellSize)
                    .position(cellPosition(row: row, col: col, totalSize: totalSize))
                    .opacity(phase >= 2 ? 0 : 1)
                    .scaleEffect(phase == 2 ? 1.3 : 1.0)
            }

            // Surrounding (pushable) blocks
            ForEach(pushBlocks) { block in
                let currentRow = phase >= 3 ? block.pushRow : block.row
                let currentCol = phase >= 3 ? block.pushCol : block.col

                RoundedRectangle(cornerRadius: 4)
                    .fill(block.color)
                    .frame(width: cellSize, height: cellSize)
                    .position(cellPosition(row: currentRow, col: currentCol, totalSize: totalSize))
            }
        }
        .frame(width: totalSize, height: totalSize)
        .onAppear { startAnimation() }
        .onDisappear { animationTimer?.invalidate() }
    }

    private var emptyGrid: [[Color?]] {
        Array(repeating: Array(repeating: nil as Color?, count: gridSize), count: gridSize)
    }

    private func cellPosition(row: Int, col: Int, totalSize: CGFloat) -> CGPoint {
        let x = CGFloat(col) * (cellSize + spacing) + cellSize / 2
        let y = CGFloat(row) * (cellSize + spacing) + cellSize / 2
        return CGPoint(x: x, y: y)
    }

    private func startAnimation() {
        phase = 0
        animationTimer?.invalidate()
        runCycle()

        animationTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
            DispatchQueue.main.async { runCycle() }
        }
    }

    private func runCycle() {
        phase = 0

        // Phase 1: highlight cluster
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.3)) { phase = 1 }
        }
        // Phase 2: blast cluster away
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) { phase = 2 }
        }
        // Phase 3: push surrounding blocks outward
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { phase = 3 }
        }
        // Reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(.easeIn(duration: 0.2)) { phase = 0 }
        }
    }
}

// MARK: - Page 4: Bomb Animation

/// Shows a nearly-full grid, a bomb drops, 6×6 area clears.
struct BombAnimation: View {
    private let gridSize = 7
    private let cellSize: CGFloat = 32
    private let spacing: CGFloat = 2

    // Colors for the "nearly full" grid
    private let allColors: [Color] = [.blockCoral, .blockBlue, .blockPurple, .blockGreen, .blockYellow, .blockPink]

    // 6×6 clear zone: rows 0-5, cols 0-5 (offset to center on the 7×7 grid)
    private let clearZone: (rowRange: ClosedRange<Int>, colRange: ClosedRange<Int>) = (0...5, 0...5)

    @State private var phase: Int = 0 // 0=full grid, 1=bomb drops, 2=highlight zone, 3=cleared
    @State private var animationTimer: Timer?

    // Stable pseudo-random grid generated once
    @State private var stableGrid: [[Color]] = []

    var body: some View {
        let totalSize = CGFloat(gridSize) * cellSize + CGFloat(gridSize - 1) * spacing

        ZStack {
            // Grid cells
            VStack(spacing: spacing) {
                ForEach(0..<gridSize, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<gridSize, id: \.self) { col in
                            let inZone = clearZone.rowRange.contains(row) && clearZone.colRange.contains(col)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(cellColor(row: row, col: col, inZone: inZone))
                                .frame(width: cellSize, height: cellSize)
                                .opacity(cellOpacity(inZone: inZone))
                                .scaleEffect(phase == 3 && inZone ? 0.01 : 1.0)
                        }
                    }
                }
            }

            // Bomb icon
            if phase >= 1 && phase < 3 {
                Image(systemName: "flame.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.red)
                    .offset(y: phase == 1 ? -140 : 0)
                    .opacity(phase >= 2 ? 0.8 : 1)
                    .scaleEffect(phase == 2 ? 1.3 : 1.0)
            }

            // Red highlight overlay for clear zone
            if phase == 2 {
                let zoneWidth = CGFloat(6) * cellSize + CGFloat(5) * spacing
                let zoneHeight = CGFloat(6) * cellSize + CGFloat(5) * spacing
                let offsetX = (zoneWidth - totalSize) / 2 + CGFloat(clearZone.colRange.lowerBound) * (cellSize + spacing)
                let offsetY = (zoneHeight - totalSize) / 2 + CGFloat(clearZone.rowRange.lowerBound) * (cellSize + spacing)

                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.red, lineWidth: 2)
                    .fill(Color.red.opacity(0.15))
                    .frame(width: zoneWidth, height: zoneHeight)
                    .offset(x: offsetX, y: offsetY)
            }
        }
        .frame(width: totalSize, height: totalSize)
        .onAppear {
            generateStableGrid()
            startAnimation()
        }
        .onDisappear { animationTimer?.invalidate() }
    }

    private func generateStableGrid() {
        var grid: [[Color]] = []
        for row in 0..<gridSize {
            var rowColors: [Color] = []
            for col in 0..<gridSize {
                // Simple deterministic pattern
                let index = (row * gridSize + col * 3 + row * 2) % allColors.count
                rowColors.append(allColors[index])
            }
            grid.append(rowColors)
        }
        stableGrid = grid
    }

    private func cellColor(row: Int, col: Int, inZone: Bool) -> Color {
        if phase == 2 && inZone {
            return Color.white.opacity(0.7)
        }
        guard !stableGrid.isEmpty else { return Color(red: 0.176, green: 0.204, blue: 0.216) }
        return stableGrid[row][col]
    }

    private func cellOpacity(inZone: Bool) -> Double {
        if phase >= 3 && inZone { return 0 }
        return 1
    }

    private func startAnimation() {
        phase = 0
        animationTimer?.invalidate()
        runCycle()

        animationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            DispatchQueue.main.async { runCycle() }
        }
    }

    private func runCycle() {
        phase = 0

        // Phase 1: bomb appears and drops
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.4)) { phase = 1 }
        }
        // Phase 2: bomb lands, highlight zone
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.3)) { phase = 2 }
        }
        // Phase 3: clear zone blocks disappear
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeOut(duration: 0.4)) { phase = 3 }
        }
        // Reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.3) {
            withAnimation(.easeIn(duration: 0.2)) { phase = 0 }
        }
    }
}
