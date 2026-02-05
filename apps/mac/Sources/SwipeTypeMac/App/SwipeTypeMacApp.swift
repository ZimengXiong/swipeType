//
//  SwipeTypeMacApp.swift
//  SwipeTypeMac
//
//  Main entry point for the SwipeType macOS app
//

import SwiftUI

@main
struct SwipeTypeMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
