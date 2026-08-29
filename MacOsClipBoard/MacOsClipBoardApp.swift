//
//  MacOsClipBoardApp.swift
//  MacOsClipBoard
//

import SwiftData
import SwiftUI

@main
struct MacOsClipBoardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // No WindowGroup: this is a background agent (LSUIElement), so there is no Dock
    // icon and no main window. The menu bar item is the whole UI for now; it will be
    // joined by the hotkey-summoned floating panel.
    var body: some Scene {
        MenuBarExtra("Clipboard History", systemImage: "doc.on.clipboard") {
            ClipListView()
                .environment(appDelegate.monitor)
                .frame(width: 380, height: 440)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(AppModelContainer.shared)

        Settings {
            SettingsView(
                sweeper: appDelegate.sweeper,
                onHotKeyChange: { appDelegate.registerHotKey() }
            )
                .modelContainer(AppModelContainer.shared)
        }
    }
}
