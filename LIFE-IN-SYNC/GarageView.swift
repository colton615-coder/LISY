import SwiftData
import SwiftUI

struct GarageView: View {
    @Query(sort: \SwingRecord.createdAt, order: .reverse) private var swingRecords: [SwingRecord]
    @State private var isShowingAddRecord = false
    @State private var selectedTab: ModuleHubTab = .overview

    var body: some View {
        ModuleHubScaffold(
            module: .garage,
            title: "Store swing work without overclaiming analysis.",
            subtitle: "Track records and review sessions with local-first consistency.",
            currentState: "\(swingRecords.count) swing records currently stored.",
            nextAttention: swingRecords.isEmpty ? "Add your first swing record." : "Review recent records and tag what to repeat.",
            tabs: [.overview, .records, .review],
            selectedTab: $selectedTab
        ) {
            switch selectedTab {
            case .overview:
                GarageOverviewCard(recordCount: swingRecords.count)
            case .records:
                GarageRecordsTab(records: swingRecords) {
                    isShowingAddRecord = true
                }
            case .review:
                ModuleEmptyStateCard(
                    theme: AppModule.garage.theme,
                    title: "Review scaffolding ready",
                    message: "Use this tab to compare sessions and summarize what changed before your next range block.",
                    actionTitle: "Add Swing Record",
                    action: { isShowingAddRecord = true }
                )
            default:
                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    isShowingAddRecord = true
                } label: {
                    Label("Add Swing Record", systemImage: "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppModule.garage.theme.primary)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $isShowingAddRecord) {
            AddSwingRecordSheet()
        }
    }
}

private struct GarageRecordsTab: View {
    let records: [SwingRecord]
    let addRecord: () -> Void

    var body: some View {
        ModuleActivityFeedSection(title: "Swing Records") {
            if records.isEmpty {
                GarageEmptyStateView(action: addRecord)
            } else {
                ForEach(records.prefix(8)) { record in
                    SwingRecordCard(record: record)
                }
            }
        }
    }
}

private struct GarageOverviewCard: View {
    let recordCount: Int

    var body: some View {
        ModuleVisualizationContainer(title: "Review Snapshot") {
            HStack(spacing: 12) {
                ModuleMetricChip(theme: AppModule.garage.theme, title: "Records", value: "\(recordCount)")
                ModuleMetricChip(theme: AppModule.garage.theme, title: "Mode", value: "Local")
            }
        }
    }
}

private struct SwingRecordCard: View {
    let record: SwingRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.title)
                .font(.headline)

            if let mediaFilename = record.mediaFilename, mediaFilename.isEmpty == false {
                Text(mediaFilename)
                    .font(.caption)
                    .foregroundStyle(AppModule.garage.theme.primary)
            }

            if record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Text(record.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct GarageEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.garage.theme,
            title: "No swing records yet",
            message: "Add a swing session with a short note or media reference to begin tracking your progress.",
            actionTitle: "Add First Record",
            action: action
        )
    }
}

private struct AddSwingRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var mediaFilename = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Swing Record") {
                    TextField("Title", text: $title)
                    TextField("Media filename", text: $mediaFilename)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle("New Swing Record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedTitle.isEmpty == false else {
                            return
                        }

                        modelContext.insert(
                            SwingRecord(
                                title: trimmedTitle,
                                mediaFilename: mediaFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : mediaFilename.trimmingCharacters(in: .whitespacesAndNewlines),
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview("Garage") {
    PreviewScreenContainer {
        GarageView()
    }
    .modelContainer(for: SwingRecord.self, inMemory: true)
}
