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
    @State private var drillReviews: [UUID: GaragePostDrillReviewDraft] = [:]
    @State private var pendingDrillReview: GaragePendingDrillReview?
    @State private var isDrillDetailExpanded = false
    @State private var noteEditor: DrillNoteEditorState?
    @State private var resolver: GarageDrillResolverState?
    @State private var summaryDraft: GarageSessionSummaryDraft?
    @State private var reviewHandoffMessage: String?
    @State private var saveErrorMessage: String?

    let onEndSession: () -> Void

    init(
        session: ActivePracticeSession,
        onEndSession: @escaping () -> Void
    ) {
        _session = State(initialValue: session)
        let firstUnresolvedIndex = session.drillProgress.firstIndex { $0.isResolved == false } ?? 0
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
                        focusPrimaryAction(payload: payload, action: "next")
                    },
                    onSkip: { payload in
                        resolveCurrentDrill(payload: payload, outcome: .skipped, action: "skip")
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
                                    reviewByDrillID: drillReviews
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
            case .postDrillReview:
                if let pendingDrillReview {
                    GaragePostDrillReviewView(
                        pendingReview: pendingDrillReview,
                        review: Binding(
                            get: {
                                drillReviews[pendingDrillReview.drillID]
                                ?? GaragePostDrillReviewDraft(mode: pendingDrillReview.mode)
                            },
                            set: { drillReviews[pendingDrillReview.drillID] = $0 }
                        ),
                        onBack: { phase = .focusRoom },
                        onContinue: { review in
                            finishPostDrillReview(review, for: pendingDrillReview)
                        }
                    )
                } else {
                    GarageProScaffold {
                        GarageProHeroCard(
                            eyebrow: "Drill Review",
                            title: session.templateName,
                            subtitle: "Preparing drill review."
                        )
                    }
                    .onAppear {
                        phase = .focusRoom
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
        .sheet(item: $resolver) { resolver in
            GarageDrillResolverSheet(
                state: resolver,
                onResolve: resolveResolverSelection(_:),
                onKeepWorking: keepWorkingFromResolver
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
        case .postDrillReview:
            "Drill Review"
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
        session.orderedDrillEntries.firstIndex(where: { $0.progress.isResolved == false })
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
            isCompleted: currentEntry.progress.isResolved
        )
    }

    private var focusRailItems: [GarageFocusDrillRailItem] {
        session.orderedDrillEntries.enumerated().map { index, entry in
            let status: GarageFocusDrillRailStatus
            if index == currentDrillIndex {
                status = .current
            } else if entry.progress.isResolved {
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
                isSelectable: entry.progress.isResolved
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

        guard entries[index].progress.isResolved else {
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

        drillElapsedSeconds[currentEntry.drill.id] = max(payload.elapsedSeconds, drillElapsedSeconds[currentEntry.drill.id] ?? 0)
        pendingDrillReview = GaragePendingDrillReview(
            drillID: currentEntry.drill.id,
            title: currentEntry.drill.title,
            mode: payload.mode,
            elapsedSeconds: payload.elapsedSeconds,
            durationSeconds: payload.durationSeconds,
            targetMetric: currentDrillPresentation?.content.targetMetric ?? "Complete the timed block."
        )
        drillReviews[currentEntry.drill.id] = drillReviews[currentEntry.drill.id]
            ?? GaragePostDrillReviewDraft(mode: payload.mode)
        phase = .postDrillReview
    }

    private func finishPostDrillReview(
        _ review: GaragePostDrillReviewDraft,
        for pendingReview: GaragePendingDrillReview
    ) {
        drillReviews[pendingReview.drillID] = review

        let completedCountBefore = session.completedDrillCount
        let indexBefore = currentDrillIndex
        session.resolveDrill(pendingReview.drillID, outcome: .completedTarget)
        logAuthorityResolution(
            drillID: pendingReview.drillID,
            drillTitle: pendingReview.title,
            mode: pendingReview.mode,
            action: "targetCompletion",
            outcome: .completedTarget,
            indexBefore: indexBefore,
            indexAfter: nextUnresolvedDrillIndex(after: indexBefore) ?? indexBefore,
            completedCountBefore: completedCountBefore,
            completedCountAfter: session.completedDrillCount,
            totalReps: 1
        )

        self.pendingDrillReview = nil
        advanceAfterResolution()
    }

    private func focusPrimaryAction(payload: GarageFocusCompletionPayload, action: String) {
        if unresolvedDrillIndex == nil {
            presentReview(autoRouted: false)
        } else if payload.goalMet {
            completeCurrentDrill(payload: payload)
        } else {
            resolveEarlyExit(payload: payload, action: action)
        }
    }

    private func resolveEarlyExit(payload: GarageFocusCompletionPayload, action: String) {
        switch payload.mode {
        case .pressureTest:
            resolveCurrentDrill(payload: payload, outcome: .skipped, action: action)
        case .process, .target:
            switch payload.goal {
            case .timed:
                resolveCurrentDrill(payload: payload, outcome: .partial, action: action)
            case .repTarget, .streak, .timeTrial, .ladder, .checklist, .manual:
                presentResolver(payload: payload)
            }
        }
    }

    private func presentResolver(payload: GarageFocusCompletionPayload) {
        guard let currentEntry else {
            presentReview(autoRouted: false)
            return
        }

        resolver = GarageDrillResolverState(
            drillID: currentEntry.drill.id,
            drillTitle: currentEntry.drill.title,
            payload: payload,
            supportsCompletedEarly: supportsCompletedEarly(goal: payload.goal),
            supportsPartial: supportsPartial(goal: payload.goal)
        )
    }

    private func supportsCompletedEarly(goal: GarageDrillGoal) -> Bool {
        switch goal {
        case .timed, .checklist:
            return false
        case .repTarget, .streak, .timeTrial, .ladder, .manual:
            return true
        }
    }

    private func supportsPartial(goal: GarageDrillGoal) -> Bool {
        switch goal {
        case .timed:
            return false
        case .repTarget, .streak, .timeTrial, .ladder, .checklist, .manual:
            return true
        }
    }

    private func resolveResolverSelection(_ outcome: GarageDrillOutcome) {
        guard let resolver else {
            return
        }

        resolveCurrentDrill(payload: resolver.payload, outcome: outcome, action: "resolver.\(outcome.rawValue)")
    }

    private func resolveCurrentDrill(
        payload: GarageFocusCompletionPayload,
        outcome: GarageDrillOutcome,
        action: String
    ) {
        guard let currentEntry else {
            presentReview(autoRouted: false)
            return
        }

        let indexBefore = currentDrillIndex
        let completedCountBefore = session.completedDrillCount
        drillElapsedSeconds[currentEntry.drill.id] = max(payload.elapsedSeconds, drillElapsedSeconds[currentEntry.drill.id] ?? 0)
        session.resolveDrill(currentEntry.drill.id, outcome: outcome)
        drillReviews[currentEntry.drill.id] = GaragePostDrillReviewDraft(
            mode: payload.mode,
            outcome: outcome
        )
        let indexAfter = nextUnresolvedDrillIndex(after: indexBefore) ?? indexBefore
        logAuthorityResolution(
            drillID: currentEntry.drill.id,
            drillTitle: currentEntry.drill.title,
            mode: payload.mode,
            action: action,
            outcome: outcome,
            indexBefore: indexBefore,
            indexAfter: indexAfter,
            completedCountBefore: completedCountBefore,
            completedCountAfter: session.completedDrillCount,
            totalReps: outcome == .skipped ? 0 : 1
        )
        resolver = nil
        advanceAfterResolution()
    }

    private func keepWorkingFromResolver() {
        #if DEBUG
        if GarageAuthorityQALogger.isEnabled,
           let currentEntry,
           let resolver {
            GarageAuthorityQALogger.log(
                "drillID=\(currentEntry.drill.id.uuidString) title=\"\(currentEntry.drill.title)\" mode=\(resolver.payload.mode.rawValue) action=resolver.keepWorking savedOutcome=none indexBefore=\(currentDrillIndex) indexAfter=\(currentDrillIndex) completedCountBefore=\(session.completedDrillCount) completedCountAfter=\(session.completedDrillCount)"
            )
        }
        #endif
        resolver = nil
    }

    private func logAuthorityResolution(
        drillID: UUID,
        drillTitle: String,
        mode: GarageDrillFocusMode,
        action: String,
        outcome: GarageDrillOutcome,
        indexBefore: Int,
        indexAfter: Int,
        completedCountBefore: Int,
        completedCountAfter: Int,
        totalReps: Int
    ) {
        #if DEBUG
        guard GarageAuthorityQALogger.isEnabled else {
            return
        }

        let result = DrillResult(
            name: drillTitle,
            successfulReps: outcome == .completedTarget ? 1 : 0,
            totalReps: totalReps,
            outcome: outcome
        )
        GarageAuthorityQALogger.log(
            "drillID=\(drillID.uuidString) title=\"\(drillTitle)\" mode=\(mode.rawValue) action=\(action) savedOutcome=\(outcome.rawValue) indexBefore=\(indexBefore) indexAfter=\(indexAfter) completedCountBefore=\(completedCountBefore) completedCountAfter=\(completedCountAfter) trueCompletion=\(outcome.isTrueCompletion) adaptiveContributes=\(result.contributesToAdaptiveScoring) adaptiveRatio=\(result.adaptiveSuccessRatio)"
        )
        #endif
    }

    private func advanceAfterResolution() {
        if let nextIndex = nextUnresolvedDrillIndex(after: currentDrillIndex) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentDrillIndex = nextIndex
                isDrillDetailExpanded = false
                phase = .focusRoom
            }
        } else {
            presentReview(autoRouted: false)
        }
    }

    private func nextUnresolvedDrillIndex(after index: Int) -> Int? {
        let entries = session.orderedDrillEntries
        guard entries.isEmpty == false else {
            return nil
        }

        let clampedIndex = max(0, min(index, entries.count - 1))
        let wrappedIndices = Array(entries.indices.dropFirst(clampedIndex + 1)) + Array(entries.indices.prefix(clampedIndex + 1))
        return wrappedIndices.first(where: { entries[$0].progress.isResolved == false })
    }

    private func presentReview(autoRouted: Bool = false) {
        summaryDraft = GarageSessionSummaryDraft(
            session: session,
            benchmarkSnapshot: records.benchmarkSnapshot(for: session.templateName),
            elapsedSecondsByDrillID: drillElapsedSeconds,
            reviewByDrillID: drillReviews
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
    case postDrillReview
    case review
}

#if DEBUG
private enum GarageAuthorityQALogger {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("GARAGE_DRILL_AUTHORITY_QA")
        || ProcessInfo.processInfo.arguments.contains("GARAGE_DRILL_AUTHORITY_QA_SUMMARY")
    }

    static func log(_ message: String) {
        NSLog("[GarageAuthorityQA] \(message)")
    }
}
#endif

private struct GaragePendingDrillReview: Hashable {
    let drillID: UUID
    let title: String
    let mode: GarageDrillFocusMode
    let elapsedSeconds: Int
    let durationSeconds: Int
    let targetMetric: String
}

private struct GaragePostDrillReviewDraft: Hashable {
    let mode: GarageDrillFocusMode
    var outcome: GarageDrillOutcome
    var confidenceRating: Int
    var targetReached: Bool
    var pressurePassed: Bool
    var note: String

    init(
        mode: GarageDrillFocusMode,
        outcome: GarageDrillOutcome = .completedTarget,
        confidenceRating: Int = 3,
        targetReached: Bool = false,
        pressurePassed: Bool = false,
        note: String = ""
    ) {
        self.mode = mode
        self.outcome = outcome
        self.confidenceRating = confidenceRating
        self.targetReached = targetReached
        self.pressurePassed = pressurePassed
        self.note = note
    }

    var isComplete: Bool {
        (1...5).contains(confidenceRating)
    }

    var successfulUnits: Int {
        guard outcome != .skipped else {
            return 0
        }

        switch mode {
        case .process:
            return outcome == .completedTarget && confidenceRating >= 3 ? 1 : 0
        case .target:
            return outcome == .completedTarget && targetReached ? 1 : 0
        case .pressureTest:
            return outcome == .completedTarget && pressurePassed ? 1 : 0
        }
    }

    var outcomeSummary: String {
        if outcome != .completedTarget {
            return outcome.displayTitle
        }

        switch mode {
        case .process:
            return "Quality \(confidenceRating)/5"
        case .target:
            return "\(targetReached ? "Target reached" : "Target close") - Confidence \(confidenceRating)/5"
        case .pressureTest:
            return "\(pressurePassed ? "Passed" : "Failed") - Confidence \(confidenceRating)/5"
        }
    }
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
                GarageCompactMetricCard(title: "Suggested Volume", value: "\(totalPlannedReps)", systemImage: "repeat", isActive: totalPlannedReps > 0)
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
private struct GaragePostDrillReviewView: View {
    let pendingReview: GaragePendingDrillReview
    @Binding var review: GaragePostDrillReviewDraft
    let onBack: () -> Void
    let onContinue: (GaragePostDrillReviewDraft) -> Void

    var body: some View {
        GarageProScaffold(bottomPadding: GarageSessionDockLayout.reviewBottomPadding) {
            GarageProHeroCard(
                eyebrow: pendingReview.mode.controlLabel,
                title: pendingReview.title,
                subtitle: "Timer complete. Capture the outcome before moving on.",
                value: garageSessionSummaryTime(pendingReview.elapsedSeconds),
                valueLabel: "Elapsed"
            )

            GarageTelemetrySurface(isActive: true) {
                GarageFocusLabel("Block Outcome")

                Text(pendingReview.targetMetric)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                modeSpecificControls
            }

            GarageTelemetrySurface(isActive: true) {
                GarageFocusLabel("Quality / Confidence")

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            garageTriggerSelection()
                            review.confidenceRating = value
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(review.confidenceRating == value ? ModuleTheme.garageCanvas : GarageProTheme.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(
                                    review.confidenceRating == value
                                    ? GarageProTheme.accent
                                    : GarageProTheme.insetSurface,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(GarageProTheme.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextField("Optional note from the block", text: $review.note, axis: .vertical)
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

            GarageTelemetrySurface(isActive: review.isComplete) {
                HStack(spacing: 12) {
                    GarageFocusSecondaryButton(
                        title: "Back",
                        systemImage: "chevron.left",
                        action: onBack
                    )

                    GarageProPrimaryButton(
                        title: "Continue",
                        systemImage: "checkmark.seal.fill",
                        isEnabled: review.isComplete
                    ) {
                        onContinue(review)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var modeSpecificControls: some View {
        switch pendingReview.mode {
        case .process:
            GaragePostDrillOutcomeButton(
                title: "Process block completed",
                subtitle: "Quality rating is the main review signal.",
                systemImage: "checkmark.seal.fill",
                isSelected: true,
                action: {}
            )
        case .target:
            HStack(spacing: 10) {
                GaragePostDrillOutcomeButton(
                    title: "Reached",
                    subtitle: "Target felt achieved.",
                    systemImage: "scope",
                    isSelected: review.targetReached,
                    action: { review.targetReached = true }
                )

                GaragePostDrillOutcomeButton(
                    title: "Close",
                    subtitle: "Useful miss or near target.",
                    systemImage: "circle.dashed",
                    isSelected: review.targetReached == false,
                    action: { review.targetReached = false }
                )
            }
        case .pressureTest:
            HStack(spacing: 10) {
                GaragePostDrillOutcomeButton(
                    title: "Pass",
                    subtitle: "Pressure standard held.",
                    systemImage: "checkmark.seal.fill",
                    isSelected: review.pressurePassed,
                    action: { review.pressurePassed = true }
                )

                GaragePostDrillOutcomeButton(
                    title: "Fail",
                    subtitle: "Standard broke under pressure.",
                    systemImage: "xmark.seal.fill",
                    isSelected: review.pressurePassed == false,
                    action: { review.pressurePassed = false }
                )
            }
        }
    }
}

private struct GaragePostDrillOutcomeButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))

                Text(title)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? GarageProTheme.accent : GarageProTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(GarageProTheme.insetSurface.opacity(isSelected ? 0.94 : 0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? GarageProTheme.accent.opacity(0.42) : GarageProTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("garage-resolver-\(title.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "-", with: "-"))")
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

            Text(result.reviewSummary)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(GarageProTheme.accent)
                .fixedSize(horizontal: false, vertical: true)

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

private struct GarageDrillResolverState: Identifiable {
    let drillID: UUID
    let drillTitle: String
    let payload: GarageFocusCompletionPayload
    let supportsCompletedEarly: Bool
    let supportsPartial: Bool

    var id: UUID { drillID }
}

@MainActor
private struct GarageDrillResolverSheet: View {
    let state: GarageDrillResolverState
    let onResolve: (GarageDrillOutcome) -> Void
    let onKeepWorking: () -> Void

    var body: some View {
        NavigationStack {
            GarageProScaffold(bottomPadding: 32) {
                GarageProHeroCard(
                    eyebrow: "Drill Authority",
                    title: "Move on from this drill?",
                    subtitle: state.drillTitle
                )

                GarageTelemetrySurface(isActive: true) {
                    GarageDrillResolverAction(
                        title: "Skip Drill",
                        subtitle: "Bypass this drill and keep the routine moving.",
                        systemImage: "forward.end.fill",
                        isPrimary: true
                    ) {
                        onResolve(.skipped)
                    }

                    if state.supportsPartial {
                        GarageDrillResolverAction(
                            title: "Log Partial",
                            subtitle: "Record useful work without claiming the target was met.",
                            systemImage: "circle.lefthalf.filled",
                            isPrimary: false
                        ) {
                            onResolve(.partial)
                        }
                    }

                    if state.supportsCompletedEarly {
                        GarageDrillResolverAction(
                            title: "Got It - Next Drill",
                            subtitle: "Move on early as an intentional choice.",
                            systemImage: "checkmark.seal",
                            isPrimary: false
                        ) {
                            onResolve(.completedEarly)
                        }
                    }

                    GarageDrillResolverAction(
                        title: "Keep Working",
                        subtitle: "Return to the drill without logging an outcome yet.",
                        systemImage: "arrow.uturn.backward",
                        isPrimary: false,
                        action: onKeepWorking
                    )
                }
            }
            .navigationTitle("Move On")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onKeepWorking)
                }
            }
        }
        .garagePuttingGreenSheetChrome()
    }
}

private struct GarageDrillResolverAction: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(isPrimary ? ModuleTheme.garageCanvas : GarageProTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        isPrimary ? GarageProTheme.accent : GarageProTheme.insetSurface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }
            .padding(12)
            .background(GarageProTheme.insetSurface.opacity(isPrimary ? 0.94 : 0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isPrimary ? GarageProTheme.accent.opacity(0.42) : GarageProTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
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
        reviewByDrillID: [UUID: GaragePostDrillReviewDraft]
    ) {
        id = session.id
        templateName = session.templateName
        benchmarkSessionCount = benchmarkSnapshot?.sourceSessionCount ?? 0
        let entries = session.orderedDrillEntries
        drillResults = entries.map { entry in
            let detail = GarageDrillFocusDetails.detail(for: entry.drill)
            let content = GarageDrillFocusContentAdapter.content(for: entry.drill, detail: detail)
            let elapsedSeconds = elapsedSecondsByDrillID[entry.drill.id]
            let review = reviewByDrillID[entry.drill.id] ?? GaragePostDrillReviewDraft(mode: content.mode)
            let totalReps = 1
            let outcome = entry.progress.resolvedOutcome ?? review.outcome
            let successfulReps = entry.progress.isCompletedTarget ? review.successfulUnits : 0

            return GarageSessionDrillResultDraft(
                id: entry.drill.id,
                name: entry.drill.title,
                mode: content.mode,
                goal: content.goal,
                outcome: outcome,
                totalReps: totalReps,
                successfulReps: successfulReps,
                elapsedSeconds: elapsedSeconds,
                projectedSuccessfulReps: benchmarkSnapshot?.projectedSuccessfulReps(
                    for: entry.drill.title,
                    totalReps: totalReps
                ),
                reviewSummary: review.outcomeSummary,
                note: Self.combinedNote(existingNote: entry.progress.note, review: review),
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
        drillResults.reduce(0) { $0 + ($1.outcome == .skipped ? 0 : $1.totalReps) }
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
            partialResult + (result.outcome == .skipped ? 0 : (result.projectedSuccessfulReps ?? 0))
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

    private static func combinedNote(
        existingNote: String,
        review: GaragePostDrillReviewDraft
    ) -> String {
        let trimmedExistingNote = existingNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReviewNote = review.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let reviewLine = "Review: \(review.outcomeSummary)"

        return [reviewLine, trimmedExistingNote, trimmedReviewNote]
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
    }
}

private struct GarageSessionDrillResultDraft: Identifiable {
    let id: UUID
    let name: String
    let mode: GarageDrillFocusMode
    let goal: GarageDrillGoal
    let outcome: GarageDrillOutcome
    let totalReps: Int
    var successfulReps: Int
    let elapsedSeconds: Int?
    let projectedSuccessfulReps: Int?
    let reviewSummary: String
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
        case .process:
            if outcome == .skipped {
                return "Skipped"
            }

            if elapsedSeconds == nil {
                return "No timer captured"
            }
            return outcome == .completedTarget ? "Process target completed" : outcome.displayTitle
        case .target:
            return outcome == .completedTarget ? "Target completed" : outcome.displayTitle
        case .pressureTest:
            return outcome == .completedTarget ? "Pressure test completed" : outcome.displayTitle
        }
    }

    var progressSummaryText: String {
        switch goal {
        case .timed:
            return outcome == .completedTarget ? "Timed target complete" : outcome.displayTitle
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
            totalReps: outcome == .skipped ? 0 : totalReps,
            outcome: outcome
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
