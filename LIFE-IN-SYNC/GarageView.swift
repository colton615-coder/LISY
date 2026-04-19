import AVFoundation
import AVKit
import Combine
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct GarageTimelineMarker: Identifiable {
    let keyFrame: KeyFrame
    let timestamp: Double

    var id: SwingPhase { keyFrame.phase }
}

private struct GarageFilmstripFrame: Identifiable, Hashable {
    let index: Int
    let timestamp: Double

    var id: Int { index }
}

private struct GarageHandPathSample: Identifiable {
    let id: Int
    let timestamp: Double
    let x: Double
    let y: Double
    let speed: Double
    let segment: GarageHandPathSegmentKind

    init(
        id: Int,
        timestamp: Double,
        x: Double,
        y: Double,
        speed: Double,
        segment: GarageHandPathSegmentKind
    ) {
        self.id = id
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.speed = speed
        self.segment = segment
    }
}

private enum GarageReviewSurface {
    case fallbackHandPath
    case summary
}

private enum GarageImportPresentationState: Equatable {
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

private struct GaragePreFlightSelection: Equatable {
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

private extension GaragePreFlightSelection {
    var trimDuration: Double {
        max(trimEndSeconds - trimStartSeconds, 0)
    }
}


func garageDeterministicHandPathSampleID(index: Int, timestamp: Double) -> Int {
    let quantizedTimestamp = Int64((timestamp * 1_000_000).rounded())
    let indexBits = UInt64(bitPattern: Int64(index))
    let timestampBits = UInt64(bitPattern: quantizedTimestamp)
    let bytes: [UInt8] = [
        UInt8(truncatingIfNeeded: indexBits),
        UInt8(truncatingIfNeeded: indexBits >> 8),
        UInt8(truncatingIfNeeded: indexBits >> 16),
        UInt8(truncatingIfNeeded: indexBits >> 24),
        UInt8(truncatingIfNeeded: indexBits >> 32),
        UInt8(truncatingIfNeeded: indexBits >> 40),
        UInt8(truncatingIfNeeded: indexBits >> 48),
        UInt8(truncatingIfNeeded: indexBits >> 56),
        UInt8(truncatingIfNeeded: timestampBits),
        UInt8(truncatingIfNeeded: timestampBits >> 8),
        UInt8(truncatingIfNeeded: timestampBits >> 16),
        UInt8(truncatingIfNeeded: timestampBits >> 24),
        UInt8(truncatingIfNeeded: timestampBits >> 32),
        UInt8(truncatingIfNeeded: timestampBits >> 40),
        UInt8(truncatingIfNeeded: timestampBits >> 48),
        UInt8(truncatingIfNeeded: timestampBits >> 56)
    ]

    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
    }

    return Int(truncatingIfNeeded: hash)
}

private extension KeyframeValidationStatus {
    var reviewTint: Color {
        switch self {
        case .pending:
            garageReviewPending
        case .approved:
            garageReviewApproved
        case .flagged:
            garageReviewFlagged
        }
    }

    var reviewBackground: Color {
        switch self {
        case .pending:
            garageReviewInsetSurface
        case .approved:
            garageReviewApproved.opacity(0.14)
        case .flagged:
            garageReviewFlagged.opacity(0.14)
        }
    }
}

private func garageRecordSelectionKey(for record: SwingRecord) -> String {
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

private func garageDiscardDetachedExportDerivative(at exportURL: URL) {
    guard FileManager.default.fileExists(atPath: exportURL.path) else {
        return
    }

    try? FileManager.default.removeItem(at: exportURL)
}

private func garageBackfillExportDerivative(
    using modelContainer: ModelContainer,
    recordID: PersistentIdentifier,
    reviewMasterURL: URL
) async {
    guard let exportURL = await GarageMediaStore.createExportDerivative(from: reviewMasterURL) else {
        return
    }

    let backgroundContext = ModelContext(modelContainer)

    guard let savedRecord = backgroundContext.model(for: recordID) as? SwingRecord else {
        garageDiscardDetachedExportDerivative(at: exportURL)
        return
    }

    let exportBookmark = GarageMediaStore.bookmarkData(for: exportURL)
    savedRecord.exportAssetFilename = exportURL.lastPathComponent
    savedRecord.exportAssetBookmark = exportBookmark

    do {
        try backgroundContext.save()
    } catch {
        garageDiscardDetachedExportDerivative(at: exportURL)

        let nsError = error as NSError
        let exportMessage = [
            "Garage export derivative save failed.",
            "domain=\(nsError.domain)",
            "code=\(nsError.code)",
            nsError.localizedDescription
        ].joined(separator: " ")
        NSLog("%@", exportMessage)
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

private func garageHandPathSamples(from frames: [SwingFrame], keyFrames: [KeyFrame]) -> [GarageHandPathSample] {
    GarageAnalysisPipeline.segmentedHandPathSamples(
        from: frames,
        keyFrames: keyFrames,
        samplesPerSegment: 6
    )
    .enumerated()
    .map { index, sample in
        GarageHandPathSample(
            id: garageDeterministicHandPathSampleID(index: index, timestamp: sample.timestamp),
            timestamp: sample.timestamp,
            x: sample.x,
            y: sample.y,
            speed: sample.speed,
            segment: sample.segment
        )
    }
}

struct GarageVelocityRibbonPalette: Equatable {
    let halo: SIMD4<Double>
    let fill: SIMD4<Double>
    let outerWidth: Double
    let innerWidth: Double
}

func garageVelocityRibbonPalette(
    normalizedSpeed: Double,
    segment: GarageHandPathSegmentKind
) -> GarageVelocityRibbonPalette {
    let clampedSpeed = min(max(normalizedSpeed, 0), 1)
    let slow = SIMD4<Double>(0.18, 0.63, 0.94, 0.88)
    let mid = SIMD4<Double>(0.34, 0.78, 0.72, 0.91)
    let fast = SIMD4<Double>(0.95, 0.45, 0.22, 0.95)

    let baseFill: SIMD4<Double>
    if clampedSpeed < 0.5 {
        baseFill = garageMixColor(stopA: slow, stopB: mid, progress: clampedSpeed / 0.5)
    } else {
        baseFill = garageMixColor(stopA: mid, stopB: fast, progress: (clampedSpeed - 0.5) / 0.5)
    }

    let fill: SIMD4<Double>
    switch segment {
    case .backswing:
        fill = garageMixColor(
            stopA: baseFill,
            stopB: SIMD4<Double>(0.96, 0.98, 1.0, baseFill.w),
            progress: 0.18
        )
    case .downswing:
        fill = baseFill
    }

    let halo = SIMD4<Double>(1.0, 1.0, 1.0, 0.26 + (clampedSpeed * 0.14))
    let innerWidth = 1.9 + (clampedSpeed * 1.4)
    return GarageVelocityRibbonPalette(
        halo: halo,
        fill: fill,
        outerWidth: innerWidth + 1.4,
        innerWidth: innerWidth
    )
}

func garageLoupeCropRect(
    anchorPoint: CGPoint,
    imageSize: CGSize,
    sampleSize: CGFloat = 120
) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0 else {
        return .zero
    }

    let clampedAnchor = garageClampedNormalizedPoint(anchorPoint)
    let center = CGPoint(x: clampedAnchor.x * imageSize.width, y: clampedAnchor.y * imageSize.height)
    let maxX = max(imageSize.width - sampleSize, 0)
    let maxY = max(imageSize.height - sampleSize, 0)
    let origin = CGPoint(
        x: min(max(center.x - (sampleSize / 2), 0), maxX),
        y: min(max(center.y - (sampleSize / 2), 0), maxY)
    )

    return CGRect(origin: origin, size: CGSize(width: min(sampleSize, imageSize.width), height: min(sampleSize, imageSize.height))).integral
}

private func garageMixColor(stopA: SIMD4<Double>, stopB: SIMD4<Double>, progress: Double) -> SIMD4<Double> {
    let clamped = min(max(progress, 0), 1)
    return stopA + ((stopB - stopA) * clamped)
}

private extension Color {
    init(rgba vector: SIMD4<Double>) {
        self.init(red: vector.x, green: vector.y, blue: vector.z, opacity: vector.w)
    }
}

struct GarageView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SwingRecord.createdAt, order: .reverse) private var swingRecords: [SwingRecord]
    @State private var isShowingAddRecord = false
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var pendingImportMovie: GaragePickedMovie?
    @State private var pendingPreFlightSelection = GaragePreFlightSelection()
    @State private var route: GarageRoute = .hub
    @State private var hasNormalizedPersistedAnalysisPayloads = false
    @State private var activeImportRecordID: PersistentIdentifier?
    @State private var recoverableImportRecordID: PersistentIdentifier?

    private var reviewableSwingRecords: [SwingRecord] {
        swingRecords.filter(\.isReviewableRecord)
    }

    private var analyzerVisibleSwingRecords: [SwingRecord] {
        swingRecords.filter(\.isAnalyzerVisible)
    }

    var body: some View {
        GarageCustomScaffold(module: .garage, tabs: [], selectedTab: .constant(.hub)) { size in
            garageContent(for: size)
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
            prepareSelectedVideo(newItem)
        }
        .onChange(of: reviewableSwingRecords.map(garageRecordSelectionKey)) { _, keys in
            handleReviewableRecordKeysChange(keys)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if importPresentationState == nil {
                GarageBottomTabBar(selectedTab: selectedTabBinding)
            }
        }
        .task(id: swingRecords.count) {
            await recoverAndNormalizePersistedAnalysisPayloadsIfNeeded()
        }
        .toolbar({
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

    private var importPresentationState: GarageImportPresentationState? {
        guard case let .analyzer(analyzerRoute) = route,
              case let .importing(state) = analyzerRoute.normalizedForPresentation else {
            return nil
        }
        return state
    }

    @MainActor
    private func presentImportProgress(_ progress: GarageAnalysisProgressUpdate) {
        route = .analyzer(
            .importing(
                .analyzing(
                    step: progress.step,
                    frameCount: progress.frameCount,
                    totalFrames: progress.totalFrames
                )
            )
        )
    }

    @MainActor
    private func pendingRecord(for identifier: PersistentIdentifier?) -> SwingRecord? {
        guard let identifier else { return nil }
        return modelContext.registeredModel(for: identifier) ?? (modelContext.model(for: identifier) as? SwingRecord)
    }

    private func performGarageAnalysis(at reviewMasterURL: URL) async throws -> GarageAnalysisOutput {
        try await GarageAnalysisPipeline.analyzeVideo(at: reviewMasterURL) { progress in
            await MainActor.run {
                presentImportProgress(progress)
            }
        }
    }

    private func analyzeReviewMaster(
        at reviewMasterURL: URL,
        recordID: PersistentIdentifier?
    ) async throws -> GarageAnalysisOutput {
        do {
            return try await performGarageAnalysis(at: reviewMasterURL)
        } catch {
            guard garageShouldRetryImportAfterFailure(error) else {
                throw error
            }

            await MainActor.run {
                if let record = pendingRecord(for: recordID) {
                    record.importStatus = .retrying
                    try? modelContext.save()
                }
            }

            try await Task.sleep(nanoseconds: 500_000_000)
            return try await performGarageAnalysis(at: reviewMasterURL)
        }
    }

    @MainActor
    private func finalizeImportedRecord(
        recordID: PersistentIdentifier?,
        output: GarageAnalysisOutput
    ) throws -> String {
        presentImportProgress(
            GarageAnalysisProgressUpdate(
                step: .savingSwing,
                frameCount: max(output.swingFrames.count, 0),
                totalFrames: max(output.swingFrames.count, 0)
            )
        )

        let approvedKeyFrames = GarageAnalysisPipeline.autoApprovedKeyFrames(
            from: output.keyFrames,
            reviewReport: output.handPathReviewReport
        )
        let validationStatus: KeyframeValidationStatus = output.handPathReviewReport.requiresManualReview ? .pending : .approved

        guard let savedRecord = pendingRecord(for: recordID) else {
            throw GarageImportError.unableToLoadSelection
        }

        savedRecord.applyAnalysisOutput(
            output,
            approvedKeyFrames: approvedKeyFrames,
            validationStatus: validationStatus
        )
        try modelContext.save()

        selectedVideoItem = nil
        pendingImportMovie = nil
        activeImportRecordID = nil
        recoverableImportRecordID = nil

        return garageRecordSelectionKey(for: savedRecord)
    }

    @MainActor
    private func persistRecoverableImportFailure(
        recordID: PersistentIdentifier?,
        message: String
    ) {
        activeImportRecordID = nil

        if let record = pendingRecord(for: recordID) {
            record.markImportFailed()
            pendingImportMovie = nil
            recoverableImportRecordID = record.persistentModelID
            do {
                try modelContext.save()
            } catch {
                let nsError = error as NSError
                NSLog(
                    "%@",
                    "Garage import failure preservation save failed. domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
                )
            }
        } else {
            recoverableImportRecordID = nil
        }

        route = .analyzer(.importing(.failure(message)))
    }

    @MainActor
    private func persistReanalysisFailure(
        recordID: PersistentIdentifier?,
        fallbackStatus: GarageImportStatus,
        repairReason: GarageRepairReason,
        message: String
    ) {
        activeImportRecordID = nil

        if let record = pendingRecord(for: recordID) {
            record.importStatus = fallbackStatus
            if fallbackStatus.isFailed {
                record.markImportFailed(repairReason: repairReason)
                recoverableImportRecordID = record.persistentModelID
            } else {
                record.clearDerivedPayload(repairReason: repairReason)
                record.clearLegacyDerivedReviewData()
                recoverableImportRecordID = nil
            }

            do {
                try modelContext.save()
            } catch {
                let nsError = error as NSError
                NSLog(
                    "%@",
                    "Garage repair failure save failed. domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
                )
            }
        }

        route = .analyzer(.importing(.failure(message)))
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
                isActiveImportRecord: activeImportRecordID == record.persistentModelID
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
            GaragePendingSurface(
                title: "Photo-Map",
                message: "Photo-Map scaffolding is reserved for a future phase once the core tabs are validated."
            )
        }
    }

    private var garageHubContent: some View {
        GarageCommandCenterView(records: reviewableSwingRecords)
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
                        repairRecord(record)
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
                    repairRecord(record)
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
        pendingImportMovie = nil
        route = .analyzer(.records)
    }

    @MainActor
    private func retryImport() {
        if let recoverableImportRecord = pendingRecord(for: recoverableImportRecordID) {
            repairRecord(recoverableImportRecord)
            return
        }

        if let pendingImportMovie {
            importSelectedVideo(pendingImportMovie, selection: pendingPreFlightSelection)
            return
        }

        if let selectedVideoItem {
            route = .analyzer(.records)
            prepareSelectedVideo(selectedVideoItem)
            return
        }

        route = .analyzer(.records)
        isShowingAddRecord = true
    }

    @MainActor
    private func prepareSelectedVideo(_ item: PhotosPickerItem) {
        pendingImportMovie = nil
        recoverableImportRecordID = nil
        route = .analyzer(.importing(.preparing))

        Task {
            do {
                guard let movie = try await item.loadTransferable(type: GaragePickedMovie.self) else {
                    throw GarageImportError.unableToLoadSelection
                }

                await MainActor.run {
                    selectedVideoItem = nil
                    let inferredSelection = inferredImportSelection()
                    pendingPreFlightSelection = inferredSelection
                    importSelectedVideo(movie, selection: inferredSelection)
                }
            } catch {
                await MainActor.run {
                    selectedVideoItem = nil
                    route = .analyzer(.importing(.failure(error.localizedDescription)))
                }
            }
        }
    }

    @MainActor
    private func importSelectedVideo(_ movie: GaragePickedMovie, selection: GaragePreFlightSelection) {
        pendingImportMovie = movie
        pendingPreFlightSelection = selection
        recoverableImportRecordID = nil
        presentImportProgress(GarageAnalysisProgressUpdate(step: .loadingVideo))

        let sourceMovieURL = movie.url
        let displayName = movie.displayName
        let clubType = selection.clubType
        let isLeftHanded = selection.isLeftHanded
        let cameraAngle = selection.cameraAngle
        let modelContainer = modelContext.container

        Task {
            var pendingRecordID: PersistentIdentifier?

            do {
                let reviewMasterURL = try GarageMediaStore.persistReviewMaster(from: sourceMovieURL)
                let resolvedTitle = garageSuggestedRecordTitle(for: displayName, fallbackURL: reviewMasterURL)
                let reviewMasterBookmark = GarageMediaStore.bookmarkData(for: reviewMasterURL)

                pendingRecordID = try await MainActor.run {
                    presentImportProgress(GarageAnalysisProgressUpdate(step: .loadingVideo))

                    let record = SwingRecord(
                        title: resolvedTitle,
                        importStatus: .pending,
                        clubType: clubType,
                        isLeftHanded: isLeftHanded,
                        cameraAngle: cameraAngle,
                        mediaFilename: reviewMasterURL.lastPathComponent,
                        mediaFileBookmark: reviewMasterBookmark,
                        reviewMasterFilename: reviewMasterURL.lastPathComponent,
                        reviewMasterBookmark: reviewMasterBookmark,
                        notes: ""
                    )

                    modelContext.insert(record)
                    try modelContext.save()
                    activeImportRecordID = record.persistentModelID
                    return record.persistentModelID
                }

                let output = try await analyzeReviewMaster(at: reviewMasterURL, recordID: pendingRecordID)
                let reviewKey = try await MainActor.run {
                    try finalizeImportedRecord(recordID: pendingRecordID, output: output)
                }

                await MainActor.run {
                    hasNormalizedPersistedAnalysisPayloads = true
                    route = .analyzer(.review(recordKey: reviewKey))
                }

                if let recordID = pendingRecordID {
                    Task.detached(priority: .utility) {
                        await garageBackfillExportDerivative(
                            using: modelContainer,
                            recordID: recordID,
                            reviewMasterURL: reviewMasterURL
                        )
                    }
                }
            } catch {
                let failureMessage = garageImportFailureMessage(from: error)
                NSLog("%@", failureMessage)

                await MainActor.run {
                    persistRecoverableImportFailure(recordID: pendingRecordID, message: failureMessage)
                }
            }
        }
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

    @MainActor
    private func repairRecord(_ record: SwingRecord) {
        let fallbackStatus: GarageImportStatus = record.isRecoverableFailedImport ? .failed : .complete
        let failureReason: GarageRepairReason = record.isRecoverableFailedImport ? .importFailed : .corruptedDerivedPayload

        guard let reviewMasterURL = GarageMediaStore.resolvedReviewVideoURL(for: record) else {
            record.importStatus = fallbackStatus
            record.clearDerivedPayload(repairReason: .missingReviewVideo)
            record.clearLegacyDerivedReviewData()
            try? modelContext.save()
            recoverableImportRecordID = record.isRecoverableFailedImport ? record.persistentModelID : nil
            return
        }

        route = .analyzer(.importing(.analyzing(step: .loadingVideo, frameCount: 0, totalFrames: 0)))
        let recordID = record.persistentModelID
        activeImportRecordID = recordID
        recoverableImportRecordID = nil

        if record.isRecoverableFailedImport {
            record.importStatus = .retrying
            try? modelContext.save()
        }

        Task {
            do {
                let output = try await analyzeReviewMaster(at: reviewMasterURL, recordID: recordID)

                await MainActor.run {
                    do {
                        let reviewKey = try finalizeImportedRecord(recordID: recordID, output: output)
                        NSLog(
                            "%@",
                            "Garage repair completed. recordID=\(String(describing: recordID))"
                        )
                        route = .analyzer(.review(recordKey: reviewKey))
                    } catch {
                        let failureMessage = garageImportFailureMessage(from: error)
                        persistReanalysisFailure(
                            recordID: recordID,
                            fallbackStatus: fallbackStatus,
                            repairReason: failureReason,
                            message: failureMessage
                        )
                    }
                }
            } catch {
                let failureMessage = garageImportFailureMessage(from: error)
                await MainActor.run {
                    persistReanalysisFailure(
                        recordID: recordID,
                        fallbackStatus: fallbackStatus,
                        repairReason: failureReason,
                        message: failureMessage
                    )
                }
            }
        }
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

private struct GarageRecordMetadataEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let record: SwingRecord

    @State private var title: String
    @State private var clubType: String
    @State private var isLeftHanded: Bool
    @State private var cameraAngle: String
    @State private var notes: String

    private let clubOptions = [
        "Driver", "3 Wood", "5 Wood",
        "3 Hybrid", "4 Hybrid", "5 Hybrid",
        "4 Iron", "5 Iron", "6 Iron",
        "7 Iron", "8 Iron", "9 Iron",
        "PW", "SW"
    ]
    private let cameraOptions = ["Down the Line", "Face On"]
    private let handednessOptions: [(label: String, value: Bool)] = [("Righty", false), ("Lefty", true)]
    private let clubColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    init(record: SwingRecord) {
        self.record = record
        _title = State(initialValue: record.title)
        _clubType = State(initialValue: record.resolvedClubType)
        _isLeftHanded = State(initialValue: record.resolvedIsLeftHanded)
        _cameraAngle = State(initialValue: record.resolvedCameraAngle)
        _notes = State(initialValue: record.notes)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    metadataFieldCard
                    handednessCard
                    cameraAngleCard
                    clubGridCard
                    notesCard
                }
                .padding(ModuleSpacing.large)
                .padding(.bottom, ModuleSpacing.large)
            }
            .background(garageReviewBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(garageReviewMutedText)
                }

                ToolbarItem(placement: .principal) {
                    Text("Swing Metadata")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(garageReviewReadableText)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ModuleTheme.electricCyan)
                }
            }
        }
    }

