//
//  SettingsWindowController.swift
//  MacOsClipBoard
//
//  An app-owned Settings window.
//
//  SwiftUI's `Settings` scene plus `@Environment(\.openSettings)` proved unreliable
//  here for two reasons, both inherent to this app's shape:
//
//  * `openSettings` is supplied by the *scene graph*. The floating panel hosts its
//    SwiftUI content in a hand-built `NSHostingView`, which is outside that graph,
//    so the action silently did nothing when invoked from the panel.
//  * As an `LSUIElement` accessory app we are usually inactive, so even a window
//    that *was* created opened behind the frontmost app — indistinguishable from
//    nothing happening.
//
//  Owning the window makes both surfaces deterministic.
//

import AppKit
import SwiftData
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject {
    private var window: NSWindow?

    private let sweeper: RetentionSweeper
    private let hotKeys: HotKeyManager
    private let container: ModelContainer
    private let onHotKeyChange: () -> Void

    init(
        sweeper: RetentionSweeper,
        hotKeys: HotKeyManager,
        container: ModelContainer,
        onHotKeyChange: @escaping () -> Void
    ) {
        self.sweeper = sweeper
        self.hotKeys = hotKeys
        self.container = container
        self.onHotKeyChange = onHotKeyChange
        super.init()
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window

        // An accessory app must activate, or the window opens behind whatever the
        // user is looking at.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let root = SettingsView(
            sweeper: sweeper,
            hotKeys: hotKeys,
            onHotKeyChange: onHotKeyChange
        )
        .modelContainer(container)

        let hosting = NSHostingView(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Reclip Settings"
        window.contentView = hosting
        // A programmatically created NSWindow is released when closed by default,
        // which would leave `window` dangling and make the *second* open fail — the
        // classic "worked once, then stopped" settings bug.
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
