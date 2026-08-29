//
//  ClipStore.swift
//  MacOsClipBoard
//
//  All writes to the clip history go through here: dedupe, ordering, pruning.
//

import Foundation
import OSLog
import SwiftData

@MainActor
struct ClipStore {
    private static let log = Logger(subsystem: "kimsinh.MacOsClipBoard", category: "store")

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Records freshly copied text. A repeat of an existing clip moves that clip to
    /// the top rather than inserting a duplicate.
    @discardableResult
    func record(_ text: String, sourceBundleID: String? = nil) -> Clip? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let clip: Clip
        if let existing = existingClip(withHash: Clip.hash(of: text)) {
            existing.lastUsedAt = .now
            if let sourceBundleID { existing.sourceBundleID = sourceBundleID }
            clip = existing
        } else {
            let new = Clip(content: text, sourceBundleID: sourceBundleID)
            context.insert(new)
            clip = new
        }

        // Commit before pruning. `fetchOffset` is applied to persisted rows only —
        // SwiftData merges unsaved inserts into the result *after* the offset, so
        // pruning with the new clip still uncommitted deletes the very clip we just
        // recorded (insert + delete in one transaction = a silent no-op).
        save()
        prune()
        return clip
    }

    /// Called when a clip is pasted out of history, so reuse floats it back up.
    func markUsed(_ clip: Clip) {
        clip.lastUsedAt = .now
        save()
    }

    func togglePin(_ clip: Clip) {
        clip.isPinned.toggle()
        save()
    }

    func delete(_ clip: Clip) {
        context.delete(clip)
        save()
    }

    func deleteAllUnpinned() {
        try? context.delete(model: Clip.self, where: #Predicate { $0.isPinned == false })
        save()
    }

    /// Wipes the entire history, pinned clips included. Irreversible — the caller is
    /// responsible for confirming with the user first.
    func deleteAll() {
        do {
            try context.delete(model: Clip.self)
        } catch {
            Self.log.error("clear all failed: \(error, privacy: .public)")
            return
        }
        save()
    }

    /// Drops clips whose last use predates the retention window. Pinned clips are
    /// exempt — pinning is the user saying "keep this regardless".
    ///
    /// This is a batch delete: SwiftData pushes it down to a single SQL statement
    /// rather than faulting every expired clip into memory, so the cost does not
    /// scale with how much history has accumulated.
    @discardableResult
    func sweepExpired(retention: RetentionPeriod = AppSettings.retention) -> Bool {
        let cutoff = retention.cutoff
        do {
            try context.delete(
                model: Clip.self,
                where: #Predicate { $0.isPinned == false && $0.lastUsedAt < cutoff }
            )
        } catch {
            Self.log.error("retention sweep failed: \(error, privacy: .public)")
            return false
        }
        let changed = context.hasChanges
        save()
        return changed
    }

    var clipCount: Int {
        (try? context.fetchCount(FetchDescriptor<Clip>())) ?? 0
    }

    /// Shown before a wipe so the user knows what they are about to lose.
    var pinnedCount: Int {
        let descriptor = FetchDescriptor<Clip>(predicate: #Predicate { $0.isPinned == true })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    private func existingClip(withHash hash: String) -> Clip? {
        var descriptor = FetchDescriptor<Clip>(predicate: #Predicate { $0.contentHash == hash })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func prune() {
        var descriptor = FetchDescriptor<Clip>(
            predicate: #Predicate { $0.isPinned == false },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        descriptor.fetchOffset = AppSettings.historyLimit
        guard let stale = try? context.fetch(descriptor), !stale.isEmpty else { return }
        for clip in stale { context.delete(clip) }
        save()
    }

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // Dropping one clip is recoverable; crashing the user's clipboard is not.
            Self.log.error("failed to save clip history: \(error, privacy: .public)")
        }
    }
}
