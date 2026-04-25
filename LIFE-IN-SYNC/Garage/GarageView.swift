import AVFoundation
import AVKit
import Combine
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum GarageImportPresentationState: Equatable {
    case idle
    case preparing
    case analyzing(step: GarageAnalysisProgressStep, frameCount: Int = 0, totalFrames: Int = 0)
    case failure(String)

    var isPresented: Bool {
        self != .idle
    }

    var headline: String {
        switch self {
        case .idle:
            ""
        case .preparing:
            "Preparing import"
        case .analyzing:
            "Importing swing"
        case .failure:
            "Import failed"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            ""
        case .preparing:
            "Loading the selected video from Photos."
        case let .analyzing(step, _, _):
            step.detail
        case let .failure(message):
            message
        }
    }

    var activeStepTitle: String? {
        switch self {
        case let .analyzing(step, _, _):
            step.title
        default:
            nil
        }
    }

    var frameProgressLabel: String? {
        switch self {
        case let .analyzing(_, frameCount, totalFrames) where totalFrames > 0:
            "FRAME: \(frameCount) / \(totalFrames)"
        default:
            nil
        }
    }

    var showsProgress: Bool {
        switch self {
        case .preparing, .analyzing:
            true
        case .idle, .failure:
            false
        }
    }

    var tipRotationKey: String {
        switch self {
        case .idle:
            "idle"
        case .preparing:
            "preparing"
        case let .analyzing(step, _, _):
            "analyzing-\(step.title)"
        case .failure:
            "failure"
        }
    }

    var telemetryLabel: String {
        switch self {
        case .idle:
            "STANDBY"
        case .preparing:
            "SOURCE LINK"
        case let .analyzing(step, _, _):
            step.telemetryLabel
        case .failure:
            "RECOVERY"
        }
    }

    var liveStatusLine: String {
        switch self {
        case .idle:
            ""
        case .preparing:
            "Locking the local review master before Garage wakes the analysis stack."
        case let .analyzing(step, _, _):
            step.liveStatusLine
        case .failure:
            "Garage stopped before review routing. You can retry without leaving Analyzer."
        }
    }

    var rotatingTips: [String] {
        switch self {
        case .idle:
            []
        case .preparing:
            [
                "Pinning the selected swing locally so review playback stays reliable.",
                "Staging the review master first so later export work never blocks analysis.",
                "Keeping Garage local-first before any downstream swing processing begins."
            ]
        case let .analyzing(step, _, _):
            step.rotatingTips
        case .failure:
            []
        }
    }
}

private extension GarageAnalysisProgressStep {
    var telemetryLabel: String {
        switch self {
        case .loadingVideo:
            "REVIEW MASTER"
        case .samplingFrames:
            "FRAME SCAN"
        case .detectingBody:
            "POSE TRACK"
        case .mappingCheckpoints:
            "CHECKPOINT MAP"
        case .savingSwing:
            "PERSISTENCE"
        }
    }

    var liveStatusLine: String {
        switch self {
        case .loadingVideo:
            "Staging the review master and priming the Garage analysis pipeline."
        case .samplingFrames:
            "Sampling clean review frames so key checkpoints stay anchored to the real swing."
        case .detectingBody:
            "Tracking body landmarks and hand path structure across the live motion sequence."
        case .mappingCheckpoints:
            "Resolving swing phases, checkpoint timing, and review confidence."
        case .savingSwing:
            "Persisting the analyzed swing package now so review can open before export catch-up."
        }
    }

    var rotatingTips: [String] {
        switch self {
        case .loadingVideo:
            [
                "Locking in the review master before any optimization work starts.",
                "Preserving the source clip first so Garage can always route straight into review.",
                "Warming the analysis stack around the selected motion window."
            ]
        case .samplingFrames:
            [
                "Pulling representative frames so checkpoint review starts from stable references.",
                "Separating noisy frames from the swing window before pose work begins.",
                "Building a clean frame rail for later keyframe validation."
            ]
        case .detectingBody:
            [
                "Tracing wrist and shoulder landmarks to stabilize the swing skeleton.",
                "Watching how the hand path accelerates through transition and impact.",
                "Measuring posture retention so the coaching layer has trustworthy geometry."
            ]
        case .mappingCheckpoints:
            [
                "Resolving address, takeaway, top, and impact into a reviewable sequence.",
                "Cross-checking timing consistency before Garage promotes the checkpoint map.",
                "Packaging confidence signals so manual review can focus on the real outliers."
            ]
        case .savingSwing:
            [
                "Saving the analyzed swing now so Analyzer can open immediately.",
                "Detaching later export optimization from the review path.",
                "Promoting the review package while the derivative export drops in behind the scenes."
            ]
        }
    }
}

private enum GarageAnalyzerRoute: Equatable {
    case records
    case importing(GarageImportPresentationState)
    case review(recordKey: String?)

    var normalizedForPresentation: GarageAnalyzerRoute {
        switch self {
        case .importing(.idle):
            return .records
        case .records, .importing, .review:
            return self
        }
    }
}

private enum GarageRoute: Equatable {
    case hub
    case analyzer(GarageAnalyzerRoute)
    case drills
    case range

    var tab: ModuleHubTab {
        switch self {
        case .hub:
            return .hub
        case .analyzer:
            return .analyzer
        case .drills:
            return .drills
        case .range:
            return .range
        }
    }

    init(tab: ModuleHubTab) {
        switch tab {
        case .hub:
            self = .hub
        case .analyzer:
            self = .analyzer(.records)
        case .records:
            self = .analyzer(.records)
        case .review:
            self = .analyzer(.review(recordKey: nil))
        case .drills:
            self = .drills
        case .range:
            self = .range
        case .overview, .entries, .advisor, .builder:
            assertionFailure("Unsupported ModuleHubTab passed to GarageRoute.init(tab:): \(tab)")
            self = .hub
        @unknown default:
            assertionFailure("Unsupported ModuleHubTab passed to GarageRoute.init(tab:): \(tab)")
            self = .hub
        }
    }
}

struct GaragePreFlightSelection: Equatable {
    var clubType: String = "7 Iron"
    var isLeftHanded: Bool = false
    var cameraAngle: String = "Down the Line"
    var trimStartSeconds: Double = 0
    var trimEndSeconds: Double = 0
    var hasConfirmedTrimWindow = false
}

let garageLongClipTrimThreshold = 8.0
let garageDefaultTrimWindowDuration = 4.0
let garageMinimumTrimWindowDuration = 1.5
let garageMaximumTrimWindowDuration = 6.0

func garageRequiresManualTrim(for duration: Double) -> Bool {
    duration > garageLongClipTrimThreshold
}

func garageDefaultTrimWindow(for duration: Double) -> ClosedRange<Double> {
    let safeDuration = max(duration, 0)
    guard safeDuration > 0 else { return 0...0 }

    let preferredWindow = min(max(garageDefaultTrimWindowDuration, garageMinimumTrimWindowDuration), min(garageMaximumTrimWindowDuration, safeDuration))
    let midpoint = safeDuration / 2
    let start = max(min(midpoint - (preferredWindow / 2), safeDuration - preferredWindow), 0)
    let end = min(start + preferredWindow, safeDuration)
    return start...end
}

func garageNormalizedTrimWindow(start: Double, end: Double, duration: Double) -> ClosedRange<Double> {
    let safeDuration = max(duration, 0)
    guard safeDuration > 0 else { return 0...0 }

    let minimumWindow = min(garageMinimumTrimWindowDuration, safeDuration)
    let maximumWindow = min(garageMaximumTrimWindowDuration, safeDuration)

    var lowerBound = min(max(start, 0), safeDuration)
    var upperBound = min(max(end, 0), safeDuration)
    if upperBound < lowerBound {
        swap(&lowerBound, &upperBound)
    }

    var windowLength = upperBound - lowerBound
    if windowLength < minimumWindow {
        upperBound = min(lowerBound + minimumWindow, safeDuration)
        lowerBound = max(upperBound - minimumWindow, 0)
        windowLength = upperBound - lowerBound
    }

    if windowLength > maximumWindow {
        upperBound = min(lowerBound + maximumWindow, safeDuration)
        lowerBound = max(upperBound - maximumWindow, 0)
    }

    return lowerBound...upperBound
}

