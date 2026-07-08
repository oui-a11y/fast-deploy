import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var selectedItemID: DeploymentHistoryRecord.ID?
    @State private var selectedLog = ""
    @State private var showClearAllConfirmation = false

    private var selectedItem: DeploymentHistoryRecord? {
        let id = selectedItemID ?? store.history.first?.id
        return store.history.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(store.history.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button(role: .destructive) {
                        showClearAllConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .disabled(store.history.isEmpty)
                    .help("Clear all history")
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

                if store.history.isEmpty {
                    EmptyHistoryState()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedItemID) {
                        ForEach(store.history) { item in
                            HistorySidebarRow(item: item)
                                .tag(item.id)
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(width: 220)
            .background(.bar)

            Divider()

            if let item = selectedItem {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            AppSectionHeader(
                                title: "\(item.projectName) / \(item.environmentName)",
                                subtitle: "\(item.startedAt.formatted()) - \(item.finishedAt.formatted())",
                                systemImage: "clock.badge.checkmark"
                            )

                            StatusPill(
                                title: item.summary,
                                systemImage: item.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill",
                                color: item.succeeded ? DeployBarTheme.success : DeployBarTheme.danger
                            )

                            Button(role: .destructive) {
                                deleteSelectedItem()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                        HStack(spacing: 8) {
                            MetadataChip(title: "Started", value: item.startedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                            MetadataChip(title: "Duration", value: durationText(item), systemImage: "timer")
                            MetadataChip(title: "Log", value: logLengthText(item), systemImage: "text.alignleft")
                        }
                    }
                    .padding(12)
                    .deploySurface()

                    VStack(spacing: 0) {
                        HStack {
                            Label("Run Log", systemImage: "terminal")
                                .font(.caption.weight(.semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.bar)

                        ConsoleTextView(text: selectedLog, placeholder: "No log captured.")
                    }
                    .deploySurface()
                }
                .padding(14)
            } else {
                EmptyHistoryState()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            selectedItemID = selectedItemID ?? store.history.first?.id
            loadSelectedLog()
        }
        .onChange(of: selectedItemID) { _, _ in
            loadSelectedLog()
        }
        .onChange(of: store.history.map(\.id)) { _, _ in
            if let selectedItemID, !store.history.contains(where: { $0.id == selectedItemID }) {
                self.selectedItemID = store.history.first?.id
            }
            loadSelectedLog()
        }
        .confirmationDialog("Clear all deployment history?", isPresented: $showClearAllConfirmation, titleVisibility: .visible) {
            Button("Clear All History", role: .destructive) {
                store.clearHistory()
                selectedItemID = nil
                selectedLog = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every saved deployment record and log.")
        }
    }

    private func durationText(_ item: DeploymentHistoryRecord) -> String {
        let seconds = max(0, Int(item.finishedAt.timeIntervalSince(item.startedAt)))
        if seconds < 60 {
            return "\(seconds)s"
        }
        return "\(seconds / 60)m \(seconds % 60)s"
    }

    private func logLengthText(_ item: DeploymentHistoryRecord) -> String {
        if let count = item.logCharacterCount {
            return "\(count) chars"
        }
        return selectedLog.isEmpty ? "On demand" : "\(selectedLog.count) chars"
    }

    private func loadSelectedLog() {
        guard let item = selectedItem else {
            selectedLog = ""
            return
        }
        selectedLog = store.loadHistoryLog(for: item)
    }

    private func deleteSelectedItem() {
        guard let item = selectedItem else { return }
        store.deleteHistory(item)
        selectedItemID = store.history.first?.id
        loadSelectedLog()
    }
}

private struct EmptyHistoryState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(.tertiary)

            Text("No History")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct HistorySidebarRow: View {
    let item: DeploymentHistoryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: item.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(item.succeeded ? DeployBarTheme.success : DeployBarTheme.danger)
                Text("\(item.projectName) / \(item.environmentName)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            Text(item.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
