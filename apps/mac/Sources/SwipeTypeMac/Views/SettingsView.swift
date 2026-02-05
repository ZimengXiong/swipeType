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
        Form {
            Section("Hotkey") {
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
                    }

                    LabeledContent("Modifiers") {
                        HStack(spacing: 10) {
                            Toggle("⇧", isOn: modifierBinding(AppSettings.ModifierBits.shift))
                                .toggleStyle(.button)
                                .help("Shift")
                            Toggle("⌃", isOn: modifierBinding(AppSettings.ModifierBits.control))
                                .toggleStyle(.button)
                                .help("Control")
                            Toggle("⌥", isOn: modifierBinding(AppSettings.ModifierBits.option))
                                .toggleStyle(.button)
                                .help("Option")
                            Toggle("⌘", isOn: modifierBinding(AppSettings.ModifierBits.command))
                                .toggleStyle(.button)
                                .help("Command")
                        }
                    }

                    LabeledContent("Preview") {
                        Text(AppSettings.hotkeyHintSymbol(keyCode: customToggleHotkeyKeyCode, modifierMask: customToggleHotkeyModifiers))
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }

                    if !isCustomHotkeyValid {
                        Text("Select at least one modifier.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Menu Bar") {
                Toggle("Show menu bar icon", isOn: $showMenuBarItem)
                    .disabled(isMenuBarRequired)

                if isMenuBarRequired {
                    Text("Menu bar icon is required when no hotkey is configured.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Typing") {
                Toggle("Auto-commit after pause", isOn: $autoCommitAfterPause)
                Toggle("Require pause before Enter/1-5", isOn: $requirePauseBeforeCommit)
                Toggle("Add space after committed word", isOn: $insertTrailingSpace)
                Toggle("Play swipe animation after pause", isOn: $playSwipeAnimation)

                LabeledContent("Pause duration") {
                    HStack(spacing: 10) {
                        Slider(value: $debounceDelaySeconds, in: 0.15...1.2, step: 0.05)
                            .frame(width: 220)
                        Text("\(debounceDelaySeconds, specifier: "%.2f")s")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            }

            Section("Overlay") {
                LabeledContent("Background dim") {
                    HStack(spacing: 10) {
                        Slider(value: $overlayBackgroundOpacity, in: 0.0...0.9, step: 0.05)
                            .frame(width: 220)
                        Text("\(Int((overlayBackgroundOpacity.clamped(to: 0.0...0.9)) * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section("Permissions") {
                Button("Request Accessibility Permission") {
                    PermissionManager.shared.requestAccessibilityPermission()
                }
            }

            Section("About") {
                if !appVersionText.isEmpty {
                    LabeledContent("SwipeType") {
                        Text(appVersionText)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button("Reset to Defaults", role: .destructive) {
                        isShowingResetConfirmation = true
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 520, height: 460)
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

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
