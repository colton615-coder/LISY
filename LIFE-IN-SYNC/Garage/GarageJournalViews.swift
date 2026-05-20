import SwiftUI

@MainActor
struct GarageJournalNewEntryView: View {
    private let entryTypes = [
        "Swing Feel",
        "Scorecard Note",
        "Course Management",
        "Drill Discovery",
        "Setup / Equipment",
        "Coach Cue",
        "General Note"
    ]

    var body: some View {
        GarageProScaffold(bottomPadding: 48) {
            GarageProHeroCard(
                eyebrow: "Journal",
                title: "New Entry",
                subtitle: "Capture the golf notes worth carrying into the next practice.",
                value: "\(entryTypes.count)",
                valueLabel: "Types"
            )

            VStack(alignment: .leading, spacing: 14) {
                GarageProSectionHeader(
                    eyebrow: "Entry Type",
                    title: "Choose A Note"
                )

                ForEach(entryTypes, id: \.self) { entryType in
                    GarageJournalTypeRow(title: entryType)
                }
            }
        }
        .navigationTitle("New Entry")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
struct GarageJournalArchiveView: View {
    var body: some View {
        GarageProScaffold(bottomPadding: 48) {
            GarageProHeroCard(
                eyebrow: "Journal",
                title: "Archive",
                subtitle: "A calm home for saved swing feels, course notes, coach cues, and practice takeaways.",
                value: "0",
                valueLabel: "Entries"
            )

            GarageProCard(cornerRadius: 26, padding: 20) {
                Text("No journal entries yet.")
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text("New Entry will become the capture path once journal persistence is approved.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GarageJournalTypeRow: View {
    let title: String

    var body: some View {
        GarageProCard(cornerRadius: 22, padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: "note.text")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Spacer(minLength: 8)
            }
        }
    }
}
