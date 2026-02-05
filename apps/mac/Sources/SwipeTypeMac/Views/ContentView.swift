//
//  ContentView.swift
//  SwipeTypeMac
//

import SwiftUI
import AppKit
import Foundation

enum OverlayLayout {
    static let panelWidth: CGFloat = 388
    static let horizontalPadding: CGFloat = 16
    static let verticalPaddingTop: CGFloat = 12
    static let verticalPaddingBottom: CGFloat = 4
    static let sectionSpacing: CGFloat = 4
    static let predictionCount = 5
    static let predictionRowHeight: CGFloat = 28
    static let predictionRowSpacing: CGFloat = 5
    static let statsHeight: CGFloat = 16
    static let keyboardHeight: CGFloat = 96
    static let footerHeight: CGFloat = 14
    static let containerCornerRadius: CGFloat = 14
    static let rowCornerRadius: CGFloat = 8
    static let keyCornerRadius: CGFloat = 7
    static let keyboardSidePadding: CGFloat = 10
    static let backgroundOverlayOpacity: CGFloat = 0.72

    static var predictionAreaHeight: CGFloat {
        CGFloat(predictionCount) * predictionRowHeight
            + CGFloat(max(predictionCount - 1, 0)) * predictionRowSpacing
    }

    static var panelHeight: CGFloat {
        verticalPaddingTop + verticalPaddingBottom
            + predictionAreaHeight
            + statsHeight
            + keyboardHeight
            + footerHeight
            + sectionSpacing * 3
    }

    static var panelSize: CGSize {
        CGSize(width: panelWidth, height: panelHeight)
    }
}

struct ContentView: View {
    @ObservedObject private var appState = AppState.shared
    @AppStorage(AppSettings.Keys.overlayBackgroundOpacity) private var backgroundOverlayOpacity = AppSettings.Defaults.overlayBackgroundOpacity
    @State private var isShowingHelp = false

    private var backgroundOpacity: Double {
        min(max(backgroundOverlayOpacity, 0.0), 0.95)
    }

    private var visiblePredictionWords: [String] {
        appState.predictions.prefix(OverlayLayout.predictionCount).map { $0.word }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OverlayLayout.sectionSpacing) {
            VStack(alignment: .leading, spacing: OverlayLayout.predictionRowSpacing) {
                ForEach(0..<OverlayLayout.predictionCount, id: \.self) { index in
                    if index < visiblePredictionWords.count {
                        let word = visiblePredictionWords[index]
                        PredictionRow(
                            index: index,
                            word: word,
                            isPrimary: index == 0,
                            isPlaceholder: false
                        )
                    } else {
                        PredictionRow(
                            index: index,
                            word: "",
                            isPrimary: false,
                            isPlaceholder: true
                        )
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: OverlayLayout.predictionAreaHeight,
                maxHeight: OverlayLayout.predictionAreaHeight,
                alignment: .topLeading
            )

            HStack {
                Text("computed in \(String(format: "%.3f", appState.predictionTime))s")
                Spacer()
                if appState.actualWPM > 0 {
                    Text("\(appState.actualWPM) actual WPM")
                }
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.secondary.opacity(0.8))
            .padding(.horizontal, 4)
            .frame(height: OverlayLayout.statsHeight)
            .opacity(appState.currentInput.isEmpty ? 0 : 1)

            KeyboardView(
                input: appState.currentInput,
                inputTimestamps: appState.inputTimestamps,
                isPlaybackActive: appState.isPlaybackActive,
                playbackStartTime: appState.playbackStartTime,
                isWordCommitted: appState.isWordCommitted
            )
                .frame(maxWidth: .infinity)

            FooterBar(isShowingHelp: $isShowingHelp)
        }
        .padding(.horizontal, OverlayLayout.horizontalPadding)
        .padding(.top, OverlayLayout.verticalPaddingTop)
        .padding(.bottom, OverlayLayout.verticalPaddingBottom)
        .frame(width: OverlayLayout.panelSize.width, height: OverlayLayout.panelSize.height)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow, emphasized: false)
                .overlay(Color.black.opacity(backgroundOpacity))
        )
        .clipShape(RoundedRectangle(cornerRadius: OverlayLayout.containerCornerRadius))
        .overlay {
            if isShowingHelp {
                HelpView(isShowing: $isShowingHelp)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}

private struct FooterBar: View {
    @Binding var isShowingHelp: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            FooterHint()
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                HelpGlyphButton(isShowingHelp: $isShowingHelp)
                SettingsGlyphButton()
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.gray)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: OverlayLayout.footerHeight)
    }
}