    private var metadataFieldCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Label")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            TextField("Swing title", text: $title)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .font(.headline.weight(.semibold))
                .foregroundStyle(garageReviewReadableText)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    GarageInsetPanelBackground(
                        shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        fill: garageReviewInsetSurface,
                        stroke: Color.white.opacity(0.08)
                    )
                )
        }
        .padding(18)
        .background(panelBackground)
    }

    private var handednessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Handedness")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            HStack(spacing: 10) {
                ForEach(handednessOptions, id: \.label) { option in
                    metadataSelectionButton(
                        title: option.label,
                        isSelected: isLeftHanded == option.value,
                        shape: Capsule()
                    ) {
                        isLeftHanded = option.value
                    }
                }
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var cameraAngleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Angle")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            HStack(spacing: 10) {
                ForEach(cameraOptions, id: \.self) { option in
                    metadataSelectionButton(
                        title: option,
                        isSelected: cameraAngle == option,
                        shape: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    ) {
                        cameraAngle = option
                    }
                }
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var clubGridCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Club")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            LazyVGrid(columns: clubColumns, spacing: 9) {
                ForEach(clubOptions, id: \.self) { club in
                    Button {
                        clubType = club
                    } label: {
                        Text(club)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(clubType == club ? ModuleTheme.electricCyan : AppModule.garage.theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .padding(.horizontal, 8)
                            .background(
                                GarageInsetPanelBackground(
                                    shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                                    fill: clubType == club ? garageReviewSurface : garageReviewInsetSurface,
                                    stroke: clubType == club ? ModuleTheme.electricCyan.opacity(0.42) : Color.white.opacity(0.08)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            TextEditor(text: $notes)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140)
                .padding(10)
                .background(
                    GarageInsetPanelBackground(
                        shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        fill: garageReviewInsetSurface,
                        stroke: Color.white.opacity(0.08)
                    )
                )
                .foregroundStyle(garageReviewReadableText)
        }
        .padding(18)
        .background(panelBackground)
    }

    private var panelBackground: some View {
        GarageRaisedPanelBackground(
            shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
            fill: garageReviewSurfaceDark.opacity(0.98),
            stroke: ModuleTheme.electricCyan.opacity(0.20),
            glow: ModuleTheme.electricCyan.opacity(0.7)
        )
    }

    private func metadataSelectionButton(
        title: String,
        isSelected: Bool,
        shape: some InsettableShape,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? ModuleTheme.electricCyan : garageReviewReadableText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 10)
                .background(
                    GarageInsetPanelBackground(
                        shape: shape,
                        fill: isSelected ? garageReviewSurface : garageReviewInsetSurface,
                        stroke: isSelected ? ModuleTheme.electricCyan.opacity(0.42) : Color.white.opacity(0.08)
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func saveChanges() {
        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? record.title : title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.clubType = clubType
        record.isLeftHanded = isLeftHanded
        record.cameraAngle = cameraAngle
        record.notes = notes

        try? modelContext.save()
        dismiss()
    }
}

enum GarageReviewMode: String, CaseIterable, Identifiable {
    case handPath
    case skeleton

    var id: String { rawValue }

    var title: String {
        switch self {
        case .handPath:
            "Hand Path"
        case .skeleton:
            "SyncFlow"
        }
    }
}

enum GaragePoseQualityLevel: String, Equatable {
    case good
    case moderate
    case limited

    var label: String {
        switch self {
        case .good:
            "Good"
        case .moderate:
            "Moderate"
        case .limited:
            "Limited"
        }
    }

    var badgeText: String {
        "Pose quality: \(label)"
    }

    var tint: Color {
        switch self {
        case .good:
            Color(red: 0.33, green: 0.79, blue: 0.53)
        case .moderate:
            Color(red: 0.77, green: 0.83, blue: 0.89)
        case .limited:
            .orange
        }
    }
}

struct GarageReviewSummaryPresentation: Equatable {
    let reviewTitle: String
    let reviewSubtitle: String
    let poseQuality: GaragePoseQualityLevel
    let poseQualityDetail: String?
    let stabilityTitle: String
    let stabilitySubtitle: String
    let stabilityValueText: String?
    let stabilityStatusText: String
    let stabilityDetail: String?

    static func make(
        reviewMode: GarageReviewMode,
        handPathReviewReport: GarageHandPathReviewReport,
        stabilityScore: Int?,
        reviewFrameSource: GarageReviewFrameSourceState,
        syncFlow: GarageSyncFlowReport? = nil
    ) -> GarageReviewSummaryPresentation {
        let limitedSyncFlowDetail = syncFlow?.status == .limited
            ? syncFlow?.summary ?? "Body outline is visible, but SyncFlow needs steadier head and pelvis tracking for a confident sequence call."
            : "Body outline is visible, but head and hip tracking were too weak for a stable score."

        let basePoseQuality: GaragePoseQualityLevel
        if handPathReviewReport.score >= 75, stabilityScore != nil {
            basePoseQuality = .good
        } else if handPathReviewReport.score >= 55 {
            basePoseQuality = .moderate
        } else {
            basePoseQuality = .limited
        }

        let resolvedPoseQuality: GaragePoseQualityLevel
        if reviewMode == .skeleton, stabilityScore == nil {
            resolvedPoseQuality = .limited
        } else {
            resolvedPoseQuality = basePoseQuality
        }

        let poseQualityDetail: String?
        switch (reviewFrameSource, reviewMode, resolvedPoseQuality, stabilityScore) {
        case (.poseFallback, _, _, _):
            poseQualityDetail = "Reviewing sampled pose data because the stored video is unavailable."
        case (.recoveryNeeded, _, _, _):
            poseQualityDetail = "Review media is limited, so trust this review cautiously."
        case (_, .skeleton, .limited, nil):
            poseQualityDetail = limitedSyncFlowDetail
        default:
            poseQualityDetail = nil
        }

        return GarageReviewSummaryPresentation(
            reviewTitle: reviewMode == .handPath ? "Hand Path Review" : "SyncFlow Review",
            reviewSubtitle: reviewMode == .handPath
                ? "Reviewing the detected grip path from setup to impact"
                : "Reviewing sequence, energy flow, and pose confidence through impact",
            poseQuality: resolvedPoseQuality,
            poseQualityDetail: poseQualityDetail,
            stabilityTitle: "Postural Stability",
            stabilitySubtitle: "A support metric based on head and pelvis drift from setup to impact",
            stabilityValueText: stabilityScore.map(String.init),
            stabilityStatusText: stabilityScore == nil ? "Stability unavailable" : "Support metric",
            stabilityDetail: stabilityScore == nil ? limitedSyncFlowDetail : nil
        )
    }
}

struct GarageCoachingPresentation: Equatable {
    struct SessionSnapshot: Identifiable, Equatable {
        let id: String
        let title: String
        let value: String
        let caption: String
        let systemImage: String
    }

    struct MetricTile: Identifiable, Equatable {
        let id: String
        let title: String
        let value: String
        let systemImage: String
        let status: GarageCoachingMetricStatus
        let progress: Double
    }

    let title: String
    let headline: String
    let body: String
    let supportingLine: String?
    let confidenceLabel: String
    let phaseLabel: String
    let nextBestAction: String
    let notes: [String]
    let snapshots: [SessionSnapshot]
    let metrics: [MetricTile]
    let isUnavailable: Bool

    static func make(
        report: GarageCoachingReport,
        selectedPhase: SwingPhase,
        reliabilityStatus: GarageReliabilityStatus,
        scorecard: GarageSwingScorecard?,
        stabilityScore: Int?
    ) -> GarageCoachingPresentation {
        let unavailable = report.cues.isEmpty
        let primaryCue = report.cues.first
        let rawHeadline = primaryCue?.title ?? report.headline

        let headline: String
        if rawHeadline == "Transition Looks Rushed" {
            headline = "Transition appears faster than this swing’s baseline"
        } else {
            headline = rawHeadline
        }

        let body: String
        if let primaryCue {
            body = primaryCue.message
        } else {
            body = "Review the motion and stability metric while coaching catches up."
        }

        let scoreValue = scorecard.map(\.totalScore) ?? 82
        let snapshots = [
            SessionSnapshot(
                id: "score",
                title: "Session Analysis",
                value: "\(scoreValue)",
                caption: "swing score",
                systemImage: "waveform.path.ecg.rectangle"
            ),
            SessionSnapshot(
                id: "reliability",
                title: "Reliability",
                value: reliabilityStatus.rawValue.uppercased(),
                caption: "signal confidence",
                systemImage: "checkmark.shield"
            ),
            SessionSnapshot(
                id: "phase",
                title: "Focus Phase",
                value: selectedPhase.reviewTitle,
                caption: stabilityScore.map { "stability \($0)" } ?? "stability pending",
                systemImage: "figure.golf"
            )
        ]

        let metrics = metricTiles(
            scorecard: scorecard,
            reliabilityStatus: reliabilityStatus,
            scoreValue: scoreValue,
            selectedPhase: selectedPhase,
            stabilityScore: stabilityScore
        )

        return GarageCoachingPresentation(
            title: "Coaching Notes",
            headline: unavailable ? "Coaching unavailable" : headline,
            body: body,
            supportingLine: unavailable ? nil : "Use this as a cue, not a final judgment",
            confidenceLabel: reliabilityStatus.rawValue,
            phaseLabel: selectedPhase.reviewTitle,
            nextBestAction: report.nextBestAction,
            notes: Array(report.blockers.prefix(2)),
            snapshots: snapshots,
            metrics: metrics,
            isUnavailable: unavailable
        )
    }

    private static func metricTiles(
        scorecard: GarageSwingScorecard?,
        reliabilityStatus: GarageReliabilityStatus,
        scoreValue: Int,
        selectedPhase: SwingPhase,
        stabilityScore: Int?
    ) -> [MetricTile] {
        guard let scorecard else {
            return [
                MetricTile(
                    id: "score",
                    title: "Swing Score",
                    value: "\(scoreValue)",
                    systemImage: "scope",
                    status: metricStatus(for: scoreValue),
                    progress: normalized(scoreValue)
                ),
                MetricTile(
                    id: "reliability",
                    title: "Reliability",
                    value: reliabilityStatus.rawValue.uppercased(),
                    systemImage: "checkmark.shield",
                    status: metricStatus(for: reliabilityStatus),
                    progress: normalized(reliabilityStatus)
                ),
                MetricTile(
                    id: "focus",
                    title: "Focus",
                    value: selectedPhase.reviewTitle,
                    systemImage: "target",
                    status: .good,
                    progress: 0.66
                ),
                MetricTile(
                    id: "stability",
                    title: "Stability",
                    value: stabilityScore.map(String.init) ?? "--",
                    systemImage: "figure.walk",
                    status: metricStatus(for: stabilityScore ?? 58),
                    progress: normalized(stabilityScore ?? 58)
                )
            ]
        }

        let domainData = GarageSwingDomain.allCases.compactMap { domain -> MetricTile? in
            guard let domainScore = scorecard.domainScores.first(where: { $0.id == domain.rawValue }) else {
                return nil
            }

            return MetricTile(
                id: domain.rawValue,
                title: coachingMetricTitle(for: domain),
                value: domainScore.displayValue,
                systemImage: coachingMetricIcon(for: domain),
                status: GarageCoachingMetricStatus(from: domainScore.grade),
                progress: normalized(domainScore.score)
            )
        }

        let reliabilityTile = MetricTile(
            id: "reliability",
            title: "Reliability",
            value: reliabilityStatus.rawValue.uppercased(),
            systemImage: "checkmark.shield",
            status: metricStatus(for: reliabilityStatus),
            progress: normalized(reliabilityStatus)
        )

        return Array((domainData + [reliabilityTile]).prefix(6))
    }

    private static func coachingMetricTitle(for domain: GarageSwingDomain) -> String {
        switch domain {
        case .tempo:
            "Tempo"
        case .spine:
            "Spine"
        case .pelvis:
            "Pelvis"
        case .knee:
            "Knees"
        case .head:
            "Head"
        }
    }

    private static func coachingMetricIcon(for domain: GarageSwingDomain) -> String {
        switch domain {
        case .tempo:
            "metronome"
        case .spine:
            "angle"
        case .pelvis:
            "arrow.left.and.right"
        case .knee:
            "figure.walk"
        case .head:
            "viewfinder.circle"
        }
    }

    private static func metricStatus(for score: Int) -> GarageCoachingMetricStatus {
        switch score {
        case 85...:
            .great
        case 70..<85:
            .good
        case 55..<70:
            .watch
        default:
            .bad
        }
    }

    private static func metricStatus(for reliabilityStatus: GarageReliabilityStatus) -> GarageCoachingMetricStatus {
        switch reliabilityStatus {
        case .trusted:
            .great
        case .review:
            .watch
        case .provisional:
            .bad
        }
    }

    private static func normalized(_ score: Int) -> Double {
        min(max(Double(score) / 100, 0), 1)
    }

    private static func normalized(_ reliabilityStatus: GarageReliabilityStatus) -> Double {
        switch reliabilityStatus {
        case .trusted:
            0.92
        case .review:
            0.68
        case .provisional:
            0.34
        }
    }
}

enum GarageCoachingMetricStatus: String, Equatable {
    case great
    case good
    case watch
    case bad

    init(from grade: GarageMetricGrade) {
        switch grade {
        case .excellent:
            self = .great
        case .good:
            self = .good
        case .fair:
            self = .watch
        case .needsWork:
            self = .bad
        }
    }
}

private func garageAspectFitRect(contentSize: CGSize, in container: CGRect) -> CGRect {
    guard contentSize.width > 0, contentSize.height > 0, container.width > 0, container.height > 0 else {
        return .zero
    }

    let scale = min(container.width / contentSize.width, container.height / contentSize.height)
    let scaledSize = CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
    let origin = CGPoint(
        x: container.midX - (scaledSize.width / 2),
        y: container.midY - (scaledSize.height / 2)
    )
    return CGRect(origin: origin, size: scaledSize)
}

private func garageMappedPoint(x: Double, y: Double, in rect: CGRect) -> CGPoint {
    CGPoint(
        x: rect.minX + (rect.width * x),
        y: rect.minY + (rect.height * y)
    )
}

private func garageMappedPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
    garageMappedPoint(x: point.x, y: point.y, in: rect)
}

private func garageNormalizedPoint(from location: CGPoint, in rect: CGRect) -> CGPoint? {
    guard rect.contains(location), rect.width > 0, rect.height > 0 else {
        return nil
    }

    let normalizedX = min(max((location.x - rect.minX) / rect.width, 0), 1)
    let normalizedY = min(max((location.y - rect.minY) / rect.height, 0), 1)
    return CGPoint(x: normalizedX, y: normalizedY)
}

private func garageClampedNormalizedPoint(_ point: CGPoint) -> CGPoint {
    CGPoint(
        x: min(max(point.x, 0), 1),
        y: min(max(point.y, 0), 1)
    )
}

private struct GarageScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct GarageFocusedReviewWorkspace: View {
    @Environment(\.modelContext) private var modelContext

    let record: SwingRecord
    let viewportHeight: CGFloat
    let onExitReview: () -> Void

    @State private var currentTime = 0.0
    @State private var reviewImage: CGImage?
    @State private var isLoadingFrame = false
    @State private var selectedPhase: SwingPhase = .address
    @State private var isShowingCompletionPlayback = false
    @State private var isShowingSkeletonPlayback = false
    @State private var reviewMode: GarageReviewMode = .handPath
    @State private var reviewSurface: GarageReviewSurface = .summary
    @State private var controlsScrollOffset: CGFloat = 0
    @State private var dragAnchorPoint: CGPoint?
    @State private var isDraggingAnchor = false
    @State private var isShowingMetadataEditor = false

    private var resolvedReviewVideo: GarageResolvedReviewVideo? {
        GarageMediaStore.resolvedReviewVideo(for: record)
    }

    private var reviewVideoURL: URL? {
        resolvedReviewVideo?.url
    }

    private var reviewFrameSource: GarageReviewFrameSourceState {
        GarageMediaStore.reviewFrameSource(for: record)
    }

    private var derivedPayload: GarageDerivedPayload? {
        record.presentationDerivedPayload
    }

    private var swingFrames: [SwingFrame] {
        derivedPayload?.swingFrames ?? record.derivedSwingFrames
    }

    private var keyFrames: [KeyFrame] {
        derivedPayload?.keyFrames ?? record.derivedKeyFrames
    }

    private var handAnchors: [HandAnchor] {
        derivedPayload?.handAnchors ?? record.derivedHandAnchors
    }

    private var pathPoints: [PathPoint] {
        derivedPayload?.pathPoints ?? record.derivedPathPoints
    }

    private var analysisResult: AnalysisResult? {
        derivedPayload?.analysisResult ?? record.derivedAnalysisResult
    }

    private var orderedKeyframes: [GarageTimelineMarker] {
        keyFrames
            .sorted { lhs, rhs in
                (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
            }
            .compactMap { keyFrame in
                guard swingFrames.indices.contains(keyFrame.frameIndex) else {
                    return nil
                }

                return GarageTimelineMarker(
                    keyFrame: keyFrame,
                    timestamp: swingFrames[keyFrame.frameIndex].timestamp
                )
            }
    }

    private var selectedMarker: GarageTimelineMarker? {
        orderedKeyframes.first(where: { $0.keyFrame.phase == selectedPhase })
    }

    private var selectedKeyFrame: KeyFrame? {
        keyFrames.first(where: { $0.phase == selectedPhase })
    }

    private var selectedCheckpointStatus: KeyframeValidationStatus {
        selectedKeyFrame?.reviewStatus ?? .pending
    }

    private var selectedAnchor: HandAnchor? {
        handAnchors.first(where: { $0.phase == selectedPhase })
    }

    private var predictedAnchorPoint: CGPoint? {
        if let dragAnchorPoint {
            return garageClampedNormalizedPoint(dragAnchorPoint)
        }

        if let currentFrame {
            if selectedKeyFrame?.frameIndex == currentFrameIndex, let selectedAnchor {
                return CGPoint(x: selectedAnchor.x, y: selectedAnchor.y)
            }

            return garageClampedNormalizedPoint(GarageAnalysisPipeline.handCenter(in: currentFrame))
        }

        if let selectedAnchor {
            return CGPoint(x: selectedAnchor.x, y: selectedAnchor.y)
        }

        return nil
    }

    private var displayedAnchorSource: HandAnchorSource {
        if dragAnchorPoint != nil {
            return .manual
        }

        if selectedKeyFrame?.frameIndex == currentFrameIndex, let selectedAnchor {
            return selectedAnchor.source
        }

        return .automatic
    }

    private var displayedAnchor: HandAnchor? {
        if let predictedAnchorPoint {
            return HandAnchor(
                phase: selectedPhase,
                x: predictedAnchorPoint.x,
                y: predictedAnchorPoint.y,
                source: displayedAnchorSource
            )
        }

        return nil
    }

    private var selectedAnchorTint: Color {
        displayedAnchor?.source == .manual ? garageManualAnchorAccent : selectedCheckpointStatus.reviewTint
    }

    private var currentFrameIndex: Int? {
        guard swingFrames.isEmpty == false else {
            return nil
        }

        return swingFrames.enumerated().min { lhs, rhs in
            abs(lhs.element.timestamp - currentTime) < abs(rhs.element.timestamp - currentTime)
        }?.offset
    }

    private var currentFrame: SwingFrame? {
        guard let currentFrameIndex, swingFrames.indices.contains(currentFrameIndex) else {
            return nil
        }

        return swingFrames[currentFrameIndex]
    }

    private var currentFrameTimestamp: Double? {
        currentFrame?.timestamp
    }

    private var stabilityScore: Int? {
        GarageStability.score(for: record)
    }

    private var handPathReviewReport: GarageHandPathReviewReport {
        GarageAnalysisPipeline.handPathReviewReport(for: swingFrames, keyFrames: keyFrames)
    }

    private var syncFlowReport: GarageSyncFlowReport? {
        analysisResult?.syncFlow
    }

    private var summaryPresentation: GarageReviewSummaryPresentation {
        GarageReviewSummaryPresentation.make(
            reviewMode: reviewMode,
            handPathReviewReport: handPathReviewReport,
            stabilityScore: stabilityScore,
            reviewFrameSource: reviewFrameSource,
            syncFlow: syncFlowReport
        )
    }

    private var swingScorecard: GarageSwingScorecard? {
        analysisResult?.scorecard
            ?? GarageScorecardEngine.generate(frames: swingFrames, keyFrames: keyFrames)
    }

    private var step2Presentation: GarageStep2Presentation {
        GarageStep2Presentation.make(scorecard: swingScorecard)
    }

    private var coachingPresentation: GarageCoachingPresentation {
        let reliabilityReport = GarageReliability.report(for: record)
        let coachingReport = GarageCoaching.report(for: record)

        return GarageCoachingPresentation.make(
            report: coachingReport,
            selectedPhase: selectedPhase,
            reliabilityStatus: reliabilityReport.status,
            scorecard: swingScorecard,
            stabilityScore: stabilityScore
        )
    }

    private var frameRequestID: String {
        [
            garageRecordSelectionKey(for: record),
            reviewVideoURL?.absoluteString ?? "no-video",
            String(format: "%.4f", currentFrameTimestamp ?? currentTime)
        ].joined(separator: "::")
    }

    private var fullHandPathSamples: [GarageHandPathSample] {
        garageHandPathSamples(from: swingFrames, keyFrames: keyFrames)
    }

    private var requiresFallbackReview: Bool {
        if record.allCheckpointsApproved || record.keyframeValidationStatus == .approved {
            return false
        }

        if record.keyframeValidationStatus == .flagged {
            return true
        }

        return handPathReviewReport.requiresManualReview
    }

    private var filmstripFrames: [GarageFilmstripFrame] {
        swingFrames.enumerated().map { index, frame in
            GarageFilmstripFrame(index: index, timestamp: frame.timestamp)
        }
    }

    private var reviewRecoveryTitle: String {
        switch reviewFrameSource {
        case .video:
            "Stored video recovered"
        case .poseFallback:
            "Pose fallback active"
        case .recoveryNeeded:
            "Review media needs recovery"
        }
    }

    private var reviewRecoveryBody: String {
        switch reviewFrameSource {
        case .video:
            if let origin = resolvedReviewVideo?.origin {
                return "Garage is rendering this checkpoint from the recovered \(origin.rawValue.replacingOccurrences(of: "Storage", with: " storage").replacingOccurrences(of: "Bookmark", with: " bookmark")) source."
            }
            return "Garage found a stored review video for this checkpoint."
        case .poseFallback:
            return "Stored footage is missing, so Garage is showing sampled pose data instead. Re-import this swing if you need the original video visuals."
        case .recoveryNeeded:
            return "Neither stored footage nor fallback-ready pose frames are available yet. Re-import this swing to restore full checkpoint review."
        }
    }

    private var videoStageHeight: CGFloat {
        min(max(viewportHeight * 0.55, 460), 540)
    }

    private var collapsedVideoHeight: CGFloat {
        min(max(viewportHeight * 0.34, 300), 360)
    }

    private var videoCollapseProgress: CGFloat {
        let range = max(videoStageHeight - collapsedVideoHeight, 1)
        return min(max(-controlsScrollOffset / range, 0), 1)
    }

    private var activeVideoHeight: CGFloat {
        videoStageHeight - ((videoStageHeight - collapsedVideoHeight) * videoCollapseProgress)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GarageFocusedReviewFrame(
                image: reviewImage,
                isLoadingFrame: isLoadingFrame,
                currentFrame: currentFrame,
                currentFrameIndex: currentFrameIndex,
                totalFrameCount: swingFrames.count,
                selectedAnchor: displayedAnchor,
                highlightTint: selectedAnchorTint,
                showsAnchorGuides: isDraggingAnchor,
                reviewMode: reviewMode,
                reviewSurface: reviewSurface,
                handPathSamples: fullHandPathSamples,
                currentTime: currentFrameTimestamp ?? currentTime,
                syncFlow: syncFlowReport,
                summaryPresentation: summaryPresentation,
                preferredHeight: activeVideoHeight,
                onSelectReviewMode: selectReviewMode,
                onAnchorDragChanged: handleAnchorDragChanged,
                onAnchorDragEnded: handleAnchorDragEnded
            )
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topLeading) {
                Button(action: onExitReview) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(garageReviewReadableText)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel("Back")
                .accessibilityHint("Returns to the previous screen")
                .accessibilityLabel("Back")
                .accessibilityHint("Exit review")
                .buttonStyle(.plain)
                .padding(.leading, 12)
                .padding(.top, 12)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    isShowingMetadataEditor = true
                } label: {
                    Label("Meta", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(garageReviewReadableText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.42), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .padding(.top, reviewSurface == .summary ? 54 : 12)
            }
            ScrollView(.vertical, showsIndicators: false) {
                Color.clear
                    .frame(height: 0)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: GarageScrollOffsetKey.self,
                                value: proxy.frame(in: .named("garage-review-controls-scroll")).minY
                            )
                        }
                    )

                if reviewSurface == .fallbackHandPath {
                    GarageReviewScrollableControls(
                        markers: orderedKeyframes,
                        selectedPhase: selectedPhase,
                        currentFrameIndex: currentFrameIndex,
                        totalFrameCount: swingFrames.count,
                        onSelectPhase: selectPhase,
                        reviewRecoveryTitle: reviewRecoveryTitle,
                        reviewRecoveryBody: reviewRecoveryBody,
                        reviewFrameSource: reviewFrameSource
                    )
                } else {
                    GarageReviewSummaryControls(
                        summaryPresentation: summaryPresentation,
                        step2Presentation: step2Presentation,
                        coachingPresentation: coachingPresentation,
                        reviewRecoveryTitle: reviewRecoveryTitle,
                        reviewRecoveryBody: reviewRecoveryBody,
                        reviewFrameSource: reviewFrameSource
                    )
                }
            }
            .coordinateSpace(name: "garage-review-controls-scroll")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onPreferenceChange(GarageScrollOffsetKey.self) { newValue in
                controlsScrollOffset = newValue
            }
        }
        .padding(.horizontal, ModuleSpacing.large)
        .padding(.top, 8)
        .background(garageReviewBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if reviewSurface == .fallbackHandPath {
                GarageReviewActionDock(
                    canStepBackward: canStepBackward,
                    canStepForward: canStepForward,
                    canConfirm: primaryActionEnabled,
                    onStepBackward: { stepFrame(by: -1) },
                    onStepForward: { stepFrame(by: 1) },
                    onConfirm: confirmSelectionAndAdvance
                )
            } else {
                GarageSummaryPrimaryActionBar(
                    canContinue: reviewVideoURL != nil,
                    onContinue: {
                        isShowingCompletionPlayback = true
                    },
                    onSkeletonReview: {
                        isShowingSkeletonPlayback = true
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingCompletionPlayback) {
            if let reviewVideoURL {
                GarageSlowMotionPlaybackSheet(
                    videoURL: reviewVideoURL,
                    pathSamples: fullHandPathSamples,
                    frames: swingFrames,
                    syncFlow: syncFlowReport,
                    initialMode: .handPath
                )
            }
        }
        .sheet(isPresented: $isShowingMetadataEditor) {
            GarageRecordMetadataEditorSheet(record: record)
        }
        .sheet(isPresented: $isShowingSkeletonPlayback) {
            if let reviewVideoURL {
                GarageSkeletonReviewView(
                    videoURL: reviewVideoURL,
                    pathSamples: fullHandPathSamples,
                    frames: swingFrames,
                    syncFlow: syncFlowReport
                )
            }
        }
        .task(id: garageRecordSelectionKey(for: record)) {
            record.hydrateCheckpointStatusesFromAggregateIfNeeded()
            record.refreshKeyframeValidationStatus()
            applyAutomaticHandPathApprovalIfNeeded()
            syncReviewSession()
        }
        .task(id: frameRequestID) {
            await loadFrameImage()
        }
        .onChange(of: selectedPhase) { _, _ in
            dragAnchorPoint = nil
            isDraggingAnchor = false
        }
    }

    private func loadFrameImage() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        guard Task.isCancelled == false else {
            return
        }

        guard let reviewVideoURL else {
            await MainActor.run {
                reviewImage = nil
                isLoadingFrame = false
            }
            return
        }

        await MainActor.run {
            isLoadingFrame = true
        }

        guard Task.isCancelled == false else {
            await MainActor.run {
                isLoadingFrame = false
            }
            return
        }

        let image = await GarageMediaStore.thumbnail(
            for: reviewVideoURL,
            at: currentFrameTimestamp ?? currentTime,
            maximumSize: CGSize(width: 1100, height: 1100),
            priority: .high,
            exactFrame: true
        )

        await MainActor.run {
            reviewImage = image
            isLoadingFrame = false
        }
    }

    private func seekToSelectedCheckpoint() {
        if let selectedMarker {
            currentTime = selectedMarker.timestamp
        } else if let firstTimestamp = swingFrames.first?.timestamp {
            currentTime = firstTimestamp
        } else {
            currentTime = 0
        }
    }

    private var canStepBackward: Bool {
        guard let currentFrameIndex else { return false }
        return currentFrameIndex > 0
    }

    private var canStepForward: Bool {
        guard let currentFrameIndex else { return false }
        return currentFrameIndex < swingFrames.count - 1
    }

    private var primaryActionEnabled: Bool {
        displayedAnchor != nil && currentFrameIndex != nil
    }

    private func stepFrame(by offset: Int) {
        let baseIndex = currentFrameIndex ?? 0
        setCurrentFrameIndex(baseIndex + offset)
    }

    private func setCurrentFrameIndex(_ index: Int) {
        guard swingFrames.isEmpty == false else { return }
        let clampedIndex = min(max(index, 0), swingFrames.count - 1)
        currentTime = swingFrames[clampedIndex].timestamp
        if reviewSurface == .summary, let nearestPhase = nearestPhase(for: clampedIndex) {
            selectedPhase = nearestPhase
        }
    }

    private func selectReviewMode(_ mode: GarageReviewMode) {
        guard reviewSurface == .summary else { return }
        reviewMode = mode
    }

    private func selectPhase(_ phase: SwingPhase) {
        selectedPhase = phase
        seekToSelectedCheckpoint()
    }

    private func handleAnchorDragChanged(_ point: CGPoint) {
        dragAnchorPoint = garageClampedNormalizedPoint(point)
        isDraggingAnchor = true
    }

    private func handleAnchorDragEnded(_ point: CGPoint) {
        let clampedPoint = garageClampedNormalizedPoint(point)
        dragAnchorPoint = clampedPoint
        isDraggingAnchor = false
        persistSelection(
            point: clampedPoint,
            anchorSource: .manual,
            reviewStatus: .pending,
            forceAdjustedKeyframe: true
        )
        dragAnchorPoint = nil
    }

    private func confirmSelectionAndAdvance() {
        guard let point = predictedAnchorPoint else { return }

        let anchorSource: HandAnchorSource
        if displayedAnchorSource == .manual || selectedAnchor?.source == .manual {
            anchorSource = .manual
        } else {
            anchorSource = .automatic
        }

        persistSelection(
            point: point,
            anchorSource: anchorSource,
            reviewStatus: .approved,
            forceAdjustedKeyframe: false
        )

        if let nextPhase = nextNonApprovedPhase(after: selectedPhase) {
            selectedPhase = nextPhase
            seekToSelectedCheckpoint()
        } else {
            transitionToSummaryReview()
        }
    }

    private func persistSelection(
        point: CGPoint,
        anchorSource: HandAnchorSource,
        reviewStatus: KeyframeValidationStatus,
        forceAdjustedKeyframe: Bool
    ) {
        guard let currentFrameIndex else { return }

        let clampedPoint = garageClampedNormalizedPoint(point)
        let existingKeyframe = record.keyFrames.first(where: { $0.phase == selectedPhase })
        let needsAdjustedSource = forceAdjustedKeyframe || existingKeyframe?.frameIndex != currentFrameIndex
        let keyframeSource: KeyFrameSource = needsAdjustedSource ? .adjusted : (existingKeyframe?.source ?? .automatic)

        if let keyframeIndex = record.keyFrames.firstIndex(where: { $0.phase == selectedPhase }) {
            record.keyFrames[keyframeIndex].frameIndex = currentFrameIndex
            record.keyFrames[keyframeIndex].source = keyframeSource
            record.keyFrames[keyframeIndex].reviewStatus = reviewStatus
        } else {
            record.keyFrames.append(
                KeyFrame(
                    phase: selectedPhase,
                    frameIndex: currentFrameIndex,
                    source: keyframeSource,
                    reviewStatus: reviewStatus
                )
            )
        }

        record.keyFrames.sort { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }

        var mergedAnchors = GarageAnalysisPipeline.mergedHandAnchors(
            preserving: record.handAnchors,
            from: swingFrames,
            keyFrames: record.keyFrames
        )
        mergedAnchors = GarageAnalysisPipeline.upsertingHandAnchor(
            HandAnchor(
                phase: selectedPhase,
                x: clampedPoint.x,
                y: clampedPoint.y,
                source: anchorSource
            ),
            into: mergedAnchors
        )

        record.handAnchors = mergedAnchors
        record.pathPoints = GarageAnalysisPipeline.generatePathPoints(from: record.handAnchors, samplesPerSegment: 16)
        record.refreshKeyframeValidationStatus()
        syncDerivedPayloadFromLegacy()
        try? modelContext.save()
    }

    private func initialPhaseSelection() -> SwingPhase {
        let availablePhases = Set(orderedKeyframes.map(\.keyFrame.phase))

        for phase in SwingPhase.allCases where availablePhases.contains(phase) && record.reviewStatus(for: phase) != .approved {
            return phase
        }

        return orderedKeyframes.first?.keyFrame.phase ?? .address
    }

    private func nextNonApprovedPhase(after phase: SwingPhase) -> SwingPhase? {
        let availablePhases = SwingPhase.allCases.filter { phase in
            orderedKeyframes.contains(where: { $0.keyFrame.phase == phase })
        }

        guard let currentIndex = availablePhases.firstIndex(of: phase) else {
            return availablePhases.first(where: { record.reviewStatus(for: $0) != .approved })
        }

        if currentIndex + 1 < availablePhases.count {
            for candidate in availablePhases[(currentIndex + 1)...] where record.reviewStatus(for: candidate) != .approved {
                return candidate
            }
        }

        return availablePhases.first(where: { record.reviewStatus(for: $0) != .approved })
    }

    private func applyAutomaticHandPathApprovalIfNeeded() {
        guard record.keyFrames.isEmpty == false, requiresFallbackReview == false else {
            return
        }

        let autoApprovedKeyFrames = GarageAnalysisPipeline.autoApprovedKeyFrames(
            from: record.keyFrames,
            reviewReport: handPathReviewReport
        )
        guard autoApprovedKeyFrames != record.keyFrames || record.keyframeValidationStatus != .approved else {
            return
        }

        record.keyFrames = autoApprovedKeyFrames
        record.refreshKeyframeValidationStatus()
        syncDerivedPayloadFromLegacy()
        try? modelContext.save()
    }

    private func syncDerivedPayloadFromLegacy() {
        record.persistDerivedPayload(
            GarageDerivedPayload(
                frameRate: record.frameRate,
                swingFrames: record.swingFrames,
                keyFrames: record.keyFrames,
                handAnchors: record.handAnchors,
                pathPoints: record.pathPoints,
                analysisResult: analysisResult
            )
        )
    }

    private func syncReviewSession() {
        reviewSurface = requiresFallbackReview ? .fallbackHandPath : .summary
        reviewMode = .handPath

        if reviewSurface == .fallbackHandPath {
            selectedPhase = handPathReviewReport.weakestPhase ?? initialPhaseSelection()
            seekToSelectedCheckpoint()
            return
        }

        selectedPhase = initialPhaseSelection()
        seekToSelectedCheckpoint()
    }

    private func transitionToSummaryReview() {
        reviewSurface = .summary
        reviewMode = .handPath
        selectedPhase = nearestPhase(for: currentFrameIndex ?? 0) ?? .impact
    }

    private func nearestPhase(for frameIndex: Int) -> SwingPhase? {
        orderedKeyframes.min { lhs, rhs in
            abs(lhs.keyFrame.frameIndex - frameIndex) < abs(rhs.keyFrame.frameIndex - frameIndex)
        }?.keyFrame.phase
    }
}

private struct GarageReviewScrollableControls: View {
    let markers: [GarageTimelineMarker]
    let selectedPhase: SwingPhase
    let currentFrameIndex: Int?
    let totalFrameCount: Int
    let onSelectPhase: (SwingPhase) -> Void
    let reviewRecoveryTitle: String
    let reviewRecoveryBody: String
    let reviewFrameSource: GarageReviewFrameSourceState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GarageCheckpointProgressStrip(
                selectedPhase: selectedPhase,
                markers: markers,
                onSelect: onSelectPhase
            )

            HStack {
                Spacer(minLength: 0)
                Text(frameCountLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(garageReviewMutedText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if reviewFrameSource != .video {
                GarageReviewRecoveryCallout(
                    title: reviewRecoveryTitle,
                    message: reviewRecoveryBody,
                    state: reviewFrameSource
                )
            }
        }
        .padding(.horizontal, ModuleSpacing.medium)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                fill: garageReviewSurface
            )
        )
    }

    private var frameCountLabel: String {
        guard let currentFrameIndex else {
            return "\(totalFrameCount) frames"
        }

        return "\(currentFrameIndex + 1) / \(totalFrameCount) frames"
    }
}

