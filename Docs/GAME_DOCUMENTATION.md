# Stack & Blast - Complete Game Documentation

> **Version:** 1.0.0 (Build 1)
> **Platform:** iOS 17.0+
> **Bundle ID:** `com.piotrgebski.StackAndBlast`
> **Last Updated:** 2026-02-16

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Game Mechanics](#3-game-mechanics)
4. [Game Modes](#4-game-modes)
5. [Power-Up System](#5-power-up-system)
6. [Scoring & Progression](#6-scoring--progression)
7. [Skins System](#7-skins-system)
8. [UI Screens & Navigation](#8-ui-screens--navigation)
9. [SpriteKit Rendering](#9-spritekit-rendering)
10. [Audio System](#10-audio-system)
11. [Haptic Feedback](#11-haptic-feedback)
12. [Ad Integration](#12-ad-integration)
13. [Data Persistence](#13-data-persistence)
14. [Privacy & Data Handling](#14-privacy--data-handling)
15. [Configuration & Constants](#15-configuration--constants)
16. [File Structure](#16-file-structure)
17. [Dependencies](#17-dependencies)
18. [Design Decisions & Notes](#18-design-decisions--notes)

---

## 1. Project Overview

**Stack & Blast** is a color-matching puzzle game for iOS where players drag polyomino pieces onto a grid. When same-colored blocks form groups large enough to meet the current threshold, they explode -- pushing neighboring blocks outward and triggering chain reactions. The game features three modes, procedural audio, cosmetic skins, and a single rewarded-ad monetization point.

### Key Facts

| Property | Value |
|----------|-------|
| Display Name | Stack & Blast |
| Swift Version | 5.9 |
| Xcode Version | 16.0 |
| Deployment Target | iOS 17.0 |
| Devices | iPhone + iPad |
| Orientation | Portrait only |
| Build System | XcodeGen (`project.yml`) |
| Monetization | Rewarded video ads (Google AdMob) |
| Localization | English only |
| User Accounts | None (all data local) |

---

## 2. Architecture

### Pattern: Observable + ViewModel + SpriteKit Hybrid

The app uses iOS 17's `@Observable` macro throughout, SwiftUI for all UI chrome, and SpriteKit for game board rendering.

### Data Flow

```
StackAndBlastApp (@main)
  └─ ContentView (root navigation)
       ├─ OnboardingView (first launch only)
       ├─ MenuView (mode selection)
       │    ├─ StatsView (.fullScreenCover)
       │    └─ SettingsView (.fullScreenCover)
       └─ GameView (SpriteKit host + HUD)
            ├─ GameScene (SpriteKit rendering + touch)
            ├─ GameViewModel (bridge layer)
            │    └─ GameEngine (core logic)
            │         ├─ BlastResolver (group detection + push physics)
            │         └─ PieceGenerator (weighted random pieces)
            ├─ PauseOverlay (inline overlay)
            └─ GameOverView (modal overlay)
```

### Singleton Services

All services use `static let shared`:

| Service | Responsibility |
|---------|---------------|
| `AdManager` | Google AdMob rewarded video ads |
| `AudioManager` | Procedural PCM audio synthesis via AVAudioEngine |
| `HapticManager` | Core Haptics feedback |
| `NetworkMonitor` | NWPathMonitor for connectivity status |
| `ScoreManager` | High score persistence per game mode |
| `SettingsManager` | User preferences (sound, haptics, colorblind, grid size, skin) |
| `SkinManager` | Cosmetic skin themes with unlock conditions |
| `StatsManager` | Lifetime gameplay statistics |

---

## 3. Game Mechanics

### 3.1 The Grid

- Variable size: **8x8**, **9x9** (default), **10x10**, or **12x12**
- Stored as `[[Block?]]` (2D array of optionals)
- Origin (0,0) is top-left; row increases downward, column rightward
- Grid size is configurable in Settings and takes effect on the next new game

### 3.2 Blocks

Each block on the grid has:
- **Color** -- one of 6 colors: Coral, Blue, Purple, Green, Yellow, Pink
- **Position** -- row/column on the grid
- **Power-Up** -- optional power-up type (colorBomb, rowBlast, columnBlast)
- **UUID** -- unique identifier for SpriteKit node tracking

### 3.3 Pieces

**24 piece templates** across 5 size categories:

| Category | Cell Count | Spawn Weight | Shapes |
|----------|-----------|-------------|--------|
| Monomino | 1 | 10% | Dot |
| Domino | 2 | 15% | Horizontal, Vertical |
| Triomino | 3 | 30% | Lines (H/V), 4 L-shapes |
| Tetromino | 4 | 30% | Lines (H/V), Square, 4 T-shapes, 2 L-shapes, S, Z |
| Pentomino | 5 | 15% | Plus, U, 2 large L-shapes |

**Tray rules:**
- 3 pieces displayed at a time in the tray at the bottom
- At least 1 piece is guaranteed to have 3+ cells
- Colors are assigned randomly from the 6-color palette

### 3.4 Piece Placement

1. Player drags a piece from the tray onto the grid
2. A ghost preview shows placement validity (green = valid, red = invalid)
3. Piece is rendered above the finger during drag for visibility
4. On release over a valid position, blocks are placed on the grid
5. Points awarded: **1 point per cell placed**

### 3.5 Blast Resolution (Core Mechanic)

After every piece placement, the blast resolver runs:

1. **Scan** -- BFS flood fill finds all connected same-color groups
2. **Qualify** -- Groups with size >= `currentMinGroupSize` become blasts
3. **Clear** -- Qualifying groups are removed from the grid
4. **Chain-Push** -- All blocks adjacent to cleared areas are pushed 1 cell away from the blast center. If a pushed block collides with another block, that block is also pushed (chain reaction). Blocks pushed off the grid are destroyed.
5. **Cascade** -- After pushing, the resolver runs again (up to 10 cascade levels). This allows chain reactions where pushed blocks form new qualifying groups.

### 3.6 Combo System

- A **combo** is the total number of blast events from a single piece placement
- When combo >= 2, a "COMBO xN!" overlay appears on the grid
- Color coding: **Orange** (x2), **Red** (x3), **Gold** (x4+)
- `maxCombo` is tracked per game; `highestCombo` is tracked lifetime

### 3.7 Game Over

Game over triggers when:
- **Classic:** No piece in the tray can fit anywhere on the grid
- **Timed modes:** Timer reaches zero OR no piece can fit

### 3.8 Bomb Continue

- Available **once per game** (not available after already used)
- Player watches a rewarded video ad to earn the bomb
- Enters **bomb placement mode** -- player taps a grid cell
- Bomb clears a **6x6 area** centered on the tap (±2 rows, ±3 columns, clamped to grid bounds)
- No blast cascades triggered by the bomb -- just removal
- After bomb, if any piece can now be placed, the game resumes; otherwise stays game over

---

## 4. Game Modes

### 4.1 Classic Mode

| Property | Value |
|----------|-------|
| Timer | None (endless) |
| Pieces | Random (weighted) |
| End Condition | No piece can be placed |
| Difficulty | Blast threshold increases with score |

Standard endless puzzle mode. Place pieces, trigger blasts, and score as high as possible.

### 4.2 Daily Challenge

| Property | Value |
|----------|-------|
| Timer | 60 seconds |
| Pieces | Deterministic (seeded by date) |
| End Condition | Timer runs out OR no piece fits |
| Seed | SplitMix64 RNG with FNV-1a hash of date string |

All players worldwide get the same pieces on the same day. Uses a seeded RNG (SplitMix64) with a seed derived from the current date via FNV-1a 64-bit hash. Completion is tracked per day -- the menu button shows "DAILY COMPLETED" with a checkmark after playing.

### 4.3 Blast Rush

| Property | Value |
|----------|-------|
| Initial Timer | 90 seconds |
| Time Bonus | +5 seconds per blast |
| End Condition | Timer reaches zero OR no piece fits |
| Difficulty | Standard progressive threshold |

Fast-paced mode where every blast extends your time. The urgency builds as the timer runs down.

### Timer Display

For timed modes, the timer updates at 0.1s intervals and displays in `M:SS.T` format. When under 10 seconds remaining, the display turns red and pulses for urgency.

---

## 5. Power-Up System

### Spawn Rules

- A power-up block spawns on a random empty cell every **8 pieces placed**
- The power-up block has a random color and a random power-up type
- Power-up blocks display a pulsing icon overlay on the grid

### Power-Up Types

| Type | Symbol | Effect |
|------|--------|--------|
| **Color Bomb** | Star (★) | Removes ALL blocks of a random other color from the entire grid |
| **Row Blast** | Right Arrow (→) | Clears the entire row where the power-up block was located |
| **Column Blast** | Down Arrow (↓) | Clears the entire column where the power-up block was located |

### Activation

Power-up effects trigger when the power-up block is included in a qualifying blast group. The power-up effect executes as part of the blast resolution, potentially creating additional cascade opportunities.

---

## 6. Scoring & Progression

### Points

| Action | Points |
|--------|--------|
| Placing a piece | 1 point per cell |
| Blast (base) | `groupSize × 20` |
| Blast size bonus (threshold + 1) | +50 |
| Blast size bonus (threshold + 2) | +150 |
| Blast size bonus (threshold + 4) | +300 |
| Cascade multiplier | `2^cascadeLevel` (1x, 2x, 4x, 8x...) |

### Progressive Difficulty

The minimum group size required for a blast increases as the player scores more points:

| Grid Size | Starting Threshold | Maximum Threshold |
|-----------|-------------------|-------------------|
| 8×8 | 8 | 12 |
| 9×9 | 10 | 14 |
| 10×10 | 12 | 16 |
| 12×12 | 16 | 20 |

The threshold increases by **1 for every 500 points** scored, up to the cap.

### Statistics Tracked

**Per Game:**
- Score, blasts triggered, pieces placed, max combo

**Lifetime (persistent):**
- Total games played, total score, total blasts, total pieces placed, highest combo, highest single-game score

**High Scores (per mode):**
- Classic high score, Daily Challenge high score, Blast Rush high score

---

## 7. Skins System

### Overview

Skins are cosmetic color themes that change the appearance of blocks on the grid. Each skin defines custom colors for all 6 block types plus their dark (stroke) variants.

### Available Skins

| ID | Name | Unlock Condition |
|----|------|-----------------|
| `default` | Default | Always unlocked |
| `neon` | Neon | Play 10 games |
| `pastel` | Pastel | Score 1,000+ in a single game |
| `retro` | Retro | Trigger 100 total blasts |
| `monochrome` | Monochrome | Play 50 games |
| `galaxy` | Galaxy | Score 5,000+ AND trigger 500+ total blasts |

### Skin Picker UI

- Accessed via Settings > Block Skins
- 2-column grid of skin cards
- Each card shows: name, 6-color palette preview (circles), lock/unlock status
- Locked skins display a lock icon + unlock condition text
- Active skin shows a green checkmark + "Active" label

---

## 8. UI Screens & Navigation

### 8.1 Onboarding (First Launch Only)

4-page animated tutorial, gated by `@AppStorage("hasSeenOnboarding")`:

| Page | Title | Content |
|------|-------|---------|
| 1 | PLACE PIECES | Animated L-piece sliding onto a mini 5x5 grid |
| 2 | MATCH COLORS | Color cluster highlighting and blasting animation |
| 3 | CHAIN PUSH | Cluster blast pushing surrounding blocks outward |
| 4 | USE THE BOMB | Bomb dropping on 7x7 grid, clearing a 6x6 area |

Each page has a looping SwiftUI animation. Navigation via NEXT/LET'S PLAY button and page dots. Skip button on non-final pages.

### 8.2 Main Menu

- **Title:** "STACK &" / "BLAST" (coral accent)
- **Buttons:** PLAY (Classic), DAILY CHALLENGE, BLAST RUSH
- **Top-right icons:** Stats (chart.bar.fill), Settings (gearshape.fill)
- All game buttons disabled when offline (NetworkMonitor)
- Daily Challenge button shows completion state after playing

### 8.3 Game View

- SpriteKit scene hosted in SwiftUI via `SpriteView` (`.resizeFill`)
- **HUD overlay (top):** Score, GOAL (current minimum group size), Combo counter (when active), Timer (timed modes), Pause button
- Score uses animated `.numericText()` content transition
- Timer uses monospaced font with urgency pulsing under 10 seconds

### 8.4 Pause Menu

Semi-transparent overlay with 4 buttons:
- **RESUME** (green)
- **SETTINGS** (gray)
- **RESTART** (blue)
- **QUIT** (purple)

### 8.5 Game Over

Modal overlay with dimmed background:
- Score (large coral number)
- Stat row: blasts, best combo, pieces placed
- **USE BOMB** button (gradient orange-red, flame icon, "Watch ad to clear 6x6 area") -- hidden after use
- **PLAY AGAIN** button (coral)
- **MAIN MENU** text button

### 8.6 Settings

| Section | Controls |
|---------|----------|
| Preferences | Sound toggle, Haptics toggle, Colorblind Mode toggle |
| Grid Size | Segmented picker: 8×8, 9×9, 10×10, 12×12 |
| Cosmetics | Block Skins button → SkinPickerView |
| Power-Ups Legend | Lists all 3 power-ups with symbols and descriptions |
| Links | Privacy Policy, Terms of Use, FAQ & Support, Contact Us |

Grid size change takes effect on the next new game.

### 8.7 Stats

- 2-column grid of stat cards: Games Played, Total Score, Total Blasts, Pieces Placed, Best Combo, Best Score
- High Scores section: Classic, Daily Challenge, Blast Rush
- Large numbers formatted with K/M suffixes

---

## 9. SpriteKit Rendering

### Layout

- **Background:** #1E272E (deep charcoal)
- **Grid:** Centered checkerboard with alternating dark gray shades (#2D3436 / slightly darker)
- **Tray:** Subtle background pill at bottom with pieces rendered at 0.6x scale
- Cell size calculated to fit both width and height constraints
- iPad grid is capped so it doesn't fill the entire screen

### Z-Ordering

| Z-Position | Content |
|-----------|---------|
| 0 | Grid checkerboard background |
| 1 | Block sprites + tray node |
| 2 | Ghost preview / bomb preview nodes |
| 4-7 | Shockwave rings, particles, flash effects |
| 10 | Dragged piece node |
| 14-16 | Power-up effect overlays (flash lines, arrows, color bomb) |
| 20 | Combo overlay text |

### Block Rendering

- `SKShapeNode` with rounded rectangle (cornerRadius: 4)
- Colors from active skin via `SkinManager`
- Stroke = dark variant of fill color
- Inner highlight strip (top 30%, white 12% opacity) for 3D bevel effect
- **Colorblind mode:** Unicode symbol label centered on block
- **Power-up blocks:** Additional pulsing icon overlay (scale 0.9-1.2)

### Block Node Management

- `blockNodes: [UUID: SKShapeNode]` dictionary for O(1) lookup
- `updateGrid()` diffs current nodes vs. new grid state
- Adds new, removes deleted, repositions moved blocks

### Blast Animation Sequence

For each blast event in cascade order:

1. **Detonate:** Flash blocks white → scale up + fade out (0.25s)
2. **Particles:** 6-8 color-matched rectangular particles per cell, flying outward
3. **Center flash:** White circle at group center, expanding and fading
4. **Screen shake:** Grid node shake (amplitude proportional to group size)
5. **Shockwave ring:** Expanding circle from group center, tinted to group color
6. **Push animation:** Blocks slide to new positions (0.2s easeOut); off-grid blocks slide away and fade
7. **Pause:** 0.15s between cascade levels

### Power-Up Animations

| Type | Visual |
|------|--------|
| Row Blast | Bright yellow horizontal bar expanding across row + arrow symbol |
| Column Blast | Bright cyan vertical bar expanding down column + arrow symbol |
| Color Bomb | Glowing colored circles at target positions + large rotating star at grid center |

### Bomb Explosion Animation

- Flash white → red → shrink + fade (all blocks in 6x6 area)
- Fire-colored particles (orange, red, yellow) at each cleared position
- Heavy screen shake (intensity 12)
- Large expanding orange shockwave ring from bomb center

---

## 10. Audio System

### Architecture

- **Engine:** `AVAudioEngine` with a mixer node and 8 concurrent `AVAudioPlayerNode` channels
- **Generation:** All sounds are **procedurally generated as PCM buffers** at initialization time (no audio files in the bundle)
- **Waveform:** "warmWave" blend = 60% sine + 25% triangle + 15% second harmonic
- **Sample Rate:** 44,100 Hz, mono
- **Simulator-safe:** Gracefully handles missing audio hardware

### Sound Effects

| Sound | Description | Volume |
|-------|------------|--------|
| Pickup | Warm ping, pitch varies by piece size (1200-1450 Hz) | 0.12 |
| Placement | Low-frequency thud (160 Hz + noise burst) | 0.30 |
| Line Complete | Ascending C5-E5-G5 warm tones | 0.25 |
| Blast | Descending sweep (200→60 Hz) + filtered noise whoosh | 0.40 |
| Swap | Ascending sweep (400→800 Hz) | 0.25 |
| Cascade (Lv 0) | Single C5 tone | 0.20 |
| Cascade (Lv 1) | C5 + G5 chord | 0.30 |
| Cascade (Lv 2) | C5 + E5 + G5 chord | 0.40 |
| Cascade (Lv 3+) | C5 + E5 + G5 + C6 chord | 0.50 |
| Cascade (Lv 4+) | Above chord + ascending sweep overlay | 0.50 |
| Game Over | Slow descending sweep (330→131 Hz, 1.2s) | 0.35 |
| Row Blast | Fast ascending sweep (200→1200 Hz) | 0.30 |
| Column Blast | Fast descending sweep (1200→200 Hz) | 0.30 |
| Color Bomb | Rapid C5-E5-G5-C6 arpeggio (30ms per note) | 0.30 |

---

## 11. Haptic Feedback

Uses `UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator`. Checks hardware haptics support before initializing. Toggleable via Settings.

| Event | Feedback Type |
|-------|--------------|
| Pickup | Impact (light) |
| Placement | Impact (medium) |
| Blast | Impact (heavy) |
| Cascade | Notification (success) |

---

## 12. Ad Integration

### Setup

- **SDK:** Google Mobile Ads (AdMob) v11.2.0+
- **App ID:** `ca-app-pub-2741592186352961~7671478866`
- **Rewarded Ad Unit:** `ca-app-pub-2741592186352961/8805323485`

### Flow

1. **ATT Prompt:** `ATTrackingManager.requestTrackingAuthorization` fires 1 second after first UI appearance
2. **SDK Init:** Google Mobile Ads SDK initializes regardless of ATT choice
3. **Pre-loading:** A rewarded ad is pre-loaded after SDK init and reloaded after each dismissal/failure
4. **Presentation:** When the player taps USE BOMB on game over, the ad is presented. If not yet loaded, it loads first then presents.
5. **Reward:** On successful completion, the player enters bomb placement mode

### Ad Usage Description

> "This allows us to show you relevant ads and support free gameplay."

---

## 13. Data Persistence

All data is stored locally in `UserDefaults`. No cloud sync, no user accounts.

### Settings (SettingsManager)

| Key | Default | Type | Description |
|-----|---------|------|-------------|
| `isSoundEnabled` | `true` | Bool | Sound effects toggle |
| `isHapticsEnabled` | `true` | Bool | Haptic feedback toggle |
| `isColorblindMode` | `false` | Bool | Show symbols on blocks |
| `activeSkinID` | `"default"` | String | Currently selected skin |
| `gridSize` | `9` | Int | Grid dimension (8, 9, 10, or 12) |

### High Scores (ScoreManager)

| Key | Description |
|-----|-------------|
| `classicHighScore` | Best Classic mode score |
| `blastRushHighScore` | Best Blast Rush score |
| `dailyChallengeHighScore` | Best Daily Challenge score |

### Lifetime Stats (StatsManager)

| Key | Description |
|-----|-------------|
| `stats_totalGamesPlayed` | Total games played |
| `stats_totalScore` | Cumulative score across all games |
| `stats_totalBlasts` | Total blasts triggered |
| `stats_totalPiecesPlaced` | Total pieces placed |
| `stats_highestCombo` | Best combo ever achieved |
| `stats_highestSingleGameScore` | Highest single-game score |

### Other

| Key | Description |
|-----|-------------|
| `hasSeenOnboarding` | Whether onboarding has been completed |
| `lastDailyChallengeDate` | Date string (yyyy-MM-dd) of last daily challenge |

---

## 14. Privacy & Data Handling

### PrivacyInfo.xcprivacy

| Field | Value |
|-------|-------|
| NSPrivacyTracking | `true` |
| Tracking Domains | `googleads.g.doubleclick.net`, `googlesyndication.com`, `app-measurement.com` |
| Collected Data Type | Device ID (NSPrivacyCollectedDataTypeDeviceID) |
| Linked to User | No |
| Used for Tracking | Yes |
| Purpose | Third-party advertising |
| Accessed APIs | UserDefaults (reason CA92.1) |

### Summary

- **The app itself** collects no personal data. All gameplay data is stored locally in UserDefaults.
- **Google AdMob SDK** collects Device ID (IDFA), coarse location, usage data, and diagnostics for advertising purposes. This data is not linked to user identity.

---

## 15. Configuration & Constants

### Color Palette

| Color | Hex | RGB |
|-------|-----|-----|
| Coral | `#E17055` | (225, 112, 85) |
| Blue | `#0984E3` | (9, 132, 227) |
| Purple | `#6C5CE7` | (108, 92, 231) |
| Green | `#00B894` | (0, 184, 148) |
| Yellow | `#FDCB6E` | (253, 203, 110) |
| Pink | `#FD79A8` | (253, 121, 168) |
| Background | `#1E272E` | (30, 39, 46) |
| Grid Light | `#2D3436` | (45, 52, 54) |
| Accent | `#E17055` | Coral (same as block coral) |

### Colorblind Symbols

| Color | Symbol |
|-------|--------|
| Coral | ● (filled circle) |
| Blue | ■ (filled square) |
| Purple | ▲ (filled triangle) |
| Green | ◆ (filled diamond) |
| Yellow | ★ (filled star) |
| Pink | ♥ (heart) |

### Timing Constants

| Constant | Value |
|----------|-------|
| Placement bounce duration | 0.15s |
| Detonate flash duration | 0.10s |
| Shockwave fade duration | 0.40s |
| Push animation duration | 0.20s |
| Cascade pause duration | 0.15s |
| Daily Challenge duration | 60s |
| Blast Rush initial time | 90s |

### Game Constants

| Constant | Value |
|----------|-------|
| Points per cell placed | 1 |
| Base blast score per cell | 20 |
| Group size increase interval | 500 points |
| Max cascade depth | 10 |
| Pieces per tray | 3 |
| Power-up spawn interval | Every 8 pieces |
| Bomb clear area | 6×6 (±2 rows, ±3 cols) |
| Blast Rush time bonus | +5s per blast |

### Blast Size Bonuses

| Group Size | Bonus Points |
|-----------|-------------|
| At threshold | 0 |
| Threshold + 1 | +50 |
| Threshold + 2 | +150 |
| Threshold + 4 | +300 |

---

## 16. File Structure

```
StackShatter/
├── project.yml                          # XcodeGen project specification
├── generate_icon.swift                  # CoreGraphics app icon generator
├── AppStore_Release_Documentation.md    # App Store listing metadata
├── Docs/
│   ├── StackAndBlast_GDD.docx           # Game Design Document
│   └── GAME_DOCUMENTATION.md            # This file
├── StackAndBlast.xcodeproj/             # Generated Xcode project
└── StackAndBlast/
    ├── Info.plist                        # App configuration
    ├── PrivacyInfo.xcprivacy             # Privacy nutrition label
    ├── App/
    │   ├── StackAndBlastApp.swift        # @main entry point
    │   └── ContentView.swift            # Root navigation controller
    ├── Engine/
    │   ├── GameEngine.swift             # Core game logic (grid, placement, scoring)
    │   ├── BlastResolver.swift          # Flood-fill group detection + chain-push
    │   └── PieceGenerator.swift         # Weighted random piece generation + seeded RNG
    ├── Models/
    │   ├── Block.swift                  # Block model (color, position, powerUp, UUID)
    │   ├── Piece.swift                  # Polyomino piece model (cells, color)
    │   ├── PieceDefinitions.swift       # 24 piece templates with spawn weights
    │   ├── GridPosition.swift           # Row/col coordinate with bounds checking
    │   ├── GameState.swift              # Enum: menu, playing, blasting, gameOver, paused
    │   ├── GameConstants.swift          # All tuning constants
    │   ├── BlastEvent.swift             # Blast result struct
    │   └── PowerUpType.swift            # 3 power-up types
    ├── Extensions/
    │   ├── BlockColor+UIColor.swift     # UIColor mapping for SpriteKit
    │   ├── BlockColor+Accessibility.swift  # Colorblind symbols
    │   └── Color+Theme.swift            # SwiftUI Color palette
    ├── Services/
    │   ├── AdManager.swift              # Google AdMob rewarded ads
    │   ├── AudioManager.swift           # Procedural PCM audio synthesis
    │   ├── HapticManager.swift          # Core Haptics feedback
    │   ├── NetworkMonitor.swift         # Connectivity tracking
    │   ├── ScoreManager.swift           # High score persistence
    │   ├── SettingsManager.swift        # User preferences
    │   ├── SkinManager.swift            # Cosmetic skin themes
    │   └── StatsManager.swift           # Lifetime statistics
    ├── ViewModels/
    │   └── GameViewModel.swift          # Bridges GameEngine to views
    ├── Views/
    │   ├── Game/
    │   │   ├── GameScene.swift          # SpriteKit scene rendering + touch
    │   │   └── GameView.swift           # SwiftUI host + HUD overlay
    │   ├── GameOver/
    │   │   └── GameOverView.swift       # Game over modal
    │   ├── Menu/
    │   │   └── MenuView.swift           # Main menu + GameMode enum
    │   ├── Onboarding/
    │   │   └── OnboardingView.swift     # 4-page tutorial
    │   ├── Settings/
    │   │   ├── SettingsView.swift       # Settings screen
    │   │   └── SkinPickerView.swift     # Skin selection grid
    │   └── Stats/
    │       └── StatsView.swift          # Lifetime stats display
    └── Resources/
        └── Assets.xcassets/
            ├── AccentColor.colorset/    # Coral (#E17055)
            └── AppIcon.appiconset/      # 1024x1024 generated icon
```

**Total Swift source files: 28**

---

## 17. Dependencies

### SDK Frameworks

| Framework | Usage |
|-----------|-------|
| SpriteKit | Game board rendering and animations |
| AVFoundation | Procedural audio via AVAudioEngine |
| CoreHaptics | Haptic feedback |
| AppTrackingTransparency | ATT prompt for ad tracking |
| GameKit | Linked but **not used** (no Game Center integration) |
| StoreKit | Linked but **not used** (no in-app purchases) |

### Swift Packages (SPM)

| Package | Version | Purpose |
|---------|---------|---------|
| Google Mobile Ads (AdMob) | 11.2.0+ (resolved: 11.13.0) | Rewarded video ads |
| Google User Messaging Platform | Transitive (resolved: 2.7.0) | GDPR consent (via AdMob) |

---

## 18. Design Decisions & Notes

### Notable Architectural Choices

1. **Zero audio assets** -- All sound effects are procedurally generated as PCM buffers at init time. This eliminates asset management overhead and keeps the bundle size minimal while providing zero-latency playback.

2. **Dark theme enforced** -- `.preferredColorScheme(.dark)` is set on the root view. The entire UI is designed for dark mode only.

3. **No unit tests** -- No test target or test files exist in the project.

4. **No localization** -- All strings are hardcoded in English.

5. **No cloud sync** -- All data (scores, stats, settings) is device-local via UserDefaults.

6. **No user accounts** -- No authentication, no social features, no leaderboards.

7. **Single monetization point** -- Only one rewarded ad placement (bomb continue). No banner ads, interstitials, or in-app purchases.

8. **Unused frameworks** -- GameKit and StoreKit are linked as SDK dependencies but have no corresponding code. These may be placeholders for future Game Center leaderboards and IAP.

9. **Deterministic daily challenge** -- Uses SplitMix64 RNG seeded with FNV-1a hash of the date string, ensuring identical piece sequences worldwide.

10. **Network gating** -- Menu buttons are disabled when offline because the rewarded ad requires connectivity to pre-load.

### Known Limitations

- No landscape support
- No iCloud data sync between devices
- No Game Center leaderboards (framework linked but unused)
- No in-app purchases (framework linked but unused)
- No localization beyond English
- No test coverage
- Grid size change requires starting a new game