private struct PredictionRow: View {
    let index: Int
    let word: String
    let isPrimary: Bool
    let isPlaceholder: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isPrimary ? .white : .secondary)
                .frame(width: 22, height: 22)
                .background(isPrimary ? Color.accentColor : Color.white.opacity(0.18))
                .clipShape(Circle())

            Text(word)
                .font(.system(size: 15, weight: isPrimary ? .semibold : .regular))
                .foregroundColor(isPrimary ? Color(red: 0.4, green: 0.7, blue: 1.0) : .primary)
                .baselineOffset(-0.5)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: OverlayLayout.predictionRowHeight,
            maxHeight: OverlayLayout.predictionRowHeight,
            alignment: .leading
        )
        .padding(.horizontal, 8)
        .background(Color.white.opacity(isPrimary ? 0.12 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: OverlayLayout.rowCornerRadius))
        .opacity(isPlaceholder ? 0 : 1)
    }
}

private struct FooterHint: View {
    @AppStorage(AppSettings.Keys.hotkeyPreset) private var hotkeyPresetRaw = AppSettings.Defaults.hotkeyPreset.rawValue
    @AppStorage(AppSettings.Keys.customToggleHotkeyKeyCode) private var customToggleHotkeyKeyCode = AppSettings.Defaults.customToggleHotkeyKeyCode
    @AppStorage(AppSettings.Keys.customToggleHotkeyModifiers) private var customToggleHotkeyModifiers = AppSettings.Defaults.customToggleHotkeyModifiers

    private var toggleHint: String {
        let preset = AppSettings.ToggleHotkeyPreset(rawValue: hotkeyPresetRaw) ?? AppSettings.Defaults.hotkeyPreset

        switch preset {
        case .custom:
            guard customToggleHotkeyModifiers != 0 else { return "Menu" }
            return AppSettings.hotkeyHintSymbol(
                keyCode: customToggleHotkeyKeyCode,
                modifierMask: customToggleHotkeyModifiers
            )
        default:
            return preset.hintSymbol
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            FooterIconLabel(icon: toggleHint, text: "toggle")
            FooterDot()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                FooterIconLabel(icon: "↵", text: "or")
                Text("1-5")
                Text("select")
                    .padding(.leading, 2)
            }
            FooterDot()
            FooterIconLabel(icon: "⎋", text: "close")
        }
    }
}

private struct HelpGlyphButton: View {
    @Binding var isShowingHelp: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isShowingHelp.toggle()
            }
        } label: {
            Image(systemName: isShowingHelp ? "questionmark.circle.fill" : "questionmark.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isShowingHelp ? .accentColor : .gray)
                .frame(width: 18, height: OverlayLayout.footerHeight)
        }
        .buttonStyle(.plain)
        .help("Help")
    }
}

private struct SettingsGlyphButton: View {
    var body: some View {
        Button {
            NotificationCenter.default.post(name: .openSettings, object: nil)
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 18, height: OverlayLayout.footerHeight)
        }
        .buttonStyle(.plain)
        .help("Settings")
        .accessibilityLabel("Settings")
    }
}

private struct HelpView: View {
    @Binding var isShowing: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .onTapGesture {
                    withAnimation(.easeIn(duration: 0.15)) {
                        isShowing = false
                    }
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("How to use SwipeType")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    Button {
                        withAnimation(.easeIn(duration: 0.15)) {
                            isShowing = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        HelpSection(title: "Usage", icon: "keyboard") {
                            Text("Draw patterns across the keys to type. To commit a word, you can **just start typing** the next pattern, press **Return**, or use **1-5** to select a specific prediction. SwipeType automatically handles spacing, and you can use **Backspace** to undo.")
                        }
                    }
                }
            }
            .padding(16)
            .frame(width: 300, height: 260)
            .background(
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow, emphasized: true)
                    .overlay(Color(nsColor: .windowBackgroundColor).opacity(0.1))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 20)
        }
    }
}

