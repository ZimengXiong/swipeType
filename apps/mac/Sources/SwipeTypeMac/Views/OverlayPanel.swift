//
//  OverlayPanel.swift
//  SwipeTypeMac
//

import Cocoa
import SwiftUI

class OverlayPanel: NSPanel {
    private static let positionKey = "overlayPosition"
    private var hasSavedPosition: Bool {
        UserDefaults.standard.object(forKey: Self.positionKey) != nil
    }

    init() {
        let panelSize = OverlayLayout.panelSize
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: panelSize.width, height: panelSize.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setup()
    }

    private func setup() {
        let panelSize = OverlayLayout.panelSize
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true

        setContentSize(panelSize)
        contentMinSize = panelSize
        contentMaxSize = panelSize

        let hosting = NSHostingView(rootView: ContentView())
        hosting.frame = contentRect(forFrameRect: frame)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting


        if hasSavedPosition {
            restorePosition()
        } else {
            positionAtCenter()
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(hide), name: .hideOverlay, object: nil
        )


        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMove), name: NSWindow.didMoveNotification, object: self
        )


        NotificationCenter.default.addObserver(
            self, selector: #selector(screenDidChange), name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    @objc private func screenDidChange() {
        if hasSavedPosition {
            restorePosition()
        } else {
            positionAtCenter()
        }
    }

    private func positionAtCenter() {
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - frame.width / 2
            let y = screen.visibleFrame.midY - frame.height / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    private func restorePosition() {
        if let savedPos = UserDefaults.standard.object(forKey: Self.positionKey) as? [String: CGFloat],
           let x = savedPos["x"], let y = savedPos["y"] {
            let origin = NSPoint(x: x, y: y)
            if let screen = NSScreen.main {
                let clampedX = min(max(origin.x, screen.visibleFrame.minX), screen.visibleFrame.maxX - frame.width)
                let clampedY = min(max(origin.y, screen.visibleFrame.minY), screen.visibleFrame.maxY - frame.height)
                setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
            } else {
                setFrameOrigin(origin)
            }
        }
    }

    @objc private func windowDidMove() {
        let position: [String: CGFloat] = ["x": frame.origin.x, "y": frame.origin.y]
        UserDefaults.standard.set(position, forKey: Self.positionKey)
    }

    func showOverlay() {
        orderFrontRegardless()
    }

    @objc func hide() {
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension Notification.Name {
    static let hideOverlay = Notification.Name("hideOverlay")
    static let openSettings = Notification.Name("openSettings")
}
