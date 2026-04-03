import SwiftData
import SwiftUI

struct BibleStudyView: View {
    @Query(sort: \StudyEntry.createdAt, order: .reverse) private var entries: [StudyEntry]
    @State private var isShowingAddEntry = false
    @State private var selectedTab: ModuleHubTab = .overview

    var body: some View {
        ModuleHubScaffold(
            module: .bibleStudy,
            title: "Keep study sessions simple and grounded.",
            subtitle: "Capture passages, preserve reflections, and keep review surfaces calm and text-first.",
            currentState: "\(entries.count) study entries recorded locally.",
            nextAttention: entries.isEmpty ? "Add a first passage and reflection." : "Review recent entries and return to the passages worth deeper meditation.",
            tabs: [.overview, .entries, .review],
            selectedTab: $selectedTab
        ) {
            switch selectedTab {
            case .overview:
                BibleStudyOverviewCard(entryCount: entries.count)
            case .entries:
                BibleStudyEntriesTab(entries: entries) {
                    isShowingAddEntry = true
                }
            case .review:
                BibleStudyReviewTab(entries: entries)
            default:
                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            ModuleBottomActionBar(
                theme: AppModule.bibleStudy.theme,
                title: "Add Study Entry",
                systemImage: "plus"
            ) {
                isShowingAddEntry = true
            }
        }
        .sheet(isPresented: $isShowingAddEntry) {
            AddStudyEntrySheet()
        }
    }
}

private struct BibleStudyEntriesTab: View {
    let entries: [StudyEntry]
    let addEntry: () -> Void

    var body: some View {
        ModuleActivityFeedSection(title: "Recent Study Entries") {
            if entries.isEmpty {
                BibleStudyEmptyStateView(action: addEntry)
            } else {
                ForEach(entries.prefix(8)) { entry in
                    StudyEntryCard(entry: entry)
                }
            }
        }
    }
}

private struct BibleStudyReviewTab: View {
    let entries: [StudyEntry]

    var body: some View {
        ModuleVisualizationContainer(title: "Review Lane") {
            if let latestEntry = entries.first {
                VStack(alignment: .leading, spacing: ModuleSpacing.small) {
                    Text(latestEntry.passageReference)
                        .font(.headline)
                        .foregroundStyle(AppModule.bibleStudy.theme.primary)
                    Text(latestEntry.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(latestEntry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No notes recorded on the latest entry." : latestEntry.notes)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            } else {
                Text("Review surfaces will become more useful once study history exists.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BibleStudyOverviewCard: View {
    let entryCount: Int

    var body: some View {
        ModuleVisualizationContainer(title: "Study Snapshot") {
            HStack(spacing: 12) {
                ModuleMetricChip(theme: AppModule.bibleStudy.theme, title: "Entries", value: "\(entryCount)")
                ModuleMetricChip(theme: AppModule.bibleStudy.theme, title: "Focus", value: "Scripture")
            }
        }
    }
}

private struct StudyEntryCard: View {
    let entry: StudyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.headline)

            Text(entry.passageReference)
                .font(.subheadline)
                .foregroundStyle(AppModule.bibleStudy.theme.primary)

            if entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Text(entry.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct BibleStudyEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.bibleStudy.theme,
            title: "No study entries yet",
            message: "Capture a passage reference, title, and short reflection to start building your study history.",
            actionTitle: "Add First Entry",
            action: action
        )
    }
}

private struct AddStudyEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var passageReference = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Study Entry") {
                    TextField("Title", text: $title)
                    TextField("Passage Reference", text: $passageReference)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle("New Study Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedPassage = passageReference.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedTitle.isEmpty == false, trimmedPassage.isEmpty == false else {
                            return
                        }

                        modelContext.insert(
                            StudyEntry(
                                title: trimmedTitle,
                                passageReference: trimmedPassage,
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(
                        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        passageReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}

#Preview("Bible Study") {
    PreviewScreenContainer {
        BibleStudyView()
    }
    .modelContainer(for: StudyEntry.self, inMemory: true)
}
