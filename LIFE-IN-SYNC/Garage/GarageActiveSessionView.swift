import SwiftData
import SwiftUI

@MainActor
struct GarageActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]
    @State private var session: ActivePracticeSession
    @State private var phase: GarageActiveSessionPhase = .lobby
    @State private var currentDrillIndex = 0
    @State private var expandedDetailSection: GarageDrillDetailSection = .purpose
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
        Group {
            switch phase {
            case .lobby:
                GarageSessionLobbyView(
                    session: session,
                    totalPlannedReps: totalPlannedReps,
                    estimatedMinutes: totalEstimatedMinutes,
                    primaryFocus: primaryFocusText,
                    coachDirective: coachDirectiveText,
                    equipment: equipmentSummary,
                    onEnter: enterFocusRoom
                )
            case .focusRoom:
                GarageFocusSessionView(
                    session: session,
                    currentDrillIndex: currentDrillIndex,
                    currentEntry: currentEntry,
                    detail: currentEntry.map { GarageDrillFocusDetails.detail(for: $0.drill) },
                    overallProgressRatio: overallProgressRatio,
                    expandedDetailSection: $expandedDetailSection,
                    note: currentEntry.map { noteBinding(for: $0.drill.id) } ?? .constant(""),
                    onSelectDrill: selectDrill(at:),
                    onPrevious: moveToPreviousDrill,
                    onCompleteCurrent: completeCurrentDrill,
                    onEditNote: {
                        if let currentEntry {
                            presentNoteEditor(for: currentEntry)
                        }
                    },
                    onReview: presentReview
                )
            case .review:
                if summaryDraft != nil {
                    GarageSessionReviewView(
                        draft: Binding(
                            get: { summaryDraft ?? GarageSessionSummaryDraft(session: session, benchmarkSnapshot: records.benchmarkSnapshot(for: session.templateName)) },
                            set: { summaryDraft = $0 }
                        ),
                        entries: session.orderedDrillEntries,
                        onBack: { phase = .focusRoom },
                        onSave: saveSummary
                    )
                } else {
                    GarageProScaffold {
                        GarageProHeroCard(
                            eyebrow: "Session Review",
                            title: session.templateName,
                            subtitle: "Preparing review details."
                        )
                    }
                    .onAppear(perform: presentReview)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
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
        .alert("Unable To Save Session", isPresented: saveErrorAlertIsPresented) {
            Button("OK", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "An unexpected error occurred.")
        }
    }

    private var navigationTitle: String {
        switch phase {
        case .lobby:
            "Session Lobby"
        case .focusRoom:
            "Focus Room"
        case .review:
            "Session Review"
        }
    }

    private var totalPlannedReps: Int {
        session.drills.reduce(0) { $0 + max($1.defaultRepCount, 0) }
    }

    private var totalEstimatedMinutes: Int {
        session.drills.reduce(0) { $0 + GarageDrillFocusDetails.detail(for: $1).estimatedMinutes }
    }

    private var primaryFocusText: String {
        let focusAreas = session.drills
            .map(\.focusArea)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        let focusText = Array(NSOrderedSet(array: focusAreas).compactMap { $0 as? String })
            .prefix(2)
            .joined(separator: " + ")

        return focusText.isEmpty ? "Focused practice reps" : focusText
    }

    private var coachDirectiveText: String {
        currentEntry
            .map { GarageDrillFocusDetails.detail(for: $0.drill).resetCue } ??
            session.drills.first.map { GarageDrillFocusDetails.detail(for: $0).resetCue } ??
            "Enter with one clear cue and make each rep count."
    }

    private var equipmentSummary: [String] {
        let equipment = session.drills.flatMap { GarageDrillFocusDetails.detail(for: $0).equipment }
        return Array(NSOrderedSet(array: equipment).compactMap { $0 as? String }).prefix(5).map { $0 }
    }

    private var currentEntry: PracticeSessionDrillEntry? {
        let entries = session.orderedDrillEntries
        guard entries.indices.contains(currentDrillIndex) else {
            return entries.first
        }

        return entries[currentDrillIndex]
    }

    private var overallProgressRatio: Double {
        guard session.totalDrillCount > 0 else {
            return 0
        }

        return Double(session.completedDrillCount) / Double(session.totalDrillCount)
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

    private func presentNoteEditor(for entry: PracticeSessionDrillEntry) {
        noteEditor = DrillNoteEditorState(
            drillID: entry.drill.id,
            drillTitle: entry.drill.title,
            note: entry.progress.note
        )
    }

    private func enterFocusRoom() {
        garageTriggerImpact(.heavy)
        phase = .focusRoom
    }

    private func selectDrill(at index: Int) {
        guard session.orderedDrillEntries.indices.contains(index) else {
            return
        }

        garageTriggerSelection()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentDrillIndex = index
            expandedDetailSection = .purpose
        }
    }

    private func moveToPreviousDrill() {
        guard currentDrillIndex > 0 else {
            return
        }

        garageTriggerSelection()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentDrillIndex -= 1
            expandedDetailSection = .purpose
        }
    }

    private func completeCurrentDrill() {
        guard let currentEntry else {
            presentReview()
            return
        }

        if currentEntry.progress.isCompleted == false {
            session.toggleCompletion(for: currentEntry.drill.id)
        }

        if currentDrillIndex < session.totalDrillCount - 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentDrillIndex += 1
                expandedDetailSection = .purpose
            }
        } else {
            presentReview()
        }
    }

    private func presentReview() {
        summaryDraft = GarageSessionSummaryDraft(
            session: session,
            benchmarkSnapshot: records.benchmarkSnapshot(for: session.templateName)
        )
        phase = .review
    }

    private func noteBinding(for drillID: UUID) -> Binding<String> {
        Binding(
            get: { session.progress(for: drillID)?.note ?? "" },
            set: { session.updateNote($0, for: drillID) }
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

private enum GarageActiveSessionPhase {
    case lobby
    case focusRoom
    case review
}

private enum GarageSessionDockLayout {
    static let contentBottomPadding: CGFloat = 230
    static let reviewBottomPadding: CGFloat = 300
}

private enum GarageDrillDetailSection: String, CaseIterable, Identifiable {
    case purpose
    case setup
    case execution
    case successStandard
    case commonMiss
    case equipment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .purpose:
            "Purpose"
        case .setup:
            "Setup"
        case .execution:
            "Execution"
        case .successStandard:
            "Success Standard"
        case .commonMiss:
            "Common Miss"
        case .equipment:
            "Equipment"
        }
    }

    var collapsedSummary: String {
        switch self {
        case .purpose:
            "Why this drill matters"
        case .setup:
            "Build the station before the rep"
        case .execution:
            "One clean rep sequence"
        case .successStandard:
            "Know what counts"
        case .commonMiss:
            "Watch the failure pattern"
        case .equipment:
            "What needs to be in the room"
        }
    }
}