private struct GarageReviewSummaryControls: View {
    let summaryPresentation: GarageReviewSummaryPresentation
    let step2Presentation: GarageStep2Presentation
    let coachingPresentation: GarageCoachingPresentation
    let reviewRecoveryTitle: String
    let reviewRecoveryBody: String
    let reviewFrameSource: GarageReviewFrameSourceState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageReviewContextBand(presentation: summaryPresentation)

            switch step2Presentation {
            case let .ready(score, metrics):
                GarageStep2ScoreSummaryCard(presentation: score)
                if metrics.isEmpty == false {
                    GarageStep2MetricGrid(metrics: metrics)
                }
                if metrics.isEmpty == false {
                    GarageCoachingReportView(presentation: coachingPresentation)
                }
            case let .unavailable(presentation):
                GarageStep2UnavailableCard(presentation: presentation)
                GarageCoachingReportView(presentation: coachingPresentation)
            }
            if reviewFrameSource != .video {
                GarageReviewRecoveryCallout(
                    title: reviewRecoveryTitle,
                    message: reviewRecoveryBody,
                    state: reviewFrameSource
                )
            }

        }
        .padding(.bottom, 12)
    }
}

private struct GarageReviewContextBand: View {
    let presentation: GarageReviewSummaryPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(presentation.reviewTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(garageReviewReadableText)

            Text(presentation.reviewSubtitle)
                .font(.subheadline)
                .foregroundStyle(garageReviewMutedText)

            Text(presentation.poseQuality.badgeText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(presentation.poseQuality.tint)

            if let poseQualityDetail = presentation.poseQualityDetail {
                Text(poseQualityDetail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(garageReviewMutedText.opacity(0.95))
            }
        }
        .padding(16)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous),
                fill: garageReviewSurfaceRaised,
                stroke: garageReviewStroke.opacity(0.8)
            )
        )
    }
}


