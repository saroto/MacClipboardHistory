//
//  PanelController.swift
//  MacOsClipBoard
//
//  The hotkey-summoned floating panel, and the focus dance around pasting.
//

import AppKit
import SwiftData
import SwiftUI

/// A normal window cannot float over full-screen apps and cannot take keys without
/// activating the app. This can do both.
final class HistoryPanel: NSPanel {
    // Without this a `.nonactivatingPanel` receives no keystrokes at all — the most
    // common way this class of window ends up feeling broken.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var onCancel: (() -> Void)?

    /// Escape.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private var panel: HistoryPanel?
    /// Whoever was frontmost when the panel opened, so focus can be handed back.
    private var previousApp: NSRunningApplication?

    private let monitor: ClipboardMonitor
    private let container: ModelContainer
    private let onOpenSettings: () -> Void

    init(
        monitor: ClipboardMonitor,
        container: ModelContainer,
        onOpenSettings: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.container = container
        self.onOpenSettings = onOpenSettings
        super.init()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        if isVisible { hide(restoringFocus: true) } else { show() }
    }

    // MARK: - Presentation

    func show() {
        // Step 1 of the paste sequence: remember the target *before* we take focus.
        previousApp = NSWorkspace.shared.frontmostApplication

        let panel = self.panel ?? makePanel()
        self.panel = panel

        // Rebuild the SwiftUI content on every open. The window is reused, but its
        // hosting view must not be: a reused view keeps its @State (stale selection,
        // stale search text), never re-runs `.onAppear`, and can keep serving the
        // @Query snapshot it had when the panel was first created — which is why a
        // clip chosen from history appeared not to move to the top.
        panel.contentView = NSHostingView(rootView: makeRootView())
        position(panel)

        panel.makeKeyAndOrderFront(nil)
        // An accessory app needs to activate to reliably own the keyboard. The panel
        // stays non-activating for layering purposes; focus is handed back explicitly
        // in `hide(restoringFocus:)`, so this does not strand the user's app.
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide(restoringFocus: Bool) {
        panel?.orderOut(nil)
        guard restoringFocus else { return }
        previousApp?.activate()
    }

    private func makePanel() -> HistoryPanel {
        let panel = HistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        // Follow the user across Spaces and sit above full-screen apps.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide(restoringFocus: true) }
        return panel
    }

    private func makeRootView() -> some View {
        ClipListView(
            onActivate: { [weak self] clip in self?.paste(clip) },
            onOpenSettings: { [weak self] in
                // Dismiss first: the settings window taking key would fire
                // windowDidResignKey anyway, and we want focus handed back cleanly.
                self?.hide(restoringFocus: false)
                self?.onOpenSettings()
            }
        )
        .environment(monitor)
        .modelContainer(container)
    }

    /// Show near the pointer, clamped to the screen it is on.
    private func position(_ panel: HistoryPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height)
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
    }

    // MARK: - Pasting

    /// The ordering here is the whole trick. Getting it wrong produces the classic
    /// "hotkey works but nothing pastes".
    private func paste(_ clip: Clip) {
        // 2. Put the clip on the pasteboard (routed through the monitor so we do not
        //    re-capture our own write) and get out of the way.
        monitor.write(clip)
        let target = previousApp
        hide(restoringFocus: false)

        guard AppSettings.autoPaste, PasteService.isTrusted else {
            // No permission, or the user turned auto-paste off: the clip is on the
            // pasteboard and they can press Cmd+V themselves.
            target?.activate()
            return
        }

        // 3. Hand focus back, then 4. paste once the target is actually key.
        target?.activate()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            PasteService.pasteToFrontmostApp()
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // Clicking away dismisses, like every other picker of this shape.
        hide(restoringFocus: false)
    }
}