@MainActor
private struct GarageSessionLobbyView: View {
    let session: ActivePracticeSession
    let totalPlannedReps: Int
    let estimatedMinutes: Int
    let primaryFocus: String
    let coachDirective: String
    let equipment: [String]
    let onEnter: () -> Void

    var body: some View {
        GarageProScaffold(bottomPadding: GarageSessionDockLayout.contentBottomPadding) {
            GarageSessionLobbyLeadCard(session: session)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                GarageCompactMetricCard(title: "Environment", value: session.environment.displayName, systemImage: session.environment.systemImage, isActive: true)
                GarageCompactMetricCard(title: "Planned Reps", value: "\(totalPlannedReps)", systemImage: "repeat", isActive: totalPlannedReps > 0)
                GarageCompactMetricCard(title: "Est. Time", value: "\(estimatedMinutes)m", systemImage: "timer", isActive: estimatedMinutes > 0)
                GarageCompactMetricCard(title: "Completed", value: "\(session.completedDrillCount)/\(session.totalDrillCount)", systemImage: "checkmark.seal", isActive: session.completedDrillCount > 0)
            }

            GarageProCard(isActive: true) {
                GarageFocusLabel("Primary Focus")
                Text(primaryFocus)
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .overlay(GarageProTheme.border)

                GarageFocusLabel("Coach Directive")
                Text(coachDirective)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GarageEquipmentCard(equipment: equipment)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Spacer()

                GarageProPrimaryButton(
                    title: "Enter Focus Room",
                    systemImage: "figure.golf"
                ) {
                    onEnter()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .padding(.top, 4)
            .background(.ultraThinMaterial)
        }
    }
}

@MainActor
private struct GarageFocusSessionView: View {
    let session: ActivePracticeSession
    let currentDrillIndex: Int
    let currentEntry: PracticeSessionDrillEntry?
    let detail: GarageDrillFocusDetail?
    let overallProgressRatio: Double
    @Binding var expandedDetailSection: GarageDrillDetailSection
    @Binding var note: String
    let onSelectDrill: (Int) -> Void
    let onPrevious: () -> Void
    let onCompleteCurrent: () -> Void
    let onEditNote: () -> Void
    let onReview: () -> Void

