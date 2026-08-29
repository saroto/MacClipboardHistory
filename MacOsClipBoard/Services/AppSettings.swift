//
//  AppSettings.swift
//  MacOsClipBoard
//

import Foundation

/// How long an unpinned clip survives after it was last used.
enum RetentionPeriod: Int, CaseIterable, Identifiable, Sendable {
    case oneDay = 1
    case threeDays = 3
    case oneWeek = 7
    case twoWeeks = 14
    case oneMonth = 30

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .oneDay: "1 day"
        case .threeDays: "3 days"
        case .oneWeek: "1 week"
        case .twoWeeks: "2 weeks"
        case .oneMonth: "1 month"
        }
    }

    /// Clips last used before this instant are expired.
    var cutoff: Date {
        Calendar.current.date(byAdding: .day, value: -rawValue, to: .now) ?? .distantPast
    }
}

enum SettingsKey {
    static let retentionDays = "retentionDays"
    static let historyLimit = "historyLimit"
    static let hotKeyPreset = "hotKeyPreset"
    static let autoPaste = "autoPaste"
}

enum AppSettings {
    static let defaultRetention: RetentionPeriod = .oneWeek
    static let defaultHistoryLimit = 500

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.retentionDays: defaultRetention.rawValue,
            SettingsKey.historyLimit: defaultHistoryLimit,
            SettingsKey.hotKeyPreset: HotKeyPreset.commandShiftV.rawValue,
            SettingsKey.autoPaste: true,
        ])
    }

    static var retention: RetentionPeriod {
        RetentionPeriod(rawValue: UserDefaults.standard.integer(forKey: SettingsKey.retentionDays))
            ?? defaultRetention
    }

    static var hotKey: HotKeyPreset {
        HotKeyPreset(rawValue: UserDefaults.standard.integer(forKey: SettingsKey.hotKeyPreset))
            ?? .commandShiftV
    }

    /// When off (or when Accessibility is denied) choosing a clip only copies it.
    static var autoPaste: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.autoPaste)
    }

    static var historyLimit: Int {
        let stored = UserDefaults.standard.integer(forKey: SettingsKey.historyLimit)
        return stored > 0 ? stored : defaultHistoryLimit
    }
}