private struct HelpSection<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)
            content()
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FooterIconLabel: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(icon)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .baselineOffset(-0.4)
            Text(text)
        }
    }
}

private struct FooterDot: View {
    var body: some View {
        Text("·")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 1)
    }
}

struct KeyboardView: View {
    let input: String
    let inputTimestamps: [TimeInterval]
    let isPlaybackActive: Bool
    let playbackStartTime: TimeInterval
    let isWordCommitted: Bool

    private let keyboardLayout: [(String, CGFloat, CGFloat)] = [
        ("Q", 0, 0), ("W", 1, 0), ("E", 2, 0), ("R", 3, 0), ("T", 4, 0),
        ("Y", 5, 0), ("U", 6, 0), ("I", 7, 0), ("O", 8, 0), ("P", 9, 0),
        ("[", 10, 0), ("]", 11, 0), ("\\", 12, 0),
        ("A", 1, 1), ("S", 2, 1), ("D", 3, 1), ("F", 4, 1), ("G", 5, 1),
        ("H", 6, 1), ("J", 7, 1), ("K", 8, 1), ("L", 9, 1),
        (";", 10, 1), ("'", 11, 1),
        ("Z", 1.5, 2), ("X", 2.5, 2), ("C", 3.5, 2), ("V", 4.5, 2), ("B", 5.5, 2),
        ("N", 6.5, 2), ("M", 7.5, 2), (",", 8.5, 2), (".", 9.5, 2), ("/", 10.5, 2)
    ]

    private let idleLoopPadding: TimeInterval = 0.5
    private let sloppinessVariants = 5
    private let sloppinessAmplitude: CGFloat = 1.0
    private let animationSloppinessAmplitude: CGFloat = 1.5

    @State private var animationBaseTime: TimeInterval = 0