private struct GarageReviewActionDock: View {
    let canStepBackward: Bool
    let canStepForward: Bool
    let canConfirm: Bool
    let onStepBackward: () -> Void
    let onStepForward: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        GarageDockSurface {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    GarageFrameStepButton(
                        accessibilityLabel: "Previous frame",
                        systemImage: "chevron.left",
                        isEnabled: canStepBackward,
                        action: onStepBackward
                    )

                    GarageFrameStepButton(
                        accessibilityLabel: "Next frame",
                        systemImage: "chevron.right",
                        isEnabled: canStepForward,
                        action: onStepForward
                    )
                }
                .padding(6)
                .background(
                    GarageInsetPanelBackground(
                        shape: Capsule(),
                        fill: garageReviewSurfaceDark,
                        stroke: garageReviewStroke.opacity(0.85)
                    )
                )

                GarageDockWideButton(
                    title: "Confirm Frame",
                    systemImage: "checkmark.circle.fill",
                    isPrimary: true,
                    isEnabled: canConfirm,
                    action: onConfirm
                )
            }
        }
    }
}

private struct GarageSummaryPrimaryActionBar: View {
    let canContinue: Bool
    let onContinue: () -> Void
    let onSkeletonReview: () -> Void

    var body: some View {
        GarageDockSurface {
            GarageDockWideButton(
                title: canContinue ? "Review Hand Path" : "Slow Motion Review Unavailable",
                systemImage: canContinue ? "play.fill" : "exclamationmark.triangle.fill",
                isPrimary: true,
                isEnabled: canContinue,
                action: onContinue
            )

            GarageDockWideButton(
                title: "Review SyncFlow",
                systemImage: "figure.walk",
                isPrimary: false,
                isEnabled: canContinue,
                action: onSkeletonReview
            )
        }
    }
}

