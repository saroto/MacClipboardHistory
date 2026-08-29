//
//  AppModelContainer.swift
//  MacOsClipBoard
//

import Foundation
import SwiftData

enum AppModelContainer {
    static let schema = Schema([Clip.self])

    static let shared: ModelContainer = make()

    /// Explicit store location. Unsandboxed, SwiftData's default configuration puts
    /// a file literally named `default.store` in the *shared* Application Support
    /// directory, where it collides with every other app that did the same. Keep our
    /// history in its own subdirectory.
    static var storeURL: URL {
        let base = URL.applicationSupportDirectory.appending(path: "MacOsClipBoard", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: "ClipHistory.store", directoryHint: .notDirectory)
    }

    private static func make() -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]
            )
        } catch {
            // The on-disk store is unreadable (corrupt, or a schema change we can't
            // migrate). Losing history is bad; refusing to launch is worse, so fall
            // back to an ephemeral store and keep working for this session.
            NSLog("MacOsClipBoard: persistent store unavailable (\(error)); using in-memory history")
            // An in-memory container has no filesystem to fail on.
            return try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }
    }
}