    private var activeKeys: Set<Character> {
        Set(input.uppercased())
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.periodic(from: .now, by: isPlaybackActive ? 1.0 / 60.0 : 0.5)) { timeline in
                Canvas { context, _ in
                    let totalCols: CGFloat = 13
                    let gap: CGFloat = 2
                    let minPadding: CGFloat = OverlayLayout.keyboardSidePadding
                    let availableWidth = max(0, proxy.size.width - minPadding * 2 - gap * (totalCols - 1))
                    let keyW = max(16, min(24, availableWidth / totalCols))
                    let keyH = keyW * 0.7

                    let keyboardWidth = totalCols * keyW + (totalCols - 1) * gap
                    let leftPad = (proxy.size.width - keyboardWidth) / 2

                    let maxRow = keyboardLayout.map { $0.2 }.max() ?? 0
                    let gridHeight = maxRow * (keyH + gap) + keyH
                    let verticalPad = max(0, (proxy.size.height - gridHeight) / 2)

                    func center(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                        CGPoint(
                            x: x * (keyW + gap) + keyW / 2 + leftPad,
                            y: y * (keyH + gap) + keyH / 2 + verticalPad
                        )
                    }

                    var pathPoints: [CGPoint] = []
                    var chars: [Character] = []
                    var timestamps: [TimeInterval] = []

                    let uppercased = Array(input.uppercased())
                    for (index, char) in uppercased.enumerated() {
                        guard let entry = keyboardLayout.first(where: { $0.0 == String(char) }) else { continue }
                        let point = center(entry.1, entry.2)
                        pathPoints.append(point)
                        chars.append(char)
                        if index < inputTimestamps.count {
                            timestamps.append(inputTimestamps[index])
                        }
                    }

                    let usableCount = min(pathPoints.count, timestamps.count, chars.count)
                    let points = Array(pathPoints.prefix(usableCount))
                    let timeSamples = Array(timestamps.prefix(usableCount))
                    let keyChars = Array(chars.prefix(usableCount))

                    let showSimulation = isWordCommitted && usableCount >= 2
                    let isAnimating = showSimulation && isPlaybackActive && playbackStartTime > 0
                        && timeline.date.timeIntervalSinceReferenceDate >= playbackStartTime

                    let animationSeed: UInt64? = showSimulation ? seedFrom(input: input) : nil
                    let animationVariant = animationSeed.map {
                        Int($0 % UInt64(max(sloppinessVariants, 1)))
                    } ?? 0
                    let animationPathPoints = animationSeed.map {
                        jitteredPath(
                            points: points,
                            seed: $0,
                            variant: animationVariant,
                            amplitude: animationSloppinessAmplitude
                        )
                    } ?? points

                    func interpolatedPoint(at time: TimeInterval, points: [CGPoint], wrap: Bool) -> (CGPoint, Int)? {
                        guard timeSamples.count >= 2, points.count >= 2 else { return nil }
                        let start = timeSamples[0]
                        let end = timeSamples[timeSamples.count - 1]
                        let total = end - start
                        guard total > 0 else { return nil }

                        let target: TimeInterval
                        if wrap {
                            var normalized = (time - start).truncatingRemainder(dividingBy: total)
                            if normalized < 0 { normalized += total }
                            target = start + normalized
                        } else {
                            guard time >= start && time <= end else { return nil }
                            target = time
                        }

                        var segmentIdx = 0
                        for idx in 0..<(timeSamples.count - 1) {
                            if target >= timeSamples[idx] && target < timeSamples[idx + 1] {
                                segmentIdx = idx
                                break
                            } else if target >= end {
                                segmentIdx = timeSamples.count - 2
                            }
                        }

                        let segStart = timeSamples[segmentIdx]
                        let segEnd = timeSamples[segmentIdx + 1]
                        let progress = min(1, (target - segStart) / max(segEnd - segStart, 0.001))
                        let startPoint = points[segmentIdx]
                        let endPoint = points[segmentIdx + 1]
                        let x = startPoint.x + (endPoint.x - startPoint.x) * progress
                        let y = startPoint.y + (endPoint.y - startPoint.y) * progress
                        return (CGPoint(x: x, y: y), segmentIdx)
                    }
                    // Draw simulated paths only after commit (not during animation)
                    if showSimulation && !isPlaybackActive {
                        if let seed = animationSeed, points.count >= 2 {
                            for variant in 0..<sloppinessVariants {
                                let variantPath = jitteredPath(
                                    points: points,
                                    seed: seed,
                                    variant: variant,
                                    amplitude: sloppinessAmplitude
                                )
                                let path = smoothPath(points: variantPath)
                                let opacity = 0.06 + (Double(variant) * 0.01)
                                context.stroke(
                                    path,
                                    with: .color(.accentColor.opacity(opacity)),
                                    style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
                                )
                            }
                        }
                    }

                    var activeKey: Character? = nil

                    if isAnimating, timeSamples.count >= 2, animationPathPoints.count >= 2 {
                        let totalDuration = timeSamples.last! - timeSamples.first!
                        let loopDuration = totalDuration + idleLoopPadding
                        let elapsed = timeline.date.timeIntervalSinceReferenceDate - animationBaseTime
                        let loopElapsed = elapsed.truncatingRemainder(dividingBy: max(loopDuration, 0.01))

                        if loopElapsed >= totalDuration {
                            if let lastPoint = animationPathPoints.last {
                                activeKey = keyChars.last
                                
                                let fullPath = smoothPath(points: animationPathPoints)
                                context.stroke(
                                    fullPath,
                                    with: .color(Color.accentColor.opacity(0.7)),
                                    style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round)
                                )

                                context.fill(Path(ellipseIn: CGRect(x: lastPoint.x - 6, y: lastPoint.y - 6, width: 12, height: 12)),
                                             with: .color(.accentColor.opacity(0.9)))
                            }
                        } else {
                            let currentTime = timeSamples.first! + loopElapsed
                            if let (currPoint, segmentIdx) = interpolatedPoint(at: currentTime, points: animationPathPoints, wrap: false) {
                                activeKey = segmentIdx < keyChars.count ? keyChars[segmentIdx] : nil

                                var animPoints: [CGPoint] = [animationPathPoints[0]]
                                if segmentIdx > 0 {
                                    animPoints.append(contentsOf: animationPathPoints[1...segmentIdx])
                                }
                                animPoints.append(currPoint)
                                let animPath = smoothPath(points: animPoints)
                                context.stroke(
                                    animPath,
                                    with: .color(Color.accentColor.opacity(0.7)),
                                    style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round)
                                )

                                context.fill(Path(ellipseIn: CGRect(x: currPoint.x - 6, y: currPoint.y - 6, width: 12, height: 12)),
                                             with: .color(.accentColor.opacity(0.9)))
                            }
                        }
                    }