    var body: some View {
        GarageProScaffold(bottomPadding: GarageSessionDockLayout.contentBottomPadding) {
            GarageFocusHeaderCard(
                session: session,
                currentDrillIndex: currentDrillIndex,
                overallProgressRatio: overallProgressRatio
            )

            if let currentEntry, let detail {
                GarageFocusedDrillCard(
                    entry: currentEntry,
                    detail: detail,
                    drillNumber: currentDrillIndex + 1,
                    totalDrills: session.totalDrillCount,
                    expandedDetailSection: $expandedDetailSection,
                    note: $note,
                    onEditNote: onEditNote
                )

                GarageRemainingDrillStack(
                    entries: session.orderedDrillEntries,
                    currentDrillIndex: currentDrillIndex,
                    onSelectDrill: onSelectDrill
                )
            } else {
                GarageProCard {
                    Text("No drills in this session")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Return to Garage and choose a routine with at least one drill.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 12) {
                GarageFocusSecondaryButton(
                    title: "Back",
                    systemImage: "chevron.left",
                    isEnabled: currentDrillIndex > 0,
                    action: onPrevious
                )

                if session.completedDrillCount == session.totalDrillCount, session.totalDrillCount > 0 {
                    GarageProPrimaryButton(
                        title: "Review",
                        systemImage: "checkmark.seal.fill",
                        action: onReview
                    )
                } else {
                    GarageProPrimaryButton(
                        title: currentDrillIndex >= session.totalDrillCount - 1 ? "Complete & Review" : "Complete Drill",
                        systemImage: "checkmark.circle.fill",
                        action: onCompleteCurrent
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .padding(.top, 4)
            .background(.ultraThinMaterial)
        }
    }
}

@MainActor
private struct GarageFocusHeaderCard: View {
    let session: ActivePracticeSession
    let currentDrillIndex: Int
    let overallProgressRatio: Double

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 24, padding: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    GarageFocusLabel("Focus Room")

                    Text(session.templateName)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("\(session.environment.displayName) • Drill \(min(currentDrillIndex + 1, max(session.totalDrillCount, 1))) of \(session.totalDrillCount)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.84)
                }

                Spacer(minLength: 8)

                Text("\(Int((overallProgressRatio * 100).rounded()))%")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundStyle(GarageProTheme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            GarageLinearProgressBar(ratio: overallProgressRatio)
                .padding(.top, 2)
        }
    }
}

@MainActor
private struct GarageFocusedDrillCard: View {
    let entry: PracticeSessionDrillEntry
    let detail: GarageDrillFocusDetail
    let drillNumber: Int
    let totalDrills: Int
    @Binding var expandedDetailSection: GarageDrillDetailSection
    @Binding var note: String
    let onEditNote: () -> Void

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 26, padding: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    GarageFocusLabel("Current Drill")

                    Text(entry.drill.title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(entry.drill.metadataSummary)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                GarageDrillOrdinalBadge(
                    drillNumber: drillNumber,
                    totalDrills: totalDrills,
                    isCompleted: entry.progress.isCompleted
                )
            }

            GarageDrillDetailPanel(
                detail: detail,
                repTarget: detail.repTargetText(for: entry.drill),
                expandedSection: $expandedDetailSection
            )
            .padding(.top, 2)

            GarageFocusNotesCard(note: $note, onEditNote: onEditNote)
                .padding(.top, 2)
        }
    }
}

@MainActor
private struct GarageDrillDetailPanel: View {
    let detail: GarageDrillFocusDetail
    let repTarget: String
    @Binding var expandedSection: GarageDrillDetailSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                GarageDetailCompactBlock(title: "Reset Cue", value: detail.resetCue, isAccent: true)
                GarageDetailCompactBlock(title: "Rep Target", value: repTarget, isAccent: false)
            }

