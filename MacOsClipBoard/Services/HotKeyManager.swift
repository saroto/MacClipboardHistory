//
//  HotKeyManager.swift
//  MacOsClipBoard
//
//  Global summon shortcut.
//
//  Carbon's RegisterEventHotKey is used deliberately over a CGEventTap: it needs no
//  Accessibility permission and adds no per-keystroke cost to the whole system. A
//  tap would make every keystroke on the machine pass through this process.
//

import AppKit
import Carbon.HIToolbox
import Foundation
import Observation
import OSLog

/// The Carbon callback is a C function pointer and carries no Swift context, so the
/// handler is parked here. Only ever touched on the main thread.
nonisolated(unsafe) private var hotKeyFiredHandler: (() -> Void)?

private nonisolated func hotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async { hotKeyFiredHandler?() }
    return noErr
}

/// Shortcuts offered in Settings. A full key recorder is more UI than this needs
/// today; these avoid the obvious system and app conflicts.
enum HotKeyPreset: Int, CaseIterable, Identifiable, Sendable {
    case commandShiftV = 0
    case controlShiftV = 1
    case optionShiftV = 2
    case controlOptionV = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .commandShiftV: "⌘⇧V"
        case .controlShiftV: "⌃⇧V"
        case .optionShiftV: "⌥⇧V"
        case .controlOptionV: "⌃⌥V"
        }
    }

    var keyCode: UInt32 { UInt32(kVK_ANSI_V) }

    var carbonModifiers: UInt32 {
        switch self {
        case .commandShiftV: UInt32(cmdKey | shiftKey)
        case .controlShiftV: UInt32(controlKey | shiftKey)
        case .optionShiftV: UInt32(optionKey | shiftKey)
        case .controlOptionV: UInt32(controlKey | optionKey)
        }
    }
}

@MainActor
@Observable
final class HotKeyManager {
    private static let log = Logger(subsystem: "kimsinh.MacOsClipBoard", category: "hotkey")
    private static let signature: OSType = 0x434C_4950 // 'CLIP'

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private(set) var isRegistered = false

    /// Installs the shortcut. Safe to call repeatedly; the previous one is released.
    @discardableResult
    func register(_ preset: HotKeyPreset, onFire: @escaping () -> Void) -> Bool {
        unregister()
        hotKeyFiredHandler = onFire

        if handlerRef == nil {
            var spec = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let status = InstallEventHandler(
                GetApplicationEventTarget(),
                hotKeyEventHandler,
                1,
                &spec,
                nil,
                &handlerRef
            )
            guard status == noErr else {
                Self.log.error("InstallEventHandler failed: \(status, privacy: .public)")
                return false
            }
        }

        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            preset.keyCode,
            preset.carbonModifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            // Most commonly: another app already owns this combination.
            Self.log.error("RegisterEventHotKey failed: \(status, privacy: .public)")
            isRegistered = false
            return false
        }
        isRegistered = true
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        isRegistered = false
    }
}