extension GaragePreFlightSelection {
    var trimDuration: Double {
        max(trimEndSeconds - trimStartSeconds, 0)
    }
}

func garageRecordSelectionKey(for record: SwingRecord) -> String {
    String(describing: record.persistentModelID)
}

func garageImportRetryErrorCode(from error: Error) -> Int? {
    let nsError = error as NSError

    if garageIsRetryableImportNSError(nsError) {
        return nsError.code
    }

    if let detailedErrors = nsError.userInfo["NSDetailedErrors"] as? [NSError] {
        for detailedError in detailedErrors {
            if let retryCode = garageImportRetryErrorCode(from: detailedError) {
                return retryCode
            }
        }
    }

    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
        return garageImportRetryErrorCode(from: underlyingError)
    }

    return nil
}

func garageShouldRetryImportAfterFailure(_ error: Error) -> Bool {
    garageImportRetryErrorCode(from: error) != nil
}

func garageImportFailureMessage(from error: Error) -> String {
    let nsError = error as NSError
    var diagnostics: [String] = []
    var currentError: NSError? = nsError

    while let error = currentError {
        var segment = "domain=\(error.domain) code=\(error.code) description=\(error.localizedDescription)"

        if let failureReason = error.localizedFailureReason, failureReason.isEmpty == false {
            segment += " reason=\(failureReason)"
        }

        if let recoverySuggestion = error.localizedRecoverySuggestion, recoverySuggestion.isEmpty == false {
            segment += " suggestion=\(recoverySuggestion)"
        }

        diagnostics.append(segment)
        currentError = error.userInfo[NSUnderlyingErrorKey] as? NSError
    }

    guard diagnostics.isEmpty == false else {
        return "Import failed: \(error.localizedDescription)"
    }

    return "Import failed: \(diagnostics.joined(separator: " | underlying: "))"
}

private func garageIsRetryableImportNSError(_ error: NSError) -> Bool {
    let domain = error.domain.lowercased()

    switch domain {
    case "com.apple.swiftdata":
        return error.code == -54
    case "nscocoaerrordomain":
        return [4097, 4099, 134110].contains(error.code)
    case "nssqliteerrordomain":
        return [5, 6].contains(error.code)
    case "nsposixerrordomain":
        return error.code == 16
    default:
        return false
    }
}

private func garageClubBadgeCode(for clubType: String) -> String {
    let trimmed = clubType.trimmingCharacters(in: .whitespacesAndNewlines)
    switch trimmed {
    case "Driver":
        return "DR"
    case "PW", "SW":
        return trimmed
    default:
        break
    }

    if let clubNumber = trimmed.split(separator: " ").first {
        if trimmed.contains("Wood") {
            return "\(clubNumber)W"
        }
        if trimmed.contains("Hybrid") {
            return "\(clubNumber)H"
        }
        if trimmed.contains("Iron") {
            return "\(clubNumber)I"
        }
    }

    return trimmed.uppercased()
}

struct GarageView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SwingRecord.createdAt, order: .reverse) private var swingRecords: [SwingRecord]
    @State private var isShowingAddRecord = false
    @State private var selectedVideoItem: PhotosPickerItem?
    @StateObject private var importCoordinator = GarageImportCoordinator()
    @State private var route: GarageRoute = .hub
    @State private var hasNormalizedPersistedAnalysisPayloads = false

    private var reviewableSwingRecords: [SwingRecord] {
        swingRecords.filter(\.isReviewableRecord)
    }

    private var analyzerVisibleSwingRecords: [SwingRecord] {
        swingRecords.filter(\.isAnalyzerVisible)
    }

    var body: some View {
        Group {
            if case .range = route {
                GarageCourseMapView(
                    bottomInset: 0,
                    onExit: {
                        route = .hub
                    }
                )
            } else {
                GarageCustomScaffold(module: .garage, tabs: [], selectedTab: .constant(.hub)) { size in
                    garageContent(for: size)
                }
            }
        }
        .overlay {
            if let importState = importPresentationState {
                GarageImportPresentationScreen(
                    state: importState,
                    onDismiss: dismissImportPresentation,
                    onRetry: retryImport
                )
            }
        }
        .photosPicker(
            isPresented: $isShowingAddRecord,
            selection: $selectedVideoItem,
            matching: .videos,
            preferredItemEncoding: .current
        )
        .onChange(of: selectedVideoItem) { _, newItem in
            guard let newItem else { return }
            selectedVideoItem = nil
            importCoordinator.prepareSelectedVideo(
                newItem,
                inferredSelection: inferredImportSelection(),
                modelContext: modelContext,
                navigation: importNavigation
            )
        }
        .onChange(of: reviewableSwingRecords.map(garageRecordSelectionKey)) { _, keys in
            handleReviewableRecordKeysChange(keys)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if importPresentationState == nil, route != .range {
                GarageBottomTabBar(selectedTab: selectedTabBinding)
            }
        }
        .task(id: swingRecords.count) {
            await recoverAndNormalizePersistedAnalysisPayloadsIfNeeded()
        }
        .toolbar({
            if route == .range {
                return .hidden
            }
            if case let .analyzer(analyzerRoute) = route,
               case .review = analyzerRoute.normalizedForPresentation {
                return .hidden
            }
            return .visible
        }(), for: .navigationBar)
    }

    private var selectedTabBinding: Binding<ModuleHubTab> {
        Binding(
            get: { route.tab },
            set: { newTab in
                if newTab == .analyzer, case let .analyzer(analyzerRoute) = route {
                    route = .analyzer(analyzerRoute.normalizedForPresentation)
                } else {
                    route = GarageRoute(tab: newTab)
                }
            }
        )
    }

    private var importNavigation: GarageImportNavigation {
        GarageImportNavigation(
            showAnalyzerRecords: {
                route = .analyzer(.records)
            },
            openReview: { reviewKey in
                hasNormalizedPersistedAnalysisPayloads = true
                route = .analyzer(.review(recordKey: reviewKey))
            },
            presentPicker: {
                route = .analyzer(.records)
                isShowingAddRecord = true
            },
            didMutatePersistence: {
                hasNormalizedPersistedAnalysisPayloads = true
            }
        )
    }

    private var importPresentationState: GarageImportPresentationState? {
        let state = importCoordinator.importPresentationState
        return state.isPresented ? state : nil
    }

    @MainActor
    private func handleReviewableRecordKeysChange(_ keys: [String]) {
        guard case let .analyzer(analyzerRoute) = route else { return }

        let recordKey: String?
        switch analyzerRoute.normalizedForPresentation {
        case let .review(candidateKey):
            recordKey = candidateKey
        default:
            return
        }

        if keys.isEmpty {
            route = .analyzer(.records)
            return
        }

        guard let recordKey else { return }
        guard keys.contains(recordKey) == false else { return }
        route = .analyzer(.review(recordKey: keys.first))
    }

    @MainActor
    private func recoverAndNormalizePersistedAnalysisPayloadsIfNeeded() async {
        guard hasNormalizedPersistedAnalysisPayloads == false else { return }
        let candidates = persistedSwingRecords()

        guard candidates.isEmpty == false else {
            hasNormalizedPersistedAnalysisPayloads = true
            return
        }

        var didTouchPayload = false
        for record in candidates {
            if record.reconcileStrandedImportIfNeeded(
                isActiveImportRecord: importCoordinator.activeImportRecordID == record.persistentModelID
            ) {
                didTouchPayload = true
                NSLog(
                    "%@",
                    "Garage import reconciliation preserved stranded record. recordID=\(String(describing: record.persistentModelID)) title=\(record.title) reason=import_failed"
                )
                continue
            }

            guard record.isReviewableRecord else {
                continue
            }

            if record.decodedDerivedPayload != nil {
                continue
            }

            if let legacyPayload = record.legacyDerivedPayloadFallback {
                record.persistDerivedPayload(legacyPayload)
                didTouchPayload = true
                if record.repairReason != nil {
                    NSLog(
                        "%@",
                        "Garage repair resolved. recordID=\(String(describing: record.persistentModelID)) title=\(record.title) reason=legacy_payload_migrated"
                    )
                }
                continue
            }

            if record.hasLegacyDerivedContent || record.derivedPayloadData != nil {
                let reason: GarageRepairReason = record.hasLegacyDerivedContent ? .legacyReviewPayload : .corruptedDerivedPayload
                if record.repairReason != reason {
                    record.clearDerivedPayload(repairReason: reason)
                    didTouchPayload = true
                }
                NSLog(
                    "%@",
                    "Garage recovery quarantined derived payload. recordID=\(String(describing: record.persistentModelID)) title=\(record.title) reason=\(reason.rawValue)"
                )
            }
        }

        guard didTouchPayload else {
            hasNormalizedPersistedAnalysisPayloads = true
            return
        }

        do {
            try modelContext.save()
            hasNormalizedPersistedAnalysisPayloads = true
        } catch {
            let nsError = error as NSError
            NSLog(
                "%@",
                "Garage analysis normalization save failed. domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
            )
            hasNormalizedPersistedAnalysisPayloads = false
        }
    }

    @MainActor
    private func persistedSwingRecords() -> [SwingRecord] {
        let descriptor = FetchDescriptor<SwingRecord>(
            sortBy: [SortDescriptor(\SwingRecord.createdAt, order: .reverse)]
        )

        return (try? modelContext.fetch(descriptor)) ?? swingRecords
    }

    @ViewBuilder
    private func garageContent(for size: CGSize) -> some View {
        switch route {
        case .hub:
            garageHubContent
        case let .analyzer(analyzerRoute):
            garageAnalyzerContent(for: analyzerRoute.normalizedForPresentation, size: size)
        case .drills:
            GaragePendingSurface(
                title: "Drills",
                message: "Drills is planned for Phase 2. Command Center and Analyzer are active in this pass."
            )
        case .range:
            GarageCourseMapView(
                bottomInset: 78,
                onExit: {
                    route = .hub
                }
            )
        }
    }

    private var garageHubContent: some View {
        GarageCommandCenterView(
            records: reviewableSwingRecords,
            openCourseMap: {
                route = .range
            }
        )
    }

    @ViewBuilder
    private func garageAnalyzerContent(for analyzerRoute: GarageAnalyzerRoute, size: CGSize) -> some View {
        switch analyzerRoute {
        case .records, .importing:
            GarageRecordsTab(
                records: analyzerVisibleSwingRecords,
                importVideo: {
                    presentAddRecord()
                },
                openReview: { record in
                    if record.isRecoverableFailedImport {
                        importCoordinator.repairRecord(
                            record,
                            modelContext: modelContext,
                            navigation: importNavigation
                        )
                    } else {
                        route = .analyzer(.review(recordKey: garageRecordSelectionKey(for: record)))
                    }
                }
            )
            .safeAreaInset(edge: .bottom) {
                ModuleBottomActionBar(
                    theme: AppModule.garage.theme,
                    title: "Add Swing Record",
                    systemImage: "plus"
                ) {
                    presentAddRecord()
                }
                .padding(.bottom, 70)
            }
        case let .review(recordKey):
            GarageReviewTab(
                records: reviewableSwingRecords,
                selectedRecordKey: Binding(
                    get: { recordKey },
                    set: { newKey in
                        route = .analyzer(.review(recordKey: newKey))
                    }
                ),
                viewportHeight: size.height,
                onRequestReanalysis: { record in
                    importCoordinator.repairRecord(
                        record,
                        modelContext: modelContext,
                        navigation: importNavigation
                    )
                },
                onBackToRecords: {
                    route = .analyzer(.records)
                }
            )
        }
    }

    private func presentAddRecord() {
        isShowingAddRecord = true
    }

    private func dismissImportPresentation() {
        selectedVideoItem = nil
        importCoordinator.dismissImportPresentation(navigation: importNavigation)
    }

    @MainActor
    private func retryImport() {
        importCoordinator.retryImport(
            modelContext: modelContext,
            navigation: importNavigation
        )
    }

    @MainActor
    private func inferredImportSelection() -> GaragePreFlightSelection {
        if let latestRecord = swingRecords.first {
            return GaragePreFlightSelection(
                clubType: latestRecord.resolvedClubType,
                isLeftHanded: latestRecord.resolvedIsLeftHanded,
                cameraAngle: latestRecord.resolvedCameraAngle
            )
        }

        return GaragePreFlightSelection()
    }
}

