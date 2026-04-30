import SwiftData
import SwiftUI

@MainActor
struct GarageSkillVaultView: View {
    @Query(
        sort: [
            SortDescriptor(\PracticeSessionRecord.templateName),
            SortDescriptor(\PracticeSessionRecord.date, order: .reverse)
        ]
    ) private var records: [PracticeSessionRecord]

    var body: some View {
        List {
            if groupedRecords.isEmpty {
                Section {
                    Text("Completed Garage sessions will appear here once you end a checklist session.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(groupedRecords, id: \.templateName) { group in
                    Section(group.templateName) {
                        ForEach(group.records, id: \.id) { record in
                            GarageSkillVaultRecordRow(record: record)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Skill Vault")
        .navigationBarTitleDisplayMode(.large)
    }

    private var groupedRecords: [PracticeSessionRecordGroup] {
        let grouped = Dictionary(grouping: records, by: \.templateName)
        return grouped.keys.sorted().map { key in
            PracticeSessionRecordGroup(
                templateName: key,
                records: grouped[key]?
                    .sorted { $0.date > $1.date } ?? []
            )
        }
    }
}

@MainActor
private struct GarageSkillVaultRecordRow: View {
    let record: PracticeSessionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.completionRatioText)
                    .font(.headline)

                Spacer()

                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(record.environmentDisplayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if record.aggregatedNotes.isEmpty == false {
                Text(record.aggregatedNotes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PracticeSessionRecordGroup {
    let templateName: String
    let records: [PracticeSessionRecord]
}

#Preview("Garage Skill Vault") {
    NavigationStack {
        GarageSkillVaultView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
