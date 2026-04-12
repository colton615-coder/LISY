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

    init(
        id: Int,
        timestamp: Double,
        x: Double,
        y: Double,
        speed: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.speed = speed
    }
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

private func garageHandPathSamples(from frames: [SwingFrame]) -> [GarageHandPathSample] {
    guard frames.count >= 2 else {
        return []
    }

    let smoothedCenters = GarageAnalysisPipeline.generatePathPoints(from: frames, samplesPerSegment: 6).map {
        CGPoint(x: $0.x, y: $0.y)
    }
    guard smoothedCenters.count >= 2 else { return [] }

    return smoothedCenters.enumerated().map { index, point in
        let priorIndex = max(index - 1, 0)
        let nextIndex = min(index + 1, smoothedCenters.count - 1)
        let previousPoint = smoothedCenters[priorIndex]
        let nextPoint = smoothedCenters[nextIndex]
        let speed = GarageAnalysisPipeline.distance(from: previousPoint, to: nextPoint)
        let normalizedT = Double(index) / Double(max(smoothedCenters.count - 1, 1))
        let sourceFrame = min(Int((Double(frames.count - 1) * normalizedT).rounded()), frames.count - 1)

        return GarageHandPathSample(
            id: garageDeterministicHandPathSampleID(index: index, timestamp: frames[sourceFrame].timestamp),
            timestamp: frames[sourceFrame].timestamp,
            x: point.x,
            y: point.y,
            speed: speed
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
                    keyFrames: output.keyFrames,
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

private enum GarageReviewMode: String, CaseIterable, Identifiable {
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
    @State private var didAutoPresentCompletionPlayback = false
    @State private var reviewMode: GarageReviewMode = .handPath
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

    private var frameRequestID: String {
        [
            garageRecordSelectionKey(for: record),
            reviewVideoURL?.absoluteString ?? "no-video",
            String(format: "%.4f", currentFrameTimestamp ?? currentTime)
        ].joined(separator: "::")
    }

    private var fullHandPathSamples: [GarageHandPathSample] {
        garageHandPathSamples(from: record.swingFrames)
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
        max(viewportHeight * 0.74, 420)
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
                stabilityScore: stabilityScore,
                preferredHeight: videoStageHeight,
                onExitReview: onExitReview,
                onSelectReviewMode: selectReviewMode,
                onAnchorDragChanged: handleAnchorDragChanged,
                onAnchorDragEnded: handleAnchorDragEnded
            )
            .frame(maxWidth: .infinity)

            GarageReviewScrollableControls(
                videoURL: reviewVideoURL,
                frames: filmstripFrames,
                markers: orderedKeyframes,
                selectedPhase: selectedPhase,
                currentFrameIndex: currentFrameIndex,
                totalFrameCount: record.swingFrames.count,
                onSelectPhase: selectPhase,
                onSelectFrame: setCurrentFrameIndex,
                reviewRecoveryTitle: reviewRecoveryTitle,
                reviewRecoveryBody: reviewRecoveryBody,
                reviewFrameSource: reviewFrameSource,
                showsCompletionPlayback: record.allCheckpointsApproved && reviewVideoURL != nil,
                onOpenCompletionPlayback: {
                    isShowingCompletionPlayback = true
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(garageReviewBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GarageReviewActionDock(
                canStepBackward: canStepBackward,
                canStepForward: canStepForward,
                canConfirm: displayedAnchor != nil && currentFrameIndex != nil,
                onStepBackward: { stepFrame(by: -1) },
                onStepForward: { stepFrame(by: 1) },
                onConfirm: confirmSelectionAndAdvance
            )
        }
        .sheet(isPresented: $isShowingCompletionPlayback) {
            if let reviewVideoURL {
                GarageSlowMotionPlaybackSheet(
                    videoURL: reviewVideoURL,
                    pathSamples: fullHandPathSamples
                )
            }
        }
        .task(id: garageRecordSelectionKey(for: record)) {
            record.hydrateCheckpointStatusesFromAggregateIfNeeded()
            record.refreshKeyframeValidationStatus()
            try? modelContext.save()
            reviewMode = .handPath
            syncSelectedPhase()
            seekToSelectedCheckpoint()
            autoPresentCompletionPlaybackIfNeeded()
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
            maximumSize: CGSize(width: 1100, height: 1100)
        )

        await MainActor.run {
            reviewImage = image
            isLoadingFrame = false
        }
    }

    private func syncSelectedPhase() {
        selectedPhase = initialPhaseSelection()
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

    private func stepFrame(by offset: Int) {
        let baseIndex = currentFrameIndex ?? 0
        setCurrentFrameIndex(baseIndex + offset)
    }

    private func setCurrentFrameIndex(_ index: Int) {
        guard record.swingFrames.isEmpty == false else { return }
        let clampedIndex = min(max(index, 0), record.swingFrames.count - 1)
        currentTime = record.swingFrames[clampedIndex].timestamp
    }

    private func selectReviewMode(_ mode: GarageReviewMode) {
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
            autoPresentCompletionPlaybackIfNeeded()
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
        didAutoPresentCompletionPlayback = false
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

    private func autoPresentCompletionPlaybackIfNeeded() {
        guard record.allCheckpointsApproved, didAutoPresentCompletionPlayback == false, reviewVideoURL != nil else { return }
        didAutoPresentCompletionPlayback = true
        isShowingCompletionPlayback = true
    }
}

private struct GarageReviewScrollableControls: View {
    let videoURL: URL?
    let frames: [GarageFilmstripFrame]
    let markers: [GarageTimelineMarker]
    let selectedPhase: SwingPhase
    let currentFrameIndex: Int?
    let totalFrameCount: Int
    let onSelectPhase: (SwingPhase) -> Void
    let onSelectFrame: (Int) -> Void
    let reviewRecoveryTitle: String
    let reviewRecoveryBody: String
    let reviewFrameSource: GarageReviewFrameSourceState
    let showsCompletionPlayback: Bool
    let onOpenCompletionPlayback: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
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

                GarageReviewFilmstrip(
                    videoURL: videoURL,
                    frames: frames,
                    markers: markers,
                    currentFrameIndex: currentFrameIndex,
                    onSelectFrame: onSelectFrame
                )

                if reviewFrameSource != .video {
                    GarageReviewRecoveryCallout(
                        title: reviewRecoveryTitle,
                        message: reviewRecoveryBody,
                        state: reviewFrameSource
                    )
                }

                if showsCompletionPlayback {
                    GarageCompletionPlaybackCallout(replay: onOpenCompletionPlayback)
                }
            }
            .padding(.horizontal, ModuleSpacing.medium)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
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
                Label("Confirm Frame + Hand", systemImage: "checkmark")
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
    let stabilityScore: Int?
    let preferredHeight: CGFloat
    let onExitReview: () -> Void
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
        stabilityScore: Int?,
        preferredHeight: CGFloat,
        onExitReview: @escaping () -> Void,
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
        self.stabilityScore = stabilityScore
        self.preferredHeight = preferredHeight
        self.onExitReview = onExitReview
        self.onSelectReviewMode = onSelectReviewMode
        self.onAnchorDragChanged = onAnchorDragChanged
        self.onAnchorDragEnded = onAnchorDragEnded
    }

    var body: some View {
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
        .overlay(alignment: .topLeading) {
            Button(action: onExitReview) {
                Label("Swings", systemImage: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        GarageRaisedPanelBackground(
                            shape: Capsule(),
                            fill: garageReviewSurfaceRaised
                        )
                    )
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 10) {
                GarageReviewModeSwitcher(
                    selectedMode: reviewMode,
                    onSelect: onSelectReviewMode
                )

                if reviewMode == .skeleton {
                    GarageStabilityScoreChip(score: stabilityScore)
                }
            }
            .padding(14)
        }
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
                Button {
                    onSelect(mode)
                } label: {
                    Text(mode.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(mode == selectedMode ? garageReviewCanvasFill : garageReviewReadableText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(mode == selectedMode ? garageReviewAccent : Color.clear)
                                .shadow(
                                    color: mode == selectedMode ? garageReviewAccent.opacity(0.45) : .clear,
                                    radius: mode == selectedMode ? 10 : 0,
                                    x: 0,
                                    y: 0
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            GarageRaisedPanelBackground(
                shape: Capsule(),
                fill: garageReviewSurface,
                stroke: garageReviewStroke
            )
        )
    }
}

private struct GarageStabilityScoreChip: View {
    let score: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Postural Stability")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(garageReviewMutedText)

            Text(score.map { "Stability \($0)" } ?? "Stability N/A")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(garageReviewAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            GarageInsetPanelBackground(
                shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                fill: garageReviewInsetSurface,
                stroke: garageReviewStroke.opacity(0.9)
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
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                if reviewMode == .skeleton {
                    GarageSkeletonOverlay(
                        drawRect: imageRect,
                        currentFrame: currentFrame
                    )
                    .allowsHitTesting(false)
                }

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

private struct GaragePoseFallbackOverlay: View {
    let currentFrame: SwingFrame
    let selectedAnchor: HandAnchor?
    let highlightTint: Color
    let showsAnchorGuides: Bool
    let reviewMode: GarageReviewMode
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
                        drawRect: drawRect,
                        currentFrame: currentFrame
                    )
                    .allowsHitTesting(false)
                }

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
                let haloRect = CGRect(x: anchorPoint.x - 18, y: anchorPoint.y - 18, width: 36, height: 36)
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
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(tint, lineWidth: 1.5)
                )
                .shadow(color: garageReviewShadowDark.opacity(0.7), radius: 10, x: 6, y: 6)
                .shadow(color: garageReviewShadowLight.opacity(0.7), radius: 8, x: -4, y: -4)

            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .shadow(color: tint.opacity(0.6), radius: 4, x: 0, y: 0)
        }
        .frame(width: 44, height: 44)
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

    @StateObject private var playbackController: GarageSlowMotionPlaybackController
    @State private var videoDisplaySize = CGSize(width: 1, height: 1)

    init(videoURL: URL, pathSamples: [GarageHandPathSample]) {
        self.videoURL = videoURL
        self.pathSamples = pathSamples
        _playbackController = StateObject(wrappedValue: GarageSlowMotionPlaybackController(url: videoURL))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
                Text("Slow-motion review")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                Text("A clean replay of the approved swing with the hand path drawn progressively across the full motion.")
                    .foregroundStyle(AppModule.garage.theme.textSecondary)

                ZStack {
                    GarageSlowMotionPlayerView(player: playbackController.player)
                        .frame(minHeight: 480)
                        .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))

                    GarageSlowMotionPathOverlay(
                        pathSamples: pathSamples,
                        currentTime: playbackController.currentTime,
                        videoSize: videoDisplaySize
                    )
                    .allowsHitTesting(false)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                        .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
                )

                HStack(spacing: ModuleSpacing.medium) {
                    Text("Playback \(String(format: "%.2fs", playbackController.currentTime))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textSecondary)

                    Spacer(minLength: 0)

                    Button("Replay") {
                        playbackController.replay()
                    }
                    .buttonStyle(.plain)
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
            }
            .padding(ModuleSpacing.large)
            .navigationTitle("Approved Playback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            let metadata = await GarageMediaStore.assetMetadata(for: videoURL)
            await MainActor.run {
                videoDisplaySize = metadata?.naturalSize ?? CGSize(width: 1, height: 1)
            }
        }
        .onAppear {
            playbackController.startSlowMotion()
        }
        .onDisappear {
            playbackController.stop()
        }
    }
}

private struct GarageSlowMotionPathOverlay: View {
    let pathSamples: [GarageHandPathSample]
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

    var body: some View {
        GeometryReader { proxy in
            let containerRect = CGRect(origin: .zero, size: proxy.size)
            let videoRect = aspectFitRect(videoSize: videoSize, in: containerRect)

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
                    let baseWidth = 2.4 + (normalizedSpeed * 2.2)

                    var segmentPath = Path()
                    segmentPath.move(to: mappedPoint(x: previous.x, y: previous.y, in: videoRect))
                    segmentPath.addLine(to: mappedPoint(x: current.x, y: current.y, in: videoRect))

                    context.stroke(
                        segmentPath,
                        with: .color(Color.white.opacity(0.78)),
                        style: StrokeStyle(lineWidth: baseWidth + 2.0, lineCap: .round, lineJoin: .round)
                    )
                    context.stroke(
                        segmentPath,
                        with: .color(garageReviewAccent.opacity(0.45 + (normalizedSpeed * 0.45))),
                        style: StrokeStyle(lineWidth: baseWidth, lineCap: .round, lineJoin: .round)
                    )
                }

                let lastSample = pathSamples[visibleSampleCount - 1]
                let point = mappedPoint(x: lastSample.x, y: lastSample.y, in: videoRect)
                let outerRect = CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)
                let innerRect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                context.fill(Ellipse().path(in: outerRect), with: .color(Color.white))
                context.fill(Ellipse().path(in: innerRect), with: .color(garageReviewAccent))
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

    let player: AVPlayer

    private var timeObserverToken: Any?
    private var playbackEndObserver: NSObjectProtocol?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 60.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTime = max(CMTimeGetSeconds(time), 0)
            }
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.pause()
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

    func startSlowMotion() {
        replay()
    }

    func replay() {
        currentTime = 0
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player.playImmediately(atRate: 0.35)
    }

    func stop() {
        player.pause()
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
