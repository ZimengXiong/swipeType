//
//  SettingsView.swift
//  SwipeTypeMac
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.Keys.hotkeyPreset) private var hotkeyPresetRaw = AppSettings.Defaults.hotkeyPreset.rawValue
    @AppStorage(AppSettings.Keys.showMenuBarItem) private var showMenuBarItem = AppSettings.Defaults.showMenuBarItem

    @AppStorage(AppSettings.Keys.customToggleHotkeyKeyCode) private var customToggleHotkeyKeyCode = AppSettings.Defaults.customToggleHotkeyKeyCode
    @AppStorage(AppSettings.Keys.customToggleHotkeyModifiers) private var customToggleHotkeyModifiers = AppSettings.Defaults.customToggleHotkeyModifiers

    @AppStorage(AppSettings.Keys.autoCommitAfterPause) private var autoCommitAfterPause = AppSettings.Defaults.autoCommitAfterPause
    @AppStorage(AppSettings.Keys.debounceDelaySeconds) private var debounceDelaySeconds = AppSettings.Defaults.debounceDelaySeconds
    @AppStorage(AppSettings.Keys.requirePauseBeforeCommit) private var requirePauseBeforeCommit = AppSettings.Defaults.requirePauseBeforeCommit
    @AppStorage(AppSettings.Keys.insertTrailingSpace) private var insertTrailingSpace = AppSettings.Defaults.insertTrailingSpace
    @AppStorage(AppSettings.Keys.overlayBackgroundOpacity) private var overlayBackgroundOpacity = AppSettings.Defaults.overlayBackgroundOpacity
    @AppStorage(AppSettings.Keys.playSwipeAnimation) private var playSwipeAnimation = AppSettings.Defaults.playSwipeAnimation

    @State private var isShowingResetConfirmation = false

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (v?, b?):
            return "Version \(v) (\(b))"
        case let (v?, nil):
            return "Version \(v)"
        case let (nil, b?):
            return "Build \(b)"
        default:
            return ""
        }
    }

    private var hotkeyPreset: AppSettings.ToggleHotkeyPreset {
        AppSettings.ToggleHotkeyPreset(rawValue: hotkeyPresetRaw) ?? AppSettings.Defaults.hotkeyPreset
    }

    private var isCustomHotkeyValid: Bool {
        customToggleHotkeyModifiers != 0
    }

    private var isMenuBarRequired: Bool {
        switch hotkeyPreset {
        case .none:
            return true
        case .custom:
            return !isCustomHotkeyValid
        default:
            return false
        }
    }

    private func modifierBinding(_ bit: Int) -> Binding<Bool> {
        Binding(
            get: { (customToggleHotkeyModifiers & bit) != 0 },
            set: { isOn in
                if isOn {
                    customToggleHotkeyModifiers |= bit
                } else {
                    customToggleHotkeyModifiers &= ~bit
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Toggle overlay", selection: $hotkeyPresetRaw) {
                        ForEach(AppSettings.ToggleHotkeyPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    if hotkeyPreset == .none {
                        Text("Hotkey disabled. Use the menu bar icon to toggle the overlay.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if hotkeyPreset == .custom {
                        LabeledContent("Key") {
                            Picker("Key", selection: $customToggleHotkeyKeyCode) {
                                ForEach(AppSettings.customHotkeyKeyOptions) { option in
                                    Text(option.displayName).tag(option.keyCode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }

                        LabeledContent("Modifiers") {
                            HStack(spacing: 4) {
                                ModifierToggle(symbol: "⌃", name: "Control", isOn: modifierBinding(AppSettings.ModifierBits.control))
                                ModifierToggle(symbol: "⌥", name: "Option", isOn: modifierBinding(AppSettings.ModifierBits.option))
                                ModifierToggle(symbol: "⇧", name: "Shift", isOn: modifierBinding(AppSettings.ModifierBits.shift))
                                ModifierToggle(symbol: "⌘", name: "Command", isOn: modifierBinding(AppSettings.ModifierBits.command))
                            }
                        }

                        LabeledContent("Preview") {
                            Text(AppSettings.hotkeyHintSymbol(keyCode: customToggleHotkeyKeyCode, modifierMask: customToggleHotkeyModifiers))
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        if !isCustomHotkeyValid {
                            Text("Select at least one modifier.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Label("Hotkey", systemImage: "keyboard")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Section {
                    Toggle("Show menu bar icon", isOn: $showMenuBarItem)
                        .disabled(isMenuBarRequired)

                    if isMenuBarRequired {
                        Text("Menu bar icon is required when no hotkey is configured.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Menu Bar", systemImage: "menubar.rectangle")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Section {
                    Toggle("Auto-commit after pause", isOn: $autoCommitAfterPause)
                    Toggle("Require pause before Enter/1-5", isOn: $requirePauseBeforeCommit)
                    Toggle("Add space after committed word", isOn: $insertTrailingSpace)
                    Toggle("Play swipe animation after pause", isOn: $playSwipeAnimation)

                    LabeledContent("Pause duration") {
                        VStack(alignment: .trailing, spacing: 4) {
                            Slider(value: $debounceDelaySeconds, in: 0.15...1.2, step: 0.05)
                                .frame(width: 200)
                            Text("\(debounceDelaySeconds, specifier: "%.2f")s")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Typing", systemImage: "square.and.pencil")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Section {
                    LabeledContent("Background dim") {
                        VStack(alignment: .trailing, spacing: 4) {
                            Slider(value: $overlayBackgroundOpacity, in: 0.0...0.9, step: 0.05)
                                .frame(width: 200)
                            Text("\(Int((overlayBackgroundOpacity.clamped(to: 0.0...0.9)) * 100))%")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Overlay", systemImage: "macwindow")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Section {
                    Button {
                        PermissionManager.shared.requestAccessibilityPermission()
                    } label: {
                        Label("Request Accessibility Permission", systemImage: "hand.raised.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } header: {
                    Label("Permissions", systemImage: "lock.shield")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            Image(nsImage: NSApp.applicationIconImage)
                                .resizable()
                                .frame(width: 48, height: 48)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SwipeType")
                                    .font(.headline)
                                if !appVersionText.isEmpty {
                                    Text(appVersionText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Text("A fast, lightweight swipe typing engine for macOS. Use swipe patterns to type words efficiently across any application.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Label("About", systemImage: "info.circle")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Reset to Defaults", role: .destructive) {
                    isShowingResetConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(width: 520)
        .fixedSize(horizontal: true, vertical: true)
        .onChange(of: hotkeyPresetRaw) { _ in
            if isMenuBarRequired {
                showMenuBarItem = true
            }
        }
        .onChange(of: customToggleHotkeyModifiers) { _ in
            if isMenuBarRequired {
                showMenuBarItem = true
            }
        }
        .confirmationDialog(
            "Reset all settings?",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                AppSettings.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore default settings for hotkey, typing, and overlay.")
        }
    }
}

private struct ModifierToggle: View {
    let symbol: String
    let name: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(symbol, isOn: $isOn)
            .toggleStyle(.button)
            .font(.system(.body, design: .rounded))
            .fontWeight(.medium)
            .frame(width: 32)
            .help(name)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
