//
//  RetentionSweeper.swift
//  MacOsClipBoard
//
//  Enforces the "history doesn't live forever" rule on a slow timer.
//

import Foundation
import Observation

@MainActor
@Observable
final class RetentionSweeper {
    /// Expiry is not time-critical — a clip lingering a few extra minutes past its
    /// window costs nothing, so this runs rarely and with a huge tolerance.
    static let sweepInterval: TimeInterval = 10 * 60
    static let sweepTolerance: TimeInterval = 60

    private(set) var lastSweep: Date?

    private let store: ClipStore
    private var timer: Timer?

    init(store: ClipStore) {
        self.store = store
    }

    func start() {
        // Catch up on everything that expired while the app was not running.
        sweep()
        let timer = Timer(timeInterval: Self.sweepInterval, repeats: true) { _ in
            MainActor.assumeIsolated { self.sweep() }
        }
        timer.tolerance = Self.sweepTolerance
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func sweep() {
        store.sweepExpired()
        lastSweep = .now
    }
}
