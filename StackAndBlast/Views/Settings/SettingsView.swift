import SwiftUI

/// Settings screen with toggles for sound, haptics, colorblind mode, and link to skin picker.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isSoundEnabled = SettingsManager.shared.isSoundEnabled
    @State private var isHapticsEnabled = SettingsManager.shared.isHapticsEnabled
    @State private var isColorblindMode = SettingsManager.shared.isColorblindMode
    @State private var selectedGridSize = SettingsManager.shared.gridSize
    @State private var showSkinPicker = false

    private let gridSizeOptions = [8, 9, 10, 12]

    /// Called when colorblind mode changes so the scene can refresh blocks.
    var onColorblindChanged: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.118, green: 0.153, blue: 0.180)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Toggle rows
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "speaker.wave.2.fill",
                            title: "Sound",
                            isOn: $isSoundEnabled
                        )
                        Divider().background(Color.white.opacity(0.1))
                        SettingsToggleRow(
                            icon: "iphone.radiowaves.left.and.right",
                            title: "Haptics",
                            isOn: $isHapticsEnabled
                        )
                        Divider().background(Color.white.opacity(0.1))
                        SettingsToggleRow(
                            icon: "eye",
                            title: "Colorblind Mode",
                            isOn: $isColorblindMode
                        )
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Grid size picker
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "square.grid.3x3")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 30)
                            Text("Grid Size")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.white)
                        }

                        Picker("Grid Size", selection: $selectedGridSize) {
                            ForEach(gridSizeOptions, id: \.self) { size in
                                Text("\(size)x\(size)").tag(size)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Takes effect on next new game")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.gray)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Skin picker button
                    Button {
                        showSkinPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                                .font(.title3)
                            Text("BLOCK SKINS")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color(red: 0.424, green: 0.361, blue: 0.906), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Power-up legend
                    VStack(alignment: .leading, spacing: 12) {
                        Text("POWER-UPS")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)

                        Text("Special blocks spawn every 8 pieces. Blast them to trigger their effect!")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.gray.opacity(0.8))

                        ForEach(PowerUpType.allCases, id: \.rawValue) { powerUp in
                            HStack(spacing: 12) {
                                Text(powerUp.symbol)
                                    .font(.system(size: 24))
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(powerUp.name)
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    Text(powerUp.description)
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Links section
                    VStack(spacing: 0) {
                        SettingsLinkRow(icon: "doc.text", title: "Privacy Policy",
                                        url: URL(string: "https://geba89.github.io/stackandblast-web/privacy")!)
                        Divider().background(Color.white.opacity(0.1))
                        SettingsLinkRow(icon: "doc.plaintext", title: "Terms of Use",
                                        url: URL(string: "https://geba89.github.io/stackandblast-web/terms")!)
                        Divider().background(Color.white.opacity(0.1))
                        SettingsLinkRow(icon: "questionmark.circle", title: "FAQ & Support",
                                        url: URL(string: "https://geba89.github.io/stackandblast-web/faq")!)
                        Divider().background(Color.white.opacity(0.1))
                        SettingsLinkRow(icon: "envelope", title: "Contact Us",
                                        url: URL(string: "mailto:piotr@gebski.cloud")!)
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showSkinPicker) {
                SkinPickerView()
            }
            .onChange(of: isSoundEnabled) { _, newValue in
                SettingsManager.shared.isSoundEnabled = newValue
                AudioManager.shared.setSoundEnabled(newValue)
            }
            .onChange(of: isHapticsEnabled) { _, newValue in
                SettingsManager.shared.isHapticsEnabled = newValue
                HapticManager.shared.setHapticsEnabled(newValue)
            }
            .onChange(of: isColorblindMode) { _, newValue in
                SettingsManager.shared.isColorblindMode = newValue
                onColorblindChanged?()
            }
            .onChange(of: selectedGridSize) { _, newValue in
                SettingsManager.shared.gridSize = newValue
            }
        }
    }
}

// MARK: - Link Row

private struct SettingsLinkRow: View {
    let icon: String
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 30)
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Toggle Row

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 30)
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color(red: 0.0, green: 0.722, blue: 0.580))
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}