                    for (key, x, y) in keyboardLayout {
                        let p = center(x, y)
                        let rect = CGRect(x: p.x - keyW / 2, y: p.y - keyH / 2, width: keyW, height: keyH)
                        let keyChar = Character(key)
                        let isActive = !isAnimating && activeKeys.contains(keyChar)
                        let isHighlighted = activeKey == keyChar
                        let fill = isHighlighted ? Color.accentColor.opacity(0.55) : (isActive ? .accentColor.opacity(0.35) : Color.white.opacity(0.08))
                        let stroke = isHighlighted ? Color.accentColor : (isActive ? .accentColor : .white.opacity(0.2))

                        let labelOffset = labelOffset(for: keyChar, keyW: keyW, keyH: keyH)
                        let labelPoint = CGPoint(x: p.x + labelOffset.width, y: p.y + labelOffset.height)

                        context.fill(RoundedRectangle(cornerRadius: OverlayLayout.keyCornerRadius).path(in: rect), with: .color(fill))
                        context.stroke(RoundedRectangle(cornerRadius: OverlayLayout.keyCornerRadius).path(in: rect), with: .color(stroke), lineWidth: 0.5)
                        context.draw(Text(key).font(.system(size: keyW * 0.42, weight: .semibold, design: .rounded))
                            .foregroundColor(isHighlighted ? .white : (isActive ? .accentColor : .primary)), at: labelPoint)
                    }
                }
            }
            .onChange(of: playbackStartTime) { _ in
                animationBaseTime = playbackStartTime
            }
        }
        .frame(height: OverlayLayout.keyboardHeight)
    }

    private func seedFrom(input: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }

    private func jitteredPath(points: [CGPoint], seed: UInt64, variant: Int, amplitude: CGFloat) -> [CGPoint] {
        var jittered: [CGPoint] = []
        for (idx, point) in points.enumerated() {
            // Stable seed per point to prevent path shifting
            var pointState = UInt64(idx) &* 0x12345678 ^ UInt64(variant) &* 0x87654321
            let dx = (nextRandom(&pointState) - 0.5) * amplitude
            let dy = (nextRandom(&pointState) - 0.5) * amplitude
            jittered.append(CGPoint(x: point.x + dx, y: point.y + dy))
        }
        return jittered
    }

    private func smoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)

        if points.count == 2, let last = points.last {
            path.addLine(to: last)
            return path
        }

        if points.count > 2 {
            let p0 = points[0]
            let p1 = points[1]
            let firstMid = CGPoint(x: (p0.x + p1.x) * 0.5, y: (p0.y + p1.y) * 0.5)
            path.addLine(to: firstMid)

            for idx in 1..<(points.count - 1) {
                let current = points[idx]
                let next = points[idx + 1]
                let mid = midpoint(current, next)
                path.addQuadCurve(to: mid, control: current)
            }
        }

        if let last = points.last {
            path.addLine(to: last)
        }

        return path
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    }

    private func nextRandom(_ state: inout UInt64) -> CGFloat {
        state = state &* 6364136223846793005 &+ 1
        let value = Double(state >> 33) / Double(1 << 31)
        return CGFloat(value)
    }

    private func labelOffset(for key: Character, keyW: CGFloat, keyH: CGFloat) -> CGSize {
        var offset = CGSize(width: keyW * 0.015, height: keyH * 0.08)

        switch key {
        case ";", ".":
            offset.height -= keyH * 0.07
        case "'":
            offset.height -= keyH * 0.04
        case ",":
            offset.height -= keyH * 0.05
        case "/":
            offset.width -= keyW * 0.05
        default:
            break
        }

        return offset
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    var emphasized: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = emphasized
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
