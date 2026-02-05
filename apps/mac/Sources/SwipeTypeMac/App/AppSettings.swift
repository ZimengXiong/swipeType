//
//  AppSettings.swift
//  SwipeTypeMac
//

import Carbon.HIToolbox
import CoreGraphics
import Foundation

enum AppSettings {
    enum Keys {
        static let hotkeyPreset = "hotkeyPreset"
        static let showMenuBarItem = "showMenuBarItem"

        static let customToggleHotkeyKeyCode = "customToggleHotkeyKeyCode"
        static let customToggleHotkeyModifiers = "customToggleHotkeyModifiers"

        static let autoCommitAfterPause = "autoCommitAfterPause"
        static let debounceDelaySeconds = "debounceDelaySeconds"
        static let requirePauseBeforeCommit = "requirePauseBeforeCommit"
        static let insertTrailingSpace = "insertTrailingSpace"
        static let overlayBackgroundOpacity = "overlayBackgroundOpacity"
        static let playSwipeAnimation = "playSwipeAnimation"
    }

    enum ModifierBits {
        static let shift = 1 << 0
        static let control = 1 << 1
        static let option = 1 << 2
        static let command = 1 << 3
    }

    enum Defaults {
        static let hotkeyPreset: ToggleHotkeyPreset = .shiftTab
        static let showMenuBarItem = false

        static let customToggleHotkeyKeyCode = kVK_ANSI_S
        static let customToggleHotkeyModifiers = ModifierBits.control | ModifierBits.option

        static let autoCommitAfterPause = true
        static let debounceDelaySeconds: Double = 0.45
        static let requirePauseBeforeCommit = true
        static let insertTrailingSpace = true
        static let overlayBackgroundOpacity: Double = 0.72
        static let playSwipeAnimation = true
    }

    struct Hotkey: Sendable {
        let keyCode: Int
        let modifiers: CGEventFlags
    }

