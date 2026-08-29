//
//  SettingsView.swift
//  MacOsClipBoard
//

import ServiceManagement
import SwiftData
import SwiftUI

struct SettingsView: View {
    let sweeper: RetentionSweeper
    /// Called when the shortcut changes so the old registration is replaced.
    var onHotKeyChange: () -> Void = {}

    @Environment(\.modelContext) private var context

    @AppStorage(SettingsKey.hotKeyPreset) private var hotKeyPreset = HotKeyPreset.commandShiftV.rawValue
    @AppStorage(SettingsKey.autoPaste) private var autoPaste = true
    @AppStorage(SettingsKey.retentionDays) private var retentionDays = AppSettings.defaultRetention.rawValue
    @AppStorage(SettingsKey.historyLimit) private var historyLimit = AppSettings.defaultHistoryLimit

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?
    @State private var accessibilityTrusted = PasteService.isTrusted
    @State private var confirmingClearAll = false

    private var store: ClipStore { ClipStore(context: context) }

    var body: some View {
        Form {
            Section {
                Picker("Show history with", selection: $hotKeyPreset) {
                    ForEach(HotKeyPreset.allCases) { preset in
                        Text(preset.label).tag(preset.rawValue)
                    }
                }
                .onChange(of: hotKeyPreset) { onHotKeyChange() }

                Toggle("Paste automatically after choosing", isOn: $autoPaste)

                if autoPaste && !accessibilityTrusted {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Accessibility permission is required to paste for you.")
                            .font(.caption)
                        Text("Without it, choosing a clip still copies it — press ⌘V yourself.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Grant Permission…") {
                                PasteService.requestPermission()
                            }
                            Button("Open Settings") {
                                PasteService.openAccessibilitySettings()
                            }
                            Button("Recheck") {
                                accessibilityTrusted = PasteService.isTrusted
                            }
                        }
                    }
                }
            } header: {
                Text("Shortcut")
            }

            Section {
                Picker("Keep clips for", selection: $retentionDays) {
                    ForEach(RetentionPeriod.allCases) { period in
                        Text(period.label).tag(period.rawValue)
                    }
                }
                .onChange(of: retentionDays) { sweeper.sweep() }

                Stepper(
                    "Keep at most \(historyLimit) clips",
                    value: $historyLimit,
                    in: 50...5000,
                    step: 50
                )
            } header: {
                Text("History")
            } footer: {
                Text("Pinned clips are never deleted, no matter how old they are.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                LabeledContent("Clips stored", value: "\(store.clipCount)")
                LabeledContent("Pinned", value: "\(store.pinnedCount)")
                HStack {
                    Button("Sweep Expired Now") { sweeper.sweep() }
                    Button("Clear Unpinned", role: .destructive) {
                        store.deleteAllUnpinned()
                    }
                    Spacer()
                    Button("Clear Everything…", role: .destructive) {
                        confirmingClearAll = true
                    }
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("“Clear Unpinned” keeps pinned clips. “Clear Everything” does not.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .confirmationDialog(
            "Delete all \(store.clipCount) clips?",
            isPresented: $confirmingClearAll,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) { store.deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes your entire clipboard history, including \(store.pinnedCount) pinned clip(s). It cannot be undone.")
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            // Commonly fails for builds run out of DerivedData rather than /Applications.
            loginItemError = "Could not update login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

#Preview {
    SettingsView(sweeper: RetentionSweeper(store: ClipStore(context: AppModelContainer.shared.mainContext)))
}
