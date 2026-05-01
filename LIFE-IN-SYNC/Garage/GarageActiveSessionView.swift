import SwiftData
import SwiftUI

@MainActor
struct GarageActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]
    @State private var session: ActivePracticeSession
    @State private var noteEditor: DrillNoteEditorState?
    @State private var summaryDraft: GarageSessionSummaryDraft?
    @State private var saveErrorMessage: String?

    let onEndSession: () -> Void

    init(
        session: ActivePracticeSession,
        onEndSession: @escaping () -> Void
    ) {
        _session = State(initialValue: session)
        self.onEndSession = onEndSession
    }

    var body: some View {
        GarageProScaffold {
            GarageProHeroCard(
                eyebrow: "Active Checklist",
                title: session.templateName,
                subtitle: "\(session.environment.displayName) • \(progressSummary)",
                value: "\(session.completedDrillCount)/\(session.totalDrillCount)",
                valueLabel: "Complete"
            ) {
                Image(systemName: session.environment.systemImage)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(GarageProTheme.accent.opacity(0.3), lineWidth: 1)
                    )
            }

            GarageSessionProgressCard(
                completed: session.completedDrillCount,
                total: session.totalDrillCount
            )

            VStack(alignment: .leading, spacing: 14) {
                GarageChecklistHeader(title: "Drill Stack")

                ForEach(session.orderedDrillEntries) { entry in
                    GaragePracticeDrillRow(
                        entry: entry,
                        onToggle: {
                            garageTriggerSelection()
                            session.toggleCompletion(for: entry.drill.id)
                        },
                        onEditNote: { presentNoteEditor(for: entry) }
                    )
                }
            }
        }
        .navigationTitle("Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Spacer()

                GarageProPrimaryButton(
                    title: "Finish & Review",
                    systemImage: "checkmark.seal.fill"
                ) {
                    presentSummary()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
        }
        .sheet(item: $noteEditor) { editor in
            GarageDrillNoteEditorSheet(
                drillTitle: editor.drillTitle,
                note: editor.note,
                onCancel: { noteEditor = nil },
                onSave: { updatedNote in
                    session.updateNote(updatedNote, for: editor.drillID)
                    noteEditor = nil
                }
            )
        }
        .sheet(isPresented: summarySheetIsPresented) {
            if summaryDraft != nil {
                GarageSessionSummarySheet(
                    draft: Binding(
                        get: { summaryDraft! },
                        set: { summaryDraft = $0 }
                    ),
                    onCancel: { summaryDraft = nil },
                    onSave: saveSummary
                )
            }
        }
        .alert("Unable To Save Session", isPresented: saveErrorAlertIsPresented) {
            Button("OK", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "An unexpected error occurred.")
        }
    }

    private var progressSummary: String {
        "\(session.completedDrillCount) of \(session.totalDrillCount) drills complete"
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

    private var summarySheetIsPresented: Binding<Bool> {
        Binding(
            get: { summaryDraft != nil },
            set: { isPresented in
                if isPresented == false {
                    summaryDraft = nil
                }
            }
        )
    }

    private func presentNoteEditor(for entry: PracticeSessionDrillEntry) {
        noteEditor = DrillNoteEditorState(
            drillID: entry.drill.id,
            drillTitle: entry.drill.title,
            note: entry.progress.note
        )
    }

    private func presentSummary() {
        summaryDraft = GarageSessionSummaryDraft(
            session: session,
            benchmarkSnapshot: records.benchmarkSnapshot(for: session.templateName)
        )
    }

    private func saveSummary(_ draft: GarageSessionSummaryDraft) {
        let record = session.makeRecord(
            drillResults: draft.drillResults.map(\.recordValue),
            sessionFeelNote: draft.sessionFeelNote
        )
        modelContext.insert(record)

        do {
            let isPersonalRecord = try GarageAchievementService.refreshPersonalRecordState(
                for: record,
                in: modelContext
            )
            _ = try GarageAuditService.refreshCoachingAudit(
                for: record,
                in: modelContext
            )
            try modelContext.save()

            if isPersonalRecord {
                garageTriggerImpact(.heavy)
            }

            summaryDraft = nil
            onEndSession()
        } catch {
            modelContext.delete(record)
            saveErrorMessage = error.localizedDescription
        }
    }
}

