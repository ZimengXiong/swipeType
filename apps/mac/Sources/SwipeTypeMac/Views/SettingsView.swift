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
    @AppStorage(AppSettings.Keys.useTransparency) private var useTransparency = AppSettings.Defaults.useTransparency
    @AppStorage(AppSettings.Keys.playSwipeAnimation) private var playSwipeAnimation = AppSettings.Defaults.playSwipeAnimation

    @State private var isShowingResetConfirmation = false
    @State private var hasAccessibilityPermission = PermissionManager.shared.checkAccessibilityPermission()

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
        VStack(alignment: .trailing, spacing: 0) {
            HStack(alignment: .top, spacing: 24) {

                VStack(alignment: .leading, spacing: 20) {
                    settingsSection(title: "Hotkey", icon: "keyboard") {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledContent("Shortcut") {
                                Picker("Shortcut", selection: $hotkeyPresetRaw) {
                                    ForEach(AppSettings.ToggleHotkeyPreset.allCases) { preset in
                                        Text(preset.displayName).tag(preset.rawValue)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }

                            if hotkeyPreset == .none {
                                Text("Hotkey disabled. Use the menu bar icon.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 2)
                            }

                            if hotkeyPreset == .custom {
                                VStack(spacing: 10) {
                                                                LabeledContent("Key") {
                                                                    Picker("Key", selection: $customToggleHotkeyKeyCode) {
                                                                        ForEach(AppSettings.customHotkeyKeyOptions) { option in
                                                                            Text(option.displayName).tag(option.keyCode)
                                                                        }
                                                                    }
                                                                    .labelsHidden()
                                                                    .pickerStyle(.menu)
                                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                                                }
                                    
                                                                LabeledContent("Modifiers") {
                                                                    HStack(spacing: 4) {
                                                                        ModifierToggle(symbol: "⌃", name: "Control", isOn: modifierBinding(AppSettings.ModifierBits.control))
                                                                        ModifierToggle(symbol: "⌥", name: "Option", isOn: modifierBinding(AppSettings.ModifierBits.option))
                                                                        ModifierToggle(symbol: "⇧", name: "Shift", isOn: modifierBinding(AppSettings.ModifierBits.shift))
                                                                        ModifierToggle(symbol: "⌘", name: "Command", isOn: modifierBinding(AppSettings.ModifierBits.command))
                                                                    }
                                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                                                }
                                                                        LabeledContent("Preview") {
                                        Text(AppSettings.hotkeyHintSymbol(keyCode: customToggleHotkeyKeyCode, modifierMask: customToggleHotkeyModifiers))
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.primary.opacity(0.05))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                                .padding(10)
                                .background(Color.primary.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            Divider().padding(.vertical, 4)
                            
                            Toggle("Show menu bar icon", isOn: $showMenuBarItem)
                        }
                    }

                    settingsSection(title: "Typing", icon: "square.and.pencil") {
                        VStack(alignment: .leading, spacing: 12) {
                            ToggleGroup(title: "Auto-commit after pause", isOn: $autoCommitAfterPause, description: "Inserts prediction when starting a new word.")
                            ToggleGroup(title: "Require pause before select", isOn: $requirePauseBeforeCommit, description: "Prevents accidental selection while swiping.")
                            ToggleGroup(title: "Add space after word", isOn: $insertTrailingSpace, description: "Appends a space after selection.")
                            ToggleGroup(title: "Play swipe animation", isOn: $playSwipeAnimation, description: "Replays path on overlay keyboard.")

                            VStack(alignment: .leading, spacing: 4) {
                                LabeledContent("Pause duration") {
                                    HStack(spacing: 8) {
                                        Slider(value: $debounceDelaySeconds, in: 0.15...1.2, step: 0.05)
                                            .frame(width: 120)
                                        Text("\(debounceDelaySeconds, specifier: "%.2f")s")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text("Wait time before committing or animating.")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary.opacity(0.8))
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                                                HStack {
                                                    Text("Accessibility")
                                                        .font(.subheadline.bold())
                                                        .foregroundColor(.white) // Always white
                        
                                                     Image(systemName: hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                         .foregroundColor(hasAccessibilityPermission ? .green : .red)
                        
                                                    Spacer()
                        
                                                     if !hasAccessibilityPermission {
                                                         Button("Open Settings") {
                                                            PermissionManager.shared.openAccessibilitySettings() // Direct call
                                                        }
                                                        .buttonStyle(.bordered)
                                                        .controlSize(.small)
                                                    }
                                                }
                                                .padding(12)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.primary.opacity(0.03))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .frame(width: 360)
                .onAppear {
                    PermissionManager.shared.startMonitoringPermission { granted in
                        hasAccessibilityPermission = granted
                    }
                }


                VStack(alignment: .leading, spacing: 20) {
                    settingsSection(title: "Overlay", icon: "macwindow") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Use transparency", isOn: $useTransparency)
                            
                            HStack {
                                Text("Dim")
                                Spacer()
                                Slider(value: $overlayBackgroundOpacity, in: 0.0...0.9, step: 0.05)
                                    .frame(width: 120)
                                Text("\(Int(overlayBackgroundOpacity * 100))%")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Appearance Preview")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                
                                
                                VStack(spacing: 2) {
                                    // Predictions
                                    VStack(spacing: 3) {
                                        MockRow(text: "alpaca", primary: true)
                                        MockRow(text: "penguin", primary: false)
                                    }
                                    
                                    // Stats
                                    HStack {
                                        Rectangle().fill(.white.opacity(0.3)).frame(width: 45, height: 2)
                                        Spacer()
                                        Rectangle().fill(.white.opacity(0.3)).frame(width: 30, height: 2)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.top, 2)
                                    
                                    // Keyboard mock
                                    MockKeyboardView(input: "asdfghjklppokjhgfdsaxccsa")
                                        .frame(height: 52)
                                    
                                    // Footer
                                    Capsule().fill(.white.opacity(0.2)).frame(width: 60, height: 3)
                                        .padding(.bottom, 4)
                                }
                                .padding(12)
                                .frame(width: 180)
                                .background(
                                    ZStack {
                                        if useTransparency {
                                            RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.12))
                                            RoundedRectangle(cornerRadius: 12).fill(.black.opacity(overlayBackgroundOpacity))
                                        } else {
                                            RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.25 * (1.0 - overlayBackgroundOpacity / 0.9)))
                                        }
                                        RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                    }
                                )
                                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                            }
                        }
                    }

                    settingsSection(title: "About", icon: "info.circle") {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("SwipeType").font(.headline)
                                if !appVersionText.isEmpty {
                                    Text(appVersionText).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            
                            Text("A fast, lightweight swipe typing engine.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Link(destination: URL(string: "https://github.com/ZimengXiong/swipeType")!) {
                                Label("GitHub", systemImage: "link")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .frame(width: 360)
            }
            .padding(24)

            Button(role: .destructive) {
                isShowingResetConfirmation = true
            } label: {
                Text("Reset to Defaults")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.small)
            .clipShape(Capsule())
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 820)
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

    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
                        Label(title, systemImage: icon)
                            .font(.headline)
                            .foregroundStyle(.primary)
            
                                    VStack(alignment: .leading, spacing: 0) {
            
                                        content()
            
                                    }
            
                                    .padding(12)
            
                                    .frame(maxWidth: .infinity, alignment: .leading)
            
                                    .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        }
    }

    private func ToggleGroup(title: String, isOn: Binding<Bool>, description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(title, isOn: isOn)
            Text(description)
                .font(.system(size: 9))
                .foregroundStyle(.secondary.opacity(0.8))
        }
    }
}

private struct MockKeyboardView: View {
    let input: String
    
    private let keyboardLayout: [(String, CGFloat, CGFloat)] = [
        ("Q", 0, 0), ("W", 1, 0), ("E", 2, 0), ("R", 3, 0), ("T", 4, 0),
        ("Y", 5, 0), ("U", 6, 0), ("I", 7, 0), ("O", 8, 0), ("P", 9, 0),
        ("A", 1, 1), ("S", 2, 1), ("D", 3, 1), ("F", 4, 1), ("G", 5, 1),
        ("H", 6, 1), ("J", 7, 1), ("K", 8, 1), ("L", 9, 1),
        ("Z", 1.5, 2), ("X", 2.5, 2), ("C", 3.5, 2), ("V", 4.5, 2), ("B", 5.5, 2),
        ("N", 6.5, 2), ("M", 7.5, 2)
    ]

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.periodic(from: .now, by: 1.0/60.0)) { timeline in
                Canvas { context, size in
                    let keySize: CGFloat = 13
                    let gap: CGFloat = 3
                    
                    let totalCols: CGFloat = 10
                    let keyboardWidth = totalCols * (keySize + gap) - gap
                    let leftPad = (size.width - keyboardWidth) / 2
                    let topPad: CGFloat = 2
                    
                    func center(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                        CGPoint(
                            x: x * (keySize + gap) + keySize/2 + leftPad,
                            y: y * (keySize + gap) + keySize/2 + topPad
                        )
                    }
                    
                    // Draw Keys
                    for (_, x, y) in keyboardLayout {
                        let p = center(x, y)
                        let rect = CGRect(x: p.x - keySize/2, y: p.y - keySize/2, width: keySize, height: keySize)
                        context.fill(RoundedRectangle(cornerRadius: 2).path(in: rect), with: .color(.white.opacity(0.12)))
                    }
                    
                    // Draw Animated Path
                    let rawPoints: [CGPoint] = input.uppercased().compactMap { char in
                        guard let entry = keyboardLayout.first(where: { $0.0 == String(char) }) else { return nil }
                        return center(entry.1, entry.2)
                    }
                    
                    // Apply pronounced stable jitter for the "sloppy" look
                    let points = rawPoints.enumerated().map { idx, pt in
                        var state = UInt64(idx) &* 0x12345678 ^ 0x87654321
                        let dx = (nextRandom(&state) - 0.5) * 4.0
                        let dy = (nextRandom(&state) - 0.5) * 4.0
                        return CGPoint(x: pt.x + dx, y: pt.y + dy)
                    }
                    
                    if points.count >= 2 {
                        let totalDuration: TimeInterval = 1.2 // Faster snappy animation
                        let elapsed = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: totalDuration)
                        let progress = elapsed / (totalDuration * 0.75) // allow for pause
                        
                        if progress < 1.0 {
                            let count = Int(Double(points.count - 1) * progress) + 1
                            let visiblePoints = Array(points.prefix(max(2, count)))
                            
                            let path = smoothPath(points: visiblePoints)
                            context.stroke(path, with: .color(Color.accentColor.opacity(0.7)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            
                            if let last = visiblePoints.last {
                                context.fill(Path(ellipseIn: CGRect(x: last.x - 3, y: last.y - 3, width: 6, height: 6)), with: .color(Color.accentColor))
                            }
                        } else {
                            // Pause state: show full path
                            let path = smoothPath(points: points)
                            context.stroke(path, with: .color(Color.accentColor.opacity(0.7)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            if let last = points.last {
                                context.fill(Path(ellipseIn: CGRect(x: last.x - 3, y: last.y - 3, width: 6, height: 6)), with: .color(Color.accentColor))
                            }
                        }
                    }
                }
            }
        }
    }

    private func smoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }
        if points.count > 2 {
            let firstMid = CGPoint(x: (points[0].x + points[1].x) * 0.5, y: (points[0].y + points[1].y) * 0.5)
            path.addLine(to: firstMid)
            for i in 1..<(points.count - 1) {
                let curr = points[i]
                let next = points[i+1]
                let mid = CGPoint(x: (curr.x + next.x) * 0.5, y: (curr.y + next.y) * 0.5)
                path.addQuadCurve(to: mid, control: curr)
            }
        }
        if let last = points.last { path.addLine(to: last) }
        return path
    }

    private func nextRandom(_ state: inout UInt64) -> CGFloat {
        state = state &* 6364136223846793005 &+ 1
        let value = Double(state >> 33) / Double(1 << 31)
        return CGFloat(value)
    }
}

private struct MockRow: View {
    let text: String
    let primary: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(primary ? Color.accentColor : .white.opacity(0.3))
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10, weight: primary ? .bold : .regular))
                .foregroundColor(primary ? .white : .white.opacity(0.8))
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.white.opacity(primary ? 0.15 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 4))
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
