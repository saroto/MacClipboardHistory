//
//  ClipListView.swift
//  MacOsClipBoard
//
//  Shared content for the menu bar popover and the hotkey panel. The only
//  difference is what "activating" a clip does: the popover just copies, the panel
//  copies and pastes into the app you came from.
//

import AppKit
import SwiftData
import SwiftUI

struct ClipListView: View {
    /// Supplied by the panel. When nil, activating a clip only copies it.
    var onActivate: ((Clip) -> Void)?
    /// Opening Settings goes through the app-owned window controller rather than
    /// `@Environment(\.openSettings)`, which is a no-op outside the scene graph.
    var onOpenSettings: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(ClipboardMonitor.self) private var monitor

    // Most-recently-used first. Bool isn't Comparable, so pinned-first can't be a
    // SortDescriptor — that half of the ordering happens in `visibleClips`, along
    // with search filtering. The history is capped at a few hundred rows, so
    // sorting and filtering in memory is cheap.
    @Query(sort: \Clip.lastUsedAt, order: .reverse)
    private var clips: [Clip]

    @State private var searchText = ""
    @State private var selection: Clip.ID?
    @FocusState private var searchFocused: Bool

    private var store: ClipStore { ClipStore(context: context) }

    private var visibleClips: [Clip] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = query.isEmpty
            ? clips
            : clips.filter { $0.content.localizedCaseInsensitiveContains(query) }
        // Stable partition: pinned clips float to the top, each group staying in
        // the most-recently-used order the query already produced.
        return matches.filter(\.isPinned) + matches.filter { !$0.isPinned }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            list
            Divider()
            footer
        }
        .frame(minWidth: 320, minHeight: 240)
        .onAppear {
            searchFocused = true
            selection = visibleClips.first?.id
        }
        .onChange(of: searchText) { selection = visibleClips.first?.id }
        // Arrow keys must work while the search field holds focus, so they are
        // handled here rather than left to the List.
        .onKeyPress(.downArrow) { moveSelection(by: 1) }
        .onKeyPress(.upArrow) { moveSelection(by: -1) }
        .onKeyPress(.return) {
            guard let clip = selectedClip else { return .ignored }
            activate(clip)
            return .handled
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clips", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
        }
        .padding(8)
    }

    private var list: some View {
        List(visibleClips, selection: $selection) { clip in
            ClipRow(clip: clip)
                .contentShape(Rectangle())
                .onTapGesture { activate(clip) }
                .contextMenu {
                    Button(clip.isPinned ? "Unpin" : "Pin") { store.togglePin(clip) }
                    Button("Copy") { monitor.write(clip) }
                    Divider()
                    Button("Delete", role: .destructive) { store.delete(clip) }
                }
                .tag(clip.id)
        }
        .listStyle(.inset)
        .overlay {
            if clips.isEmpty {
                ContentUnavailableView(
                    "No clips yet",
                    systemImage: "doc.on.clipboard",
                    description: Text("Copy something and it will show up here.")
                )
            } else if visibleClips.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("↑↓ to move · ↩ to paste · esc to close")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                onOpenSettings?()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var selectedClip: Clip? {
        visibleClips.first { $0.id == selection }
    }

    private func moveSelection(by offset: Int) -> KeyPress.Result {
        let items = visibleClips
        guard !items.isEmpty else { return .ignored }
        let current = items.firstIndex { $0.id == selection } ?? -1
        let next = max(0, min(items.count - 1, current + offset))
        selection = items[next].id
        return .handled
    }

    private func activate(_ clip: Clip) {
        if let onActivate {
            onActivate(clip)
        } else {
            // Route writes through the monitor so the app does not re-capture its
            // own write as a brand new clip.
            monitor.write(clip)
        }
    }
}

private struct ClipRow: View {
    let clip: Clip

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.preview)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(clip.lastUsedAt, format: .relative(presentation: .numeric))
                    if clip.lineCount > 1 {
                        Text("· \(clip.lineCount) lines")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Clip.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ClipListView()
        .environment(ClipboardMonitor(store: ClipStore(context: container.mainContext)))
        .modelContainer(container)
}
