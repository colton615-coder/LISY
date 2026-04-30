import SwiftData
import SwiftUI

@MainActor
struct GarageTemplateBuilderWizard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var path: [GarageTemplateBuilderStep] = []
    @State private var draft = GarageTemplateDraft()
    @State private var isPresentingNewDrillSheet = false
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            GarageTemplateSetupStep(
                draft: $draft,
                onNext: { path.append(.dictionary) }
            )
            .navigationDestination(for: GarageTemplateBuilderStep.self) { step in
                switch step {
                case .dictionary:
                    GarageTemplateDictionaryStep(
                        draft: $draft,
                        onCreateDefinition: { isPresentingNewDrillSheet = true },
                        onReview: { path.append(.review) }
                    )
                case .review:
                    GarageTemplateReviewStep(
                        draft: draft,
                        onSave: saveTemplate
                    )
                }
            }
        }
        .sheet(isPresented: $isPresentingNewDrillSheet) {
            GarageDrillDefinitionEditorView { definition in
                draft.toggle(definition)
            }
        }
        .alert("Unable To Save Template", isPresented: saveErrorAlertIsPresented) {
            Button("OK", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "An unexpected error occurred.")
        }
    }

    private var saveErrorAlertIsPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    saveErrorMessage = nil
                }
            }
        )
    }

    private func saveTemplate() {
        let template = draft.makeTemplate()
        modelContext.insert(template)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

private enum GarageTemplateBuilderStep: Hashable {
    case dictionary
    case review
}

private struct GarageTemplateDraft {
    var title = ""
    var environment: PracticeEnvironment = .net
    var drills: [PracticeTemplateDrill] = []

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canContinueFromSetup: Bool {
        trimmedTitle.isEmpty == false
    }

    var canReview: Bool {
        drills.isEmpty == false
    }

    mutating func toggle(_ definition: PracticeDrillDefinition) {
        if let existingIndex = drills.firstIndex(where: { $0.definitionID == definition.id }) {
            drills.remove(at: existingIndex)
        } else {
            drills.append(PracticeTemplateDrill(definition: definition))
        }
    }

    func contains(_ definition: PracticeDrillDefinition) -> Bool {
        drills.contains(where: { $0.definitionID == definition.id })
    }

    func makeTemplate() -> PracticeTemplate {
        PracticeTemplate(
            title: trimmedTitle,
            environment: environment.rawValue,
            drills: drills
        )
    }
}

@MainActor
private struct GarageTemplateSetupStep: View {
    @Binding var draft: GarageTemplateDraft

    let onNext: () -> Void

    var body: some View {
        Form {
            Section("Template") {
                TextField("Template Title", text: $draft.title)
            }

            Section("Environment") {
                Picker("Environment", selection: $draft.environment) {
                    ForEach(PracticeEnvironment.allCases) { environment in
                        Text(environment.displayName).tag(environment)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button("Continue", action: onNext)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.canContinueFromSetup == false)
            }
        }
        .navigationTitle("New Template")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
private struct GarageTemplateDictionaryStep: View {
    @Binding var draft: GarageTemplateDraft
    @Query(sort: \PracticeDrillDefinition.title) private var definitions: [PracticeDrillDefinition]

    let onCreateDefinition: () -> Void
    let onReview: () -> Void

    var body: some View {
        List {
            Section("Dictionary") {
                if definitions.isEmpty {
                    Text("No drills exist yet. Tap + to create the first reusable drill.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(definitions, id: \.id) { definition in
                        Button {
                            draft.toggle(definition)
                        } label: {
                            GarageDictionaryDefinitionRow(
                                definition: definition,
                                isSelected: draft.contains(definition)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Selected") {
                if draft.drills.isEmpty {
                    Text("Pick drills from the dictionary to build this template.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(draft.drills) { drill in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(drill.title)
                                .font(.headline)
                            Text(drill.metadataSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section {
                Button("Review Template", action: onReview)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.canReview == false)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Drill Dictionary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onCreateDefinition()
                } label: {
                    Label("New Drill", systemImage: "plus")
                }
            }
        }
    }
}

@MainActor
private struct GarageDictionaryDefinitionRow: View {
    let definition: PracticeDrillDefinition
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.title)
                    .font(.headline)
                Text(definition.metadataSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
private struct GarageTemplateReviewStep: View {
    let draft: GarageTemplateDraft
    let onSave: () -> Void

    var body: some View {
        List {
            Section("Template") {
                LabeledContent("Title", value: draft.trimmedTitle)
                LabeledContent("Environment", value: draft.environment.displayName)
                LabeledContent("Drills", value: "\(draft.drills.count)")
            }

            Section("Checklist") {
                ForEach(Array(draft.drills.enumerated()), id: \.element.id) { offset, drill in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(offset + 1). \(drill.title)")
                            .font(.headline)
                        Text(drill.metadataSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section {
                Button("Save Template", action: onSave)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
private struct GarageDrillDefinitionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var focusArea = ""
    @State private var targetClub = ""
    @State private var defaultRepCount = 10
    @State private var saveErrorMessage: String?

    let onSave: (PracticeDrillDefinition) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Drill") {
                    TextField("Title", text: $title)
                    TextField("Focus Area", text: $focusArea)
                    TextField("Target Club", text: $targetClub)
                    Stepper("Default Reps: \(defaultRepCount)", value: $defaultRepCount, in: 1...50)
                }
            }
            .navigationTitle("New Drill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveDefinition)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .alert("Unable To Save Drill", isPresented: saveErrorAlertIsPresented) {
                Button("OK", role: .cancel) {
                    saveErrorMessage = nil
                }
            } message: {
                Text(saveErrorMessage ?? "An unexpected error occurred.")
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var saveErrorAlertIsPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    saveErrorMessage = nil
                }
            }
        )
    }

    private func saveDefinition() {
        let definition = PracticeDrillDefinition(
            title: trimmedTitle,
            focusArea: focusArea.trimmingCharacters(in: .whitespacesAndNewlines),
            targetClub: targetClub.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultRepCount: defaultRepCount
        )
        modelContext.insert(definition)

        do {
            try modelContext.save()
            onSave(definition)
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

#Preview("Garage Template Builder") {
    GarageTemplateBuilderWizard()
        .modelContainer(PreviewCatalog.populatedApp)
}