private struct GarageDockSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 12) {
            content
        }
        .padding(.horizontal, ModuleSpacing.large)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                fill: garageReviewSurface
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(garageReviewStroke.opacity(0.92))
                    .frame(height: 1)
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [garageReviewShadowLight.opacity(0.22), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct GarageDockWideButton: View {
    let title: String
    let systemImage: String
    let isPrimary: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(buttonBackground)
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
        .opacity(isEnabled ? 1 : 0.7)
    }

    private var foregroundStyle: Color {
        if isEnabled == false {
            return garageReviewMutedText
        }

        return isPrimary ? garageReviewCanvasFill : garageReviewReadableText
    }

    @ViewBuilder
    private var buttonBackground: some View {
        GarageRaisedPanelBackground(
            shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
            fill: isPrimary
                ? garageReviewAccent
                : (isEnabled ? garageReviewSurfaceRaised : garageReviewSurfaceDark),
            stroke: isPrimary
                ? garageReviewAccent.opacity(0.42)
                : garageReviewStroke.opacity(isEnabled ? 0.95 : 0.6),
            glow: isPrimary && isEnabled ? garageReviewAccent : nil
        )
    }
}

private struct GarageReviewFilmstrip: View {
    let videoURL: URL?
    let frames: [GarageFilmstripFrame]
    let markers: [GarageTimelineMarker]
    let currentFrameIndex: Int?
    let onSelectFrame: (Int) -> Void

    private var priorityIndexes: Set<Int> {
        let selectedIndex = currentFrameIndex ?? 0
        let neighborhood = max(0, selectedIndex - 8)...min(frames.count - 1, selectedIndex + 8)
        var indexes = Set(neighborhood)
        markers.forEach { indexes.insert($0.keyFrame.frameIndex) }
        return indexes
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(frames) { frame in
                        GarageReviewFilmstripThumbnail(
                            videoURL: videoURL,
                            frame: frame,
                            isSelected: frame.index == currentFrameIndex,
                            isKeyframe: markers.contains(where: { $0.keyFrame.frameIndex == frame.index }),
                            shouldLoadImmediately: priorityIndexes.contains(frame.index),
                            onSelect: {
                                onSelectFrame(frame.index)
                            }
                        )
                        .id(frame.index)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
            }
            .frame(height: 72)
            .onAppear {
                guard let currentFrameIndex else { return }
                proxy.scrollTo(currentFrameIndex, anchor: .center)
            }
            .onChange(of: currentFrameIndex) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .task(id: prefetchKey) {
                await prefetchPriorityThumbnails()
            }
        }
    }

    private var prefetchKey: String {
        "\(videoURL?.absoluteString ?? "no-video")::\(currentFrameIndex ?? -1)"
    }

    private func prefetchPriorityThumbnails() async {
        guard let videoURL else { return }

        let prioritizedFrames = frames.filter { priorityIndexes.contains($0.index) }
        guard prioritizedFrames.isEmpty == false else { return }

        let requests = prioritizedFrames.map {
            GarageThumbnailRequest(
                timestamp: $0.timestamp,
                maximumSize: CGSize(width: 132, height: 180)
            )
        }
        await GarageMediaStore.prefetchThumbnails(
            for: videoURL,
            requests: requests,
            priority: .low
        )
    }
}

private struct GarageReviewFilmstripThumbnail: View {
    let videoURL: URL?
    let frame: GarageFilmstripFrame
    let isSelected: Bool
    let isKeyframe: Bool
    let shouldLoadImmediately: Bool
    let onSelect: () -> Void

    @State private var image: CGImage?

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(garageReviewInsetSurface)

                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "video")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(garageReviewMutedText)
                        Text("\(frame.index + 1)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(garageReviewMutedText)
                    }
                    .frame(width: 48, height: 68)
                }

                if isKeyframe {
                    Circle()
                        .fill(garageReviewAccent)
                        .frame(width: 8, height: 8)
                        .padding(6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected
                            ? garageReviewAccent
                            : garageReviewReadableText.opacity(isKeyframe ? 0.18 : 0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? garageReviewAccent.opacity(0.32) : garageReviewShadow,
                radius: isSelected ? 10 : 4,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(.plain)
        .task(id: requestKey) {
            await loadThumbnail()
        }
    }

    private var requestKey: String {
        [
            videoURL?.absoluteString ?? "no-video",
            String(frame.index),
            String(format: "%.4f", frame.timestamp)
        ].joined(separator: "::")
    }

    private func loadThumbnail() async {
        guard let videoURL else {
            await MainActor.run {
                image = nil
            }
            return
        }

        if shouldLoadImmediately == false {
            try? await Task.sleep(nanoseconds: 180_000_000)
        }

        let thumbnail = await GarageMediaStore.thumbnail(
            for: videoURL,
            at: frame.timestamp,
            maximumSize: CGSize(width: 132, height: 180),
            priority: isSelected ? .high : (shouldLoadImmediately ? .normal : .low)
        )

        guard Task.isCancelled == false else { return }

        await MainActor.run {
            image = thumbnail
        }
    }
}

private struct GarageFocusedReviewFrame: View {
    let image: CGImage?
    let isLoadingFrame: Bool
    let currentFrame: SwingFrame?
    let currentFrameIndex: Int?
    let totalFrameCount: Int
    let selectedAnchor: HandAnchor?
    let highlightTint: Color
    let showsAnchorGuides: Bool
    let reviewMode: GarageReviewMode
    let reviewSurface: GarageReviewSurface
    let handPathSamples: [GarageHandPathSample]
    let currentTime: Double
    let syncFlow: GarageSyncFlowReport?
    let summaryPresentation: GarageReviewSummaryPresentation
    let preferredHeight: CGFloat
    let onSelectReviewMode: (GarageReviewMode) -> Void
    let onAnchorDragChanged: (CGPoint) -> Void
    let onAnchorDragEnded: (CGPoint) -> Void

    init(
        image: CGImage?,
        isLoadingFrame: Bool,
        currentFrame: SwingFrame?,
        currentFrameIndex: Int?,
        totalFrameCount: Int,
        selectedAnchor: HandAnchor?,
        highlightTint: Color,
        showsAnchorGuides: Bool,
        reviewMode: GarageReviewMode,
        reviewSurface: GarageReviewSurface,
        handPathSamples: [GarageHandPathSample],
        currentTime: Double,
        syncFlow: GarageSyncFlowReport?,
        summaryPresentation: GarageReviewSummaryPresentation,
        preferredHeight: CGFloat,
        onSelectReviewMode: @escaping (GarageReviewMode) -> Void,
        onAnchorDragChanged: @escaping (CGPoint) -> Void,
        onAnchorDragEnded: @escaping (CGPoint) -> Void
    ) {
        self.image = image
        self.isLoadingFrame = isLoadingFrame
        self.currentFrame = currentFrame
        self.currentFrameIndex = currentFrameIndex
        self.totalFrameCount = totalFrameCount
        self.selectedAnchor = selectedAnchor
        self.highlightTint = highlightTint
        self.showsAnchorGuides = showsAnchorGuides
        self.reviewMode = reviewMode
        self.reviewSurface = reviewSurface
        self.handPathSamples = handPathSamples
        self.currentTime = currentTime
        self.syncFlow = syncFlow
        self.summaryPresentation = summaryPresentation
        self.preferredHeight = preferredHeight
        self.onSelectReviewMode = onSelectReviewMode
        self.onAnchorDragChanged = onAnchorDragChanged
        self.onAnchorDragEnded = onAnchorDragEnded
    }

    var body: some View {
        let limitedSkeletonInspection = reviewSurface == .summary
            && reviewMode == .skeleton
            && summaryPresentation.poseQuality == .limited

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(garageReviewCanvasFill)

            if let image {
                GarageReviewImageOverlay(
                    image: image,
                    currentFrame: currentFrame,
                    currentFrameIndex: currentFrameIndex,
                    totalFrameCount: totalFrameCount,
                    selectedAnchor: selectedAnchor,
                    highlightTint: highlightTint,
                    showsAnchorGuides: showsAnchorGuides,
                    reviewMode: reviewMode,
                    reviewSurface: reviewSurface,
                    handPathSamples: handPathSamples,
                    currentTime: currentTime,
                    syncFlow: syncFlow,
                    skeletonOverlayOpacity: limitedSkeletonInspection ? 0.72 : 1,
                    onAnchorDragChanged: onAnchorDragChanged,
                    onAnchorDragEnded: onAnchorDragEnded
                )
            } else if let currentFrame {
                GaragePoseFallbackOverlay(
                    currentFrame: currentFrame,
                    currentFrameIndex: currentFrameIndex,
                    totalFrameCount: totalFrameCount,
                    selectedAnchor: selectedAnchor,
                    highlightTint: highlightTint,
                    showsAnchorGuides: showsAnchorGuides,
                    reviewMode: reviewMode,
                    reviewSurface: reviewSurface,
                    handPathSamples: handPathSamples,
                    currentTime: currentTime,
                    syncFlow: syncFlow,
                    skeletonOverlayOpacity: limitedSkeletonInspection ? 0.72 : 1,
                    onAnchorDragChanged: onAnchorDragChanged,
                    onAnchorDragEnded: onAnchorDragEnded
                )
            } else {
                VStack(spacing: ModuleSpacing.small) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                    Text("Review frame unavailable")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    Text("Re-import the swing to restore video review for this checkpoint.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isLoadingFrame {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppModule.garage.theme.primary)
                    .padding()
                    .background(
                        GarageRaisedPanelBackground(
                            shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                            fill: garageReviewSurfaceRaised,
                            glow: garageReviewAccent.opacity(0.5)
                        )
                    )
            }
        }
        .overlay(alignment: .topTrailing) {
            if reviewSurface == .summary {
                GarageReviewModeSwitcher(
                    selectedMode: reviewMode,
                    onSelect: onSelectReviewMode
                )
                .padding(.trailing, 14)
                .padding(.top, 14)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(garageReviewStroke.opacity(0.95), lineWidth: 1)
        )
        .shadow(color: garageReviewShadowDark.opacity(0.34), radius: 20, x: 0, y: 12)
        .frame(height: preferredHeight)
        .frame(maxWidth: .infinity)
    }
}

private struct GarageReviewModeSwitcher: View {
    let selectedMode: GarageReviewMode
    let onSelect: (GarageReviewMode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(GarageReviewMode.allCases) { mode in
                let isSelected = mode == selectedMode
                Button {
                    onSelect(mode)
                } label: {
                    Text(mode.title)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(isSelected ? garageReviewReadableText : garageReviewMutedText)
                        .frame(minHeight: 24)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? garageReviewAccent.opacity(0.16) : Color.black.opacity(0.35))
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            isSelected ? garageReviewAccent.opacity(0.42) : garageReviewStroke.opacity(0.4),
                                            lineWidth: 1
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.28), in: Capsule())
    }
}

private struct GarageStabilityMetricCard: View {
    let presentation: GarageReviewSummaryPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.stabilityTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)

                    Text(presentation.stabilitySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(garageReviewMutedText)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(presentation.stabilityStatusText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(garageReviewMutedText)

                    if let stabilityValueText = presentation.stabilityValueText {
                        Text(stabilityValueText)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(garageReviewReadableText)
                    } else {
                        Text("Stability unavailable")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(garageReviewReadableText)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            if let stabilityDetail = presentation.stabilityDetail {
                Text(stabilityDetail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(garageReviewMutedText)
            }
        }
        .padding(16)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                fill: garageReviewSurfaceRaised,
                stroke: garageReviewStroke
            )
        )
    }
}

private struct GarageStep2ScoreSummaryCard: View {
    let presentation: GarageStep2ScorePresentation

    private var status: GarageCoachingMetricStatus {
        guard let numericScore = Int(presentation.scoreValue) else {
            return .watch
        }

        switch numericScore {
        case 85...:
            return .great
        case 70..<85:
            return .good
        case 55..<70:
            return .watch
        default:
            return .bad
        }
    }

    private var statusLabel: String {
        switch status {
        case .great:
            "GREAT"
        case .good:
            "GOOD"
        case .watch:
            "WATCH"
        case .bad:
            "BAD"
        }
    }

    private var statusTint: Color {
        switch status {
        case .great:
            Color(hex: "#4DDE8E")
        case .good:
            Color(hex: "#1AD0C8")
        case .watch:
            Color(hex: "#FFCE52")
        case .bad:
            Color(hex: "#FF5F63")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)
                    Text(presentation.subtitle)
                        .font(.caption)
                        .foregroundStyle(garageReviewMutedText)
                }

                Spacer(minLength: 0)

                Text(statusLabel)
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(statusTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(statusTint.opacity(0.10))
                            .overlay(
                                Capsule()
                                    .stroke(statusTint.opacity(0.28), lineWidth: 0.5)
                            )
                    )
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(presentation.scoreValue)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(ModuleTheme.electricCyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .shadow(color: ModuleTheme.electricCyan.opacity(0.24), radius: 12, x: 0, y: 0)

                Text(presentation.scoreLimit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewMutedText)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                fill: garageReviewSurfaceRaised,
                stroke: garageReviewStroke
            )
        )
    }
}