@MainActor
private struct GarageSessionProgressCard: View {
    let completed: Int
    let total: Int

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        GarageProCard(isActive: completed > 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Session Progress")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("\(completed) of \(total) drills completed")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }

                Spacer()

                Text("\(Int((ratio * 100).rounded()))%")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundStyle(GarageProTheme.accent)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(GarageProTheme.accent.opacity(0.2))

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(GarageProTheme.accent)
                        .frame(width: proxy.size.width * ratio)
                        .animation(.easeOut(duration: 0.28), value: ratio)
                }
            }
            .frame(height: 12)
        }
    }
}

@MainActor
private struct GarageChecklistHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.title2, design: .rounded).weight(.black))
            .foregroundStyle(GarageProTheme.textPrimary)
    }
}

@MainActor
private struct GaragePracticeDrillRow: View {
    let entry: PracticeSessionDrillEntry
    let onToggle: () -> Void
    let onEditNote: () -> Void

    var body: some View {
        GarageProCard(isActive: entry.progress.isCompleted) {
            HStack(alignment: .top, spacing: 14) {
                Button(action: onToggle) {
                    Image(systemName: entry.progress.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(entry.progress.isCompleted ? GarageProTheme.accent : GarageProTheme.textSecondary)
                        .frame(width: 60, height: 60)
                        .background(GarageProTheme.accent.opacity(entry.progress.isCompleted ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(entry.progress.isCompleted ? GarageProTheme.accent.opacity(0.38) : GarageProTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.progress.isCompleted ? "Mark incomplete" : "Mark complete")

                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.drill.title)
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(entry.drill.metadataSummary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if entry.progress.note.isEmpty == false {
                        Text(entry.progress.note)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(GarageProTheme.accent.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                Button {
                    garageTriggerSelection()
                    onEditNote()
                } label: {
                    Image(systemName: entry.progress.note.isEmpty ? "square.and.pencil" : "note.text")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(GarageProTheme.accent)
                        .frame(width: 60, height: 60)
                        .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(GarageProTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.progress.note.isEmpty ? "Add note" : "Edit note")
            }
        }
    }
}

@MainActor
private struct GarageSessionSummarySheet: View {
    @Binding var draft: GarageSessionSummaryDraft

    let onCancel: () -> Void
    let onSave: (GarageSessionSummaryDraft) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ModuleSpacing.large) {
                    headerBlock
                    efficiencyCard
                    drillResultsSection
                    feelNoteSection
                }
                .padding(.horizontal, ModuleSpacing.large)
                .padding(.top, ModuleSpacing.large)
                .padding(.bottom, 40)
            }
            .background(AppModule.garage.theme.screenGradient.ignoresSafeArea())
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                    }
                }
            }
        }
        .garagePuttingGreenSheetChrome()
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRACTICE FOUNDATION")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .kerning(2.8)
                .foregroundStyle(AppModule.garage.theme.textSecondary)

            Text(draft.templateName)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            Text("Dial in each drill's objective make rate before the record is written to the vault.")
                .font(.subheadline)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var efficiencyCard: some View {
        GarageTelemetrySurface(isActive: true) {
            Text("EFFICIENCY")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .kerning(2.6)
                .foregroundStyle(AppModule.garage.theme.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(draft.aggregateEfficiencyText)
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                Text("aggregate")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
            }

            Text("\(draft.totalSuccessfulReps) successful reps across \(draft.totalAttemptedReps) attempts")
                .font(.subheadline)
                .foregroundStyle(AppModule.garage.theme.textSecondary)

            if draft.hasBenchmarkProjection {
                Divider()
                    .overlay(AppModule.garage.theme.borderSubtle)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Projected Efficiency")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    Spacer()

                    Text(draft.projectedEfficiencyText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppModule.garage.tintColor.opacity(0.8))
                }

                Text(draft.projectionComparisonText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(draft.isAheadOfProjection ? GarageSessionSummaryPalette.activeSegment : AppModule.garage.theme.textSecondary)
            }
        }
    }

    private var drillResultsSection: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            Text("Success Count")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            ForEach($draft.drillResults) { $result in
                GarageDrillResultCard(
                    result: $result,
                    benchmarkSessionCount: draft.benchmarkSessionCount
                )
            }
        }
    }

    private var feelNoteSection: some View {
        GarageTelemetrySurface {
            Text("SESSION NOTE")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .kerning(2.2)
                .foregroundStyle(AppModule.garage.theme.textSecondary)

            TextField("Optional feel note", text: $draft.sessionFeelNote, axis: .vertical)
                .lineLimit(3...6)
                .padding(14)
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous)
                        .fill(ModuleTheme.garageSurfaceInset.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                )
        }
    }
}

