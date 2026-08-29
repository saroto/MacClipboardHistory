//
//  PasteService.swift
//  MacOsClipBoard
//
//  Synthesises Cmd+V into whatever app is frontmost.
//

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation
import OSLog

@MainActor
enum PasteService {
    private static let log = Logger(subsystem: "kimsinh.MacOsClipBoard", category: "paste")

    /// Posting synthetic events into another process requires Accessibility.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt with a link to Privacy & Security. The grant only
    /// takes effect for *this* code signature — see CLAUDE.md.
    static func requestPermission() {
        // `kAXTrustedCheckOptionPrompt` is an imported global var, which Swift 6
        // rejects as shared mutable state. Its value is this string.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Posts Cmd+V. The caller is responsible for having already reactivated the
    /// target app — posting before it is key silently does nothing.
    static func pasteToFrontmostApp() {
        guard isTrusted else {
            log.notice("paste skipped: Accessibility not granted")
            return
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)

        guard let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        else {
            log.error("could not create paste events")
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}
