//
//  AppDelegate.swift
//  MacOsClipBoard
//

import AppKit
import SwiftData
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let monitor: ClipboardMonitor
    let sweeper: RetentionSweeper
    let hotKeys = HotKeyManager()
    private(set) var panelController: PanelController!
    private(set) var settingsWindow: SettingsWindowController!

    override init() {
        AppSettings.registerDefaults()
        // The monitor and sweeper both write, and both run on the main actor, so
        // they share the container's main context. Using a side context here would
        // leave @Query views stale until the next save merged.
        let store = ClipStore(context: AppModelContainer.shared.mainContext)
        let monitor = ClipboardMonitor(store: store)
        self.monitor = monitor
        self.sweeper = RetentionSweeper(store: store)
        super.init()

        settingsWindow = SettingsWindowController(
            sweeper: sweeper,
            hotKeys: hotKeys,
            container: AppModelContainer.shared,
            onHotKeyChange: { [weak self] in self?.registerHotKey() }
        )
        panelController = PanelController(
            monitor: monitor,
            container: AppModelContainer.shared,
            onOpenSettings: { [weak self] in self?.settingsWindow.show() }
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start()
        sweeper.start()
        registerHotKey()
    }

    /// Re-registers the summon shortcut, e.g. after it is changed in Settings.
    /// A `false` result means another app already owns the combination; that is
    /// surfaced in Settings via `HotKeyManager.isRegistered` rather than swallowed.
    @discardableResult
    func registerHotKey() -> Bool {
        hotKeys.register(AppSettings.hotKey) { [weak self] in
            self?.panelController.toggle()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        sweeper.stop()
        hotKeys.unregister()
    }
}