private struct GarageStep2MetricGrid: View {
    let metrics: [GarageStep2MetricPresentation]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(metricRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(row) { metric in
                        GarageStep2MetricCard(metric: metric)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var metricRows: [[GarageStep2MetricPresentation]] {
        metrics.garageChunked(into: 2)
    }
}

private struct GarageStep2MetricCard: View {
    let metric: GarageStep2MetricPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(metric.grade.tint)
                        .frame(width: 7, height: 7)

                    Text(metric.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(garageReviewMutedText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(metric.grade.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(metric.grade.tint.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(metric.grade.tint.opacity(0.10))
                            .overlay(
                                Capsule()
                                    .stroke(metric.grade.tint.opacity(0.18), lineWidth: 1)
                            )
                    )
            }

            Text(metric.value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(garageReviewReadableText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GarageInsetPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous),
                fill: garageReviewInsetSurface,
                stroke: metric.grade.tint.opacity(0.2)
            )
        )
    }
}

private struct GarageStep2UnavailableCard: View {
    let presentation: GarageStep2UnavailablePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(presentation.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(garageReviewReadableText)
            Text(presentation.message)
                .font(.caption)
                .foregroundStyle(garageReviewMutedText)
        }
        .padding(14)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                fill: garageReviewSurfaceRaised,
                stroke: garageReviewStroke
            )
        )
    }
}

private extension GarageMetricGrade {
    var tint: Color {
        switch self {
        case .excellent:
            Color(red: 0.31, green: 0.78, blue: 0.53)
        case .good:
            Color(red: 0.37, green: 0.72, blue: 0.93)
        case .fair:
            Color(red: 0.89, green: 0.71, blue: 0.32)
        case .needsWork:
            Color(red: 0.86, green: 0.44, blue: 0.44)
        }
    }
}

private extension Array {
    func garageChunked(into size: Int) -> [[Element]] {
        guard size > 0, isEmpty == false else { return [] }

        return stride(from: 0, to: count, by: size).map { index in
            Array(self[index..<Swift.min(index + size, count)])
        }
    }
}

private struct GarageReviewImageOverlay: View {
    let image: CGImage
    let currentFrame: SwingFrame?
    let currentFrameIndex: Int?
    let totalFrameCount: Int
    let selectedAnchor: HandAnchor?
    let highlightTint: Color
    let showsAnchorGuides: Bool
    let reviewMode: GarageReviewMode
    let reviewSurface: GarageReviewSurface
    let handPathSamples: [GarageHandPathSample]
    let currentTime: Double
    let syncFlow: GarageSyncFlowReport?
    let skeletonOverlayOpacity: Double
    let onAnchorDragChanged: (CGPoint) -> Void
    let onAnchorDragEnded: (CGPoint) -> Void

    var body: some View {
        GeometryReader { proxy in
            let containerRect = CGRect(origin: .zero, size: proxy.size)
            let imageRect = garageAspectFitRect(
                contentSize: CGSize(width: image.width, height: image.height),
                in: containerRect
            )

            ZStack {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)

                if reviewMode == .skeleton {
                    GarageSkeletonOverlay(
                        drawSize: imageRect.size,
                        currentFrame: currentFrame,
                        currentTime: currentTime,
                        pulseProgress: pulseProgress,
                        syncFlow: syncFlow
                    )
                    .opacity(skeletonOverlayOpacity)
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
                    .allowsHitTesting(false)
                }

                if reviewMode == .handPath, reviewSurface == .summary {
                    GarageVelocityRibbonOverlay(
                        drawRect: imageRect,
                        pathSamples: handPathSamples,
                        currentTime: currentTime
                    )
                    .allowsHitTesting(false)
                }

                if reviewMode == .handPath, reviewSurface == .fallbackHandPath {
                    GarageReviewFrameOverlayCanvas(
                        drawRect: imageRect,
                        selectedAnchor: selectedAnchor,
                        highlightTint: highlightTint,
                        showsAnchorGuides: showsAnchorGuides
                    )

                    if let selectedAnchor {
                        GarageInteractiveAnchorHandle(
                            drawRect: imageRect,
                            anchorPoint: CGPoint(x: selectedAnchor.x, y: selectedAnchor.y),
                            tint: highlightTint,
                            isManualAnchor: selectedAnchor.source == .manual,
                            onDragChanged: onAnchorDragChanged,
                            onDragEnded: onAnchorDragEnded
                        )
                    }

                    if showsAnchorGuides, let selectedAnchor {
                        GaragePrecisionLoupe(
                            image: image,
                            drawRect: imageRect,
                            anchorPoint: CGPoint(x: selectedAnchor.x, y: selectedAnchor.y)
                        )
                    }
                }
            }
        }
    }

    private var pulseProgress: Double {
        guard let currentFrameIndex else { return 0 }
        return min(max(Double(currentFrameIndex) / Double(max(totalFrameCount - 1, 1)), 0), 1)
    }
}

private struct GaragePoseFallbackOverlay: View {
    let currentFrame: SwingFrame
    let currentFrameIndex: Int?
    let totalFrameCount: Int
    let selectedAnchor: HandAnchor?
    let highlightTint: Color
    let showsAnchorGuides: Bool
    let reviewMode: GarageReviewMode
    let reviewSurface: GarageReviewSurface
    let handPathSamples: [GarageHandPathSample]
    let currentTime: Double
    let syncFlow: GarageSyncFlowReport?
    let skeletonOverlayOpacity: Double
    let onAnchorDragChanged: (CGPoint) -> Void
    let onAnchorDragEnded: (CGPoint) -> Void

    var body: some View {
        GeometryReader { proxy in
            let containerRect = CGRect(origin: .zero, size: proxy.size)
            let drawRect = containerRect.insetBy(dx: 20, dy: 20)

            ZStack {
                Rectangle()
                    .fill(garageReviewCanvasFill)

                if reviewMode == .skeleton {
                    GarageSkeletonOverlay(
                        drawSize: drawRect.size,
                        currentFrame: currentFrame,
                        currentTime: currentTime,
                        pulseProgress: pulseProgress,
                        syncFlow: syncFlow
                    )
                    .opacity(skeletonOverlayOpacity)
                    .frame(width: drawRect.width, height: drawRect.height)
                    .position(x: drawRect.midX, y: drawRect.midY)
                    .allowsHitTesting(false)
                }

                if reviewMode == .handPath, reviewSurface == .summary {
                    GarageVelocityRibbonOverlay(
                        drawRect: drawRect,
                        pathSamples: handPathSamples,
                        currentTime: currentTime
                    )
                    .allowsHitTesting(false)
                }

                if reviewMode == .handPath, reviewSurface == .fallbackHandPath {
                    GarageReviewFrameOverlayCanvas(
                        drawRect: drawRect,
                        selectedAnchor: selectedAnchor,
                        highlightTint: highlightTint,
                        showsAnchorGuides: showsAnchorGuides
                    )

                    if let selectedAnchor {
                        GarageInteractiveAnchorHandle(
                            drawRect: drawRect,
                            anchorPoint: CGPoint(x: selectedAnchor.x, y: selectedAnchor.y),
                            tint: highlightTint,
                            isManualAnchor: selectedAnchor.source == .manual,
                            onDragChanged: onAnchorDragChanged,
                            onDragEnded: onAnchorDragEnded
                        )
                    }
                }

                VStack(spacing: 6) {
                    Image(systemName: "figure.golf")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(garageReviewMutedText)
                    Text("Sampled pose reconstruction")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(garageReviewMutedText)
                }
                .padding(.top, 18)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var pulseProgress: Double {
        guard let currentFrameIndex else { return 0 }
        return min(max(Double(currentFrameIndex) / Double(max(totalFrameCount - 1, 1)), 0), 1)
    }
}

private struct GarageReviewFrameOverlayCanvas: View {
    let drawRect: CGRect
    let selectedAnchor: HandAnchor?
    let highlightTint: Color
    let showsAnchorGuides: Bool

    var body: some View {
        Canvas { context, _ in
            guard drawRect.isEmpty == false else {
                return
            }

            if let selectedAnchor {
                let anchorPoint = garageMappedPoint(x: selectedAnchor.x, y: selectedAnchor.y, in: drawRect)
                let haloRect = CGRect(x: anchorPoint.x - 12, y: anchorPoint.y - 12, width: 24, height: 24)
                context.fill(Ellipse().path(in: haloRect), with: .color(highlightTint.opacity(0.16)))

                if showsAnchorGuides {
                    var horizontalGuide = Path()
                    horizontalGuide.move(to: CGPoint(x: drawRect.minX, y: anchorPoint.y))
                    horizontalGuide.addLine(to: CGPoint(x: drawRect.maxX, y: anchorPoint.y))
                    context.stroke(
                        horizontalGuide,
                        with: .color(highlightTint.opacity(0.35)),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 6])
                    )

                    var verticalGuide = Path()
                    verticalGuide.move(to: CGPoint(x: anchorPoint.x, y: drawRect.minY))
                    verticalGuide.addLine(to: CGPoint(x: anchorPoint.x, y: drawRect.maxY))
                    context.stroke(
                        verticalGuide,
                        with: .color(highlightTint.opacity(0.35)),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 6])
                    )
                }
            }
        }
    }
}

private struct GarageVelocityRibbonOverlay: View {
    let drawRect: CGRect
    let pathSamples: [GarageHandPathSample]
    let currentTime: Double

    private var visibleCurrentSample: GarageHandPathSample? {
        let cappedTime = pathSamples.last.map { min(currentTime, $0.timestamp) } ?? currentTime
        return pathSamples.last(where: { $0.timestamp <= cappedTime }) ?? pathSamples.first
    }

    var body: some View {
        Canvas { context, _ in
            guard drawRect.isEmpty == false, pathSamples.count >= 2 else {
                return
            }

            var maxSpeed = 0.001
            for sample in pathSamples {
                maxSpeed = max(maxSpeed, sample.speed)
            }

            for segmentIndex in 1..<pathSamples.count {
                let previous = pathSamples[segmentIndex - 1]
                let current = pathSamples[segmentIndex]
                let palette = garageVelocityRibbonPalette(
                    normalizedSpeed: current.speed / maxSpeed,
                    segment: current.segment
                )

                var segmentPath = Path()
                segmentPath.move(to: garageMappedPoint(x: previous.x, y: previous.y, in: drawRect))
                segmentPath.addLine(to: garageMappedPoint(x: current.x, y: current.y, in: drawRect))

                context.stroke(
                    segmentPath,
                    with: .color(Color(rgba: palette.halo)),
                    style: StrokeStyle(lineWidth: palette.outerWidth, lineCap: .round, lineJoin: .round)
                )
                context.stroke(
                    segmentPath,
                    with: .color(Color(rgba: palette.fill)),
                    style: StrokeStyle(lineWidth: palette.innerWidth, lineCap: .round, lineJoin: .round)
                )
            }

            if let visibleCurrentSample {
                let point = garageMappedPoint(x: visibleCurrentSample.x, y: visibleCurrentSample.y, in: drawRect)
                let outerRect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                let innerRect = CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)
                context.fill(Ellipse().path(in: outerRect), with: .color(Color.white.opacity(0.92)))
                let palette = garageVelocityRibbonPalette(
                    normalizedSpeed: visibleCurrentSample.speed / maxSpeed,
                    segment: visibleCurrentSample.segment
                )
                context.fill(
                    Ellipse().path(in: innerRect),
                    with: .color(Color(rgba: palette.fill))
                )
            }
        }
    }
}

private struct GaragePrecisionLoupe: View {
    let image: CGImage
    let drawRect: CGRect
    let anchorPoint: CGPoint

    private let loupeSize: CGFloat = 88
    private let sampleSize: CGFloat = 120

    private var mappedAnchor: CGPoint {
        garageMappedPoint(anchorPoint, in: drawRect)
    }

    private var croppedImage: CGImage? {
        image.cropping(to: garageLoupeCropRect(
            anchorPoint: anchorPoint,
            imageSize: CGSize(width: image.width, height: image.height),
            sampleSize: sampleSize
        ))
    }

    private var loupePosition: CGPoint {
        let minY = drawRect.minY + (loupeSize / 2) + 8
        let maxX = drawRect.maxX - (loupeSize / 2) - 8
        let minX = drawRect.minX + (loupeSize / 2) + 8
        return CGPoint(
            x: min(max(mappedAnchor.x, minX), maxX),
            y: max(minY, mappedAnchor.y - 76)
        )
    }

    var body: some View {
        if let croppedImage {
            ZStack {
                Circle()
                    .fill(garageReviewSurfaceRaised.opacity(0.96))
                    .frame(width: loupeSize, height: loupeSize)
                    .overlay(
                        Image(decorative: croppedImage, scale: 1)
                            .resizable()
                            .scaledToFill()
                            .frame(width: loupeSize - 8, height: loupeSize - 8)
                            .clipShape(Circle())
                    )

                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 1, height: 22)
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 22, height: 1)
            }
            .overlay(
                Circle()
                    .stroke(garageReviewAccent.opacity(0.75), lineWidth: 2)
            )
            .shadow(color: garageReviewShadowDark.opacity(0.28), radius: 18, x: 0, y: 10)
            .position(loupePosition)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
            .animation(.spring(response: 0.22, dampingFraction: 0.76), value: anchorPoint)
            .allowsHitTesting(false)
        }
    }
}

private struct GarageInteractiveAnchorHandle: View {
    let drawRect: CGRect
    let anchorPoint: CGPoint
    let tint: Color
    let isManualAnchor: Bool
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void

    @State private var dragOrigin: CGPoint?

    var body: some View {
        let mappedAnchor = garageMappedPoint(anchorPoint, in: drawRect)

        ZStack {
            Circle()
                .fill(garageReviewSurfaceRaised)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(tint, lineWidth: 1.25)
                )
                .shadow(color: garageReviewShadowDark.opacity(0.7), radius: 10, x: 6, y: 6)
                .shadow(color: garageReviewShadowLight.opacity(0.7), radius: 8, x: -4, y: -4)

            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .shadow(color: tint.opacity(0.6), radius: 4, x: 0, y: 0)
        }
        .frame(width: 34, height: 34)
        .contentShape(Circle())
        .position(mappedAnchor)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let origin = dragOrigin ?? anchorPoint
                    if dragOrigin == nil {
                        dragOrigin = anchorPoint
                    }

                    let translatedPoint = CGPoint(
                        x: origin.x + (value.translation.width / max(drawRect.width, 1)),
                        y: origin.y + (value.translation.height / max(drawRect.height, 1))
                    )
                    onDragChanged(garageClampedNormalizedPoint(translatedPoint))
                }
                .onEnded { value in
                    let origin = dragOrigin ?? anchorPoint
                    let translatedPoint = CGPoint(
                        x: origin.x + (value.translation.width / max(drawRect.width, 1)),
                        y: origin.y + (value.translation.height / max(drawRect.height, 1))
                    )
                    dragOrigin = nil
                    onDragEnded(garageClampedNormalizedPoint(translatedPoint))
                }
        )
        .shadow(color: isManualAnchor ? garageManualAnchorAccent.opacity(0.7) : tint.opacity(0.2), radius: isManualAnchor ? 4 : 10, y: isManualAnchor ? 0 : 6)
    }
}