private struct GarageBottomTabBar: View {
    @Binding var selectedTab: ModuleHubTab

    private let tabs: [(tab: ModuleHubTab, icon: String)] = [
        (.hub, "gauge.with.dots.needle.100percent"),
        (.analyzer, "waveform.path.ecg.rectangle"),
        (.drills, "figure.golf"),
        (.range, "map")
    ]

    private var totalBarHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        return min(max(screenHeight * 0.065, 58), 74)
    }

    private var bottomContentPadding: CGFloat {
        1
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(tabs, id: \.tab) { item in
                    bottomBarItem(for: item)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, bottomContentPadding)
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalBarHeight, alignment: .bottom)
        .background(
            Rectangle()
                .fill(ModuleTheme.garageCanvas.opacity(0.985))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func bottomBarItem(for item: (tab: ModuleHubTab, icon: String)) -> some View {
        let isSelected = selectedTab == item.tab

        return Button {
            selectedTab = item.tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: item.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? garageReviewAccent : AppModule.garage.theme.textSecondary.opacity(0.84))
                    .shadow(color: isSelected ? garageReviewAccent.opacity(0.45) : .clear, radius: 10, x: 0, y: 0)

                Text(item.tab.rawValue)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? AppModule.garage.theme.textPrimary : AppModule.garage.theme.textSecondary.opacity(0.8))

                Capsule()
                    .fill(isSelected ? garageReviewAccent : .clear)
                    .frame(width: 24, height: 2.5)
                    .shadow(color: isSelected ? garageReviewAccent.opacity(0.5) : .clear, radius: 8, x: 0, y: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct GaragePendingSurface: View {
    let title: String
    let message: String

    var body: some View {
        ModuleRowSurface(theme: AppModule.garage.theme) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppModule.garage.theme.textPrimary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
        }
        .padding(.bottom, 90)
    }
}

private struct GarageRecordsTab: View {
    let records: [SwingRecord]
    let importVideo: () -> Void
    let openReview: (SwingRecord) -> Void

    var body: some View {
        ModuleActivityFeedSection(title: "Swing Records") {
            if records.isEmpty {
                GarageEmptyStateView(action: importVideo)
            } else {
                ModuleRowSurface(theme: AppModule.garage.theme) {
                    Text("Capture")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    Text("Import another swing video whenever you want to start a new review pass.")
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                    Button(action: importVideo) {
                        Label("Import Swing Video", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(garageReviewCanvasFill)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(
                                GarageRaisedPanelBackground(
                                    shape: Capsule(),
                                    fill: garageReviewAccent,
                                    stroke: garageReviewAccent.opacity(0.35),
                                    glow: garageReviewAccent
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(records.prefix(8)) { record in
                    SwingRecordCard(record: record) {
                        openReview(record)
                    }
                }
            }
        }
    }
}

private struct SwingRecordCard: View {
    let record: SwingRecord
    let openReview: () -> Void

    private var statusTitle: String? {
        record.isRecoverableFailedImport ? "IMPORT FAILED" : nil
    }

    private var statusTint: Color {
        record.isRecoverableFailedImport ? garageReviewFlagged : ModuleTheme.electricCyan
    }

    private var detailCopy: String {
        if record.isRecoverableFailedImport {
            return "Import stopped before review was ready. The review master is still local and ready to retry."
        }

        let trimmedNotes = record.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNotes.isEmpty ? "Telemetry ready for review routing." : trimmedNotes
    }

    private var trailingSymbol: String {
        record.isRecoverableFailedImport ? "arrow.clockwise" : "chevron.right"
    }

    var body: some View {
        Button(action: openReview) {
            HStack(spacing: 14) {
                GarageRecordStripThumbnail(record: record)

                VStack(alignment: .leading, spacing: 8) {
                    Text(record.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("CLUB: \(garageClubBadgeCode(for: record.resolvedClubType))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(ModuleTheme.electricCyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(ModuleTheme.garageSurfaceInset)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(ModuleTheme.electricCyan.opacity(0.34), lineWidth: 0.5)
                                    )
                            )

                        Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppModule.garage.theme.textMuted)
                            .lineLimit(1)

                        if let statusTitle {
                            Text(statusTitle)
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1.3)
                                .foregroundStyle(statusTint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(garageReviewSurfaceDark)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(statusTint.opacity(0.3), lineWidth: 0.5)
                                        )
                                )
                        }
                    }

                    Text(detailCopy)
                        .font(.footnote)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    GarageMiniScoreGauge(score: record.derivedAnalysisResult?.scorecard?.totalScore)

                    Image(systemName: trailingSymbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(record.isRecoverableFailedImport ? statusTint : AppModule.garage.theme.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ModuleTheme.garageSurfaceDark.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ModuleTheme.electricCyan.opacity(0.24), lineWidth: 0.5)
                )
        )
    }
}

private struct GarageRecordStripThumbnail: View {
    let record: SwingRecord

    @State private var image: CGImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ModuleTheme.garageSurfaceInset)

            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 74, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.caption.weight(.bold))
                    Text(garageClubBadgeCode(for: record.resolvedClubType))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                }
                .foregroundStyle(AppModule.garage.theme.textMuted)
            }
        }
        .frame(width: 74, height: 56)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .task(id: thumbnailRequestKey) {
            await loadThumbnail()
        }
    }

    private var thumbnailRequestKey: String {
        [
            garageRecordSelectionKey(for: record),
            String(format: "%.4f", preferredThumbnailTimestamp)
        ].joined(separator: "::")
    }

    private var preferredThumbnailTimestamp: Double {
        let keyFrames = record.derivedKeyFrames
        let swingFrames = record.derivedSwingFrames

        if let impactIndex = keyFrames.first(where: { $0.phase == .impact })?.frameIndex,
           swingFrames.indices.contains(impactIndex) {
            return swingFrames[impactIndex].timestamp
        }

        if swingFrames.isEmpty == false {
            return swingFrames[swingFrames.count / 2].timestamp
        }

        return 0
    }

    private func loadThumbnail() async {
        guard let videoURL = GarageMediaStore.resolvedReviewVideoURL(for: record) else {
            await MainActor.run {
                image = nil
            }
            return
        }

        let thumbnail = await GarageMediaStore.thumbnail(
            for: videoURL,
            at: preferredThumbnailTimestamp,
            maximumSize: CGSize(width: 200, height: 140),
            priority: .low
        )

        guard Task.isCancelled == false else { return }

        await MainActor.run {
            image = thumbnail
        }
    }
}