            VStack(alignment: .leading, spacing: 8) {
                GarageFocusLabel("Drill Detail")

                ForEach(GarageDrillDetailSection.allCases) { section in
                    GarageDrillAccordionSection(
                        title: section.title,
                        collapsedSummary: collapsedSummary(for: section),
                        isExpanded: expandedSection == section,
                        action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                expandedSection = section
                            }
                        }
                    ) {
                        detailContent(for: section)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func detailContent(for section: GarageDrillDetailSection) -> some View {
        switch section {
        case .purpose:
            GarageDetailTextSection(title: section.title, text: detail.purpose)
        case .setup:
            GarageDetailListSection(title: section.title, items: detail.setup)
        case .execution:
            GarageDetailListSection(title: section.title, items: detail.execution)
        case .successStandard:
            GarageDetailListSection(title: section.title, items: detail.successCriteria)
        case .commonMiss:
            GarageDetailListSection(title: section.title, items: detail.commonMisses)
        case .equipment:
            GarageDetailListSection(title: section.title, items: detail.equipment)
        }
    }

    private func collapsedSummary(for section: GarageDrillDetailSection) -> String {
        switch section {
        case .purpose:
            return section.collapsedSummary
        case .setup:
            return itemCountSummary(count: detail.setup.count, noun: "step", fallback: section.collapsedSummary)
        case .execution:
            return itemCountSummary(count: detail.execution.count, noun: "move", fallback: section.collapsedSummary)
        case .successStandard:
            return itemCountSummary(count: detail.successCriteria.count, noun: "check", fallback: section.collapsedSummary)
        case .commonMiss:
            return itemCountSummary(count: detail.commonMisses.count, noun: "miss", fallback: section.collapsedSummary)
        case .equipment:
            return itemCountSummary(count: detail.equipment.count, noun: "item", fallback: section.collapsedSummary)
        }
    }

    private func itemCountSummary(count: Int, noun: String, fallback: String) -> String {
        guard count > 0 else {
            return fallback
        }

        let suffix = count == 1 ? noun : "\(noun)s"
        return "\(count) \(suffix)"
    }
}

@MainActor
private struct GarageFocusNotesCard: View {
    @Binding var note: String
    let onEditNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                GarageFocusLabel("Notes")

                Spacer()

                Button(action: onEditNote) {
                    Image(systemName: note.isEmpty ? "square.and.pencil" : "note.text")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(GarageProTheme.accent)
                        .frame(width: 42, height: 42)
                        .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(GarageProTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(note.isEmpty ? "Add note" : "Edit note")
            }

            TextField("Capture the feel or miss from this drill", text: $note, axis: .vertical)
                .lineLimit(2...5)
                .padding(14)
                .frame(minHeight: 92, alignment: .topLeading)
                .foregroundStyle(GarageProTheme.textPrimary)
                .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        }
    }
}

@MainActor
private struct GarageRemainingDrillStack: View {
    let entries: [PracticeSessionDrillEntry]
    let currentDrillIndex: Int
    let onSelectDrill: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageFocusLabel("Drill Stack")