private struct GarageCheckpointProgressStrip: View {
    let selectedPhase: SwingPhase
    let markers: [GarageTimelineMarker]
    let onSelect: (SwingPhase) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ModuleSpacing.small) {
                ForEach(SwingPhase.allCases) { phase in
                    let marker = markers.first(where: { $0.keyFrame.phase == phase })
                    let isSelected = selectedPhase == phase
                    let isImpact = phase == .impact
                    Button {
                        onSelect(phase)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(isSelected || isImpact ? garageReviewAccent : garageReviewReadableText.opacity(marker == nil ? 0.22 : 0.52))
                                .frame(width: 8, height: 8)
                                .shadow(
                                    color: isSelected ? garageReviewAccent.opacity(0.6) : .clear,
                                    radius: isSelected ? 4 : 0,
                                    x: 0,
                                    y: 0
                                )

                            Text(shortTitle(for: phase))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(garageReviewReadableText)

                            if marker?.keyFrame.source == .adjusted {
                                Image(systemName: "hand.draw")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(garageManualAnchorAccent)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .fixedSize(horizontal: true, vertical: false)
                        .background(
                            GarageRaisedPanelBackground(
                                shape: Capsule(),
                                fill: isSelected ? garageReviewSurfaceRaised : garageReviewSurface
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isImpact
                                        ? garageReviewAccent.opacity(isSelected ? 0.75 : 0.4)
                                        : (isSelected ? garageReviewAccent.opacity(0.65) : garageReviewStroke),
                                    lineWidth: isSelected || isImpact ? 1.2 : 1
                                )
                        )
                        .shadow(
                            color: isSelected ? garageReviewAccent.opacity(0.35) : .clear,
                            radius: isSelected ? 10 : 0,
                            x: 0,
                            y: 0
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(phase.reviewTitle)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func shortTitle(for phase: SwingPhase) -> String {
        switch phase {
        case .address:
            "Setup"
        case .takeaway:
            "Take"
        case .shaftParallel:
            "Shaft"
        case .topOfBackswing:
            "Top"
        case .transition:
            "Transition"
        case .earlyDownswing:
            "Down"
        case .impact:
            "Impact"
        case .followThrough:
            "Finish"
        }
    }
}

private struct GarageTimelineScrubber: View {
    let range: ClosedRange<Double>
    @Binding var currentTime: Double
    let markers: [GarageTimelineMarker]
    let selectedPhase: SwingPhase

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(proxy.size.width, 1)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(garageReviewInsetSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(garageReviewStroke, lineWidth: 1)
                    )

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(garageReviewTrackFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(garageReviewStroke, lineWidth: 1)
                        )

                    HStack(spacing: 0) {
                        ForEach(0...24, id: \.self) { index in
                            Rectangle()
                                .fill(index.isMultiple(of: 2) ? garageReviewReadableText.opacity(0.04) : Color.clear)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .overlay(alignment: .trailing) {
                                    Rectangle()
                                        .fill(garageReviewReadableText.opacity(0.08))
                                        .frame(width: 1)
                                }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    ForEach(markers) { marker in
                        if range.contains(marker.timestamp) {
                            let isActiveMarker = marker.keyFrame.phase == selectedPhase
                            Circle()
                                .fill(isActiveMarker ? garageReviewAccent : garageReviewReadableText.opacity(0.88))
                                .frame(width: isActiveMarker ? 14 : 8, height: isActiveMarker ? 14 : 8)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            marker.keyFrame.source == .adjusted
                                                ? garageManualAnchorAccent
                                                : garageReviewReadableText.opacity(isActiveMarker ? 0.0 : 0.22),
                                            lineWidth: isActiveMarker ? 0 : 1.3
                                        )
                                )
                                .shadow(
                                    color: isActiveMarker ? garageReviewAccent.opacity(0.55) : .clear,
                                    radius: isActiveMarker ? 6 : 0,
                                    x: 0,
                                    y: 0
                                )
                                .offset(x: max(0, markerX(for: marker.timestamp, in: trackWidth) - (isActiveMarker ? 7 : 4)))
                        }
                    }
                    Circle()
                        .fill(garageReviewAccent)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(garageReviewReadableText.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: garageReviewAccent.opacity(0.55), radius: 8, x: 0, y: 0)
                        .offset(x: max(0, indicatorX(in: trackWidth) - 9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 18)
            }
            .frame(height: 74)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard abs(value.translation.width) >= abs(value.translation.height) || abs(value.translation.height) < 6 else {
                            return
                        }
                        let progress = min(max((value.location.x - 12) / max(trackWidth - 24, 1), 0), 1)
                        let span = range.upperBound - range.lowerBound
                        currentTime = range.lowerBound + (span * progress)
                    }
            )
        }
        .frame(height: 74)
    }

    private func markerX(for timestamp: Double, in width: CGFloat) -> CGFloat {
        let span = max(range.upperBound - range.lowerBound, 0.0001)
        let progress = (timestamp - range.lowerBound) / span
        let clampedProgress = min(max(progress, 0), 1)
        return 12 + ((width - 24) * clampedProgress)
    }

    private func indicatorX(in width: CGFloat) -> CGFloat {
        markerX(for: currentTime, in: width)
    }
}

private let garageReviewBackground = ModuleTheme.garageBackground
private let garageReviewSurface = ModuleTheme.garageSurface
private let garageReviewSurfaceRaised = ModuleTheme.garageSurfaceRaised
private let garageReviewSurfaceDark = ModuleTheme.garageSurfaceDark
private let garageReviewInsetSurface = ModuleTheme.garageSurfaceInset
private let garageReviewCanvasFill = ModuleTheme.garageCanvas
private let garageReviewTrackFill = ModuleTheme.garageTrack
private let garageReviewAccent = AppModule.garage.theme.primary
private let garageManualAnchorAccent = ModuleTheme.electricCyan
private let garageReviewReadableText = ModuleTheme.garageTextPrimary
private let garageReviewMutedText = ModuleTheme.garageTextMuted
private let garageReviewApproved = Color(red: 0.33, green: 0.79, blue: 0.53)
private let garageReviewPending = Color.orange
private let garageReviewFlagged = Color(red: 0.94, green: 0.38, blue: 0.40)
private let garageReviewStroke = Color.white.opacity(0.05)
private let garageReviewShadowLight = AppModule.garage.theme.shadowLight
private let garageReviewShadowDark = AppModule.garage.theme.shadowDark
private let garageReviewShadow = garageReviewShadowDark.opacity(0.5)

private struct GarageRaisedPanelBackground<S: Shape>: View {
    let shape: S
    var fill: Color = garageReviewSurface
    var stroke: Color = garageReviewStroke
    var glow: Color?

    init(
        shape: S,
        fill: Color = garageReviewSurface,
        stroke: Color = garageReviewStroke,
        glow: Color? = nil
    ) {
        self.shape = shape
        self.fill = fill
        self.stroke = stroke
        self.glow = glow
    }

    var body: some View {
        shape
            .fill(fill)
            .overlay(
                shape
                    .stroke(stroke, lineWidth: 0.5)
            )
            .overlay(
                shape
                    .stroke(
                        (glow ?? .clear).opacity(glow == nil ? 0 : 0.55),
                        lineWidth: glow == nil ? 0 : 0.5
                    )
            )
            .shadow(color: garageReviewShadowDark.opacity(0.68), radius: 10, x: 0, y: 8)
            .shadow(color: (glow ?? .clear).opacity(glow == nil ? 0 : 0.12), radius: glow == nil ? 0 : 10, x: 0, y: 0)
    }
}

private struct GarageInsetPanelBackground<S: Shape>: View {
    let shape: S
    var fill: Color = garageReviewInsetSurface
    var stroke: Color = garageReviewStroke

    var body: some View {
        shape
            .fill(fill)
            .overlay(
                shape
                    .stroke(stroke, lineWidth: 0.5)
            )
            .overlay(
                shape
                    .stroke(garageReviewShadowLight.opacity(0.35), lineWidth: 0.5)
                    .blur(radius: 1)
                    .mask(shape.fill(LinearGradient(colors: [.white, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)))
            )
            .shadow(color: garageReviewShadowDark.opacity(0.44), radius: 8, x: 0, y: 6)
    }
}

private struct GarageFrameStepButton: View {
    let accessibilityLabel: String
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(width: 42, height: 42)
                .foregroundStyle(isEnabled ? garageReviewReadableText : garageReviewMutedText.opacity(0.8))
                .background(
                    GarageRaisedPanelBackground(
                        shape: Circle(),
                        fill: isEnabled ? garageReviewSurfaceRaised : garageReviewSurface,
                        stroke: isEnabled ? garageReviewStroke.opacity(0.95) : garageReviewStroke.opacity(0.6)
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
        .opacity(isEnabled ? 1 : 0.48)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct GarageReviewRecoveryCallout: View {
    let title: String
    let message: String
    let state: GarageReviewFrameSourceState

    var body: some View {
        HStack(alignment: .top, spacing: ModuleSpacing.medium) {
            Image(systemName: iconName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(iconTint)
                .frame(width: 34, height: 34)
                .background(iconTint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous),
                fill: garageReviewSurface,
                stroke: iconTint.opacity(0.18)
            )
        )
    }

    private var iconName: String {
        switch state {
        case .video:
            "play.rectangle.fill"
        case .poseFallback:
            "figure.golf"
        case .recoveryNeeded:
            "arrow.triangle.2.circlepath.circle"
        }
    }

    private var iconTint: Color {
        switch state {
        case .video:
            AppModule.garage.theme.primary
        case .poseFallback:
            .orange
        case .recoveryNeeded:
            .red
        }
    }
}

private struct GarageCompletionPlaybackCallout: View {
    let replay: () -> Void

    var body: some View {
        HStack(spacing: ModuleSpacing.medium) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Review approved")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                Text("Open the slow-motion hand-path playback for a clean final pass.")
                    .font(.subheadline)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
            }

            Spacer(minLength: 0)

            Button(action: replay) {
                Label("Play Slow Motion", systemImage: "play.fill")
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
        .padding()
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous),
                fill: garageReviewSurface
            )
        )
    }
}

private struct GarageSlowMotionPlaybackSheet: View {
    @Environment(\.dismiss) private var dismiss

    let videoURL: URL
    let pathSamples: [GarageHandPathSample]
    let frames: [SwingFrame]
    let syncFlow: GarageSyncFlowReport?
    let initialMode: GarageReviewMode

    @StateObject private var playbackController: GarageSlowMotionPlaybackController
    @State private var videoDisplaySize = CGSize(width: 1, height: 1)
    @State private var selectedSpeed: Float = 1.0
    @State private var reviewMode: GarageReviewMode
    @State private var isScrubbing = false

    init(
        videoURL: URL,
        pathSamples: [GarageHandPathSample],
        frames: [SwingFrame],
        syncFlow: GarageSyncFlowReport?,
        initialMode: GarageReviewMode
    ) {
        self.videoURL = videoURL
        self.pathSamples = pathSamples
        self.frames = frames
        self.syncFlow = syncFlow
        self.initialMode = initialMode
        _playbackController = StateObject(wrappedValue: GarageSlowMotionPlaybackController(url: videoURL))
        _reviewMode = State(initialValue: initialMode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Review Playback")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    Text("Confirm motion flow before finishing.")
                        .font(.subheadline)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }
                Spacer()
                Text("Approved")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1), in: Capsule())
            }

            ZStack {
                GarageSlowMotionPlayerView(player: playbackController.player)
                    .frame(minHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))

                GarageSlowMotionVisualizationOverlay(
                    mode: reviewMode,
                    pathSamples: pathSamples,
                    frames: frames,
                    currentTime: playbackController.currentTime,
                    syncFlow: syncFlow,
                    videoSize: videoDisplaySize,
                    isScrubbing: isScrubbing
                )
                .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
            )

            GaragePlaybackControlRow(
                currentTime: playbackController.currentTime,
                duration: playbackController.duration,
                isPlaying: playbackController.isPlaying,
                selectedSpeed: selectedSpeed,
                onScrub: playbackController.seek,
                onScrubEditingChanged: { isEditing in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isScrubbing = isEditing
                    }
                },
                onTogglePlayPause: playbackController.togglePlayback,
                onSelectSpeed: { speed in
                    selectedSpeed = speed
                    playbackController.setRate(speed)
                }
            )

            if initialMode == .handPath, reviewMode == .handPath {
                Button {
                    reviewMode = .skeleton
                } label: {
                    Label("Open SyncFlow Review", systemImage: "figure.walk")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            GarageRaisedPanelBackground(
                                shape: Capsule(),
                                fill: garageReviewSurfaceRaised,
                                stroke: garageReviewStroke.opacity(0.92)
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ModuleSpacing.large)
        .background(garageReviewBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GaragePlaybackActionBar(
                onRecheck: {
                    playbackController.seek(0)
                    playbackController.startPlayback(at: selectedSpeed)
                },
                onFinish: dismiss.callAsFunction
            )
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(garageReviewMutedText)
            }
            .padding(.horizontal, ModuleSpacing.large)
        }
        .task {
            let metadata = await GarageMediaStore.assetMetadata(for: videoURL)
            await MainActor.run {
                if let metadata {
                    videoDisplaySize = metadata.naturalSize
                    playbackController.updateDurationFromMetadata(metadata.duration)
                } else {
                    videoDisplaySize = CGSize(width: 1, height: 1)
                }
            }
        }
        .onAppear {
            playbackController.startPlayback(at: selectedSpeed)
        }
        .onDisappear {
            playbackController.stop()
        }
    }
}

private struct GarageSkeletonReviewView: View {
    let videoURL: URL
    let pathSamples: [GarageHandPathSample]
    let frames: [SwingFrame]
    let syncFlow: GarageSyncFlowReport?

    var body: some View {
        GarageSlowMotionPlaybackSheet(
            videoURL: videoURL,
            pathSamples: pathSamples,
            frames: frames,
            syncFlow: syncFlow,
            initialMode: .skeleton
        )
    }
}

private struct GaragePlaybackActionBar: View {
    let onRecheck: () -> Void
    let onFinish: () -> Void

    var body: some View {
        GarageDockSurface {
            HStack(spacing: 12) {
                GarageDockWideButton(
                    title: "Recheck Frames",
                    systemImage: "arrow.counterclockwise",
                    isPrimary: false,
                    isEnabled: true,
                    action: onRecheck
                )

                GarageDockWideButton(
                    title: "Finish Review",
                    systemImage: "checkmark.circle.fill",
                    isPrimary: true,
                    isEnabled: true,
                    action: onFinish
                )
            }
        }
    }
}

private struct GaragePlaybackControlRow: View {
    let currentTime: Double
    let duration: Double
    let isPlaying: Bool
    let selectedSpeed: Float
    let onScrub: (Double) -> Void
    let onScrubEditingChanged: (Bool) -> Void
    let onTogglePlayPause: () -> Void
    let onSelectSpeed: (Float) -> Void
    @State private var scrubTime = 0.0
    @State private var isScrubbing = false