private struct GarageMiniScoreGauge: View {
    let score: Int?

    private var resolvedScore: Int {
        min(max(score ?? 0, 0), 100)
    }

    private var progress: Double {
        Double(resolvedScore) / 100
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ModuleTheme.garageTrack, lineWidth: 5)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [ModuleTheme.electricCyan, Color(hex: "#1AD0C8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(ModuleTheme.garageSurfaceInset)
                .padding(8)

            Text(score.map(String.init) ?? "--")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
        }
        .frame(width: 52, height: 52)
    }
}

private struct GarageReviewTab: View {
    let records: [SwingRecord]
    @Binding var selectedRecordKey: String?
    let viewportHeight: CGFloat
    let onRequestReanalysis: (SwingRecord) -> Void
    let onBackToRecords: () -> Void

    private var selectedRecord: SwingRecord? {
        if let selectedRecordKey {
            return records.first(where: { garageRecordSelectionKey(for: $0) == selectedRecordKey }) ?? records.first
        }

        return records.first
    }

    var body: some View {
        Group {
            if let selectedRecord {
                switch selectedRecord.reviewAvailability {
                case .ready:
                    GarageFocusedReviewWorkspace(
                        record: selectedRecord,
                        viewportHeight: viewportHeight,
                        onExitReview: onBackToRecords
                    )
                case .needsReanalysis:
                    GarageRepairSurface(
                        record: selectedRecord,
                        onReanalyze: {
                            onRequestReanalysis(selectedRecord)
                        },
                        onBackToRecords: onBackToRecords
                    )
                case .missingVideo:
                    GarageAnalysisUnavailablePanel(
                        title: "Review Media Missing",
                        message: "This swing still exists, but the saved review video is gone. Re-import the clip to restore the premium review flow.",
                        actionTitle: "Back To Records",
                        action: onBackToRecords
                    )
                case .unavailable:
                    GarageAnalysisUnavailablePanel(
                        title: "Analysis Unavailable",
                        message: "Garage quarantined unstable derived review data for this record so the app can stay up. Re-run analysis to rebuild the review package.",
                        actionTitle: "Re-analyze Swing",
                        action: {
                            onRequestReanalysis(selectedRecord)
                        }
                    )
                }
            } else {
                ModuleEmptyStateCard(
                    theme: AppModule.garage.theme,
                    title: "Review workflow is ready",
                    message: "Import a swing video from Overview or Records to begin checkpoint review.",
                    actionTitle: "Go To Records",
                    action: onBackToRecords
                )
            }
        }
        .onAppear(perform: syncSelection)
        .onChange(of: records.map(garageRecordSelectionKey)) { _, _ in
            syncSelection()
        }
    }

    private func syncSelection() {
        guard records.isEmpty == false else {
            selectedRecordKey = nil
            return
        }

        if let selectedRecordKey,
           records.contains(where: { garageRecordSelectionKey(for: $0) == selectedRecordKey }) {
            return
        }

        selectedRecordKey = records.first.map(garageRecordSelectionKey)
    }
}

private struct GarageRepairSurface: View {
    let record: SwingRecord
    let onReanalyze: () -> Void
    let onBackToRecords: () -> Void

    private var title: String {
        switch record.repairReason {
        case .importFailed?:
            "Import Recovery Ready"
        default:
            "Swing Recovery Ready"
        }
    }

    private var message: String {
        switch record.repairReason {
        case .importFailed?:
            "Garage preserved this import and its saved review master locally, but the analysis pipeline stopped before the review package was finalized. Retry the saved clip to finish the record without re-importing."
        default:
            "Garage preserved this record and its video, but the old derived review payload is no longer trusted. Re-run analysis to rebuild scorecards, SyncFlow, and checkpoint telemetry safely."
        }
    }

    private var actionTitle: String {
        switch record.repairReason {
        case .importFailed?:
            "Retry Import"
        default:
            "Re-analyze Swing"
        }
    }

    var body: some View {
        GarageAnalysisUnavailablePanel(
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: onReanalyze,
            secondaryTitle: "Back To Records",
            secondaryAction: onBackToRecords,
            diagnostics: record.repairReason?.rawValue
        )
    }
}

private struct GarageAnalysisUnavailablePanel: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
    var diagnostics: String? = nil

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 18) {
                Text("GARAGE RECOVERY")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(ModuleTheme.electricCyan.opacity(0.84))

                Text(title)
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white)

                Text(message)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let diagnostics, diagnostics.isEmpty == false {
                    Text("Diagnostics: \(diagnostics)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                }

                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(
                            GarageRaisedPanelBackground(
                                shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                                fill: ModuleTheme.garageSurface.opacity(0.98),
                                stroke: ModuleTheme.electricCyan.opacity(0.55),
                                glow: ModuleTheme.electricCyan
                            )
                        )
                }
                .buttonStyle(.plain)

                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle, action: secondaryAction)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            GarageInsetPanelBackground(
                                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                fill: garageReviewSurfaceDark,
                                stroke: Color.white.opacity(0.08)
                            )
                        )
                        .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(
                GarageRaisedPanelBackground(
                    shape: RoundedRectangle(cornerRadius: 30, style: .continuous),
                    fill: garageReviewSurfaceDark.opacity(0.98),
                    stroke: ModuleTheme.electricCyan.opacity(0.24),
                    glow: ModuleTheme.electricCyan
                )
            )
            .padding(.horizontal, ModuleSpacing.large)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(garageReviewBackground.ignoresSafeArea())
    }
}