            VStack(spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        onSelectDrill(index)
                    } label: {
                        GarageDrillStackRow(
                            entry: entry,
                            index: index,
                            isCurrent: index == currentDrillIndex
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

@MainActor
private struct GarageDrillStackRow: View {
    let entry: PracticeSessionDrillEntry
    let index: Int
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.progress.isCompleted ? "checkmark.circle.fill" : (isCurrent ? "scope" : "circle"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(entry.progress.isCompleted || isCurrent ? GarageProTheme.accent : GarageProTheme.textSecondary)
                .frame(width: 42, height: 42)
                .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(isCurrent ? GarageProTheme.accent.opacity(0.34) : GarageProTheme.border, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("\(index + 1). \(entry.drill.title)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(entry.drill.metadataSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)
        }
        .padding(12)
        .background(GarageProTheme.insetSurface.opacity(isCurrent ? 0.95 : 0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isCurrent ? GarageProTheme.accent.opacity(0.36) : GarageProTheme.border, lineWidth: 1)
        )
    }
}

@MainActor
private struct GarageSessionReviewView: View {
    @Binding var draft: GarageSessionSummaryDraft
    let entries: [PracticeSessionDrillEntry]
    let onBack: () -> Void
    let onSave: (GarageSessionSummaryDraft) -> Void

    var body: some View {
        GarageProScaffold(bottomPadding: GarageSessionDockLayout.reviewBottomPadding) {
            GarageSessionReviewLeadCard(draft: draft)

            GarageSessionReviewAccuracyGateCard(draft: draft)

            GarageSessionReviewNotes(entries: entries)

            VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
                GarageFocusLabel("Successful Reps")

                ForEach($draft.drillResults) { $result in
                    GarageDrillResultCard(
                        result: $result,
                        benchmarkSessionCount: draft.benchmarkSessionCount
                    )
                }
            }

            GarageTelemetrySurface {
                GarageFocusLabel("Session Feel Note")

                TextField("Carry-forward cue or feel note", text: $draft.sessionFeelNote, axis: .vertical)
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

                if draft.sessionFeelNoteIsEmpty {
                    Button {
                        garageTriggerSelection()
                        draft.allowsSavingWithoutCue = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: draft.allowsSavingWithoutCue ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 17, weight: .bold))

                            Text("Save without cue")
                                .font(.headline.weight(.bold))

                            Spacer(minLength: 8)
                        }
                        .foregroundStyle(draft.allowsSavingWithoutCue ? GarageSessionSummaryPalette.activeSegment : AppModule.garage.theme.textSecondary)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous)
                                .fill(ModuleTheme.garageSurfaceInset.opacity(0.72))
                                .overlay(
                                    RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous)
                                        .stroke(
                                            draft.allowsSavingWithoutCue ? GarageSessionSummaryPalette.activeSegment.opacity(0.42) : Color.white.opacity(0.06),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save without carry-forward cue")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                if draft.canSave == false {
                    Text(draft.saveGateMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 12) {
                    GarageFocusSecondaryButton(
                        title: "Back",
                        systemImage: "chevron.left",
                        action: onBack
                    )

                    GarageProPrimaryButton(
                        title: "Save Session",
                        systemImage: "checkmark.seal.fill",
                        isEnabled: draft.canSave
                    ) {
                        onSave(draft)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .padding(.top, 4)
            .background(.ultraThinMaterial)
        }
    }
}

@MainActor
private struct GarageSessionReviewAccuracyGateCard: View {
    let draft: GarageSessionSummaryDraft

    var body: some View {
        GarageProCard(isActive: draft.allDrillResultsReviewed, cornerRadius: 22, padding: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: draft.allDrillResultsReviewed ? "checkmark.seal.fill" : "scope")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(draft.allDrillResultsReviewed ? GarageSessionSummaryPalette.activeSegment : GarageProTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(GarageProTheme.border, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 7) {
                    GarageFocusLabel("Accuracy Gate")

                    Text("Completion is not a rep score.")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("A completed drill does not automatically mean every rep succeeded. Review each rep count before saving to the vault.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(draft.reviewProgressText)
                        .font(.caption.weight(.black))
                        .textCase(.uppercase)
                        .tracking(1.3)
                        .foregroundStyle(draft.allDrillResultsReviewed ? GarageSessionSummaryPalette.activeSegment : GarageProTheme.accent)
                }
            }
        }
    }
}

@MainActor
private struct GarageSessionReviewNotes: View {
    let entries: [PracticeSessionDrillEntry]

    var body: some View {
        GarageProCard(isActive: entries.contains { $0.progress.note.isEmpty == false }) {
            GarageFocusLabel("Drill Notes")

            let notedEntries = entries.filter { $0.progress.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }

            if notedEntries.isEmpty {
                Text("No drill notes captured in this session.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(notedEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.drill.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(GarageProTheme.textPrimary)

                            Text(entry.progress.note)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(GarageProTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct GarageDetailTextSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GarageFocusLabel(title)

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GarageProTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(GarageProTheme.insetSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct GarageDetailListSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GarageFocusLabel(title)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(GarageProTheme.accent)
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)

                    Text(item)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(GarageProTheme.insetSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct GarageDetailCompactBlock: View {
    let title: String
    let value: String
    let isAccent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GarageFocusLabel(title)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(isAccent ? GarageProTheme.accent : GarageProTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(GarageProTheme.insetSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct GarageDrillAccordionSection<Content: View>: View {
    let title: String
    let collapsedSummary: String
    let isExpanded: Bool
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        if isExpanded == false {
                            Text(collapsedSummary)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(GarageProTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isExpanded ? GarageProTheme.accent : GarageProTheme.textSecondary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(GarageProTheme.insetSurface.opacity(isExpanded ? 0.92 : 0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isExpanded ? GarageProTheme.accent.opacity(0.34) : GarageProTheme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct GarageSessionLobbyLeadCard: View {
    let session: ActivePracticeSession

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 24, padding: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    GarageFocusLabel("Session Lobby")

                    Text(session.templateName)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text("Enter the room with one cue, one routine, and no extra noise.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 8) {
                    Image(systemName: session.environment.systemImage)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(GarageProTheme.accent)
                        .frame(width: 50, height: 50)
                        .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(GarageProTheme.accent.opacity(0.3), lineWidth: 1)
                        )

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(session.totalDrillCount)")
                            .font(.system(size: 27, weight: .black, design: .monospaced))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        Text(session.totalDrillCount == 1 ? "Drill" : "Drills")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .tracking(1.8)
                            .foregroundStyle(GarageProTheme.textSecondary)
                    }
                }
            }
        }
    }
}

private struct GarageCompactMetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    var isActive = false

    var body: some View {
        GarageProCard(isActive: isActive, cornerRadius: 20, padding: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(GarageProTheme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer(minLength: 8)
            }

            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(GarageProTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

private struct GarageSessionReviewLeadCard: View {
    let draft: GarageSessionSummaryDraft

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 28, padding: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    GarageFocusLabel("Session Review")

                    Text(draft.templateName)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)

                    Text("Confirm successful reps, carry forward the useful feel, then write the session to the vault.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(draft.aggregateEfficiencyText)
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .foregroundStyle(GarageProTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("Efficiency")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.8)
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
            }
        }
    }
}

private struct GarageEquipmentCard: View {
    let equipment: [String]

    var body: some View {
        GarageProCard {
            GarageFocusLabel("Equipment")

            if equipment.isEmpty {
                Text("Environment-appropriate practice setup")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(equipment, id: \.self) { item in
                        Text(item)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GarageProTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GarageProTheme.insetSurface, in: Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(GarageProTheme.border, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
}

private struct GarageDrillOrdinalBadge: View {
    let drillNumber: Int
    let totalDrills: Int
    let isCompleted: Bool

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: isCompleted ? "checkmark.seal.fill" : "scope")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(GarageProTheme.accent)

            Text("\(drillNumber)/\(totalDrills)")
                .font(.caption.weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)
        }
        .frame(width: 64, height: 64)
        .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(GarageProTheme.accent.opacity(isCompleted ? 0.38 : 0.22), lineWidth: 1)
        )
    }
}

private struct GarageLinearProgressBar: View {
    let ratio: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(GarageProTheme.accent.opacity(0.18))

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(GarageProTheme.accent)
                    .frame(width: proxy.size.width * min(max(ratio, 0), 1))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: ratio)
            }
        }
        .frame(height: 12)
    }
}

private struct GarageFocusSecondaryButton: View {
    let title: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else {
                return
            }

            garageTriggerSelection()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(GarageProTheme.textPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: 60)
                .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.42)
        .disabled(isEnabled == false)
    }
}

private struct GarageFocusLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .tracking(1.8)
            .foregroundStyle(GarageProTheme.textSecondary)
    }
}

@MainActor
private struct GarageDrillResultCard: View {
    @Binding var result: GarageSessionDrillResultDraft
    let benchmarkSessionCount: Int

    var body: some View {
        GarageTelemetrySurface(isActive: result.isReviewed) {
            HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    GarageReviewStatusBadge(isReviewed: result.isReviewed)

                    Text("\(result.successfulReps) / \(result.totalReps) successful reps")
                        .font(.subheadline)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                Spacer(minLength: 8)

                Text(result.successPercentageText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(result.successfulReps > 0 ? GarageSessionSummaryPalette.activeSegment : AppModule.garage.theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                GarageSegmentedRepBar(
                    successfulReps: $result.successfulReps,
                    totalReps: result.totalReps,
                    projectedSuccessfulReps: result.projectedSuccessfulReps
                )
                .frame(height: 44)

                Text("Set the exact number of reps that met the standard, then mark this drill reviewed.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let benchmarkText = result.historicalBenchmarkText(sessionCount: benchmarkSessionCount) {
                Text(benchmarkText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(result.isAheadOfProjection ? GarageSessionSummaryPalette.activeSegment : AppModule.garage.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                garageTriggerSelection()
                result.isReviewed = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: result.isReviewed ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 17, weight: .bold))

                    Text(result.isReviewed ? "Reviewed" : "Mark Reviewed")
                        .font(.headline.weight(.bold))

                    Spacer(minLength: 8)
                }
                .foregroundStyle(result.isReviewed ? GarageSessionSummaryPalette.activeSegment : GarageProTheme.accent)
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(GarageProTheme.insetSurface.opacity(result.isReviewed ? 0.92 : 0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(result.isReviewed ? GarageSessionSummaryPalette.activeSegment.opacity(0.36) : GarageProTheme.border, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(result.isReviewed ? "\(result.name) reviewed" : "Mark \(result.name) reviewed")
        }
    }
}

private struct GarageReviewStatusBadge: View {
    let isReviewed: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isReviewed ? "checkmark.seal.fill" : "exclamationmark.circle")
                .font(.caption.weight(.bold))

            Text(isReviewed ? "Reviewed" : "Needs Review")
                .font(.caption.weight(.black))
                .textCase(.uppercase)
                .tracking(1.1)
        }
        .foregroundStyle(isReviewed ? GarageSessionSummaryPalette.activeSegment : GarageProTheme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(GarageProTheme.insetSurface.opacity(0.86))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke((isReviewed ? GarageSessionSummaryPalette.activeSegment : GarageProTheme.accent).opacity(0.34), lineWidth: 1)
                )
        )
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
    var allowsSavingWithoutCue: Bool

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
                ),
                isReviewed: false
            )
        }
        sessionFeelNote = ""
        allowsSavingWithoutCue = false
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

    var reviewedDrillCount: Int {
        drillResults.filter(\.isReviewed).count
    }

    var allDrillResultsReviewed: Bool {
        drillResults.isEmpty == false && reviewedDrillCount == drillResults.count
    }

    var sessionFeelNoteIsEmpty: Bool {
        sessionFeelNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasCarryForwardCueDecision: Bool {
        sessionFeelNoteIsEmpty == false || allowsSavingWithoutCue
    }

    var canSave: Bool {
        allDrillResultsReviewed && hasCarryForwardCueDecision
    }

    var reviewProgressText: String {
        "\(reviewedDrillCount)/\(drillResults.count) drill results reviewed"
    }

    var saveGateMessage: String {
        var missingItems: [String] = []
        let missingReviewCount = drillResults.count - reviewedDrillCount

        if drillResults.isEmpty {
            missingItems.append("add at least one drill result")
        }

        if missingReviewCount > 0 {
            let suffix = missingReviewCount == 1 ? "drill result" : "drill results"
            missingItems.append("review \(missingReviewCount) \(suffix)")
        }

        if hasCarryForwardCueDecision == false {
            missingItems.append("add a carry-forward cue or choose Save without cue")
        }

        guard missingItems.isEmpty == false else {
            return "Ready to save reviewed rep counts."
        }

        return "Before saving: \(missingItems.joined(separator: " and "))."
    }
}

private struct GarageSessionDrillResultDraft: Identifiable {
    let id: UUID
    let name: String
    let totalReps: Int
    var successfulReps: Int
    let projectedSuccessfulReps: Int?
    var isReviewed: Bool

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
