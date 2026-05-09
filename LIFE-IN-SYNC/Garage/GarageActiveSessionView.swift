import SwiftData
import SwiftUI

@MainActor
struct GarageActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]
    @State private var session: ActivePracticeSession
    @State private var phase: GarageActiveSessionPhase = .focusRoom
    @State private var currentDrillIndex = 0
    @State private var drillElapsedSeconds: [UUID: Int] = [:]
    @State private var drillTrackerValues: [UUID: Int] = [:]
    @State private var isDrillDetailExpanded = false
    @State private var noteEditor: DrillNoteEditorState?
    @State private var summaryDraft: GarageSessionSummaryDraft?
    @State private var reviewHandoffMessage: String?
    @State private var saveErrorMessage: String?

    let onEndSession: () -> Void

    init(
        session: ActivePracticeSession,
        onEndSession: @escaping () -> Void
    ) {
        _session = State(initialValue: session)
        let firstUnresolvedIndex = session.drillProgress.firstIndex { $0.isCompleted == false } ?? 0
        _currentDrillIndex = State(initialValue: firstUnresolvedIndex)
        self.onEndSession = onEndSession
    }

    var body: some View {
        Group {
            switch phase {
            case .focusRoom:
                GarageFocusRoomView(
                    sessionTitle: session.templateName,
                    environment: session.environment,
                    drillPositionText: drillPositionText,
                    completedCount: session.completedDrillCount,
                    totalCount: session.totalDrillCount,
                    drill: currentDrillPresentation,
                    railItems: focusRailItems,
                    isDetailExpanded: isDrillDetailExpanded,
                    noteTitle: focusNoteCtaTitle,
                    primaryCtaTitle: focusPrimaryCtaTitle,
                    onToggleDetail: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            isDrillDetailExpanded.toggle()
                        }
                    },
                    onSelectRailDrill: selectDrill(at:),
                    onNote: {
                        if let currentEntry {
                            presentNoteEditor(for: currentEntry)
                        }
                    },
                    onPrimary: { payload in
                        focusPrimaryAction(payload: payload)
                    },
                    onExitEmptyRoutine: onEndSession
                )
            case .review:
                if summaryDraft != nil {
                    GarageSessionReviewView(
                        draft: Binding(
                            get: {
                                summaryDraft ?? GarageSessionSummaryDraft(
                                    session: session,
                                    benchmarkSnapshot: records.benchmarkSnapshot(for: session.templateName),
                                    elapsedSecondsByDrillID: drillElapsedSeconds,
                                    trackerValueByDrillID: drillTrackerValues
                                )
                            },
                            set: { summaryDraft = $0 }
                        ),
                        entries: session.orderedDrillEntries,
                        handoffMessage: reviewHandoffMessage,
                        onBack: { phase = .focusRoom },
                        onSave: saveSummary
                    )
                } else {
                    GarageProScaffold {
                        GarageProHeroCard(
                            eyebrow: GarageFocusRoomCopy.reviewHandoffNavTitle,
                            title: session.templateName,
                            subtitle: "Preparing review details."
                        )
                    }
                    .onAppear {
                        presentReview()
                    }
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
        case .focusRoom:
            GarageFocusRoomCopy.focusRoomNavTitle
        case .review:
            GarageFocusRoomCopy.reviewHandoffNavTitle
        }
    }

    private var currentEntry: PracticeSessionDrillEntry? {
        let entries = session.orderedDrillEntries
        guard entries.indices.contains(currentDrillIndex) else {
            return entries.first
        }

        return entries[currentDrillIndex]
    }

    private var drillPositionText: String {
        let currentValue = session.totalDrillCount == 0 ? 0 : min(currentDrillIndex + 1, session.totalDrillCount)
        return GarageFocusRoomCopy.focusRoomHeaderDrillPositionFormat
            .replacingOccurrences(of: "{current}", with: "\(currentValue)")
            .replacingOccurrences(of: "{total}", with: "\(session.totalDrillCount)")
    }

    private var focusPrimaryCtaTitle: String {
        unresolvedDrillIndex == nil ? GarageFocusRoomCopy.focusRoomEnterReviewCta : GarageFocusRoomCopy.focusRoomMarkCompleteCta
    }

    private var focusNoteCtaTitle: String {
        guard let note = currentEntry?.progress.note.trimmingCharacters(in: .whitespacesAndNewlines),
              note.isEmpty == false else {
            return GarageFocusRoomCopy.focusRoomNoteAddCta
        }

        return GarageFocusRoomCopy.focusRoomNoteEditCta
    }

    private var unresolvedDrillIndex: Int? {
        session.orderedDrillEntries.firstIndex(where: { $0.progress.isCompleted == false })
    }

    private var currentDrillPresentation: GarageFocusDrillPresentation? {
        guard let currentEntry else {
            return nil
        }

        let detail = GarageDrillFocusDetails.detail(for: currentEntry.drill)
        let content = GarageDrillFocusContentAdapter.content(
            for: currentEntry.drill,
            detail: detail
        )

        return GarageFocusDrillPresentation(
            id: currentEntry.drill.id,
            content: content,
            isCompleted: currentEntry.progress.isCompleted
        )
    }

    private var focusRailItems: [GarageFocusDrillRailItem] {
        session.orderedDrillEntries.enumerated().map { index, entry in
            let status: GarageFocusDrillRailStatus
            if index == currentDrillIndex {
                status = .current
            } else if entry.progress.isCompleted {
                status = .completed
            } else {
                status = .upcoming
            }

            return GarageFocusDrillRailItem(
                id: entry.drill.id,
                index: index,
                title: entry.drill.title,
                metadata: GarageDrillFocusContentAdapter
                    .content(
                        for: entry.drill,
                        detail: GarageDrillFocusDetails.detail(for: entry.drill)
                    )
                    .goal
                    .railSummary,
                status: status,
                isSelectable: entry.progress.isCompleted
            )
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

    private func presentNoteEditor(for entry: PracticeSessionDrillEntry) {
        noteEditor = DrillNoteEditorState(
            drillID: entry.drill.id,
            drillTitle: entry.drill.title,
            note: entry.progress.note
        )
    }

    private func selectDrill(at index: Int) {
        let entries = session.orderedDrillEntries
        guard entries.indices.contains(index) else {
            return
        }

        guard entries[index].progress.isCompleted else {
            return
        }

        garageTriggerSelection()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentDrillIndex = index
            isDrillDetailExpanded = false
        }
    }

    private func completeCurrentDrill(payload: GarageFocusCompletionPayload) {
        guard let currentEntry else {
            presentReview(autoRouted: false)
            return
        }

        guard payload.goalMet else {
            return
        }

        drillElapsedSeconds[currentEntry.drill.id] = max(payload.elapsedSeconds, drillElapsedSeconds[currentEntry.drill.id] ?? 0)
        drillTrackerValues[currentEntry.drill.id] = max(payload.trackerValue, drillTrackerValues[currentEntry.drill.id] ?? 0)

        if currentEntry.progress.isCompleted == false {
            session.toggleCompletion(for: currentEntry.drill.id)
        }

        if let nextIndex = nextUnresolvedDrillIndex(after: currentDrillIndex) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentDrillIndex = nextIndex
                isDrillDetailExpanded = false
            }
        } else {
            presentReview(autoRouted: false)
        }
    }

    private func focusPrimaryAction(payload: GarageFocusCompletionPayload) {
        if unresolvedDrillIndex == nil {
            presentReview(autoRouted: false)
        } else {
            completeCurrentDrill(payload: payload)
        }
    }

    private func nextUnresolvedDrillIndex(after index: Int) -> Int? {
        let entries = session.orderedDrillEntries
        guard entries.isEmpty == false else {
            return nil
        }

        let clampedIndex = max(0, min(index, entries.count - 1))
        let wrappedIndices = Array(entries.indices.dropFirst(clampedIndex + 1)) + Array(entries.indices.prefix(clampedIndex + 1))
        return wrappedIndices.first(where: { entries[$0].progress.isCompleted == false })
    }

    private func presentReview(autoRouted: Bool = false) {
        summaryDraft = GarageSessionSummaryDraft(
            session: session,
            benchmarkSnapshot: records.benchmarkSnapshot(for: session.templateName),
            elapsedSecondsByDrillID: drillElapsedSeconds,
            trackerValueByDrillID: drillTrackerValues
        )
        reviewHandoffMessage = autoRouted ? GarageFocusRoomCopy.reviewHandoffAutoRouteMessage : nil
        phase = .review
    }

    private func saveSummary(_ draft: GarageSessionSummaryDraft) {
        for result in draft.drillResults {
            session.updateNote(result.note, for: result.id)
        }

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
    case focusRoom
    case review
}