@MainActor
private struct GarageDrillResultCard: View {
    @Binding var result: GarageSessionDrillResultDraft
    let benchmarkSessionCount: Int

    var body: some View {
        GarageTelemetrySurface {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    Text("\(result.successfulReps) / \(result.totalReps) successful reps")
                        .font(.subheadline)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                Spacer()

                Text(result.successPercentageText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(result.successfulReps > 0 ? GarageSessionSummaryPalette.activeSegment : AppModule.garage.theme.textSecondary)
            }

            GarageSegmentedRepBar(
                successfulReps: $result.successfulReps,
                totalReps: result.totalReps,
                projectedSuccessfulReps: result.projectedSuccessfulReps
            )
            .frame(height: 44)

            if let benchmarkText = result.historicalBenchmarkText(sessionCount: benchmarkSessionCount) {
                Text(benchmarkText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(result.isAheadOfProjection ? GarageSessionSummaryPalette.activeSegment : AppModule.garage.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct GarageSegmentedRepBar: View {
    @Binding var successfulReps: Int
    let totalReps: Int
    let projectedSuccessfulReps: Int?

    private let segmentSpacing: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            HStack(spacing: segmentSpacing) {
                ForEach(0..<totalReps, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(segmentFill(for: index))
                        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
                        .overlay {
                            if isProjectedGhostSegment(index) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(GarageSessionSummaryPalette.projectedSegment)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                                    )
                            }
                        }
                        .shadow(
                            color: index < successfulReps ? GarageSessionSummaryPalette.activeSegment.opacity(0.28) : .clear,
                            radius: index < successfulReps ? 6 : 0,
                            x: 0,
                            y: 0
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSuccessfulReps(with: value.location.x, width: width)
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Success count")
            .accessibilityValue("\(successfulReps) of \(totalReps)")
        }
    }

    private func segmentFill(for index: Int) -> Color {
        index < successfulReps
            ? GarageSessionSummaryPalette.activeSegment
            : GarageSessionSummaryPalette.inactiveSegment
    }

    private func isProjectedGhostSegment(_ index: Int) -> Bool {
        guard let projectedSuccessfulReps else {
            return false
        }

        return index >= successfulReps && index < projectedSuccessfulReps
    }

    private func updateSuccessfulReps(with locationX: CGFloat, width: CGFloat) {
        let segmentWidth = width / CGFloat(max(totalReps, 1))
        let clampedLocation = min(max(locationX, 0), width)
        let updatedValue = min(max(Int(ceil(clampedLocation / max(segmentWidth, 1))), 0), totalReps)

        guard updatedValue != successfulReps else {
            return
        }

        successfulReps = updatedValue
        garageTriggerImpact(.light)
    }
}

@MainActor
private struct GarageDrillNoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftNote: String

    let drillTitle: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    init(
        drillTitle: String,
        note: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.drillTitle = drillTitle
        self.onCancel = onCancel
        self.onSave = onSave
        _draftNote = State(initialValue: note)
    }

    var body: some View {
        NavigationStack {
            GarageProScaffold(bottomPadding: 32) {
                GarageProHeroCard(
                    eyebrow: "Drill Note",
                    title: drillTitle,
                    subtitle: "Capture the feel cue or correction that matters for the next rep."
                )

                GarageProCard {
                    Text("Note")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    TextField("Add a brief note", text: $draftNote, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(16)
                        .frame(minHeight: 120, alignment: .topLeading)
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(GarageProTheme.border, lineWidth: 1)
                        )
                }
            }
            .navigationTitle("Drill Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draftNote)
                        dismiss()
                    }
                }
            }
        }
        .garagePuttingGreenSheetChrome()
    }
}

private struct DrillNoteEditorState: Identifiable {
    let drillID: UUID
    let drillTitle: String
    let note: String

    var id: UUID { drillID }
}

private struct GarageSessionSummaryDraft: Identifiable {
    let id: UUID
    let templateName: String
    let benchmarkSessionCount: Int
    var drillResults: [GarageSessionDrillResultDraft]
    var sessionFeelNote: String

    init(
        session: ActivePracticeSession,
        benchmarkSnapshot: GarageTemplateBenchmarkSnapshot?
    ) {
        id = session.id
        templateName = session.templateName
        benchmarkSessionCount = benchmarkSnapshot?.sourceSessionCount ?? 0
        drillResults = session.defaultDrillResults().enumerated().map { index, result in
            GarageSessionDrillResultDraft(
                id: session.drills[index].id,
                name: result.name,
                totalReps: result.totalReps,
                successfulReps: result.successfulReps,
                projectedSuccessfulReps: benchmarkSnapshot?.projectedSuccessfulReps(
                    for: result.name,
                    totalReps: result.totalReps
                )
            )
        }
        sessionFeelNote = ""
    }

    var totalSuccessfulReps: Int {
        drillResults.reduce(0) { $0 + $1.successfulReps }
    }

    var totalAttemptedReps: Int {
        drillResults.reduce(0) { $0 + $1.totalReps }
    }

    var aggregateEfficiency: Double {
        guard totalAttemptedReps > 0 else {
            return 0
        }

        return Double(totalSuccessfulReps) / Double(totalAttemptedReps)
    }

    var aggregateEfficiencyText: String {
        "\(Int((aggregateEfficiency * 100).rounded()))%"
    }

    var projectedSuccessfulRepsTotal: Int {
        drillResults.reduce(0) { partialResult, result in
            partialResult + (result.projectedSuccessfulReps ?? 0)
        }
    }

    var hasBenchmarkProjection: Bool {
        drillResults.contains { $0.projectedSuccessfulReps != nil }
    }

    var projectedEfficiency: Double {
        guard totalAttemptedReps > 0 else {
            return 0
        }

        return Double(projectedSuccessfulRepsTotal) / Double(totalAttemptedReps)
    }

    var projectedEfficiencyText: String {
        "\(Int((projectedEfficiency * 100).rounded()))%"
    }

    var isAheadOfProjection: Bool {
        aggregateEfficiency >= projectedEfficiency
    }

    var projectionComparisonText: String {
        guard benchmarkSessionCount > 0 else {
            return "No historical benchmark yet."
        }

        let delta = Int(((aggregateEfficiency - projectedEfficiency) * 100).rounded())
        let direction = delta >= 0 ? "Above" : "Below"
        let signedDelta = delta > 0 ? "+\(delta)" : "\(delta)"
        return "\(direction) your \(benchmarkSessionCount)-session pace by \(signedDelta)%."
    }
}

private struct GarageSessionDrillResultDraft: Identifiable {
    let id: UUID
    let name: String
    let totalReps: Int
    var successfulReps: Int
    let projectedSuccessfulReps: Int?

    var successPercentageText: String {
        guard totalReps > 0 else {
            return "0%"
        }

        let percentage = Int((Double(successfulReps) / Double(totalReps) * 100).rounded())
        return "\(percentage)%"
    }

    var recordValue: DrillResult {
        DrillResult(
            name: name,
            successfulReps: successfulReps,
            totalReps: totalReps
        )
    }

    var isAheadOfProjection: Bool {
        successfulReps >= (projectedSuccessfulReps ?? successfulReps)
    }

    func historicalBenchmarkText(sessionCount: Int) -> String? {
        guard let projectedSuccessfulReps,
              sessionCount > 0 else {
            return nil
        }

        let paceText = successfulReps >= projectedSuccessfulReps ? "Above" : "Below"
        return "Historical average \(projectedSuccessfulReps)/\(totalReps) across \(sessionCount) sessions • \(paceText) normal pace"
    }
}

private enum GarageSessionSummaryPalette {
    static let activeSegment = Color(hex: "#10B981")
    static let inactiveSegment = Color(red: 0.15, green: 0.16, blue: 0.18)
    static let projectedSegment = activeSegment.opacity(0.18)
}

#Preview("Garage Active Session") {
    let template = PracticeTemplate(
        title: "Preview Wedge Ladder",
        environment: PracticeEnvironment.range.rawValue,
        drills: [
            PracticeTemplateDrill(
                title: "Carry Ladder",
                focusArea: "Distance Control",
                targetClub: "Wedge",
                defaultRepCount: 12
            ),
            PracticeTemplateDrill(
                title: "Tempo Rehearsal",
                focusArea: "Tempo",
                targetClub: "7 Iron",
                defaultRepCount: 8
            )
        ]
    )

    NavigationStack {
        GarageActiveSessionView(
            session: ActivePracticeSession(template: template),
            onEndSession: {}
        )
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