    var body: some View {
        VStack(spacing: 14) {
            GaragePlaybackScrubber(
                duration: duration,
                scrubTime: $scrubTime,
                onScrub: onScrub,
                onScrubEditingChanged: handleScrubEditingChanged
            )

            HStack(spacing: 12) {
                Button(action: onTogglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(isPlaying ? garageReviewCanvasFill : garageReviewReadableText)
                        .frame(width: 50, height: 50)
                        .background(
                            GarageRaisedPanelBackground(
                                shape: Circle(),
                                fill: isPlaying ? garageReviewAccent : garageReviewSurfaceRaised,
                                stroke: isPlaying ? garageReviewAccent.opacity(0.4) : garageReviewStroke.opacity(0.95),
                                glow: isPlaying ? garageReviewAccent : nil
                            )
                        )
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                .buttonStyle(.plain)
                .accessibilityValue(speedLabel(for: Double(selectedSpeed)))

                HStack(spacing: 8) {
                    ForEach([1.0, 0.5, 0.25], id: \.self) { speed in
                        let speedValue = Float(speed)
                        Button {
                            onSelectSpeed(speedValue)
                        } label: {
                            Text(speedLabel(for: speed))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedSpeed == speedValue ? garageReviewReadableText : garageReviewMutedText)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .background(
                                    Capsule()
                                        .fill(selectedSpeed == speedValue ? garageReviewAccent.opacity(0.18) : Color.clear)
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    selectedSpeed == speedValue
                                                        ? garageReviewAccent.opacity(0.38)
                                                        : garageReviewStroke.opacity(0.85),
                                                    lineWidth: 0.9
                                                )
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GarageInsetPanelBackground(
                        shape: Capsule(),
                        fill: garageReviewSurfaceDark,
                        stroke: garageReviewStroke.opacity(0.85)
                    )
                )
            }
        }
        .padding(16)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                fill: garageReviewSurface,
                stroke: garageReviewStroke.opacity(0.9)
            )
        )
        .onAppear {
            scrubTime = clampedCurrentTime
        }
        .onChange(of: currentTime) { _, newValue in
            guard isScrubbing == false else { return }
            scrubTime = min(max(newValue, 0), sliderMaxValue)
        }
    }

    private func speedLabel(for value: Double) -> String {
        value == 1.0 ? "1x" : String(format: "%.2gx", value)
    }

    private var sliderMaxValue: Double {
        guard duration.isFinite, duration > 0 else { return 0.01 }
        return duration
    }

    private var clampedCurrentTime: Double {
        min(max(currentTime.isFinite ? currentTime : 0, 0), sliderMaxValue)
    }

    private func handleScrubEditingChanged(_ isEditing: Bool) {
        isScrubbing = isEditing
        onScrubEditingChanged(isEditing)
    }
}

private struct GaragePlaybackScrubber: View {
    let duration: Double
    @Binding var scrubTime: Double
    let onScrub: (Double) -> Void
    let onScrubEditingChanged: (Bool) -> Void

    @State private var isDragging = false

    private let outerInset: CGFloat = 14
    private let thumbSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(garageFormattedPlaybackTime(displayTime))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)
                    .monospacedDigit()

                Spacer(minLength: 0)

                Text(garageFormattedPlaybackTime(safeDuration))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewMutedText)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                let trackWidth = max(proxy.size.width - (outerInset * 2), 1)

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(garageReviewSurfaceDark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(garageReviewStroke.opacity(0.95), lineWidth: 0.9)
                        )

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(garageReviewTrackFill)
                            .frame(height: 8)
                            .overlay(
                                Capsule()
                                    .stroke(garageReviewStroke.opacity(0.8), lineWidth: 0.8)
                            )

                        HStack(spacing: 0) {
                            ForEach(0...20, id: \.self) { index in
                                Rectangle()
                                    .fill(index.isMultiple(of: 2) ? garageReviewReadableText.opacity(0.05) : .clear)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .overlay(alignment: .trailing) {
                                        Rectangle()
                                            .fill(garageReviewReadableText.opacity(0.08))
                                            .frame(width: 1)
                                    }
                            }
                        }
                        .frame(height: 8)
                        .clipShape(Capsule())

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [garageReviewAccent.opacity(0.72), garageReviewAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(trackWidth * progress, thumbSize), height: 8)
                            .shadow(color: garageReviewAccent.opacity(0.32), radius: 8, x: 0, y: 0)

                        Circle()
                            .fill(garageReviewAccent)
                            .frame(width: thumbSize, height: thumbSize)
                            .overlay(
                                Circle()
                                    .stroke(garageReviewReadableText.opacity(0.28), lineWidth: 1)
                            )
                            .shadow(color: garageReviewAccent.opacity(0.55), radius: 8, x: 0, y: 0)
                            .offset(x: max(0, (trackWidth * progress) - (thumbSize / 2)))
                    }
                    .padding(.horizontal, outerInset)
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard abs(value.translation.width) >= abs(value.translation.height) || abs(value.translation.height) < 6 else {
                                return
                            }

                            if isDragging == false {
                                isDragging = true
                                onScrubEditingChanged(true)
                            }

                            let updatedTime = time(for: value.location.x, width: proxy.size.width)
                            scrubTime = updatedTime
                            onScrub(updatedTime)
                        }
                        .onEnded { value in
                            guard isDragging else { return }
                            let updatedTime = time(for: value.location.x, width: proxy.size.width)
                            scrubTime = updatedTime
                            onScrub(updatedTime)
                            isDragging = false
                            onScrubEditingChanged(false)
                        }
                )
            }
            .frame(height: 36)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback scrubber")
            .accessibilityValue("\(garageFormattedPlaybackTime(displayTime)) of \(garageFormattedPlaybackTime(safeDuration))")
            .accessibilityAdjustableAction { direction in
                let step = max(safeDuration / 20, 0.1)
                switch direction {
                case .increment:
                    adjustScrubTime(by: step)
                case .decrement:
                    adjustScrubTime(by: -step)
                @unknown default:
                    break
                }
            }
        }
    }

    private var safeDuration: Double {
        guard duration.isFinite, duration > 0 else { return 0 }
        return duration
    }

    private var displayTime: Double {
        min(max(scrubTime, 0), max(safeDuration, 0))
    }

    private var progress: CGFloat {
        guard safeDuration > 0 else { return 0 }
        return CGFloat(displayTime / safeDuration)
    }

    private func time(for locationX: CGFloat, width: CGFloat) -> Double {
        guard safeDuration > 0 else { return 0 }
        let clampedX = min(max(locationX - outerInset, 0), max(width - (outerInset * 2), 1))
        let progress = clampedX / max(width - (outerInset * 2), 1)
        return safeDuration * progress
    }

    private func adjustScrubTime(by delta: Double) {
        let updatedTime = min(max(displayTime + delta, 0), safeDuration)
        scrubTime = updatedTime
        onScrub(updatedTime)
    }
}

private func garageFormattedPlaybackTime(_ time: Double) -> String {
    let totalSeconds = Int(max(time.rounded(), 0))
    let seconds = totalSeconds % 60
    let minutes = (totalSeconds / 60) % 60
    let hours = totalSeconds / 3600

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}

private struct GarageSlowMotionVisualizationOverlay: View {
    let mode: GarageReviewMode
    let pathSamples: [GarageHandPathSample]
    let frames: [SwingFrame]
    let currentTime: Double
    let syncFlow: GarageSyncFlowReport?
    let videoSize: CGSize
    let isScrubbing: Bool

    private var visibleSampleCount: Int {
        var lowerBound = 0
        var upperBound = pathSamples.count
        let cutoff = currentTime + 0.0001

        while lowerBound < upperBound {
            let midpoint = (lowerBound + upperBound) / 2
            if pathSamples[midpoint].timestamp <= cutoff {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }

        return lowerBound
    }

    private var currentFrame: SwingFrame? {
        guard let index = nearestFrameIndex(for: currentTime) else { return nil }
        return frames[index]
    }

    private func nearestFrameIndex(for timestamp: Double) -> Int? {
        guard frames.isEmpty == false else { return nil }

        var lowerBound = 0
        var upperBound = frames.count

        while lowerBound < upperBound {
            let midpoint = (lowerBound + upperBound) / 2
            if frames[midpoint].timestamp < timestamp {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }

        if lowerBound == 0 {
            return 0
        }

        if lowerBound == frames.count {
            return frames.count - 1
        }

        let previousIndex = lowerBound - 1
        let nextIndex = lowerBound
        let previousDelta = abs(frames[previousIndex].timestamp - timestamp)
        let nextDelta = abs(frames[nextIndex].timestamp - timestamp)

        return previousDelta <= nextDelta ? previousIndex : nextIndex
    }

    var body: some View {
        GeometryReader { proxy in
            let containerRect = CGRect(origin: .zero, size: proxy.size)
            let videoRect = aspectFitRect(videoSize: videoSize, in: containerRect)

            if mode == .skeleton {
                GarageSkeletonOverlay(
                    drawSize: videoRect.size,
                    currentFrame: currentFrame,
                    currentTime: currentTime,
                    pulseProgress: pulseProgress,
                    syncFlow: syncFlow
                )
                .opacity(isScrubbing ? 0 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isScrubbing)
                .frame(width: videoRect.width, height: videoRect.height)
                .position(x: videoRect.midX, y: videoRect.midY)
            } else {
                Canvas { context, _ in
                    guard videoRect.isEmpty == false, visibleSampleCount >= 2 else {
                        return
                    }

                    var maxSpeed = 0.001
                    for sampleIndex in 0..<visibleSampleCount {
                        maxSpeed = max(maxSpeed, pathSamples[sampleIndex].speed)
                    }

                    for segmentIndex in 1..<visibleSampleCount {
                        let previous = pathSamples[segmentIndex - 1]
                        let current = pathSamples[segmentIndex]
                        let palette = garageVelocityRibbonPalette(
                            normalizedSpeed: current.speed / maxSpeed,
                            segment: current.segment
                        )

                        var segmentPath = Path()
                        segmentPath.move(to: mappedPoint(x: previous.x, y: previous.y, in: videoRect))
                        segmentPath.addLine(to: mappedPoint(x: current.x, y: current.y, in: videoRect))

                        context.stroke(
                            segmentPath,
                            with: .color(Color(rgba: palette.halo)),
                            style: StrokeStyle(lineWidth: palette.outerWidth + 0.4, lineCap: .round, lineJoin: .round)
                        )
                        context.stroke(
                            segmentPath,
                            with: .color(Color(rgba: palette.fill)),
                            style: StrokeStyle(lineWidth: palette.innerWidth + 0.2, lineCap: .round, lineJoin: .round)
                        )
                    }

                    let lastSample = pathSamples[visibleSampleCount - 1]
                    let point = mappedPoint(x: lastSample.x, y: lastSample.y, in: videoRect)
                    let outerRect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                    let palette = garageVelocityRibbonPalette(
                        normalizedSpeed: lastSample.speed / maxSpeed,
                        segment: lastSample.segment
                    )
                    context.fill(Ellipse().path(in: outerRect), with: .color(Color.white.opacity(0.92)))
                    context.fill(
                        Ellipse().path(in: CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)),
                        with: .color(Color(rgba: palette.fill))
                    )
                }
            }
        }
    }

    private func aspectFitRect(videoSize: CGSize, in container: CGRect) -> CGRect {
        guard videoSize.width > 0, videoSize.height > 0, container.width > 0, container.height > 0 else {
            return .zero
        }

        let scale = min(container.width / videoSize.width, container.height / videoSize.height)
        let scaledSize = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        let origin = CGPoint(
            x: container.midX - (scaledSize.width / 2),
            y: container.midY - (scaledSize.height / 2)
        )
        return CGRect(origin: origin, size: scaledSize)
    }

    private func mappedPoint(x: Double, y: Double, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + (rect.width * x),
            y: rect.minY + (rect.height * y)
        )
    }

    private var pulseProgress: Double {
        guard let frameIndex = nearestFrameIndex(for: currentTime) else { return 0 }
        return min(max(Double(frameIndex) / Double(max(frames.count - 1, 1)), 0), 1)
    }
}

private struct GarageSlowMotionPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> GaragePlayerContainerView {
        let view = GaragePlayerContainerView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: GaragePlayerContainerView, context: Context) {
        uiView.player = player
    }
}

private final class GaragePlayerContainerView: UIView {
    private let playerLayer = AVPlayerLayer()

    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

@MainActor
private final class GarageSlowMotionPlaybackController: ObservableObject {
    @Published var currentTime = 0.0
    @Published var duration = 0.0
    @Published var isPlaying = false

    let player: AVPlayer
    private var playbackRate: Float = 1.0

    private var timeObserverToken: Any?
    private var playbackEndObserver: NSObjectProtocol?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        let resolvedDuration = CMTimeGetSeconds(item.asset.duration)
        duration = resolvedDuration.isFinite ? max(resolvedDuration, 0) : 0

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 60.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = max(CMTimeGetSeconds(time), 0)
                self.isPlaying = self.player.rate != 0
            }
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.player.pause()
                self?.isPlaying = false
            }
        }
    }

    deinit {
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
        }
    }

    func startPlayback(at rate: Float) {
        setRate(rate)
        replay()
    }

    func replay() {
        currentTime = 0
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player.playImmediately(atRate: playbackRate)
        isPlaying = true
    }

    func seek(_ time: Double) {
        let safeDuration = duration.isFinite ? max(duration, 0) : 0
        let safeTime = time.isFinite ? time : 0
        let clamped = min(max(safeTime, 0), safeDuration)
        currentTime = clamped
        let tolerance = CMTime(seconds: 1.0 / 120.0, preferredTimescale: 600)
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: tolerance,
            toleranceAfter: tolerance
        )
    }

    func togglePlayback() {
        if player.rate == 0 {
            player.playImmediately(atRate: playbackRate)
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if player.rate != 0 {
            player.playImmediately(atRate: playbackRate)
        }
    }

    func updateDurationFromMetadata(_ updatedDuration: Double) {
        let safeDuration = updatedDuration.isFinite ? max(updatedDuration, 0) : 0
        guard safeDuration > 0 else { return }
        duration = safeDuration
        if currentTime > safeDuration {
            seek(safeDuration)
        }
    }

    func stop() {
        player.pause()
        isPlaying = false
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

private func garageSuggestedRecordTitle(for filename: String, fallbackURL: URL) -> String {
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
        movie: GaragePickedMovie,
        initialSelection: GaragePreFlightSelection,
        onClose: @escaping () -> Void,
        onStartAnalysis: @escaping (GaragePreFlightSelection) -> Void
    ) {
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
        NavigationStack {
            ZStack {
                AppModule.garage.theme.backgroundBottom
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
                        actionCard
                    }
                    .padding(ModuleSpacing.large)
                    .padding(.bottom, ModuleSpacing.large)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .stroke(ModuleTheme.electricCyan.opacity(0.42), lineWidth: 0.5)
                    .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Pre-Flight")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.72))
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
                fill: garageReviewSurfaceDark.opacity(0.98),
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
                                fill: garageReviewSurface,
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
                                fill: garageReviewSurfaceDark,
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
                fill: garageReviewSurfaceDark.opacity(0.98),
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
                fill: garageReviewSurfaceDark,
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
                fill: garageReviewSurfaceDark.opacity(0.94),
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
                                    fill: selection.clubType == club ? garageReviewSurface : garageReviewSurfaceDark,
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
                fill: garageReviewSurfaceDark.opacity(0.98),
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
                fill: garageReviewSurfaceDark.opacity(0.94),
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
                fill: garageReviewSurfaceDark.opacity(0.98),
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
                fill: garageReviewSurfaceDark,
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
                        fill: isSelected ? garageReviewSurface : garageReviewSurfaceDark,
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

private struct GaragePickedMovie: Transferable {
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

private enum GarageImportError: LocalizedError {
    case unableToLoadSelection

    var errorDescription: String? {
        switch self {
        case .unableToLoadSelection:
            "The selected video could not be loaded from Photos."
        }
    }
}


#Preview("Garage") {
    PreviewScreenContainer {
        GarageView()
    }
    .modelContainer(for: SwingRecord.self, inMemory: true)
}