private enum GarageSessionDockLayout {
    static let contentBottomPadding: CGFloat = 56
    static let reviewBottomPadding: CGFloat = 56
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

            HStack {
                GarageProPrimaryButton(
                    title: "Enter Focus Room",
                    systemImage: "figure.golf"
                ) {
                    onEnter()
                }
            }
        }
    }
}

@MainActor
private struct GarageSessionReviewView: View {
    @Binding var draft: GarageSessionSummaryDraft
    let entries: [PracticeSessionDrillEntry]
    let handoffMessage: String?
    let onBack: () -> Void
    let onSave: (GarageSessionSummaryDraft) -> Void

    var body: some View {
        GarageProScaffold(bottomPadding: GarageSessionDockLayout.reviewBottomPadding) {
            GarageSessionReviewLeadCard(draft: draft, handoffMessage: handoffMessage)

            GarageSessionPerformanceList(draft: $draft)

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
                    VStack(alignment: .leading, spacing: 8) {
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

                        if draft.allowsSavingWithoutCue {
                            Text("No carry-forward cue will be saved for this session.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(GarageSessionSummaryPalette.activeSegment)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            GarageSessionReviewSaveActions(
                draft: draft,
                onBack: onBack,
                onSave: onSave
            )
        }
    }
}

@MainActor
private struct GarageSessionReviewSaveActions: View {
    let draft: GarageSessionSummaryDraft
    let onBack: () -> Void
    let onSave: (GarageSessionSummaryDraft) -> Void

    var body: some View {
        GarageTelemetrySurface(isActive: draft.canSave) {
            if draft.canSave == false {
                Text(draft.saveGateMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                GarageFocusSecondaryButton(
                    title: GarageFocusRoomCopy.reviewHandoffBackToFocusCta,
                    systemImage: "chevron.left",
                    action: onBack
                )

                GarageProPrimaryButton(
                    title: GarageFocusRoomCopy.reviewHandoffSaveCta,
                    systemImage: "checkmark.seal.fill",
                    isEnabled: draft.canSave
                ) {
                    onSave(draft)
                }
            }
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

                    Text(readinessMessage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(draft.allDrillResultsReviewed ? GarageSessionSummaryPalette.activeSegment : GarageProTheme.accent)
                }
            }
        }
    }

    private var readinessMessage: String {
        if draft.allDrillResultsReviewed {
            return GarageFocusRoomCopy.reviewHandoffReadyMessage
        }

        let remaining = max(draft.drillResults.count - draft.reviewedDrillCount, 0)
        return GarageFocusRoomCopy.reviewHandoffPendingFormat
            .replacingOccurrences(of: "{remaining}", with: "\(remaining)")
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
    let handoffMessage: String?

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 28, padding: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    GarageFocusLabel(GarageFocusRoomCopy.reviewHandoffNavTitle)

                    Text(draft.templateName)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)

                    Text(GarageFocusRoomCopy.reviewHandoffSubtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let handoffMessage,
                       handoffMessage.isEmpty == false {
                        Text(handoffMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(GarageProTheme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(draft.totalElapsedTimeText)
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .foregroundStyle(GarageProTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("Total Time")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.8)
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
            }
        }
    }
}

@MainActor
private struct GarageSessionPerformanceList: View {
    @Binding var draft: GarageSessionSummaryDraft

    var body: some View {
        GarageTelemetrySurface(isActive: true) {
            HStack(alignment: .firstTextBaseline) {
                GarageFocusLabel("Drill Performance")

                Spacer(minLength: 12)

                Text(draft.reviewProgressText)
                    .font(.caption.weight(.black))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach($draft.drillResults) { $result in
                    GarageSessionPerformanceRow(result: $result)
                }
            }
        }
    }
}

@MainActor
private struct GarageSessionPerformanceRow: View {
    @Binding var result: GarageSessionDrillResultDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(result.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(result.elapsedTimeText)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(result.elapsedSeconds == nil ? GarageProTheme.textSecondary : GarageSessionSummaryPalette.activeSegment)
                    .lineLimit(1)
            }

            Text(result.performanceCaption)
                .font(.caption.weight(.black))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(result.elapsedSeconds == nil ? GarageProTheme.textSecondary : GarageSessionSummaryPalette.activeSegment)

            TextField("What did this drill teach you?", text: $result.note, axis: .vertical)
                .lineLimit(2...4)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GarageProTheme.textPrimary)
                .padding(12)
                .background(GarageProTheme.insetSurface.opacity(0.86), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GarageProTheme.border)
                .frame(height: 1)
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

    private var reviewedRepBinding: Binding<Int> {
        Binding(
            get: { result.successfulReps },
            set: { updatedValue in
                guard result.successfulReps != updatedValue else {
                    return
                }

                result.successfulReps = updatedValue
                result.isReviewed = false
            }
        )
    }

    var body: some View {
        GarageTelemetrySurface(isActive: result.isReviewed) {
            HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    GarageReviewStatusBadge(isReviewed: result.isReviewed)

                    Text(result.progressSummaryText)
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
                    successfulReps: reviewedRepBinding,
                    totalReps: result.totalReps,
                    projectedSuccessfulReps: result.projectedSuccessfulReps
                )
                .frame(height: 44)

                Text("Set the exact completion count that met the drill standard, then mark this drill reviewed.")
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
        benchmarkSnapshot: GarageTemplateBenchmarkSnapshot?,
        elapsedSecondsByDrillID: [UUID: Int],
        trackerValueByDrillID: [UUID: Int]
    ) {
        id = session.id
        templateName = session.templateName
        benchmarkSessionCount = benchmarkSnapshot?.sourceSessionCount ?? 0
        let entries = session.orderedDrillEntries
        drillResults = entries.map { entry in
            let detail = GarageDrillFocusDetails.detail(for: entry.drill)
            let content = GarageDrillFocusContentAdapter.content(for: entry.drill, detail: detail)
            let elapsedSeconds = elapsedSecondsByDrillID[entry.drill.id]
            let trackerValue = trackerValueByDrillID[entry.drill.id] ?? 0
            let execution = Self.executionMetrics(
                for: content.goal,
                trackerValue: trackerValue,
                elapsedSeconds: elapsedSeconds,
                isCompleted: entry.progress.isCompleted
            )

            return GarageSessionDrillResultDraft(
                id: entry.drill.id,
                name: entry.drill.title,
                mode: content.mode,
                goal: content.goal,
                totalReps: execution.totalReps,
                successfulReps: execution.successfulReps,
                elapsedSeconds: elapsedSeconds,
                projectedSuccessfulReps: benchmarkSnapshot?.projectedSuccessfulReps(
                    for: entry.drill.title,
                    totalReps: execution.totalReps
                ),
                note: entry.progress.note,
                isReviewed: true
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

    var totalElapsedSeconds: Int {
        drillResults.compactMap(\.elapsedSeconds).reduce(0, +)
    }

    var totalElapsedTimeText: String {
        guard totalElapsedSeconds > 0 else {
            return "--:--"
        }

        return garageSessionSummaryTime(totalElapsedSeconds)
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
        drillResults.isEmpty == false && hasCarryForwardCueDecision
    }

    var reviewProgressText: String {
        "\(drillResults.count) drills logged"
    }

    var saveGateMessage: String {
        var missingItems: [String] = []

        if drillResults.isEmpty {
            missingItems.append("add at least one drill result")
        }

        if hasCarryForwardCueDecision == false {
            missingItems.append("add a carry-forward cue or choose Save without cue")
        }

        guard missingItems.isEmpty == false else {
            return "Ready to save the session."
        }

        return "Before saving: \(missingItems.joined(separator: " and "))."
    }

    private static func executionMetrics(
        for goal: GarageDrillGoal,
        trackerValue: Int,
        elapsedSeconds: Int?,
        isCompleted: Bool
    ) -> (successfulReps: Int, totalReps: Int) {
        switch goal {
        case .timed(let durationSeconds):
            let totalReps = 1
            let elapsed = elapsedSeconds ?? 0
            let successfulReps = elapsed >= max(durationSeconds, 1) ? 1 : (isCompleted ? 1 : 0)
            return (successfulReps, totalReps)
        case .repTarget(let count, _), .streak(let count, _):
            let totalReps = max(count, 1)
            let successfulReps = min(max(trackerValue, isCompleted ? totalReps : 0), totalReps)
            return (successfulReps, totalReps)
        case .timeTrial(let targetCount, _):
            let totalReps = max(targetCount, 1)
            let successfulReps = min(max(trackerValue, isCompleted ? totalReps : 0), totalReps)
            return (successfulReps, totalReps)
        case .ladder(let steps):
            let totalReps = max(steps.count, 1)
            let successfulReps = min(max(trackerValue, isCompleted ? totalReps : 0), totalReps)
            return (successfulReps, totalReps)
        case .checklist(let items):
            let totalReps = max(items.count, 1)
            let successfulReps = min(max(trackerValue, isCompleted ? totalReps : 0), totalReps)
            return (successfulReps, totalReps)
        case .manual:
            let totalReps = 1
            let successfulReps = trackerValue > 0 || isCompleted ? 1 : 0
            return (successfulReps, totalReps)
        }
    }
}

private struct GarageSessionDrillResultDraft: Identifiable {
    let id: UUID
    let name: String
    let mode: GarageDrillFocusMode
    let goal: GarageDrillGoal
    let totalReps: Int
    var successfulReps: Int
    let elapsedSeconds: Int?
    let projectedSuccessfulReps: Int?
    var note: String
    var isReviewed: Bool

    var successPercentageText: String {
        guard totalReps > 0 else {
            return "0%"
        }

        let percentage = Int((Double(successfulReps) / Double(totalReps) * 100).rounded())
        return "\(percentage)%"
    }

    var elapsedTimeText: String {
        guard let elapsedSeconds else {
            return "--:--"
        }

        return garageSessionSummaryTime(elapsedSeconds)
    }

    var performanceCaption: String {
        switch mode {
        case .time:
            if elapsedSeconds == nil {
                return "No timer captured"
            }
            return successfulReps >= totalReps ? "Timed block complete" : "Time goal not met"
        case .reps:
            return "Rep-based drill logged"
        case .goal:
            return "Goal progression logged"
        case .challenge:
            return "Challenge attempts logged"
        case .checklist:
            return "Checklist progress logged"
        }
    }

    var progressSummaryText: String {
        switch goal {
        case .timed:
            return successfulReps >= totalReps ? "Timed block complete" : "Timed block incomplete"
        case .repTarget(_, let unit):
            return "\(successfulReps) / \(totalReps) \(unit)"
        case .streak(_, let unit):
            return "\(successfulReps) / \(totalReps) \(unit)"
        case .timeTrial(_, let unit):
            return "\(successfulReps) / \(totalReps) \(unit)"
        case .ladder:
            return "\(successfulReps) / \(totalReps) ladder steps"
        case .checklist:
            return "\(successfulReps) / \(totalReps) checklist items"
        case .manual(let label):
            return successfulReps > 0 ? "Goal complete" : label
        }
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

private func garageSessionSummaryTime(_ seconds: Int) -> String {
    let clampedSeconds = max(seconds, 0)
    let minutes = clampedSeconds / 60
    let seconds = clampedSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
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
