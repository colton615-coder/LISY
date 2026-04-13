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
    case analyzing(GarageAnalysisProgressStep)
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
        case let .analyzing(step):
            step.detail
        case let .failure(message):
            message
        }
    }

    var activeStepTitle: String? {
        switch self {
        case let .analyzing(step):
            step.title
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
    [
        record.createdAt.ISO8601Format(),
        record.title,
        record.preferredReviewFilename ?? "no-review-asset",
        record.preferredExportFilename ?? "no-export-asset"
    ].joined(separator: "::")
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

struct GarageView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SwingRecord.createdAt, order: .reverse) private var swingRecords: [SwingRecord]
    @State private var isShowingAddRecord = false
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var importPresentationState: GarageImportPresentationState = .idle
    @State private var pendingImportMovie: GaragePickedMovie?
    @State private var selectedTab: ModuleHubTab = .records
    @State private var selectedReviewRecordKey: String?

    var body: some View {
        Group {
            if importPresentationState.isPresented {
                GarageImportPresentationScreen(
                    state: importPresentationState,
                    onDismiss: dismissImportPresentation,
                    onRetry: retryImport
                )
            } else if selectedTab == .review {
                GeometryReader { proxy in
                    GarageReviewTab(
                        records: swingRecords,
                        selectedRecordKey: $selectedReviewRecordKey,
                        viewportHeight: proxy.size.height,
                        onBackToRecords: {
                            selectedTab = .records
                        }
                    )
                }
            } else {
                GarageCustomScaffold(module: .garage, tabs: [.records, .review], selectedTab: $selectedTab) { _ in
                    GarageRecordsTab(
                        records: swingRecords,
                        importVideo: {
                            presentAddRecord()
                        },
                        openReview: { record in
                            selectedReviewRecordKey = garageRecordSelectionKey(for: record)
                            selectedTab = .review
                        }
                    )
                }
                .safeAreaInset(edge: .bottom) {
                    Group {
                        if selectedTab != .review {
                            ModuleBottomActionBar(
                                theme: AppModule.garage.theme,
                                title: "Add Swing Record",
                                systemImage: "plus"
                            ) {
                                presentAddRecord()
                            }
                        }
                    }
                }
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
        .onChange(of: swingRecords.map(garageRecordSelectionKey)) { _, keys in
            guard keys.isEmpty == false else {
                selectedTab = .records
                return
            }

            if selectedTab == .records, selectedReviewRecordKey != nil {
                selectedTab = .review
            }
        }
        .toolbar(selectedTab == .review ? .hidden : .visible, for: .navigationBar)
    }

    private func presentAddRecord() {
        isShowingAddRecord = true
    }

    private func dismissImportPresentation() {
        selectedVideoItem = nil
        pendingImportMovie = nil
        importPresentationState = .idle
    }

    @MainActor
    private func retryImport() {
        if let pendingImportMovie {
            importSelectedVideo(pendingImportMovie)
            return
        }

        if let selectedVideoItem {
            prepareSelectedVideo(selectedVideoItem)
            return
        }

        importPresentationState = .idle
        isShowingAddRecord = true
    }

    @MainActor
    private func prepareSelectedVideo(_ item: PhotosPickerItem) {
        guard importPresentationState == .idle else { return }

        pendingImportMovie = nil
        importPresentationState = .preparing

        Task {
            do {
                guard let movie = try await item.loadTransferable(type: GaragePickedMovie.self) else {
                    throw GarageImportError.unableToLoadSelection
                }

                await MainActor.run {
                    pendingImportMovie = movie
                    importSelectedVideo(movie)
                }
            } catch {
                await MainActor.run {
                    importPresentationState = .failure(error.localizedDescription)
                }
            }
        }
    }

    @MainActor
    private func importSelectedVideo(_ movie: GaragePickedMovie) {
        pendingImportMovie = movie
        importPresentationState = .analyzing(.loadingVideo)

        Task {
            do {
                await MainActor.run {
                    importPresentationState = .analyzing(.loadingVideo)
                }
                let reviewMasterURL = try GarageMediaStore.persistReviewMaster(from: movie.url)
                async let analysisTask = GarageAnalysisPipeline.analyzeVideo(at: reviewMasterURL) { step in
                    await MainActor.run {
                        importPresentationState = .analyzing(step)
                    }
                }
                async let exportTask = GarageMediaStore.createExportDerivative(from: reviewMasterURL)

                let output = try await analysisTask
                let exportURL = await exportTask
                let resolvedTitle = garageSuggestedRecordTitle(for: movie.displayName, fallbackURL: reviewMasterURL)
                let reviewMasterBookmark = GarageMediaStore.bookmarkData(for: reviewMasterURL)
                let exportBookmark = exportURL.flatMap { GarageMediaStore.bookmarkData(for: $0) }
                let approvedKeyFrames = GarageAnalysisPipeline.autoApprovedKeyFrames(
                    from: output.keyFrames,
                    reviewReport: output.handPathReviewReport
                )
                let initialValidationStatus: KeyframeValidationStatus = output.handPathReviewReport.requiresManualReview ? .pending : .approved

                let record = SwingRecord(
                    title: resolvedTitle,
                    mediaFilename: reviewMasterURL.lastPathComponent,
                    mediaFileBookmark: reviewMasterBookmark,
                    reviewMasterFilename: reviewMasterURL.lastPathComponent,
                    reviewMasterBookmark: reviewMasterBookmark,
                    exportAssetFilename: exportURL?.lastPathComponent,
                    exportAssetBookmark: exportBookmark,
                    notes: "",
                    frameRate: output.frameRate,
                    swingFrames: output.swingFrames,
                    keyFrames: approvedKeyFrames,
                    keyframeValidationStatus: initialValidationStatus,
                    handAnchors: output.handAnchors,
                    pathPoints: output.pathPoints,
                    analysisResult: output.analysisResult
                )

                await MainActor.run {
                    importPresentationState = .analyzing(.savingSwing)
                    modelContext.insert(record)
                    try? modelContext.save()
                    selectedVideoItem = nil
                    pendingImportMovie = nil
                    importPresentationState = .idle
                    selectedReviewRecordKey = garageRecordSelectionKey(for: record)
                    selectedTab = .review
                }
            } catch {
                await MainActor.run {
                    importPresentationState = .failure(error.localizedDescription)
                }
            }
        }
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

    var body: some View {
        Button(action: openReview) {
            HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.title)
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    if record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        Text(record.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textMuted)
                    .padding(.top, 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct GarageReviewTab: View {
    let records: [SwingRecord]
    @Binding var selectedRecordKey: String?
    let viewportHeight: CGFloat
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
                GarageFocusedReviewWorkspace(
                    record: selectedRecord,
                    viewportHeight: viewportHeight,
                    onExitReview: onBackToRecords
                )
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

enum GarageReviewMode: String, CaseIterable, Identifiable {
    case handPath
    case skeleton

    var id: String { rawValue }

    var title: String {
        switch self {
        case .handPath:
            "Hand Path"
        case .skeleton:
            "Skeleton"
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
        reviewFrameSource: GarageReviewFrameSourceState
    ) -> GarageReviewSummaryPresentation {
        let limitedSkeletonDetail = "Body outline is visible, but head and hip tracking were too weak for a stable score."

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
            poseQualityDetail = limitedSkeletonDetail
        default:
            poseQualityDetail = nil
        }

        return GarageReviewSummaryPresentation(
            reviewTitle: reviewMode == .handPath ? "Hand Path Review" : "Skeleton Review",
            reviewSubtitle: reviewMode == .handPath
                ? "Reviewing the detected grip path from setup to impact"
                : "Checking body alignment and stability through impact",
            poseQuality: resolvedPoseQuality,
            poseQualityDetail: poseQualityDetail,
            stabilityTitle: "Postural Stability",
            stabilitySubtitle: "A support metric based on head and pelvis drift from setup to impact",
            stabilityValueText: stabilityScore.map(String.init),
            stabilityStatusText: stabilityScore == nil ? "Stability unavailable" : "Support metric",
            stabilityDetail: stabilityScore == nil ? limitedSkeletonDetail : nil
        )
    }
}

struct GarageCoachingPresentation: Equatable {
    let title: String
    let headline: String
    let body: String
    let supportingLine: String?
    let confidenceLabel: String
    let phaseLabel: String
    let notes: [String]
    let isUnavailable: Bool

    static func make(
        report: GarageCoachingReport,
        selectedPhase: SwingPhase,
        reliabilityStatus: GarageReliabilityStatus
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

        return GarageCoachingPresentation(
            title: "Coaching Notes",
            headline: unavailable ? "Coaching unavailable" : headline,
            body: body,
            supportingLine: unavailable ? nil : "Use this as a cue, not a final judgment",
            confidenceLabel: reliabilityStatus.rawValue,
            phaseLabel: selectedPhase.reviewTitle,
            notes: Array(report.blockers.prefix(2)),
            isUnavailable: unavailable
        )
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

    private var resolvedReviewVideo: GarageResolvedReviewVideo? {
        GarageMediaStore.resolvedReviewVideo(for: record)
    }

    private var reviewVideoURL: URL? {
        resolvedReviewVideo?.url
    }

    private var reviewFrameSource: GarageReviewFrameSourceState {
        GarageMediaStore.reviewFrameSource(for: record)
    }

    private var orderedKeyframes: [GarageTimelineMarker] {
        record.keyFrames
            .sorted { lhs, rhs in
                (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
            }
            .compactMap { keyFrame in
                guard record.swingFrames.indices.contains(keyFrame.frameIndex) else {
                    return nil
                }

                return GarageTimelineMarker(
                    keyFrame: keyFrame,
                    timestamp: record.swingFrames[keyFrame.frameIndex].timestamp
                )
            }
    }

    private var selectedMarker: GarageTimelineMarker? {
        orderedKeyframes.first(where: { $0.keyFrame.phase == selectedPhase })
    }

    private var selectedKeyFrame: KeyFrame? {
        record.keyFrames.first(where: { $0.phase == selectedPhase })
    }

    private var selectedCheckpointStatus: KeyframeValidationStatus {
        selectedKeyFrame?.reviewStatus ?? .pending
    }

    private var selectedAnchor: HandAnchor? {
        record.handAnchors.first(where: { $0.phase == selectedPhase })
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
        guard record.swingFrames.isEmpty == false else {
            return nil
        }

        return record.swingFrames.enumerated().min { lhs, rhs in
            abs(lhs.element.timestamp - currentTime) < abs(rhs.element.timestamp - currentTime)
        }?.offset
    }

    private var currentFrame: SwingFrame? {
        guard let currentFrameIndex, record.swingFrames.indices.contains(currentFrameIndex) else {
            return nil
        }

        return record.swingFrames[currentFrameIndex]
    }

    private var currentFrameTimestamp: Double? {
        currentFrame?.timestamp
    }

    private var stabilityScore: Int? {
        GarageStability.score(for: record)
    }

    private var handPathReviewReport: GarageHandPathReviewReport {
        GarageAnalysisPipeline.handPathReviewReport(for: record.swingFrames, keyFrames: record.keyFrames)
    }

    private var coachingReport: GarageCoachingReport {
        GarageCoaching.report(for: record)
    }

    private var summaryPresentation: GarageReviewSummaryPresentation {
        GarageReviewSummaryPresentation.make(
            reviewMode: reviewMode,
            handPathReviewReport: handPathReviewReport,
            stabilityScore: stabilityScore,
            reviewFrameSource: reviewFrameSource
        )
    }

    private var coachingPresentation: GarageCoachingPresentation {
        GarageCoachingPresentation.make(
            report: coachingReport,
            selectedPhase: selectedPhase,
            reliabilityStatus: GarageReliability.report(for: record).status
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
        garageHandPathSamples(from: record.swingFrames, keyFrames: record.keyFrames)
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
        record.swingFrames.enumerated().map { index, frame in
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
                selectedAnchor: displayedAnchor,
                highlightTint: selectedAnchorTint,
                showsAnchorGuides: isDraggingAnchor,
                reviewMode: reviewMode,
                reviewSurface: reviewSurface,
                handPathSamples: fullHandPathSamples,
                currentTime: currentFrameTimestamp ?? currentTime,
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
            .overlay(alignment: .bottom) {
                GarageReviewFilmstrip(
                    videoURL: reviewVideoURL,
                    frames: filmstripFrames,
                    markers: orderedKeyframes,
                    currentFrameIndex: currentFrameIndex,
                    onSelectFrame: setCurrentFrameIndex
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.35), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
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
                        totalFrameCount: record.swingFrames.count,
                        onSelectPhase: selectPhase,
                        reviewRecoveryTitle: reviewRecoveryTitle,
                        reviewRecoveryBody: reviewRecoveryBody,
                        reviewFrameSource: reviewFrameSource
                    )
                } else {
                    GarageReviewSummaryControls(
                        summaryPresentation: summaryPresentation,
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
                    frames: record.swingFrames,
                    initialMode: .handPath
                )
            }
        }
        .sheet(isPresented: $isShowingSkeletonPlayback) {
            if let reviewVideoURL {
                GarageSkeletonReviewView(
                    videoURL: reviewVideoURL,
                    pathSamples: fullHandPathSamples,
                    frames: record.swingFrames
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
        } else if let firstTimestamp = record.swingFrames.first?.timestamp {
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
        return currentFrameIndex < record.swingFrames.count - 1
    }

    private var primaryActionEnabled: Bool {
        displayedAnchor != nil && currentFrameIndex != nil
    }

    private func stepFrame(by offset: Int) {
        let baseIndex = currentFrameIndex ?? 0
        setCurrentFrameIndex(baseIndex + offset)
    }

    private func setCurrentFrameIndex(_ index: Int) {
        guard record.swingFrames.isEmpty == false else { return }
        let clampedIndex = min(max(index, 0), record.swingFrames.count - 1)
        currentTime = record.swingFrames[clampedIndex].timestamp
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
            from: record.swingFrames,
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
        try? modelContext.save()
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
    let coachingPresentation: GarageCoachingPresentation
    let reviewRecoveryTitle: String
    let reviewRecoveryBody: String
    let reviewFrameSource: GarageReviewFrameSourceState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageReviewContextBand(presentation: summaryPresentation)

            GarageStabilityMetricCard(presentation: summaryPresentation)

            GarageCoachingReportView(presentation: coachingPresentation)

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
        HStack(spacing: 16) {
            GarageFrameStepButton(
                accessibilityLabel: "Previous frame",
                systemImage: "chevron.left",
                isEnabled: canStepBackward,
                action: onStepBackward
            )

            Spacer(minLength: 0)

            Button(action: onConfirm) {
                Label("Confirm Frame", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(garageReviewCanvasFill)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        GarageRaisedPanelBackground(
                            shape: Capsule(),
                            fill: garageReviewAccent,
                            stroke: garageReviewAccent.opacity(0.38),
                            glow: garageReviewAccent
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(canConfirm == false)
            .opacity(canConfirm ? 1 : 0.45)

            Spacer(minLength: 0)

            GarageFrameStepButton(
                accessibilityLabel: "Next frame",
                systemImage: "chevron.right",
                isEnabled: canStepForward,
                action: onStepForward
            )
        }
        .padding(.horizontal, ModuleSpacing.medium)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                fill: garageReviewSurface
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(garageReviewStroke.opacity(0.9))
                .frame(height: 1)
        }
    }
}

private struct GarageSummaryPrimaryActionBar: View {
    let canContinue: Bool
    let onContinue: () -> Void
    let onSkeletonReview: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onContinue) {
                Text(canContinue ? "Review Hand Path" : "Slow Motion Review Unavailable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(canContinue ? garageReviewCanvasFill : garageReviewMutedText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(canContinue ? garageReviewAccent : garageReviewSurfaceRaised)
                    )
            }
            .buttonStyle(.plain)
            .disabled(canContinue == false)
            .opacity(canContinue ? 1 : 0.78)

            Button(action: onSkeletonReview) {
                Text("Review Skeleton")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)
            }
            .buttonStyle(.plain)
            .disabled(canContinue == false)
            .opacity(canContinue ? 1 : 0.6)
        }
        .padding(.horizontal, ModuleSpacing.large)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                fill: garageReviewSurface
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(garageReviewStroke.opacity(0.9))
                .frame(height: 1)
        }
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
    let selectedAnchor: HandAnchor?
    let highlightTint: Color
    let showsAnchorGuides: Bool
    let reviewMode: GarageReviewMode
    let reviewSurface: GarageReviewSurface
    let handPathSamples: [GarageHandPathSample]
    let currentTime: Double
    let summaryPresentation: GarageReviewSummaryPresentation
    let preferredHeight: CGFloat
    let onSelectReviewMode: (GarageReviewMode) -> Void
    let onAnchorDragChanged: (CGPoint) -> Void
    let onAnchorDragEnded: (CGPoint) -> Void

    init(
        image: CGImage?,
        isLoadingFrame: Bool,
        currentFrame: SwingFrame?,
        selectedAnchor: HandAnchor?,
        highlightTint: Color,
        showsAnchorGuides: Bool,
        reviewMode: GarageReviewMode,
        reviewSurface: GarageReviewSurface,
        handPathSamples: [GarageHandPathSample],
        currentTime: Double,
        summaryPresentation: GarageReviewSummaryPresentation,
        preferredHeight: CGFloat,
        onSelectReviewMode: @escaping (GarageReviewMode) -> Void,
        onAnchorDragChanged: @escaping (CGPoint) -> Void,
        onAnchorDragEnded: @escaping (CGPoint) -> Void
    ) {
        self.image = image
        self.isLoadingFrame = isLoadingFrame
        self.currentFrame = currentFrame
        self.selectedAnchor = selectedAnchor
        self.highlightTint = highlightTint
        self.showsAnchorGuides = showsAnchorGuides
        self.reviewMode = reviewMode
        self.reviewSurface = reviewSurface
        self.handPathSamples = handPathSamples
        self.currentTime = currentTime
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
                    selectedAnchor: selectedAnchor,
                    highlightTint: highlightTint,
                    showsAnchorGuides: showsAnchorGuides,
                    reviewMode: reviewMode,
                    reviewSurface: reviewSurface,
                    handPathSamples: handPathSamples,
                    currentTime: currentTime,
                    skeletonOverlayOpacity: limitedSkeletonInspection ? 0.72 : 1,
                    onAnchorDragChanged: onAnchorDragChanged,
                    onAnchorDragEnded: onAnchorDragEnded
                )
            } else if let currentFrame {
                GaragePoseFallbackOverlay(
                    currentFrame: currentFrame,
                    selectedAnchor: selectedAnchor,
                    highlightTint: highlightTint,
                    showsAnchorGuides: showsAnchorGuides,
                    reviewMode: reviewMode,
                    reviewSurface: reviewSurface,
                    handPathSamples: handPathSamples,
                    currentTime: currentTime,
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
        .overlay(alignment: .top) {
            if reviewSurface == .summary {
                HStack(alignment: .top, spacing: 12) {
                    GaragePoseQualityBadge(level: summaryPresentation.poseQuality)
                    Spacer(minLength: 12)
                    GarageReviewModeSwitcher(
                        selectedMode: reviewMode,
                        onSelect: onSelectReviewMode
                    )
                }
                .padding(.horizontal, 14)
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
        HStack(spacing: 6) {
            ForEach(GarageReviewMode.allCases) { mode in
                let isSelected = mode == selectedMode
                Button {
                    onSelect(mode)
                } label: {
                    HStack(spacing: 4) {
                        Text(mode.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundStyle(isSelected ? garageReviewReadableText : garageReviewMutedText)
                    .frame(minHeight: 30)
                    .padding(.horizontal, 9)
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
        .padding(4)
        .background(Color.black.opacity(0.28), in: Capsule())
    }
}

private struct GaragePoseQualityBadge: View {
    let level: GaragePoseQualityLevel

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(level.tint)
                .frame(width: 8, height: 8)

            Text(level.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(garageReviewReadableText)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(
            GarageInsetPanelBackground(
                shape: Capsule(),
                fill: garageReviewSurface.opacity(0.82),
                stroke: level.tint.opacity(0.28)
            )
        )
        .accessibilityLabel(level.badgeText)
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

private struct GarageReviewImageOverlay: View {
    let image: CGImage
    let currentFrame: SwingFrame?
    let selectedAnchor: HandAnchor?
    let highlightTint: Color
    let showsAnchorGuides: Bool
    let reviewMode: GarageReviewMode
    let reviewSurface: GarageReviewSurface
    let handPathSamples: [GarageHandPathSample]
    let currentTime: Double
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
                        currentFrame: currentFrame
                    )
                    .opacity(skeletonOverlayOpacity)
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
                    .allowsHitTesting(false)
                }

                if reviewMode == .handPath, reviewSurface == .summary {
                    GarageReadOnlyHandPathOverlay(
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
                }
            }
        }
    }
}

private struct GaragePoseFallbackOverlay: View {
    let currentFrame: SwingFrame
    let selectedAnchor: HandAnchor?
    let highlightTint: Color
    let showsAnchorGuides: Bool
    let reviewMode: GarageReviewMode
    let reviewSurface: GarageReviewSurface
    let handPathSamples: [GarageHandPathSample]
    let currentTime: Double
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
                        currentFrame: currentFrame
                    )
                    .opacity(skeletonOverlayOpacity)
                    .frame(width: drawRect.width, height: drawRect.height)
                    .position(x: drawRect.midX, y: drawRect.midY)
                    .allowsHitTesting(false)
                }

                if reviewMode == .handPath, reviewSurface == .summary {
                    GarageReadOnlyHandPathOverlay(
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

private struct GarageReadOnlyHandPathOverlay: View {
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
                let normalizedSpeed = min(max(current.speed / maxSpeed, 0), 1)
                let baseWidth = 1.7 + (normalizedSpeed * 1.0)
                let accentColor = current.segment == .backswing
                    ? Color.white.opacity(0.84)
                    : garageReviewAccent.opacity(0.74)

                var segmentPath = Path()
                segmentPath.move(to: garageMappedPoint(x: previous.x, y: previous.y, in: drawRect))
                segmentPath.addLine(to: garageMappedPoint(x: current.x, y: current.y, in: drawRect))

                context.stroke(
                    segmentPath,
                    with: .color(Color.white.opacity(0.32)),
                    style: StrokeStyle(lineWidth: baseWidth + 0.9, lineCap: .round, lineJoin: .round)
                )
                context.stroke(
                    segmentPath,
                    with: .color(accentColor),
                    style: StrokeStyle(lineWidth: baseWidth, lineCap: .round, lineJoin: .round)
                )
            }

            if let visibleCurrentSample {
                let point = garageMappedPoint(x: visibleCurrentSample.x, y: visibleCurrentSample.y, in: drawRect)
                let outerRect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                let innerRect = CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)
                context.fill(Ellipse().path(in: outerRect), with: .color(Color.white.opacity(0.92)))
                context.fill(
                    Ellipse().path(in: innerRect),
                    with: .color(visibleCurrentSample.segment == .backswing ? Color.white : garageReviewAccent)
                )
            }
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
private let garageReviewStroke = Color.white.opacity(0.07)
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
                    .stroke(stroke, lineWidth: 1)
            )
            .shadow(color: garageReviewShadowDark, radius: 16, x: 10, y: 10)
            .shadow(color: garageReviewShadowLight, radius: 12, x: -6, y: -6)
            .shadow(color: (glow ?? .clear).opacity(glow == nil ? 0 : 0.35), radius: glow == nil ? 0 : 12, x: 0, y: 0)
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
                    .stroke(stroke, lineWidth: 1)
            )
            .overlay(
                shape
                    .stroke(garageReviewShadowLight.opacity(0.65), lineWidth: 1)
                    .blur(radius: 1)
                    .mask(shape.fill(LinearGradient(colors: [.white, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)))
            )
            .shadow(color: garageReviewShadowDark.opacity(0.55), radius: 10, x: 6, y: 6)
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
                .frame(width: 36, height: 36)
                .foregroundStyle(isEnabled ? garageReviewReadableText : garageReviewMutedText.opacity(0.8))
                .background(
                    GarageRaisedPanelBackground(
                        shape: Circle(),
                        fill: garageReviewSurfaceRaised
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
    let initialMode: GarageReviewMode

    @StateObject private var playbackController: GarageSlowMotionPlaybackController
    @State private var videoDisplaySize = CGSize(width: 1, height: 1)
    @State private var selectedSpeed: Float = 1.0
    @State private var reviewMode: GarageReviewMode

    init(videoURL: URL, pathSamples: [GarageHandPathSample], frames: [SwingFrame], initialMode: GarageReviewMode) {
        self.videoURL = videoURL
        self.pathSamples = pathSamples
        self.frames = frames
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
                    videoSize: videoDisplaySize
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
                    Text("Open Skeleton Review")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)
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

    var body: some View {
        GarageSlowMotionPlaybackSheet(
            videoURL: videoURL,
            pathSamples: pathSamples,
            frames: frames,
            initialMode: .skeleton
        )
    }
}

private struct GaragePlaybackActionBar: View {
    let onRecheck: () -> Void
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onRecheck) {
                Text("Recheck Frames")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(garageReviewStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button(action: onFinish) {
                Text("Finish Review")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(garageReviewCanvasFill)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(garageReviewAccent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ModuleSpacing.large)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                fill: garageReviewSurface
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(garageReviewStroke.opacity(0.9))
                .frame(height: 1)
        }
    }
}

private struct GaragePlaybackControlRow: View {
    let currentTime: Double
    let duration: Double
    let isPlaying: Bool
    let selectedSpeed: Float
    let onScrub: (Double) -> Void
    let onTogglePlayPause: () -> Void
    let onSelectSpeed: (Float) -> Void
    @State private var scrubTime = 0.0
    @State private var isScrubbing = false

    var body: some View {
        VStack(spacing: 10) {
            Slider(
                value: Binding(
                    get: { scrubTime },
                    set: { scrubTime = $0 }
                ),
                in: 0...sliderMaxValue,
                onEditingChanged: handleScrubEditingChanged
            )
            .tint(garageReviewAccent)

            HStack(spacing: 14) {
                Button(action: onTogglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                .accessibilityValue(speedLabel(for: Double(selectedSpeed)))

                ForEach([1.0, 0.5, 0.25], id: \.self) { speed in
                    let speedValue = Float(speed)
                    Button {
                        onSelectSpeed(speedValue)
                    } label: {
                        Text(speedLabel(for: speed))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedSpeed == speedValue ? garageReviewReadableText : garageReviewMutedText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedSpeed == speedValue ? garageReviewAccent.opacity(0.2) : Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
        if isEditing == false {
            onScrub(scrubTime)
        }
    }
}

private struct GarageSlowMotionVisualizationOverlay: View {
    let mode: GarageReviewMode
    let pathSamples: [GarageHandPathSample]
    let frames: [SwingFrame]
    let currentTime: Double
    let videoSize: CGSize

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
                    currentFrame: currentFrame
                )
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
                        let normalizedSpeed = min(max(current.speed / maxSpeed, 0), 1)
                        let baseWidth = 1.9 + (normalizedSpeed * 1.2)
                        let accentColor = current.segment == .backswing
                            ? Color.white.opacity(0.88)
                            : garageReviewAccent.opacity(0.66)

                        var segmentPath = Path()
                        segmentPath.move(to: mappedPoint(x: previous.x, y: previous.y, in: videoRect))
                        segmentPath.addLine(to: mappedPoint(x: current.x, y: current.y, in: videoRect))

                        context.stroke(
                            segmentPath,
                            with: .color(Color.white.opacity(0.52)),
                            style: StrokeStyle(lineWidth: baseWidth + 1.0, lineCap: .round, lineJoin: .round)
                        )
                        context.stroke(
                            segmentPath,
                            with: .color(accentColor),
                            style: StrokeStyle(lineWidth: baseWidth, lineCap: .round, lineJoin: .round)
                        )
                    }

                    let lastSample = pathSamples[visibleSampleCount - 1]
                    let point = mappedPoint(x: lastSample.x, y: lastSample.y, in: videoRect)
                    let outerRect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                    context.fill(Ellipse().path(in: outerRect), with: .color(Color.white.opacity(0.92)))
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
            self?.player.pause()
            self?.isPlaying = false
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

private struct GarageImportPresentationScreen: View {
    let state: GarageImportPresentationState
    let onDismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            AppModule.garage.theme.screenGradient
                .ignoresSafeArea()

            VStack(spacing: ModuleSpacing.large) {
                VStack(spacing: 10) {
                    Text("Garage")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.accentText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(AppModule.garage.theme.primary.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(AppModule.garage.theme.primary.opacity(0.18), lineWidth: 1)
                                )
                        )

                    Text(state.headline)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    Text(state.detail)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                if let activeStepTitle = state.activeStepTitle {
                    Text(activeStepTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            GarageInsetPanelBackground(
                                shape: Capsule(),
                                fill: garageReviewInsetSurface
                            )
                        )
                }

                if state.showsProgress {
                    ZStack {
                        Circle()
                            .fill(garageReviewSurfaceRaised)
                            .frame(width: 78, height: 78)
                            .shadow(color: garageReviewAccent.opacity(0.28), radius: 16, x: 0, y: 0)

                        ProgressView()
                            .controlSize(.large)
                            .tint(AppModule.garage.theme.primary)
                            .scaleEffect(1.2)
                    }
                }

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
            .frame(maxWidth: 320)
            .padding(ModuleSpacing.large)
            .background(
                GarageRaisedPanelBackground(
                    shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                    fill: garageReviewSurface
                )
            )
            .padding(ModuleSpacing.large)
        }
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