private struct GarageEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.garage.theme,
            title: "No swing records yet",
            message: "Select a swing video from Photos to begin a cleaner review workflow.",
            actionTitle: "Select First Video",
            action: action
        )
    }
}

func garageSuggestedRecordTitle(for filename: String, fallbackURL: URL) -> String {
    let preferredName = filename.isEmpty ? fallbackURL.lastPathComponent : filename
    let stem = URL(filePath: preferredName).deletingPathExtension().lastPathComponent
        .replacingOccurrences(of: "_", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    if stem.isEmpty == false {
        return stem
    }

    return "Swing \(Date.now.formatted(date: .abbreviated, time: .shortened))"
}

private struct GaragePreFlightSheet: View {
    @Binding var isPresented: Bool
    let movie: GaragePickedMovie
    let initialSelection: GaragePreFlightSelection
    let onClose: () -> Void
    let onStartAnalysis: (GaragePreFlightSelection) -> Void

    @StateObject private var playbackController: GarageSlowMotionPlaybackController
    @State private var selection: GaragePreFlightSelection
    @State private var videoDuration = 0.0
    @State private var videoFrameRate = 0.0
    @State private var naturalSize = CGSize.zero

    private let clubOptions = [
        "Driver", "3 Wood", "5 Wood",
        "3 Hybrid", "4 Hybrid", "5 Hybrid",
        "4 Iron", "5 Iron", "6 Iron",
        "7 Iron", "8 Iron", "9 Iron",
        "PW", "SW"
    ]
    private let cameraOptions = ["Down the Line", "Face On"]
    private let handednessOptions: [(label: String, value: Bool)] = [("Righty", false), ("Lefty", true)]
    private let clubColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    init(
        isPresented: Binding<Bool>,
        movie: GaragePickedMovie,
        initialSelection: GaragePreFlightSelection,
        onClose: @escaping () -> Void,
        onStartAnalysis: @escaping (GaragePreFlightSelection) -> Void
    ) {
        _isPresented = isPresented
        self.movie = movie
        self.initialSelection = initialSelection
        self.onClose = onClose
        self.onStartAnalysis = onStartAnalysis
        _selection = State(initialValue: initialSelection)
        _playbackController = StateObject(wrappedValue: GarageSlowMotionPlaybackController(url: movie.url))
    }

    private var requiresManualTrim: Bool {
        garageRequiresManualTrim(for: videoDuration)
    }

    private var trimWindow: ClosedRange<Double> {
        garageNormalizedTrimWindow(
            start: selection.trimStartSeconds,
            end: selection.trimEndSeconds,
            duration: videoDuration
        )
    }

    private var canStartAnalysis: Bool {
        requiresManualTrim == false || selection.hasConfirmedTrimWindow
    }

    var body: some View {
        Color.clear
            .garageModal(
                isPresented: $isPresented,
                title: "Pre-Flight Setup"
            ) {
                ZStack {
                    Color.vibeBackground
                        .overlay(
                            RadialGradient(
                                colors: [
                                    ModuleTheme.electricCyan.opacity(0.16),
                                    Color.clear
                                ],
                                center: .top,
                                startRadius: 40,
                                endRadius: 360
                            )
                        )
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: ModuleSpacing.large) {
                            headerCard
                            previewCard
                            handednessCard
                            clubGridCard
                            cameraAngleCard
                        }
                        .padding(ModuleSpacing.large)
                        .padding(.bottom, ModuleSpacing.large)
                    }
                }
            } bottomDock: {
                GarageDockSurface {
                    HStack(spacing: 12) {
                        GarageDockWideButton(
                            title: "Close",
                            systemImage: "xmark",
                            isPrimary: false,
                            isEnabled: true,
                            action: {
                                isPresented = false
                                onClose()
                            }
                        )

                        GarageDockWideButton(
                            title: "Start AI Analysis",
                            systemImage: "play.fill",
                            isPrimary: true,
                            isEnabled: canStartAnalysis,
                            action: {
                                selection.trimStartSeconds = trimWindow.lowerBound
                                selection.trimEndSeconds = trimWindow.upperBound
                                onStartAnalysis(selection)
                            }
                        )
                    }
                }
            }
        .task {
            await loadMetadata()
        }
        .onDisappear {
            playbackController.stop()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FULL BAG CALIBRATION")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(ModuleTheme.electricCyan.opacity(0.82))

            Text("Pre-Flight Setup")
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(requiresManualTrim
                 ? "Select the swing window before analysis starts. Long clips now require an exact trim so Garage analyzes the real motion instead of guessing."
                 : "Dial in the exact club, handedness, and capture angle before the AI starts the heavy pass.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: 30, style: .continuous),
                fill: .vibeSurface,
                stroke: ModuleTheme.electricCyan.opacity(0.24),
                glow: ModuleTheme.electricCyan
            )
        )
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Master Preview")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            ZStack(alignment: .bottomTrailing) {
                GarageSlowMotionPlayerView(player: playbackController.player)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )

                if requiresManualTrim {
                    Text("TRIM REQUIRED")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(ModuleTheme.electricCyan.opacity(0.18))
                                .overlay(
                                    Capsule()
                                        .stroke(ModuleTheme.electricCyan.opacity(0.46), lineWidth: 0.5)
                                )
                        )
                        .padding(12)
                }
            }

            HStack(spacing: 12) {
                telemetryChip(title: "FILE", value: movie.displayName)
                telemetryChip(title: "DURATION", value: garageTrimLabel(for: videoDuration))
            }

            HStack(spacing: 12) {
                telemetryChip(title: "FPS", value: videoFrameRate > 0 ? String(format: "%.1f", videoFrameRate) : "--")
                telemetryChip(title: "SIZE", value: naturalSize.width > 0 ? "\(Int(naturalSize.width))×\(Int(naturalSize.height))" : "--")
            }

            HStack(spacing: 12) {
                Button {
                    playbackController.togglePlayback()
                } label: {
                    Label(playbackController.isPlaying ? "Pause" : "Preview", systemImage: playbackController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(
                            GarageInsetPanelBackground(
                                shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                                fill: .vibeSurface,
                                stroke: Color.white.opacity(0.08)
                            )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    playbackController.seek(trimWindow.lowerBound)
                } label: {
                    Label("Jump To Start", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(
                            GarageInsetPanelBackground(
                                shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                                fill: .vibeBackground,
                                stroke: Color.white.opacity(0.08)
                            )
                        )
                }
                .buttonStyle(.plain)
            }

            if requiresManualTrim {
                manualTrimCard
            }
        }
        .padding(22)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: 30, style: .continuous),
                fill: .vibeSurface,
                stroke: ModuleTheme.electricCyan.opacity(0.24),
                glow: ModuleTheme.electricCyan
            )
        )
    }

    private var manualTrimCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Swing Window")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.white)

            Text("Select the swing window before analysis starts.")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(ModuleTheme.electricCyan.opacity(0.92))

            HStack(spacing: 12) {
                telemetryChip(title: "START", value: garageTrimLabel(for: trimWindow.lowerBound))
                telemetryChip(title: "END", value: garageTrimLabel(for: trimWindow.upperBound))
                telemetryChip(title: "WINDOW", value: garageTrimLabel(for: trimWindow.upperBound - trimWindow.lowerBound))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Trim Start")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppModule.garage.theme.textMuted)

                Slider(
                    value: Binding(
                        get: { trimWindow.lowerBound },
                        set: { updateTrimStart($0) }
                    ),
                    in: 0...max(videoDuration - garageMinimumTrimWindowDuration, 0)
                )
                .tint(ModuleTheme.electricCyan)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Trim End")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppModule.garage.theme.textMuted)

                Slider(
                    value: Binding(
                        get: { trimWindow.upperBound },
                        set: { updateTrimEnd($0) }
                    ),
                    in: garageMinimumTrimWindowDuration...max(videoDuration, garageMinimumTrimWindowDuration)
                )
                .tint(Color(hex: "#1AD0C8"))
            }

            Button {
                selection.trimStartSeconds = trimWindow.lowerBound
                selection.trimEndSeconds = trimWindow.upperBound
                selection.hasConfirmedTrimWindow = true
                playbackController.seek(trimWindow.lowerBound)
            } label: {
                Text(selection.hasConfirmedTrimWindow ? "Trim Confirmed" : "Confirm Swing Window")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        GarageRaisedPanelBackground(
                            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                            fill: ModuleTheme.garageSurface.opacity(0.98),
                            stroke: ModuleTheme.electricCyan.opacity(0.48),
                            glow: ModuleTheme.electricCyan
                        )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            GarageInsetPanelBackground(
                shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
                fill: .vibeBackground,
                stroke: Color.white.opacity(0.07)
            )
        )
    }

    private var handednessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Handedness")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            HStack(spacing: 10) {
                ForEach(handednessOptions, id: \.label) { option in
                    preflightRowButton(
                        title: option.label,
                        isSelected: selection.isLeftHanded == option.value,
                        shape: Capsule()
                    ) {
                        selection.isLeftHanded = option.value
                    }
                }
            }
        }
        .padding(20)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
                fill: .vibeSurface,
                stroke: Color.white.opacity(0.07)
            )
        )
    }

    private var clubGridCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Club Grid")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            Text("All 14 clubs, centered for a full-bag intake.")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.white)

            LazyVGrid(columns: clubColumns, spacing: 9) {
                ForEach(clubOptions, id: \.self) { club in
                    Button {
                        selection.clubType = club
                    } label: {
                        Text(club)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(selection.clubType == club ? ModuleTheme.electricCyan : AppModule.garage.theme.textPrimary.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .padding(.horizontal, 10)
                            .background(
                                GarageInsetPanelBackground(
                                    shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                    fill: selection.clubType == club ? .vibeSurface : .vibeBackground,
                                    stroke: selection.clubType == club ? ModuleTheme.electricCyan.opacity(0.42) : Color.white.opacity(0.08)
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(
                                        selection.clubType == club ? ModuleTheme.electricCyan.opacity(0.72) : Color.clear,
                                        lineWidth: 0.5
                                    )
                            )
                            .shadow(
                                color: selection.clubType == club ? ModuleTheme.electricCyan.opacity(0.24) : .clear,
                                radius: selection.clubType == club ? 10 : 0,
                                x: 0,
                                y: 0
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(22)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: 30, style: .continuous),
                fill: .vibeSurface,
                stroke: ModuleTheme.electricCyan.opacity(0.24),
                glow: ModuleTheme.electricCyan
            )
        )
    }

    private var cameraAngleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Angle")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            HStack(spacing: 10) {
                ForEach(cameraOptions, id: \.self) { option in
                    preflightRowButton(
                        title: option,
                        isSelected: selection.cameraAngle == option,
                        shape: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    ) {
                        selection.cameraAngle = option
                    }
                }
            }
        }
        .padding(20)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
                fill: .vibeSurface,
                stroke: Color.white.opacity(0.07)
            )
        )
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(canStartAnalysis
                 ? "The robot stays idle until you tap start."
                 : "Long clip selected. Confirm the swing window to unlock the AI run.")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(ModuleTheme.electricCyan.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                selection.trimStartSeconds = trimWindow.lowerBound
                selection.trimEndSeconds = trimWindow.upperBound
                onStartAnalysis(selection)
            } label: {
                Text("Start AI Analysis")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .padding(.horizontal, 18)
                    .background(
                        GarageRaisedPanelBackground(
                            shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
                            fill: canStartAnalysis ? ModuleTheme.garageSurface.opacity(0.98) : ModuleTheme.garageSurfaceInset.opacity(0.86),
                            stroke: canStartAnalysis ? ModuleTheme.electricCyan.opacity(0.55) : Color.white.opacity(0.12),
                            glow: canStartAnalysis ? ModuleTheme.electricCyan : Color.clear
                        )
                    )
                    .opacity(canStartAnalysis ? 1 : 0.62)
            }
            .buttonStyle(.plain)
            .disabled(canStartAnalysis == false)
        }
        .padding(22)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: 30, style: .continuous),
                fill: .vibeSurface,
                stroke: ModuleTheme.electricCyan.opacity(0.26),
                glow: ModuleTheme.electricCyan
            )
        )
    }

    private func loadMetadata() async {
        selection = initialSelection
        guard let metadata = await GarageMediaStore.assetMetadata(for: movie.url) else { return }
        videoDuration = metadata.duration
        videoFrameRate = metadata.frameRate
        naturalSize = metadata.naturalSize
        playbackController.updateDurationFromMetadata(metadata.duration)

        if requiresManualTrim {
            let defaultWindow = garageDefaultTrimWindow(for: metadata.duration)
            selection.trimStartSeconds = defaultWindow.lowerBound
            selection.trimEndSeconds = defaultWindow.upperBound
            selection.hasConfirmedTrimWindow = false
            playbackController.seek(defaultWindow.lowerBound)
        } else {
            selection.trimStartSeconds = 0
            selection.trimEndSeconds = metadata.duration
            selection.hasConfirmedTrimWindow = true
        }
    }

    private func updateTrimStart(_ value: Double) {
        let normalized = garageNormalizedTrimWindow(start: value, end: trimWindow.upperBound, duration: videoDuration)
        selection.trimStartSeconds = normalized.lowerBound
        selection.trimEndSeconds = normalized.upperBound
        selection.hasConfirmedTrimWindow = false
        playbackController.seek(normalized.lowerBound)
    }

    private func updateTrimEnd(_ value: Double) {
        let normalized = garageNormalizedTrimWindow(start: trimWindow.lowerBound, end: value, duration: videoDuration)
        selection.trimStartSeconds = normalized.lowerBound
        selection.trimEndSeconds = normalized.upperBound
        selection.hasConfirmedTrimWindow = false
    }

    private func garageTrimLabel(for seconds: Double) -> String {
        guard seconds.isFinite else { return "--" }
        return String(format: "%.2fs", max(seconds, 0))
    }
    private func telemetryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppModule.garage.theme.textMuted)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            GarageInsetPanelBackground(
                shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                fill: .vibeBackground,
                stroke: Color.white.opacity(0.08)
            )
        )
    }

    private func preflightRowButton<S: Shape>(
        title: String,
        isSelected: Bool,
        shape: S,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? ModuleTheme.electricCyan : Color.white.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 10)
                .background(
                    GarageInsetPanelBackground(
                        shape: shape,
                        fill: isSelected ? .vibeSurface : .vibeBackground,
                        stroke: isSelected ? ModuleTheme.electricCyan.opacity(0.4) : Color.white.opacity(0.08)
                    )
                )
                .overlay(
                    shape
                        .stroke(
                            isSelected ? ModuleTheme.electricCyan.opacity(0.7) : Color.clear,
                            lineWidth: 0.5
                        )
                )
                .shadow(
                    color: isSelected ? ModuleTheme.electricCyan.opacity(0.22) : .clear,
                    radius: isSelected ? 10 : 0,
                    x: 0,
                    y: 0
                )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageImportPresentationScreen: View {
    let state: GarageImportPresentationState
    let onDismiss: () -> Void
    let onRetry: () -> Void
    @State private var currentTipIndex = 0
    @State private var isGlowExpanded = false
    @State private var isTelemetryBreathing = false
    @State private var telemetrySweepProgress = 0.0
    @State private var completedImpactMilestones: Set<Int> = []
    @State private var emittedSuccessHaptic = false

    private let tipRotationTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            garageReviewSurfaceDark
                .overlay(
                    GarageTelemetryGridBackground()
                        .opacity(0.42)
                )
                .ignoresSafeArea()

            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Text("GARAGE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(ModuleTheme.electricCyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(ModuleTheme.electricCyan.opacity(0.08))
                                .overlay(
                                    Capsule()
                                        .stroke(ModuleTheme.electricCyan.opacity(0.24), lineWidth: 0.5)
                                )
                        )

                    Text(state.headline)
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    Text(state.detail)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                if state.showsProgress {
                    ZStack {
                        GarageGaugeTickMarks(
                            tickCount: 60,
                            radius: 88,
                            accent: ModuleTheme.electricCyan
                        )

                        Circle()
                            .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 4, dash: [4, 6]))
                            .frame(width: 148, height: 148)

                        Circle()
                            .trim(from: 0, to: max(progressFraction, 0.035))
                            .stroke(
                                ModuleTheme.electricCyan.opacity(isGlowExpanded ? 0.14 : 0.08),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round, dash: [4, 6])
                            )
                            .frame(width: 148, height: 148)
                            .rotationEffect(.degrees(-90))
                            .blur(radius: isGlowExpanded ? 9 : 6)
                            .scaleEffect(isGlowExpanded ? 1.018 : 0.994)
                            .opacity(state.showsProgress ? 1 : 0)

                        Circle()
                            .trim(from: 0, to: max(progressFraction, 0.035))
                            .stroke(
                                LinearGradient(
                                    colors: [garageReviewAccent.opacity(0.86), ModuleTheme.electricCyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [4, 6])
                            )
                            .frame(width: 148, height: 148)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: ModuleTheme.electricCyan.opacity(isGlowExpanded ? 0.18 : 0.1), radius: 8, x: 0, y: 0)

                        Circle()
                            .trim(from: 0, to: max(progressFraction * 0.82, 0.025))
                            .stroke(
                                ModuleTheme.electricCyan.opacity(isTelemetryBreathing ? 0.12 : 0.06),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [2, 6])
                            )
                            .frame(width: 132, height: 132)
                            .rotationEffect(.degrees(-90))
                            .blur(radius: 2)

                        Circle()
                            .fill(garageReviewSurfaceDark.opacity(0.94))
                            .frame(width: 112, height: 112)

                        VStack(spacing: 6) {
                            Text(state.activeStepTitle?.uppercased() ?? state.telemetryLabel)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                                .foregroundStyle(ModuleTheme.electricCyan.opacity(0.88))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text("\(progressPercent)%")
                                .font(.system(size: 34, weight: .black, design: .monospaced))
                                .foregroundStyle(AppModule.garage.theme.textPrimary)
                                .contentTransition(.numericText())

                            Text(state.frameProgressLabel ?? "LINKED TO REVIEW MASTER")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(ModuleTheme.electricCyan.opacity(0.92))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .contentTransition(.numericText())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Text(state.showsProgress ? "AI ANALYSIS ACTIVE" : "IMPORT STATUS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(AppModule.garage.theme.textMuted.opacity(0.86))

                        Spacer(minLength: 0)

                        GarageImportSignalBars(
                            isActive: state.showsProgress,
                            isExpanded: isTelemetryBreathing
                        )
                    }

                    GarageImportTelemetryStrip(
                        label: state.telemetryLabel,
                        statusLine: state.liveStatusLine,
                        progressFraction: progressFraction,
                        sweepProgress: telemetrySweepProgress,
                        isActive: state.showsProgress
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .leading) {
                            if state.showsProgress {
                                Text(activeAnalysisTip)
                                    .id("\(state.tipRotationKey)-\(currentTipIndex)")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                                    .transition(
                                        .asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                                            removal: .opacity.combined(with: .move(edge: .top))
                                        )
                                    )
                            } else {
                                Text(state.detail)
                                    .font(.system(size: 15, weight: .semibold, design: .default))
                                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                                    .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.45), value: currentTipIndex)
                        .animation(.easeInOut(duration: 0.25), value: state.showsProgress)

                        if let frameLabel = state.frameProgressLabel, state.showsProgress {
                            Text(frameLabel)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(ModuleTheme.electricCyan.opacity(0.92))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(garageReviewInsetSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(ModuleTheme.electricCyan.opacity(0.22), lineWidth: 0.5)
                        )
                )

                if case .failure = state {
                    HStack(spacing: 12) {
                        Button(action: onDismiss) {
                            Text("Dismiss")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(garageReviewReadableText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                                .background(
                                    GarageRaisedPanelBackground(
                                        shape: Capsule(),
                                        fill: garageReviewSurfaceRaised
                                    )
                                )
                        }
                        .buttonStyle(.plain)

                        Button(action: onRetry) {
                            Text("Try Again")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(garageReviewCanvasFill)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                                .background(
                                    GarageRaisedPanelBackground(
                                        shape: Capsule(),
                                        fill: garageReviewAccent,
                                        stroke: garageReviewAccent.opacity(0.35),
                                        glow: garageReviewAccent
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: 360)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(garageReviewSurfaceDark.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(ModuleTheme.electricCyan.opacity(0.24), lineWidth: 0.5)
                    )
            )
            .padding(ModuleSpacing.large)
        }
        .onAppear {
            updateAmbientAnimations()
            triggerProgressHaptics(for: progressPercent)
        }
        .onChange(of: state.showsProgress) { _, _ in
            updateAmbientAnimations()
            if state.showsProgress == false {
                completedImpactMilestones = []
                emittedSuccessHaptic = false
            }
        }
        .onChange(of: state.tipRotationKey) { _, _ in
            currentTipIndex = 0
        }
        .onChange(of: progressPercent) { _, newValue in
            triggerProgressHaptics(for: newValue)
        }
        .onReceive(tipRotationTimer) { _ in
            let rotatingTips = state.rotatingTips
            guard state.showsProgress, rotatingTips.isEmpty == false else {
                return
            }

            withAnimation(.easeInOut(duration: 0.45)) {
                currentTipIndex = (currentTipIndex + 1) % rotatingTips.count
            }
        }
    }

    private var progressFraction: Double {
        switch state {
        case let .analyzing(step, frameCount, totalFrames):
            switch step {
            case .loadingVideo:
                return 0.08
            case .samplingFrames:
                return totalFrames > 0 ? 0.12 : 0.1
            case .detectingBody:
                guard totalFrames > 0 else { return 0.26 }
                let extractionProgress = Double(frameCount) / Double(max(totalFrames, 1))
                return 0.26 + (extractionProgress * 0.54)
            case .mappingCheckpoints:
                return 0.86
            case .savingSwing:
                return 1.0
            }
        case .preparing:
            return 0.06
        case .failure, .idle:
            return 0
        }
    }

    private var progressPercent: Int {
        Int((progressFraction * 100).rounded())
    }

    private var activeAnalysisTip: String {
        let rotatingTips = state.rotatingTips
        guard rotatingTips.isEmpty == false else {
            return state.detail
        }

        let safeIndex = min(max(currentTipIndex, 0), rotatingTips.count - 1)
        return rotatingTips[safeIndex]
    }

    private func updateAmbientAnimations() {
        guard state.showsProgress else {
            isGlowExpanded = false
            isTelemetryBreathing = false
            telemetrySweepProgress = 0
            return
        }

        isGlowExpanded = false
        isTelemetryBreathing = false
        telemetrySweepProgress = 0

        withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
            isGlowExpanded = true
        }

        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            isTelemetryBreathing = true
        }

        withAnimation(.linear(duration: 1.85).repeatForever(autoreverses: false)) {
            telemetrySweepProgress = 1
        }
    }

    private func triggerProgressHaptics(for percent: Int) {
        guard state.showsProgress else { return }

        for milestone in [25, 50, 75] where percent >= milestone && completedImpactMilestones.contains(milestone) == false {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            generator.impactOccurred()
            completedImpactMilestones.insert(milestone)
        }

        if percent >= 100, emittedSuccessHaptic == false {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            emittedSuccessHaptic = true
        }
    }
}

