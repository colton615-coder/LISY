import SwiftData
import SwiftUI

struct BibleStudyView: View {
    @Query(sort: \StudyEntry.createdAt, order: .reverse) private var entries: [StudyEntry]
    @State private var isShowingAddEntry = false
    @State private var selectedTab: ModuleHubTab = .overview

    init(initialTab: ModuleHubTab = .overview) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ModuleScreen(theme: AppModule.bibleStudy.theme) {
            ModuleHeader(
                theme: AppModule.bibleStudy.theme,
                title: "Bible Study",
                subtitle: "Keep study sessions grounded, quiet, and text-first."
            )

            ModuleHeroCard(
                module: .bibleStudy,
                eyebrow: "Recent Focus",
                title: latestPassageTitle,
                message: entries.isEmpty ? "Add a first passage and short reflection to begin building your study history." : "Review recent entries and return to the passages worth deeper meditation."
            )

            HubTabPicker(tabs: [.overview, .entries, .review], selectedTab: $selectedTab, theme: AppModule.bibleStudy.theme)

            switch selectedTab {
            case .overview:
                BibleStudyOverviewCard(entryCount: entries.count, latestEntry: entries.first)
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

    private var latestPassageTitle: String {
        entries.first?.passageReference ?? "Scripture"
    }
}

private struct BibleStudyEntriesTab: View {
    let entries: [StudyEntry]
    let addEntry: () -> Void

    var body: some View {
        ModuleListSection(title: "Recent Study Entries") {
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
        ModuleRowSurface(theme: AppModule.bibleStudy.theme) {
            if let latestEntry = entries.first {
                VStack(alignment: .leading, spacing: ModuleSpacing.small) {
                    Text(latestEntry.passageReference)
                        .font(.headline)
                        .foregroundStyle(AppModule.bibleStudy.theme.primary)
                    Text(latestEntry.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppModule.bibleStudy.theme.textPrimary)
                    Text(latestEntry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No notes recorded on the latest entry." : latestEntry.notes)
                        .foregroundStyle(AppModule.bibleStudy.theme.textSecondary)
                        .lineLimit(4)
                }
            } else {
                Text("Review surfaces will become more useful once study history exists.")
                    .foregroundStyle(AppModule.bibleStudy.theme.textSecondary)
            }
        }
    }
}

private struct BibleStudyOverviewCard: View {
    let entryCount: Int
    let latestEntry: StudyEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.large) {
            ModuleMetricStrip(theme: AppModule.bibleStudy.theme) {
                ModuleMetricChip(theme: AppModule.bibleStudy.theme, title: "Entries", value: "\(entryCount)")
            }

            ModuleRowSurface(theme: AppModule.bibleStudy.theme) {
                if let latestEntry {
                    Text(latestEntry.title)
                        .font(.headline)
                        .foregroundStyle(AppModule.bibleStudy.theme.textPrimary)
                    Text(latestEntry.passageReference)
                        .font(.subheadline)
                        .foregroundStyle(AppModule.bibleStudy.theme.primary)
                    if latestEntry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        Text(latestEntry.notes)
                            .foregroundStyle(AppModule.bibleStudy.theme.textSecondary)
                            .lineLimit(4)
                    }
                } else {
                    Text("Recent study will appear here once entries exist.")
                        .foregroundStyle(AppModule.bibleStudy.theme.textSecondary)
                }
            }
        }
    }
}

private struct StudyEntryCard: View {
    let entry: StudyEntry

    var body: some View {
        ModuleRowSurface(theme: AppModule.bibleStudy.theme) {
            Text(entry.title)
                .font(.headline)
                .foregroundStyle(AppModule.bibleStudy.theme.textPrimary)

            Text(entry.passageReference)
                .font(.subheadline)
                .foregroundStyle(AppModule.bibleStudy.theme.primary)

            if entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Text(entry.notes)
                    .font(.subheadline)
                    .foregroundStyle(AppModule.bibleStudy.theme.textSecondary)
                    .lineLimit(3)
            }

            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(AppModule.bibleStudy.theme.textSecondary)
        }
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

#Preview("Bible Study Overview") {
    PreviewScreenContainer {
        BibleStudyView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
    .preferredColorScheme(.dark)
}

#Preview("Bible Study Review") {
    PreviewScreenContainer {
        BibleStudyView(initialTab: .review)
    }
    .modelContainer(PreviewCatalog.populatedApp)
    .preferredColorScheme(.dark)
}

#Preview("Bible Study Empty") {
    PreviewScreenContainer {
        BibleStudyView(initialTab: .entries)
    }
    .modelContainer(PreviewCatalog.emptyApp)
    .preferredColorScheme(.dark)
}
