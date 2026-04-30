import SwiftData
import SwiftUI

struct BibleStudyView: View {
    @Query(sort: \StudyEntry.createdAt, order: .reverse) private var entries: [StudyEntry]
    @State private var isShowingAddEntry = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModuleHeroCard(
                    module: .bibleStudy,
                    eyebrow: "Live Module",
                    title: "Keep study sessions simple and grounded.",
                    message: "Bible Study starts with passage references, entry titles, and local notes so you can build a clear history over time."
                )

                BibleStudyOverviewCard(entryCount: entries.count)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Study Entries")
                        .font(.headline)

                    if entries.isEmpty {
                        BibleStudyEmptyStateView {
                            isShowingAddEntry = true
                        }
                    } else {
                        ForEach(entries.prefix(8)) { entry in
                            StudyEntryCard(entry: entry)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppModule.bibleStudy.theme.screenGradient)
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

private struct BibleStudyOverviewCard: View {
    let entryCount: Int

    var body: some View {
        ModuleSnapshotCard(title: "Study Snapshot") {
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
                    .foregroundStyle(ModuleTheme.secondaryText)
                    .lineLimit(3)
            }

            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(ModuleTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .puttingGreenSurface(cornerRadius: 18)
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
                .listRowBackground(ModuleTheme.elevatedSurface)
            }
            .puttingGreenFormChrome()
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
        .puttingGreenSheetChrome()
    }
}

#Preview("Bible Study") {
    PreviewScreenContainer {
        BibleStudyView()
    }
    .modelContainer(for: StudyEntry.self, inMemory: true)
}