private struct GarageImportTelemetryStrip: View {
    let label: String
    let statusLine: String
    let progressFraction: Double
    let sweepProgress: Double
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(ModuleTheme.electricCyan)

                Spacer(minLength: 0)

                Text("\(Int((progressFraction * 100).rounded()))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppModule.garage.theme.textMuted)
                    .contentTransition(.numericText())
            }

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let progressWidth = max(width * max(progressFraction, 0.12), 34)
                let sweepWidth = max(width * 0.28, 72)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ModuleTheme.garageSurfaceDark.opacity(0.9))

                    Capsule()
                        .fill(ModuleTheme.electricCyan.opacity(0.1))
                        .frame(width: min(progressWidth, width))

                    if isActive {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        ModuleTheme.electricCyan.opacity(0),
                                        ModuleTheme.electricCyan.opacity(0.24),
                                        ModuleTheme.electricCyan.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: sweepWidth)
                            .offset(x: ((width + sweepWidth) * sweepProgress) - sweepWidth)
                            .blur(radius: 5)
                    }

                    Capsule()
                        .stroke(ModuleTheme.electricCyan.opacity(0.18), lineWidth: 0.5)
                }
            }
            .frame(height: 12)

            Text(statusLine)
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(AppModule.garage.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GarageImportSignalBars: View {
    let isActive: Bool
    let isExpanded: Bool

    private let barHeights: [CGFloat] = [8, 13, 18, 12]
    private let expandedScales: [CGFloat] = [0.76, 1.04, 0.72, 0.94]

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(barHeights.enumerated()), id: \.offset) { index, height in
                Capsule()
                    .fill(ModuleTheme.electricCyan.opacity(isActive ? 0.8 : 0.26))
                    .frame(width: 4, height: height)
                    .scaleEffect(
                        x: 1,
                        y: isActive ? (isExpanded ? expandedScales[index] : 0.58) : 0.42,
                        anchor: .bottom
                    )
                    .animation(
                        .easeInOut(duration: 0.8)
                            .delay(Double(index) * 0.08),
                        value: isExpanded
                    )
            }
        }
        .frame(height: 20)
        .allowsHitTesting(false)
    }
}

