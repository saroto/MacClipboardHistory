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
    let panelController: PanelController
    let hotKeys = HotKeyManager()

    override init() {
        AppSettings.registerDefaults()
        // The monitor and sweeper both write, and both run on the main actor, so
        // they share the container's main context. Using a side context here would
        // leave @Query views stale until the next save merged.
        let store = ClipStore(context: AppModelContainer.shared.mainContext)
        let monitor = ClipboardMonitor(store: store)
        self.monitor = monitor
        self.sweeper = RetentionSweeper(store: store)
        self.panelController = PanelController(monitor: monitor, container: AppModelContainer.shared)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start()
        sweeper.start()
        registerHotKey()
    }

    /// Re-registers the summon shortcut, e.g. after it is changed in Settings.
    func registerHotKey() {
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