    enum ToggleHotkeyPreset: String, CaseIterable, Identifiable {
        case shiftTab
        case optionTab
        case controlOptionSpace
        case custom
        case none

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .shiftTab:
                return "Shift+Tab"
            case .optionTab:
                return "Option+Tab"
            case .controlOptionSpace:
                return "Control+Option+Space"
            case .custom:
                return "Custom"
            case .none:
                return "None"
            }
        }

        var hintSymbol: String {
            switch self {
            case .shiftTab:
                return "⇧⇥"
            case .optionTab:
                return "⌥⇥"
            case .controlOptionSpace:
                return "⌃⌥␠"
            case .custom:
                return "Custom"
            case .none:
                return "Menu"
            }
        }

        fileprivate var hotkey: Hotkey? {
            switch self {
            case .shiftTab:
                return Hotkey(keyCode: kVK_Tab, modifiers: .maskShift)
            case .optionTab:
                return Hotkey(keyCode: kVK_Tab, modifiers: .maskAlternate)
            case .controlOptionSpace:
                return Hotkey(keyCode: kVK_Space, modifiers: [.maskControl, .maskAlternate])
            case .custom:
                return AppSettings.customToggleHotkey
            case .none:
                return nil
            }
        }
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Keys.hotkeyPreset: Defaults.hotkeyPreset.rawValue,
            Keys.showMenuBarItem: Defaults.showMenuBarItem,

            Keys.customToggleHotkeyKeyCode: Defaults.customToggleHotkeyKeyCode,
            Keys.customToggleHotkeyModifiers: Defaults.customToggleHotkeyModifiers,

            Keys.autoCommitAfterPause: Defaults.autoCommitAfterPause,
            Keys.debounceDelaySeconds: Defaults.debounceDelaySeconds,
            Keys.requirePauseBeforeCommit: Defaults.requirePauseBeforeCommit,
            Keys.insertTrailingSpace: Defaults.insertTrailingSpace,
            Keys.overlayBackgroundOpacity: Defaults.overlayBackgroundOpacity,
            Keys.playSwipeAnimation: Defaults.playSwipeAnimation,
        ])
    }

    static func resetToDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.hotkeyPreset)
        defaults.removeObject(forKey: Keys.showMenuBarItem)

        defaults.removeObject(forKey: Keys.customToggleHotkeyKeyCode)
        defaults.removeObject(forKey: Keys.customToggleHotkeyModifiers)

        defaults.removeObject(forKey: Keys.autoCommitAfterPause)
        defaults.removeObject(forKey: Keys.debounceDelaySeconds)
        defaults.removeObject(forKey: Keys.requirePauseBeforeCommit)
        defaults.removeObject(forKey: Keys.insertTrailingSpace)
        defaults.removeObject(forKey: Keys.overlayBackgroundOpacity)
        defaults.removeObject(forKey: Keys.playSwipeAnimation)
        defaults.synchronize()
    }

    static var hotkeyPreset: ToggleHotkeyPreset {
        let raw = UserDefaults.standard.string(forKey: Keys.hotkeyPreset) ?? Defaults.hotkeyPreset.rawValue
        return ToggleHotkeyPreset(rawValue: raw) ?? Defaults.hotkeyPreset
    }

    static var showMenuBarItem: Bool {
        (UserDefaults.standard.object(forKey: Keys.showMenuBarItem) as? Bool) ?? Defaults.showMenuBarItem
    }

    static var customToggleHotkeyKeyCode: Int {
        (UserDefaults.standard.object(forKey: Keys.customToggleHotkeyKeyCode) as? Int) ?? Defaults.customToggleHotkeyKeyCode
    }

    static var customToggleHotkeyModifierMask: Int {
        (UserDefaults.standard.object(forKey: Keys.customToggleHotkeyModifiers) as? Int) ?? Defaults.customToggleHotkeyModifiers
    }

    static var autoCommitAfterPause: Bool {
        (UserDefaults.standard.object(forKey: Keys.autoCommitAfterPause) as? Bool) ?? Defaults.autoCommitAfterPause
    }

    static var requirePauseBeforeCommit: Bool {
        (UserDefaults.standard.object(forKey: Keys.requirePauseBeforeCommit) as? Bool) ?? Defaults.requirePauseBeforeCommit
    }

    static var insertTrailingSpace: Bool {
        (UserDefaults.standard.object(forKey: Keys.insertTrailingSpace) as? Bool) ?? Defaults.insertTrailingSpace
    }

    static var playSwipeAnimation: Bool {
        (UserDefaults.standard.object(forKey: Keys.playSwipeAnimation) as? Bool) ?? Defaults.playSwipeAnimation
    }

    static var debounceDelay: TimeInterval {
        let value = (UserDefaults.standard.object(forKey: Keys.debounceDelaySeconds) as? Double) ?? Defaults.debounceDelaySeconds
        return min(max(value, 0.05), 5.0)
    }

    static var overlayBackgroundOpacity: Double {
        let value = (UserDefaults.standard.object(forKey: Keys.overlayBackgroundOpacity) as? Double) ?? Defaults.overlayBackgroundOpacity
        return min(max(value, 0.0), 0.95)
    }

    static var toggleHotkeyDisplayName: String? {
        switch hotkeyPreset {
        case .none:
            return nil
        case .custom:
            guard let hotkey = customToggleHotkey else { return nil }
            return hotkeyDisplayName(keyCode: hotkey.keyCode, modifierMask: customToggleHotkeyModifierMask)
        default:
            return hotkeyPreset.displayName
        }
    }

    static var toggleHotkeyHintSymbol: String {
        switch hotkeyPreset {
        case .none:
            return "Menu"
        case .custom:
            guard let hotkey = customToggleHotkey else { return "Menu" }
            return hotkeyHintSymbol(keyCode: hotkey.keyCode, modifierMask: customToggleHotkeyModifierMask)
        default:
            return hotkeyPreset.hintSymbol
        }
    }

    static func committedText(for word: String) -> String {
        insertTrailingSpace ? (word + " ") : word
    }

    static func hotkeyDisplayName(keyCode: Int, modifierMask: Int) -> String {
        let parts = modifierDisplayNames(for: modifierMask)
        let keyName = keyDisplayName(for: keyCode)
        if parts.isEmpty {
            return keyName
        }
        return (parts + [keyName]).joined(separator: "+")
    }

    static func hotkeyHintSymbol(keyCode: Int, modifierMask: Int) -> String {
        modifierSymbols(for: modifierMask) + keySymbol(for: keyCode)
    }

    private static let relevantModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]

    private static func normalizedModifiers(_ flags: CGEventFlags) -> CGEventFlags {
        flags.intersection(relevantModifiers)
    }

    static func matchesToggleOverlayHotkey(keyCode: Int, flags: CGEventFlags) -> Bool {
        guard let hotkey = hotkeyPreset.hotkey else { return false }
        return keyCode == hotkey.keyCode && normalizedModifiers(flags) == hotkey.modifiers
    }

    // MARK: - Custom Hotkey

    private static var customToggleHotkey: Hotkey? {
        let mask = customToggleHotkeyModifierMask
        guard mask != 0 else { return nil }
        return Hotkey(keyCode: customToggleHotkeyKeyCode, modifiers: modifierFlags(for: mask))
    }

    private static func modifierFlags(for mask: Int) -> CGEventFlags {
        var flags: CGEventFlags = []

        if (mask & ModifierBits.shift) != 0 { flags.insert(.maskShift) }
        if (mask & ModifierBits.control) != 0 { flags.insert(.maskControl) }
        if (mask & ModifierBits.option) != 0 { flags.insert(.maskAlternate) }
        if (mask & ModifierBits.command) != 0 { flags.insert(.maskCommand) }

        return flags
    }

    private static func modifierDisplayNames(for mask: Int) -> [String] {
        var parts: [String] = []
        if (mask & ModifierBits.command) != 0 { parts.append("Command") }
        if (mask & ModifierBits.control) != 0 { parts.append("Control") }
        if (mask & ModifierBits.option) != 0 { parts.append("Option") }
        if (mask & ModifierBits.shift) != 0 { parts.append("Shift") }
        return parts
    }

    private static func modifierSymbols(for mask: Int) -> String {
        var out = ""
        if (mask & ModifierBits.control) != 0 { out.append("⌃") }
        if (mask & ModifierBits.option) != 0 { out.append("⌥") }
        if (mask & ModifierBits.shift) != 0 { out.append("⇧") }
        if (mask & ModifierBits.command) != 0 { out.append("⌘") }
        return out
    }

    struct KeyOption: Identifiable, Hashable {
        var id: Int { keyCode }
        let keyCode: Int
        let displayName: String
        let symbol: String
    }

    static let customHotkeyKeyOptions: [KeyOption] = {
        var items: [KeyOption] = []

        func add(_ keyCode: Int, _ name: String, symbol: String? = nil) {
            items.append(KeyOption(keyCode: keyCode, displayName: name, symbol: symbol ?? name))
        }

        add(kVK_Tab, "Tab", symbol: "⇥")
        add(kVK_Space, "Space", symbol: "␠")
        add(kVK_Return, "Return", symbol: "↵")
        add(kVK_Escape, "Escape", symbol: "⎋")

        add(kVK_ANSI_A, "A")
        add(kVK_ANSI_B, "B")
        add(kVK_ANSI_C, "C")
        add(kVK_ANSI_D, "D")
        add(kVK_ANSI_E, "E")
        add(kVK_ANSI_F, "F")
        add(kVK_ANSI_G, "G")
        add(kVK_ANSI_H, "H")
        add(kVK_ANSI_I, "I")
        add(kVK_ANSI_J, "J")
        add(kVK_ANSI_K, "K")
        add(kVK_ANSI_L, "L")
        add(kVK_ANSI_M, "M")
        add(kVK_ANSI_N, "N")
        add(kVK_ANSI_O, "O")
        add(kVK_ANSI_P, "P")
        add(kVK_ANSI_Q, "Q")
        add(kVK_ANSI_R, "R")
        add(kVK_ANSI_S, "S")
        add(kVK_ANSI_T, "T")
        add(kVK_ANSI_U, "U")
        add(kVK_ANSI_V, "V")
        add(kVK_ANSI_W, "W")
        add(kVK_ANSI_X, "X")
        add(kVK_ANSI_Y, "Y")
        add(kVK_ANSI_Z, "Z")

        add(kVK_ANSI_0, "0")
        add(kVK_ANSI_1, "1")
        add(kVK_ANSI_2, "2")
        add(kVK_ANSI_3, "3")
        add(kVK_ANSI_4, "4")
        add(kVK_ANSI_5, "5")
        add(kVK_ANSI_6, "6")
        add(kVK_ANSI_7, "7")
        add(kVK_ANSI_8, "8")
        add(kVK_ANSI_9, "9")

        add(kVK_ANSI_Grave, "`")
        add(kVK_ANSI_Minus, "-")
        add(kVK_ANSI_Equal, "=")
        add(kVK_ANSI_LeftBracket, "[")
        add(kVK_ANSI_RightBracket, "]")
        add(kVK_ANSI_Backslash, "\\")
        add(kVK_ANSI_Semicolon, ";")
        add(kVK_ANSI_Quote, "'")
        add(kVK_ANSI_Comma, ",")
        add(kVK_ANSI_Period, ".")
        add(kVK_ANSI_Slash, "/")

        return items
    }()

    private static func keyOption(for keyCode: Int) -> KeyOption? {
        customHotkeyKeyOptions.first(where: { $0.keyCode == keyCode })
    }

    private static func keyDisplayName(for keyCode: Int) -> String {
        keyOption(for: keyCode)?.displayName ?? "Key \(keyCode)"
    }

    private static func keySymbol(for keyCode: Int) -> String {
        keyOption(for: keyCode)?.symbol ?? "?"
    }
}