private struct GarageTelemetryGridBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let spacing: CGFloat = 28
                var path = Path()

                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }

                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }

                context.stroke(
                    path,
                    with: .color(ModuleTheme.electricCyan.opacity(0.08)),
                    lineWidth: 0.5
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
    }
}

private struct GarageGaugeTickMarks: View {
    let tickCount: Int
    let radius: CGFloat
    let accent: Color

    var body: some View {
        ZStack {
            ForEach(0..<tickCount, id: \.self) { index in
                Capsule()
                    .fill(accent.opacity(index.isMultiple(of: 5) ? 0.32 : 0.14))
                    .frame(width: index.isMultiple(of: 5) ? 2 : 1, height: index.isMultiple(of: 5) ? 11 : 6)
                    .offset(y: -radius)
                    .rotationEffect(.degrees((Double(index) / Double(tickCount)) * 360))
            }
        }
        .frame(width: radius * 2.2, height: radius * 2.2)
        .allowsHitTesting(false)
    }
}

private struct GarageCommandCenterView: View {
    let records: [SwingRecord]
    let openCourseMap: () -> Void

    private let fallbackScore = 82
    private let fallbackIssueTitle = "Build stable baseline"
    private let fallbackIssueDetail = "Import a swing in Analyzer, run the review checkpoints, and lock your next actionable focus."

