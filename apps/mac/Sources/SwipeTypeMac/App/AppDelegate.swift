import Cocoa
import Carbon.HIToolbox
import os
import SwiftUI

private let overlayVisibility = OSAllocatedUnfairLock(initialState: false)
private let swipeTypeSyntheticEventUserData: Int64 = 0x53575459

private func isOverlayVisible() -> Bool {
    overlayVisibility.withLock { $0 }
}

private func setOverlayVisible(_ value: Bool) {
    overlayVisibility.withLock { $0 = value }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var overlayPanel: OverlayPanel?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var statusItem: NSStatusItem?
    private var statusTimer: Timer?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

    private var settingsWindow: NSWindow?
    private var initialActivationPolicy: NSApplication.ActivationPolicy?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.registerDefaults()

        initialActivationPolicy = NSApp.activationPolicy()

        Task { @MainActor in
            AppState.shared.loadDictionary()
        }

        updateStatusItemVisibility()
        NotificationCenter.default.addObserver(
            self, selector: #selector(userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil
        )

        NotificationCenter.default.addObserver(
            self, selector: #selector(openSettingsFromNotification(_:)), name: .openSettings, object: nil
        )
        setupGlobalHotkey()
        overlayPanel = OverlayPanel()

        NotificationCenter.default.addObserver(
            self, selector: #selector(overlayDidHide), name: .hideOverlay, object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeOutsideClickMonitors()
        removeEventTap()
    }

    private static func toggleOverlayMenuTitle() -> String {
        if let hotkey = AppSettings.toggleHotkeyDisplayName {
            return "Toggle Overlay (\(hotkey))"
        }
        return "Toggle Overlay"
    }

    private func setupStatusItem() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "SwipeType")

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: Self.toggleOverlayMenuTitle(), action: #selector(toggleOverlay), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.tag = 101
        menu.addItem(toggleItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let statusItem = NSMenuItem(title: "Status: Loading...", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        self.statusItem?.menu = menu

        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatusMenuItem()
        }
    }

    @objc private func userDefaultsDidChange() {
        updateStatusItemVisibility()
        updateToggleMenuItemTitle()
    }

    private func updateStatusItemVisibility() {
        if AppSettings.showMenuBarItem {
            if statusItem == nil {
                setupStatusItem()
            }
        } else {
            removeStatusItem()
        }
    }

    private func removeStatusItem() {
        guard let statusItem else { return }

        statusTimer?.invalidate()
        statusTimer = nil

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func updateToggleMenuItemTitle() {
        guard let menu = statusItem?.menu,
              let item = menu.item(withTag: 101) else { return }
        item.title = Self.toggleOverlayMenuTitle()
    }

    @objc private func openSettings() {
        Task { @MainActor in
            presentSettingsWindow()
        }
    }

    @objc private func openSettingsFromNotification(_ notification: Notification) {
        Task { @MainActor in
            presentSettingsWindow()
        }
    }

    @MainActor
    private func presentSettingsWindow() {
        hideOverlayIfNeeded()

        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }

        let window: NSWindow
        if let settingsWindow {
            window = settingsWindow
        } else {
            window = makeSettingsWindow()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @MainActor
    private func makeSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SwipeType.SettingsWindow")
        window.collectionBehavior = [.moveToActiveSpace]
        window.delegate = self

        let hosting = NSHostingView(rootView: SettingsView())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = hosting

        window.setContentSize(hosting.fittingSize)
        window.contentMinSize = NSSize(width: 820, height: 400)
        window.center()

        return window
    }

    @MainActor
    private func hideOverlayIfNeeded() {
        let isPanelVisible = overlayPanel?.isVisible ?? false
        guard isOverlayVisible() || isPanelVisible else { return }

        AppState.shared.hideOverlay()
        setOverlayVisible(false)
        NotificationCenter.default.post(name: .hideOverlay, object: nil)
        removeOutsideClickMonitors()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == settingsWindow,
              let initialActivationPolicy,
              initialActivationPolicy != .regular else { return }

        NSApp.setActivationPolicy(initialActivationPolicy)
    }

    private func updateStatusMenuItem() {
        guard let menu = statusItem?.menu,
              let item = menu.item(withTag: 100) else { return }

        Task { @MainActor in
            let state = AppState.shared
            if state.isDictionaryLoaded {
                item.title = "✓ \(state.dictionaryWordCount) words loaded"
                statusTimer?.invalidate()
                statusTimer = nil
            } else {
                item.title = "✗ Dictionary not loaded"
            }
        }
    }

    @objc private func toggleOverlay() {
        Task { @MainActor in
            AppState.shared.toggleOverlay()
            setOverlayVisible(AppState.shared.isOverlayVisible)
            if isOverlayVisible() {
                overlayPanel?.showOverlay()
                installOutsideClickMonitors()
            } else {
                overlayPanel?.hide()
                removeOutsideClickMonitors()
            }
        }
    }

    @objc private func overlayDidHide() {
        setOverlayVisible(false)
        removeOutsideClickMonitors()
    }

    private func setupGlobalHotkey() {
        guard PermissionManager.shared.checkAccessibilityPermission() else {
            PermissionManager.shared.requestAccessibilityPermission()
            PermissionManager.shared.startMonitoringPermission { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupGlobalHotkey()
                    }
                }
            }
            return
        }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                AppDelegate.handleEvent(type: type, event: event, refcon: refcon)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func removeEventTap() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
    }

    private func enableEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func installOutsideClickMonitors() {
        guard globalClickMonitor == nil, localClickMonitor == nil else { return }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) {
            [weak self] event in
            self?.handleOutsideClick(event)
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) {
            [weak self] event in
            self?.handleOutsideClick(event)
        }
    }

    private func removeOutsideClickMonitors() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
    }

    private func handleOutsideClick(_ event: NSEvent) {
        Task { @MainActor [weak self] in
            guard let self = self,
                  isOverlayVisible(),
                  let panel = overlayPanel,
                  panel.isVisible else { return }

            let screenPoint: NSPoint
            if let window = event.window {
                screenPoint = window.convertPoint(toScreen: event.locationInWindow)
            } else {
                screenPoint = event.locationInWindow
            }

            guard !panel.frame.contains(screenPoint) else { return }

            AppState.shared.hideOverlay()
            setOverlayVisible(false)
            NotificationCenter.default.post(name: .hideOverlay, object: nil)
            removeOutsideClickMonitors()
        }
    }

    private static func handleEvent(type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let refcon {
                DispatchQueue.main.async {
                    Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue().enableEventTap()
                }
            }
            return nil
        }
        guard type == .keyDown || type == .keyUp else { return Unmanaged.passRetained(event) }

        if event.getIntegerValueField(.eventSourceUserData) == swipeTypeSyntheticEventUserData {
            return Unmanaged.passRetained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        if AppSettings.matchesToggleOverlayHotkey(keyCode: keyCode, flags: flags) {
            if type == .keyDown {
                DispatchQueue.main.async {
                    guard let refcon else { return }
                    Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue().toggleOverlay()
                }
            }
            return nil
        }

        guard type == .keyDown, isOverlayVisible() else { return Unmanaged.passRetained(event) }

        let hasModifier = flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate)
        if hasModifier {
            return Unmanaged.passRetained(event)
        }

        return handleKey(keyCode, flags: flags) ? nil : Unmanaged.passRetained(event)
    }

    private static let passthroughKeys: Set<Int> = [
        kVK_Command, kVK_Shift, kVK_Option, kVK_Control,
        kVK_RightCommand, kVK_RightShift, kVK_RightOption, kVK_RightControl,
        kVK_CapsLock, kVK_Function,
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
        kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
        kVK_VolumeUp, kVK_VolumeDown, kVK_Mute
    ]

    private static func handleKey(_ keyCode: Int, flags: CGEventFlags) -> Bool {
        if passthroughKeys.contains(keyCode) {
            return false
        }

        DispatchQueue.main.async {
            let state = AppState.shared

            switch keyCode {
            case kVK_Escape:
                state.hideOverlay()
                setOverlayVisible(false)
                NotificationCenter.default.post(name: .hideOverlay, object: nil)

            case kVK_Delete:
                state.deleteCharacter()

            case kVK_Return:
                let allowCommit: Bool
                if AppSettings.requirePauseBeforeCommit {
                    allowCommit = state.currentInput.isEmpty || state.isWordCommitted
                } else {
                    allowCommit = !state.currentInput.isEmpty && !state.predictions.isEmpty
                }

                if allowCommit, let word = state.selectPrediction(at: 0) {
                    TextInsertionService.shared.insertText(AppSettings.committedText(for: word))
                }

            case kVK_Space:
                break

            default:
                if keyCode >= kVK_ANSI_1 && keyCode <= kVK_ANSI_5 {
                    let allowCommit: Bool
                    if AppSettings.requirePauseBeforeCommit {
                        allowCommit = state.currentInput.isEmpty || state.isWordCommitted
                    } else {
                        allowCommit = !state.currentInput.isEmpty && !state.predictions.isEmpty
                    }

                    if allowCommit, let word = state.selectPrediction(at: keyCode - kVK_ANSI_1) {
                        TextInsertionService.shared.insertText(AppSettings.committedText(for: word))
                    }
                } else if let char = keyCodeToChar(keyCode) {
                    if let autoWord = state.addCharacter(char) {
                        TextInsertionService.shared.insertText(AppSettings.committedText(for: autoWord))
                    }
                }
            }
        }

        return true
    }

    private static func keyCodeToChar(_ keyCode: Int) -> Character? {
        [kVK_ANSI_A: "a", kVK_ANSI_B: "b", kVK_ANSI_C: "c", kVK_ANSI_D: "d",
         kVK_ANSI_E: "e", kVK_ANSI_F: "f", kVK_ANSI_G: "g", kVK_ANSI_H: "h",
         kVK_ANSI_I: "i", kVK_ANSI_J: "j", kVK_ANSI_K: "k", kVK_ANSI_L: "l",
         kVK_ANSI_M: "m", kVK_ANSI_N: "n", kVK_ANSI_O: "o", kVK_ANSI_P: "p",
         kVK_ANSI_Q: "q", kVK_ANSI_R: "r", kVK_ANSI_S: "s", kVK_ANSI_T: "t",
         kVK_ANSI_U: "u", kVK_ANSI_V: "v", kVK_ANSI_W: "w", kVK_ANSI_X: "x",
         kVK_ANSI_Y: "y", kVK_ANSI_Z: "z"][keyCode]
    }
}
