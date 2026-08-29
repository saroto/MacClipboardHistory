//
//  Clip.swift
//  MacOsClipBoard
//
//  One entry in the clipboard history.
//

import CryptoKit
import Foundation
import SwiftData

@Model
final class Clip {
    /// Full text as it was copied. Paste this verbatim — never the truncated preview.
    var content: String
    /// SHA-256 of `content`, used to collapse repeats of the same clip.
    var contentHash: String
    var createdAt: Date
    /// Bumped every time the clip is copied again or pasted from history.
    /// Ordering and pruning both key off this, not `createdAt`.
    var lastUsedAt: Date
    /// Pinned clips are exempt from pruning.
    var isPinned: Bool
    /// Bundle identifier of whatever app was frontmost when the clip was captured.
    var sourceBundleID: String?

    init(
        content: String,
        createdAt: Date = .now,
        isPinned: Bool = false,
        sourceBundleID: String? = nil
    ) {
        self.content = content
        self.contentHash = Clip.hash(of: content)
        self.createdAt = createdAt
        self.lastUsedAt = createdAt
        self.isPinned = isPinned
        self.sourceBundleID = sourceBundleID
    }

    static func hash(of content: String) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension Clip {
    /// Single-line, length-capped rendering for list rows.
    var preview: String {
        let collapsed = content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.count > 200 ? String(collapsed.prefix(200)) + "…" : collapsed
    }

    var lineCount: Int {
        content.split(separator: "\n", omittingEmptySubsequences: false).count
    }
}