    private var latestRecord: SwingRecord? {
        records.first
    }

    private var heroScore: Int {
        latestRecord?.derivedAnalysisResult?.scorecard?.totalScore ?? fallbackScore
    }

    private var normalizedHeroScore: Double {
        min(max(Double(heroScore) / 100, 0), 1)
    }

    private var consistencyScore: String {
        String(format: "%.1f", Double(heroScore) / 10)
    }

    private var issueTitle: String {
        latestRecord?.derivedAnalysisResult?.syncFlow?.primaryIssue?.title ?? fallbackIssueTitle
    }

    private var issueDetail: String {
        latestRecord?.derivedAnalysisResult?.syncFlow?.primaryIssue?.detail ?? fallbackIssueDetail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Command Center")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            heroStatusSurface
            criticalActionSurface
            courseMappingSurface
        }
        .padding(.bottom, 90)
    }

    private var heroStatusSurface: some View {
        GarageTelemetrySurface(isActive: true, cornerRadius: 28, padding: 24) {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    GarageGaugeTickMarks(
                        tickCount: 60,
                        radius: 82,
                        accent: ModuleTheme.electricCyan
                    )

                    Circle()
                        .stroke(ModuleTheme.garageTrack, lineWidth: 14)
                        .frame(width: 150, height: 150)

                    Circle()
                        .trim(from: 0, to: normalizedHeroScore)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    ModuleTheme.electricCyan,
                                    Color(hex: "#1AD0C8")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: ModuleTheme.electricCyan.opacity(0.16), radius: 8, x: 0, y: 0)

                    Circle()
                        .fill(ModuleTheme.garageSurfaceInset.opacity(0.96))
                        .frame(width: 118, height: 118)

                    VStack(spacing: 4) {
                        Text("\(heroScore)")
                            .font(.system(size: 42, weight: .black, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(AppModule.garage.theme.textPrimary)

                        Text("SWING SCORE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(AppModule.garage.theme.textMuted)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Latest Total Score")
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(AppModule.garage.theme.textMuted)

                    Text("Most recent analyzed swing record")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    Text("A compact performance readout built from the latest scorecard and SyncFlow pass.")
                        .font(.footnote)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)

                    HStack(spacing: 10) {
                        metricCapsule(value: consistencyScore, label: "CONSISTENCY", tint: ModuleTheme.electricCyan)
                        metricCapsule(value: "LIVE", label: "BASELINE", tint: Color(hex: "#36D7FF"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var criticalActionSurface: some View {
        GarageTelemetrySurface(isActive: true, cornerRadius: 22, padding: 20) {
            Text("Critical Next Action")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(AppModule.garage.theme.primary)

            Text(issueTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            Text(issueDetail)
                .font(.footnote)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
        }
    }

    private var courseMappingSurface: some View {
        GarageTelemetrySurface(isActive: true, cornerRadius: 22, padding: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Course Mapping")
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(AppModule.garage.theme.primary)

                    Text("Survey the hole before you swing")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    Text("Open the new Garage course surface for route lines, tactical nodes, and a restrained map-first planning layer.")
                        .font(.footnote)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                Spacer(minLength: 0)

                Button {
                    garageTriggerImpact(.medium)
                    openCourseMap()
                } label: {
                    Label("Open Map", systemImage: "map.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(garageReviewCanvasFill)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            GarageRaisedPanelBackground(
                                shape: Capsule(),
                                fill: garageReviewAccent,
                                stroke: garageReviewAccent.opacity(0.35),
                                glow: garageReviewAccent
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func metricCapsule(value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(AppModule.garage.theme.textMuted)
        }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.35), lineWidth: 0.5)
                    )
            )
    }
}

struct GaragePickedMovie: Transferable {
    let url: URL
    let displayName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let originalFilename = received.file.lastPathComponent.isEmpty ? "swing.mov" : received.file.lastPathComponent
            let stem = URL(fileURLWithPath: originalFilename).deletingPathExtension().lastPathComponent
            let ext = URL(fileURLWithPath: originalFilename).pathExtension.isEmpty ? "mov" : URL(fileURLWithPath: originalFilename).pathExtension
            let sanitizedStem = stem.replacingOccurrences(of: "/", with: "-")
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(sanitizedStem)-\(UUID().uuidString.prefix(8))")
                .appendingPathExtension(ext)

            if FileManager.default.fileExists(atPath: destinationURL.path()) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: received.file, to: destinationURL)
            return GaragePickedMovie(url: destinationURL, displayName: originalFilename)
        }
    }
}

enum GarageImportError: LocalizedError {
    case unableToLoadSelection

    var errorDescription: String? {
        switch self {
        case .unableToLoadSelection:
            "The selected video could not be loaded from Photos."
        }
    }
}

#Preview("Garage · iPhone 17 Pro") {
    PreviewScreenContainer {
        GarageView()
    }
    .modelContainer(for: SwingRecord.self, inMemory: true)
}

#Preview("Garage · iPhone 16 Pro") {
    PreviewScreenContainer {
        GarageView()
    }
    .modelContainer(for: SwingRecord.self, inMemory: true)
}
