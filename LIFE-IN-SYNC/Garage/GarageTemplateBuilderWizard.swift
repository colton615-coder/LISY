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
        .garagePuttingGreenSheetChrome()
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
        GarageProScaffold {
            GarageProHeroCard(
                eyebrow: "Template Builder",
                title: "New Routine",
                subtitle: "Name the routine and choose the practice surface before adding drills."
            )

            GarageProCard {
                Text("Template Title")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)

                TextField("Template Title", text: $draft.title)
                    .padding(16)
                    .frame(minHeight: 60)
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(GarageProTheme.border, lineWidth: 1)
                    )
            }

            GarageProCard {
                Text("Environment")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)

                GarageProSegmentedSelector(
                    options: PracticeEnvironment.allCases,
                    selection: $draft.environment
                ) { environment, isSelected in
                    VStack(spacing: 6) {
                        Image(systemName: environment.systemImage)
                            .font(.system(size: 18, weight: .bold))
                        Text(environment.displayName)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isSelected ? GarageProTheme.accent : GarageProTheme.textSecondary)
                }
            }

            HStack {
                GarageProPrimaryButton(
                    title: "Continue",
                    systemImage: "arrow.right",
                    isEnabled: draft.canContinueFromSetup
                ) {
                    onNext()
                }
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
        GarageProScaffold {
            GarageProHeroCard(
                eyebrow: "Global Dictionary",
                title: "Choose Drills",
                subtitle: "Build this routine from reusable drills, or create a new drill for the dictionary.",
                value: "\(draft.drills.count)",
                valueLabel: "Selected"
            )

            GarageProCard {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Drill Dictionary")
                            .font(.system(.title3, design: .rounded).weight(.black))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        Text(definitions.isEmpty ? "Create the first reusable drill." : "\(definitions.count) reusable drills available.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        garageTriggerImpact(.heavy)
                        onCreateDefinition()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(ModuleTheme.garageSurfaceDark)
                            .frame(width: 60, height: 60)
                            .background(GarageProTheme.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New Drill")
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                GarageBuilderSectionHeader(title: "Available")

                if definitions.isEmpty {
                    GarageProCard {
                        Text("No drills yet")
                            .font(.system(.headline, design: .rounded).weight(.black))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        Text("Tap the plus button above to create the first reusable drill.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                    }
                } else {
                    ForEach(definitions, id: \.id) { definition in
                        Button {
                            garageTriggerSelection()
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

            VStack(alignment: .leading, spacing: 14) {
                GarageBuilderSectionHeader(title: "Selected")

                if draft.drills.isEmpty {
                    GarageProCard {
                        Text("No drills selected")
                            .font(.system(.headline, design: .rounded).weight(.black))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        Text("Pick drills from the dictionary to build this template.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                    }
                } else {
                    ForEach(draft.drills) { drill in
                        GarageSelectedDrillCard(drill: drill)
                    }
                }
            }

            HStack {
                GarageProPrimaryButton(
                    title: "Review Template",
                    systemImage: "arrow.right",
                    isEnabled: draft.canReview
                ) {
                    onReview()
                }
            }
        }
        .navigationTitle("Drill Dictionary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
private struct GarageDictionaryDefinitionRow: View {
    let definition: PracticeDrillDefinition
    let isSelected: Bool

    var body: some View {
        GarageProCard(isActive: isSelected) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isSelected ? GarageProTheme.accent : GarageProTheme.textSecondary)
                    .frame(width: 60, height: 60)
                    .background(GarageProTheme.accent.opacity(isSelected ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(definition.title)
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(definition.metadataSummary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }

                Spacer(minLength: 8)
            }
            .frame(minHeight: 60)
        }
    }
}

@MainActor
private struct GarageTemplateReviewStep: View {
    let draft: GarageTemplateDraft
    let onSave: () -> Void

    var body: some View {
        GarageProScaffold {
            GarageProHeroCard(
                eyebrow: "Review",
                title: draft.trimmedTitle,
                subtitle: "\(draft.environment.displayName) • \(draft.drills.count) drills ready for execution.",
                value: "\(draft.drills.count)",
                valueLabel: "Drills"
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                GarageProMetricCard(title: "Surface", value: draft.environment.displayName, systemImage: draft.environment.systemImage, isActive: true)
                GarageProMetricCard(title: "Reps", value: "\(draft.drills.reduce(0) { $0 + $1.defaultRepCount })", systemImage: "repeat")
            }

            VStack(alignment: .leading, spacing: 14) {
                GarageBuilderSectionHeader(title: "Checklist")

                ForEach(Array(draft.drills.enumerated()), id: \.element.id) { offset, drill in
                    GarageReviewDrillCard(index: offset + 1, drill: drill)
                }
            }

            HStack {
                GarageProPrimaryButton(
                    title: "Save Template",
                    systemImage: "checkmark"
                ) {
                    onSave()
                }
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GarageBuilderSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.title2, design: .rounded).weight(.black))
            .foregroundStyle(GarageProTheme.textPrimary)
    }
}

private struct GarageSelectedDrillCard: View {
    let drill: PracticeTemplateDrill

    var body: some View {
        GarageProCard(isActive: true) {
            Text(drill.title)
                .font(.system(.headline, design: .rounded).weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text(drill.metadataSummary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GarageProTheme.textSecondary)
        }
    }
}

private struct GarageReviewDrillCard: View {
    let index: Int
    let drill: PracticeTemplateDrill

    var body: some View {
        GarageProCard {
            HStack(alignment: .top, spacing: 14) {
                Text("\(index)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 60, height: 60)
                    .background(GarageProTheme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(drill.title)
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(drill.metadataSummary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
            }
            .frame(minHeight: 60)
        }
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
            GarageProScaffold(bottomPadding: 56) {
                GarageProHeroCard(
                    eyebrow: "Dictionary",
                    title: "New Drill",
                    subtitle: "Create a reusable drill once, then add it to any future Garage routine."
                )

                GarageProCard {
                    GarageProField(title: "Title", text: $title, prompt: "Start line gate")
                    GarageProField(title: "Focus Area", text: $focusArea, prompt: "Contact, pace, face control")
                    GarageProField(title: "Target Club", text: $targetClub, prompt: "Putter, wedge, 7 iron")

                    Stepper(value: $defaultRepCount, in: 1...50) {
                        HStack {
                            Text("Default Reps")
                                .font(.system(.headline, design: .rounded).weight(.black))
                                .foregroundStyle(GarageProTheme.textPrimary)

                            Spacer()

                            Text("\(defaultRepCount)")
                                .font(.system(size: 26, weight: .black, design: .monospaced))
                                .foregroundStyle(GarageProTheme.accent)
                        }
                        .frame(minHeight: 60)
                    }
                    .tint(GarageProTheme.accent)
                }

                HStack {
                    GarageProPrimaryButton(
                        title: "Save",
                        systemImage: "checkmark",
                        isEnabled: trimmedTitle.isEmpty == false
                    ) {
                        saveDefinition()
                    }
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
            }
            .alert("Unable To Save Drill", isPresented: saveErrorAlertIsPresented) {
                Button("OK", role: .cancel) {
                    saveErrorMessage = nil
                }
            } message: {
                Text(saveErrorMessage ?? "An unexpected error occurred.")
            }
        }
        .garagePuttingGreenSheetChrome()
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

private struct GarageProField: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)

            TextField(prompt, text: $text)
                .padding(16)
                .frame(minHeight: 60)
                .foregroundStyle(GarageProTheme.textPrimary)
                .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        }
    }
}

#Preview("Garage Template Builder") {
    GarageTemplateBuilderWizard()
        .modelContainer(PreviewCatalog.populatedApp)
}
