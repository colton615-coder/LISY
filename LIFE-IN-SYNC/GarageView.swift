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
            garageReviewMutedText
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
    @Query(sort: \SwingRecord.createdAt, order: .reverse) private var swingRecords: [SwingRecord]
    @State private var isShowingAddRecord = false
    @State private var selectedTab: ModuleHubTab = .records
    @State private var selectedReviewRecordKey: String?

    var body: some View {
        ModuleHubScaffold(
            module: .garage,
            title: "Store swing work without overclaiming analysis.",
            subtitle: "Review swing checkpoints with a calmer, accuracy-first workflow.",
            currentState: "\(swingRecords.count) swing records currently stored.",
            nextAttention: swingRecords.isEmpty ? "Import your first swing video to begin review." : "Use Review to validate checkpoints and refine the current swing.",
            showsCommandCenterChrome: false,
            tabs: [.records, .review],
            selectedTab: $selectedTab
        ) {
            switch selectedTab {
            case .records:
                GarageRecordsTab(records: swingRecords) {
                    presentAddRecord()
                }
            case .review:
                GarageReviewTab(records: swingRecords, selectedRecordKey: $selectedReviewRecordKey)
            default:
                EmptyView()
            }
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
        .sheet(isPresented: $isShowingAddRecord) {
            AddSwingRecordSheet(autoPresentPicker: true, autoImportOnSelection: true) { record in
                selectedReviewRecordKey = garageRecordSelectionKey(for: record)
                selectedTab = .review
            }
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
}

private struct GarageRecordsTab: View {
    let records: [SwingRecord]
    let importVideo: () -> Void

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
                    Button("Import Swing Video", action: importVideo)
                        .buttonStyle(.borderedProminent)
                        .tint(AppModule.garage.theme.primary)
                }

                ForEach(records.prefix(8)) { record in
                    SwingRecordCard(record: record)
                }
            }
        }
    }
}

private struct SwingRecordCard: View {
    let record: SwingRecord

    private var reviewStateLabel: String {
        switch record.keyframeValidationStatus {
        case .approved:
            "Approved"
        case .flagged:
            "Flagged"
        case .pending:
            "Needs Review"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.title)
                .font(.headline)

            if record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Text(record.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: ModuleSpacing.small) {
                GarageReviewStatusPill(status: record.keyframeValidationStatus)

                Text(reviewStateLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textSecondary)

                Spacer(minLength: 0)

                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct GarageReviewTab: View {
    let records: [SwingRecord]
    @Binding var selectedRecordKey: String?

    private var selectedRecord: SwingRecord? {
        if let selectedRecordKey {
            return records.first(where: { garageRecordSelectionKey(for: $0) == selectedRecordKey }) ?? records.first
        }

        return records.first
    }

    var body: some View {
        ModuleActivityFeedSection(title: "Checkpoint Review") {
            if let selectedRecord {
                VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
                    HStack(alignment: .center, spacing: ModuleSpacing.medium) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Swing")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppModule.garage.theme.textMuted)

                            Menu {
                                ForEach(records) { record in
                                    Button(record.title) {
                                        selectedRecordKey = garageRecordSelectionKey(for: record)
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(selectedRecord.title)
                                        .font(.title3.weight(.bold))
                                        .lineLimit(1)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundStyle(AppModule.garage.theme.textPrimary)
                            }
                            .menuStyle(.borderlessButton)
                        }

                        Spacer(minLength: 0)
                    }

                    GarageFocusedReviewWorkspace(record: selectedRecord)
                }
            } else {
                ModuleEmptyStateCard(
                    theme: AppModule.garage.theme,
                    title: "Review workflow is ready",
                    message: "Import a swing video from Overview or Records to begin checkpoint review.",
                    actionTitle: "Go To Records",
                    action: {}
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

private struct GarageManualAnchorDraft: Equatable {
    let frameIndex: Int
    var point: CGPoint
}

private enum GarageOverlayPresentationMode {
    case anchorOnly
    case diagnosticPose
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

    @State private var currentTime = 0.0
    @State private var reviewImage: CGImage?
    @State private var isLoadingFrame = false
    @State private var assetDuration = 0.0
    @State private var selectedPhase: SwingPhase = .address
    @State private var isShowingCompletionPlayback = false
    @State private var didAutoPresentCompletionPlayback = false
    @State private var isEditingAnchor = false
    @State private var manualAnchorDraft: GarageManualAnchorDraft?
    @State private var overlayPresentationMode: GarageOverlayPresentationMode = .anchorOnly
    @State private var isShowingAnalysisOverlay = false

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

    private var displayedAnchor: HandAnchor? {
        if let manualAnchorDraft {
            return HandAnchor(
                phase: selectedPhase,
                x: manualAnchorDraft.point.x,
                y: manualAnchorDraft.point.y,
                source: .manual
            )
        }

        return selectedAnchor
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

    private var effectiveDuration: Double {
        max(record.swingFrames.map(\.timestamp).max() ?? 0, assetDuration, 0.1)
    }

    private var frameRequestID: String {
        [
            garageRecordSelectionKey(for: record),
            reviewVideoURL?.absoluteString ?? "no-video",
            String(format: "%.4f", currentTime)
        ].joined(separator: "::")
    }

    private var fullHandPathSamples: [GarageHandPathSample] {
        garageHandPathSamples(from: record.swingFrames)
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

    var body: some View {
        VStack(spacing: 0) {
            GarageFocusedReviewFrame(
                source: reviewFrameSource,
                image: reviewImage,
                isLoadingFrame: isLoadingFrame,
                currentFrame: currentFrame,
                selectedAnchor: displayedAnchor,
                highlightedStatus: selectedCheckpointStatus,
                isEditingAnchor: isEditingAnchor,
                overlayMode: overlayPresentationMode,
                onSetAnchor: updateDraftAnchor
            ) {
                VStack(spacing: 10) {
                    HStack {
                        Spacer(minLength: 0)
                        Button {
                            isShowingAnalysisOverlay.toggle()
                        } label: {
                            Label(isShowingAnalysisOverlay ? "Hide Analysis" : "Show Analysis", systemImage: isShowingAnalysisOverlay ? "eye.slash.fill" : "eye.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(garageReviewReadableText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(garageReviewGlassBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    GarageReviewToolRail(
                        selectedStatus: selectedCheckpointStatus,
                        isEditingAnchor: isEditingAnchor,
                        canAdjustCurrentFrame: currentFrameIndex != nil,
                        canMoveBetweenCheckpoints: orderedKeyframes.isEmpty == false,
                        onPrevious: previousCheckpoint,
                        onBeginAdjust: beginAnchorEditing,
                        onCancelAdjust: cancelAnchorEditing,
                        onSaveAdjust: saveAnchorAdjustment,
                        onApprove: approveCheckpoint,
                        onFlag: flagCheckpoint,
                        onNext: nextCheckpoint
                    )
                }
                .padding(.horizontal, ModuleSpacing.medium)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
                HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(selectedPhase.reviewTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(garageReviewReadableText)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                GarageCheckpointStatusBadge(status: selectedCheckpointStatus)

                                if selectedKeyFrame?.source == .adjusted {
                                    GarageMetadataBadge(
                                        title: "Frame adjusted",
                                        systemImage: "timeline.selection",
                                        tint: .orange
                                    )
                                }

                                if displayedAnchor?.source == .manual {
                                    GarageMetadataBadge(
                                        title: "Manual anchor",
                                        systemImage: "hand.draw.fill",
                                        tint: garageReviewMutedText
                                    )
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GarageCheckpointProgressSummary(record: record)
                        .fixedSize(horizontal: true, vertical: true)
                }

                GarageCheckpointProgressStrip(
                    selectedPhase: selectedPhase,
                    markers: orderedKeyframes,
                    statusProvider: { record.reviewStatus(for: $0) }
                ) { phase in
                    cancelAnchorEditing()
                    selectedPhase = phase
                    seekToSelectedCheckpoint()
                }

                if reviewFrameSource != .video {
                    GarageReviewRecoveryCallout(
                        title: reviewRecoveryTitle,
                        message: reviewRecoveryBody,
                        state: reviewFrameSource
                    )
                }

                if record.allCheckpointsApproved, let reviewVideoURL {
                    GarageCompletionPlaybackCallout {
                        isShowingCompletionPlayback = true
                    }
                    .sheet(isPresented: $isShowingCompletionPlayback) {
                        GarageSlowMotionPlaybackSheet(
                            videoURL: reviewVideoURL,
                            pathSamples: fullHandPathSamples
                        )
                    }
                }
            }
            .padding(.horizontal, ModuleSpacing.medium)
            .padding(.top, ModuleSpacing.medium)
            .padding(.bottom, ModuleSpacing.medium)
            .background(garageReviewSurface)
        }
        .background(garageReviewBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(isEditingAnchor ? "Scrub to the exact frame, then drag the hand marker into place." : "Scrub to pinpoint the checkpoint frame.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(garageReviewMutedText)

                    Spacer(minLength: 0)

                    if let currentFrameIndex {
                        Text("Frame \(currentFrameIndex + 1)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(garageReviewReadableText)
                    }
                }

                GarageTimelineScrubber(
                    range: 0...effectiveDuration,
                    currentTime: $currentTime,
                    markers: orderedKeyframes,
                    selectedPhase: selectedPhase,
                    statusProvider: { record.reviewStatus(for: $0) }
                )

                HStack(spacing: 12) {
                    GarageFrameStepButton(
                        title: "Prev Frame",
                        systemImage: "chevron.left",
                        isEnabled: canStepBackward,
                        action: { stepFrame(by: -1) }
                    )
                    .accessibilityLabel("Previous frame")
                    .accessibilityHint("Moves backward by exactly one frame")

                    Spacer(minLength: 0)

                    if let currentFrameIndex {
                        Text("\(currentFrameIndex + 1) / \(record.swingFrames.count) frames")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(garageReviewReadableText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    Spacer(minLength: 0)

                    GarageFrameStepButton(
                        title: "Next Frame",
                        systemImage: "chevron.right",
                        isEnabled: canStepForward,
                        action: { stepFrame(by: 1) }
                    )
                    .accessibilityLabel("Next frame")
                    .accessibilityHint("Moves forward by exactly one frame")
                }
                .padding(10)
                .background(
                    GarageInsetPanelBackground(
                        shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous)
                    )
                )
            }
            .padding(.horizontal, ModuleSpacing.medium)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background(
                Rectangle()
                    .fill(garageReviewBackground.opacity(0.96))
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(garageReviewGlassBorder.opacity(0.18))
                            .frame(height: 1)
                    }
            )
        }
        .task(id: garageRecordSelectionKey(for: record)) {
            record.hydrateCheckpointStatusesFromAggregateIfNeeded()
            record.refreshKeyframeValidationStatus()
            try? modelContext.save()
            syncSelectedPhase()
            seekToSelectedCheckpoint()
            await loadAssetDuration()
            autoPresentCompletionPlaybackIfNeeded()
        }
        .task(id: frameRequestID) {
            await loadFrameImage()
        }
        .onChange(of: currentFrameIndex) { _, _ in
            syncDraftAnchorWithCurrentFrame()
        }
        .onChange(of: isShowingAnalysisOverlay) { _, isShowing in
            overlayPresentationMode = isShowing ? .diagnosticPose : .anchorOnly
        }
    }

    private func loadAssetDuration() async {
        guard let reviewVideoURL else {
            await MainActor.run {
                assetDuration = record.swingFrames.map(\.timestamp).max() ?? 0
            }
            return
        }

        let metadata = await GarageMediaStore.assetMetadata(for: reviewVideoURL)
        await MainActor.run {
            assetDuration = metadata?.duration ?? (record.swingFrames.map(\.timestamp).max() ?? 0)
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
            at: currentTime,
            maximumSize: CGSize(width: 1600, height: 1600)
        )

        await MainActor.run {
            reviewImage = image
            isLoadingFrame = false
        }
    }

    private func syncSelectedPhase() {
        if orderedKeyframes.contains(where: { $0.keyFrame.phase == selectedPhase }) {
            return
        }

        selectedPhase = orderedKeyframes.first?.keyFrame.phase ?? .address
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

    private func previousCheckpoint() {
        cancelAnchorEditing()
        moveCheckpointSelection(by: -1)
    }

    private func nextCheckpoint() {
        cancelAnchorEditing()
        moveCheckpointSelection(by: 1)
    }

    private func moveCheckpointSelection(by offset: Int) {
        guard orderedKeyframes.isEmpty == false else { return }
        let currentIndex = orderedKeyframes.firstIndex(where: { $0.keyFrame.phase == selectedPhase }) ?? 0
        let targetIndex = min(max(currentIndex + offset, 0), orderedKeyframes.count - 1)
        selectedPhase = orderedKeyframes[targetIndex].keyFrame.phase
        seekToSelectedCheckpoint()
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

    private func approveCheckpoint() {
        cancelAnchorEditing()
        guard let keyframeIndex = record.keyFrames.firstIndex(where: { $0.phase == selectedPhase }) else { return }
        record.keyFrames[keyframeIndex].reviewStatus = .approved
        record.refreshKeyframeValidationStatus()
        try? modelContext.save()
        autoPresentCompletionPlaybackIfNeeded()
    }

    private func flagCheckpoint() {
        cancelAnchorEditing()
        guard let keyframeIndex = record.keyFrames.firstIndex(where: { $0.phase == selectedPhase }) else { return }
        record.keyFrames[keyframeIndex].reviewStatus = .flagged
        record.refreshKeyframeValidationStatus()
        try? modelContext.save()
        didAutoPresentCompletionPlayback = false
    }

    private func beginAnchorEditing() {
        guard currentFrameIndex != nil else { return }
        isEditingAnchor = true
        syncDraftAnchorWithCurrentFrame()
    }

    private func cancelAnchorEditing() {
        isEditingAnchor = false
        manualAnchorDraft = nil
    }

    private func syncDraftAnchorWithCurrentFrame() {
        guard isEditingAnchor, let currentFrameIndex, let currentFrame else {
            return
        }

        let initialPoint: CGPoint
        if selectedKeyFrame?.frameIndex == currentFrameIndex, let selectedAnchor {
            initialPoint = CGPoint(x: selectedAnchor.x, y: selectedAnchor.y)
        } else {
            initialPoint = GarageAnalysisPipeline.handCenter(in: currentFrame)
        }

        manualAnchorDraft = GarageManualAnchorDraft(
            frameIndex: currentFrameIndex,
            point: garageClampedNormalizedPoint(initialPoint)
        )
    }

    private func updateDraftAnchor(_ point: CGPoint) {
        guard isEditingAnchor, let currentFrameIndex else {
            return
        }

        manualAnchorDraft = GarageManualAnchorDraft(
            frameIndex: currentFrameIndex,
            point: garageClampedNormalizedPoint(point)
        )
    }

    private func saveAnchorAdjustment() {
        guard let manualAnchorDraft else { return }

        if let keyframeIndex = record.keyFrames.firstIndex(where: { $0.phase == selectedPhase }) {
            record.keyFrames[keyframeIndex].frameIndex = manualAnchorDraft.frameIndex
            record.keyFrames[keyframeIndex].source = .adjusted
            record.keyFrames[keyframeIndex].reviewStatus = .pending
        } else {
            record.keyFrames.append(
                KeyFrame(
                    phase: selectedPhase,
                    frameIndex: manualAnchorDraft.frameIndex,
                    source: .adjusted,
                    reviewStatus: .pending
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
                x: manualAnchorDraft.point.x,
                y: manualAnchorDraft.point.y,
                source: .manual
            ),
            into: mergedAnchors
        )

        record.handAnchors = mergedAnchors
        record.pathPoints = GarageAnalysisPipeline.generatePathPoints(from: record.handAnchors, samplesPerSegment: 16)
        record.refreshKeyframeValidationStatus()
        try? modelContext.save()
        didAutoPresentCompletionPlayback = false
        cancelAnchorEditing()
        seekToSelectedCheckpoint()
    }

    private func autoPresentCompletionPlaybackIfNeeded() {
        guard record.allCheckpointsApproved, didAutoPresentCompletionPlayback == false, reviewVideoURL != nil else { return }
        didAutoPresentCompletionPlayback = true
        isShowingCompletionPlayback = true
    }
}

private struct GarageFocusedReviewFrame: View {
    let source: GarageReviewFrameSourceState
    let image: CGImage?
    let isLoadingFrame: Bool
    let currentFrame: SwingFrame?
    let selectedAnchor: HandAnchor?
    let highlightedStatus: KeyframeValidationStatus
    let isEditingAnchor: Bool
    let overlayMode: GarageOverlayPresentationMode
    let onSetAnchor: (CGPoint) -> Void
    let floatingControls: () -> AnyView

    init(
        source: GarageReviewFrameSourceState,
        image: CGImage?,
        isLoadingFrame: Bool,
        currentFrame: SwingFrame?,
        selectedAnchor: HandAnchor?,
        highlightedStatus: KeyframeValidationStatus,
        isEditingAnchor: Bool,
        overlayMode: GarageOverlayPresentationMode,
        onSetAnchor: @escaping (CGPoint) -> Void,
        @ViewBuilder floatingControls: @escaping () -> some View = { EmptyView() }
    ) {
        self.source = source
        self.image = image
        self.isLoadingFrame = isLoadingFrame
        self.currentFrame = currentFrame
        self.selectedAnchor = selectedAnchor
        self.highlightedStatus = highlightedStatus
        self.isEditingAnchor = isEditingAnchor
        self.overlayMode = overlayMode
        self.onSetAnchor = onSetAnchor
        self.floatingControls = { AnyView(floatingControls()) }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(garageReviewBackground)

            if let image {
                GarageReviewImageOverlay(
                    image: image,
                    currentFrame: currentFrame,
                    selectedAnchor: selectedAnchor,
                    highlightedStatus: highlightedStatus,
                    isEditingAnchor: isEditingAnchor,
                    overlayMode: overlayMode,
                    onSetAnchor: onSetAnchor
                )
                .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
            } else if let currentFrame {
                GaragePoseFallbackOverlay(
                    currentFrame: currentFrame,
                    selectedAnchor: selectedAnchor,
                    highlightedStatus: highlightedStatus,
                    isEditingAnchor: isEditingAnchor,
                    overlayMode: overlayMode,
                    onSetAnchor: onSetAnchor
                )
                .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
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
            }

            if source != .recoveryNeeded {
                Text(source == .poseFallback ? "Pose Fallback" : "Video Review")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(source == .poseFallback ? .orange : AppModule.garage.theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                .padding(14)
            }

            if isLoadingFrame {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppModule.garage.theme.primary)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
            }
        }
        .overlay(alignment: .bottom) {
            floatingControls()
        }
        .frame(minHeight: 620)
        .frame(maxWidth: .infinity)
    }
}

private struct GarageReviewImageOverlay: View {
    let image: CGImage
    let currentFrame: SwingFrame?
    let selectedAnchor: HandAnchor?
    let highlightedStatus: KeyframeValidationStatus
    let isEditingAnchor: Bool
    let overlayMode: GarageOverlayPresentationMode
    let onSetAnchor: (CGPoint) -> Void

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

                GarageReviewFrameOverlayCanvas(
                    drawRect: imageRect,
                    currentFrame: currentFrame,
                    selectedAnchor: selectedAnchor,
                    highlightedStatus: highlightedStatus,
                    isEditingAnchor: isEditingAnchor,
                    overlayMode: overlayMode
                )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEditingAnchor, let point = garageNormalizedPoint(from: value.location, in: imageRect) else {
                            return
                        }
                        onSetAnchor(point)
                    }
            )
        }
    }
}

private struct GaragePoseFallbackOverlay: View {
    let currentFrame: SwingFrame
    let selectedAnchor: HandAnchor?
    let highlightedStatus: KeyframeValidationStatus
    let isEditingAnchor: Bool
    let overlayMode: GarageOverlayPresentationMode
    let onSetAnchor: (CGPoint) -> Void

    var body: some View {
        GeometryReader { proxy in
            let containerRect = CGRect(origin: .zero, size: proxy.size)

            ZStack {
                LinearGradient(
                    colors: [
                        garageReviewSurfaceRaised,
                        garageReviewSurface,
                        Color.black.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Canvas { context, _ in
                    let insetRect = containerRect.insetBy(dx: 24, dy: 24)

                    let glowRect = insetRect.insetBy(dx: insetRect.width * 0.22, dy: insetRect.height * 0.14)
                    context.fill(
                        Ellipse().path(in: glowRect),
                        with: .radialGradient(
                            Gradient(colors: [garageReviewReadableText.opacity(0.12), .clear]),
                            center: CGPoint(x: glowRect.midX, y: glowRect.midY),
                            startRadius: 4,
                            endRadius: max(glowRect.width, glowRect.height) * 0.55
                        )
                    )
                }

                GarageReviewFrameOverlayCanvas(
                    drawRect: containerRect.insetBy(dx: 20, dy: 20),
                    currentFrame: currentFrame,
                    selectedAnchor: selectedAnchor,
                    highlightedStatus: highlightedStatus,
                    isEditingAnchor: isEditingAnchor,
                    overlayMode: overlayMode
                )

                VStack(spacing: 6) {
                    Image(systemName: "figure.golf")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary.opacity(0.82))
                    Text("Sampled pose reconstruction")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }
                .padding(.top, 18)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEditingAnchor, let point = garageNormalizedPoint(from: value.location, in: containerRect.insetBy(dx: 20, dy: 20)) else {
                            return
                        }
                        onSetAnchor(point)
                    }
            )
        }
    }
}

private struct GarageReviewFrameOverlayCanvas: View {
    let drawRect: CGRect
    let currentFrame: SwingFrame?
    let selectedAnchor: HandAnchor?
    let highlightedStatus: KeyframeValidationStatus
    let isEditingAnchor: Bool
    let overlayMode: GarageOverlayPresentationMode

    var body: some View {
        Canvas { context, _ in
            guard drawRect.isEmpty == false else {
                return
            }

            if let currentFrame, overlayMode == .diagnosticPose {
                let skeletonSegments: [(SwingJointName, SwingJointName)] = [
                    (.leftShoulder, .rightShoulder),
                    (.leftShoulder, .leftElbow),
                    (.leftElbow, .leftWrist),
                    (.rightShoulder, .rightElbow),
                    (.rightElbow, .rightWrist),
                    (.leftShoulder, .leftHip),
                    (.rightShoulder, .rightHip),
                    (.leftHip, .rightHip)
                ]

                for segment in skeletonSegments {
                    guard
                        let start = currentFrame.availablePoint(named: segment.0),
                        let end = currentFrame.availablePoint(named: segment.1)
                    else {
                        continue
                    }

                    var path = Path()
                    path.move(to: garageMappedPoint(start, in: drawRect))
                    path.addLine(to: garageMappedPoint(end, in: drawRect))
                    context.stroke(path, with: .color(Color.white.opacity(0.22)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                }

                let leftWrist = garageMappedPoint(currentFrame.point(named: .leftWrist), in: drawRect)
                let rightWrist = garageMappedPoint(currentFrame.point(named: .rightWrist), in: drawRect)
                let handCenter = CGPoint(x: (leftWrist.x + rightWrist.x) / 2, y: (leftWrist.y + rightWrist.y) / 2)

                var wristLine = Path()
                wristLine.move(to: leftWrist)
                wristLine.addLine(to: rightWrist)
                context.stroke(wristLine, with: .color(Color.white.opacity(0.76)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

                for point in [leftWrist, rightWrist] {
                    let rect = CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9)
                    context.fill(Ellipse().path(in: rect), with: .color(Color.white.opacity(0.88)))
                }

                let autoCenterRect = CGRect(x: handCenter.x - 6, y: handCenter.y - 6, width: 12, height: 12)
                context.fill(Ellipse().path(in: autoCenterRect), with: .color(Color.white.opacity(0.72)))
            }

            if let selectedAnchor {
                let anchorPoint = garageMappedPoint(x: selectedAnchor.x, y: selectedAnchor.y, in: drawRect)
                let outerRect = CGRect(x: anchorPoint.x - 11, y: anchorPoint.y - 11, width: 22, height: 22)
                let innerRect = CGRect(x: anchorPoint.x - 6, y: anchorPoint.y - 6, width: 12, height: 12)
                context.fill(Ellipse().path(in: outerRect), with: .color(highlightedStatus.reviewTint.opacity(0.24)))
                context.stroke(Ellipse().path(in: outerRect), with: .color(highlightedStatus.reviewTint), lineWidth: isEditingAnchor ? 2.4 : 1.6)
                context.fill(Ellipse().path(in: innerRect), with: .color(highlightedStatus.reviewTint))

                if isEditingAnchor {
                    var horizontalGuide = Path()
                    horizontalGuide.move(to: CGPoint(x: drawRect.minX, y: anchorPoint.y))
                    horizontalGuide.addLine(to: CGPoint(x: drawRect.maxX, y: anchorPoint.y))
                    context.stroke(horizontalGuide, with: .color(highlightedStatus.reviewTint.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))

                    var verticalGuide = Path()
                    verticalGuide.move(to: CGPoint(x: anchorPoint.x, y: drawRect.minY))
                    verticalGuide.addLine(to: CGPoint(x: anchorPoint.x, y: drawRect.maxY))
                    context.stroke(verticalGuide, with: .color(highlightedStatus.reviewTint.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                }
            }
        }
    }
}

private extension SwingFrame {
    func availablePoint(named name: SwingJointName) -> CGPoint? {
        guard let joint = joints.first(where: { $0.name == name }) else {
            return nil
        }

        return CGPoint(x: joint.x, y: joint.y)
    }
}

private struct GarageCheckpointProgressStrip: View {
    let selectedPhase: SwingPhase
    let markers: [GarageTimelineMarker]
    let statusProvider: (SwingPhase) -> KeyframeValidationStatus
    let onSelect: (SwingPhase) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ModuleSpacing.small) {
                ForEach(SwingPhase.allCases) { phase in
                    let marker = markers.first(where: { $0.keyFrame.phase == phase })
                    let status = statusProvider(phase)
                    let isSelected = selectedPhase == phase
                    let isImpact = phase == .impact
                    Button {
                        onSelect(phase)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(isImpact ? garageReviewAccent : status.reviewTint)
                                .frame(width: 8, height: 8)
                                .shadow(color: isImpact ? garageReviewAccent.opacity(isSelected ? 0.45 : 0.24) : .clear, radius: isSelected ? 10 : 6)

                            Text(shortTitle(for: phase))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(garageReviewReadableText)

                            if marker?.keyFrame.source == .adjusted {
                                Image(systemName: "hand.draw")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .fixedSize(horizontal: true, vertical: false)
                        .background(
                            GarageInsetPanelBackground(
                                shape: Capsule(),
                                fill: isSelected ? garageReviewSurfaceRaised : garageReviewInsetSurface
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isImpact
                                        ? garageReviewAccent.opacity(isSelected ? 0.92 : 0.45)
                                        : (isSelected ? garageReviewReadableText.opacity(0.34) : status.reviewTint.opacity(0.24)),
                                    lineWidth: isSelected || isImpact ? 1.4 : 1
                                )
                        )
                        .shadow(color: isImpact ? garageReviewAccent.opacity(isSelected ? 0.32 : 0.18) : .clear, radius: isSelected ? 12 : 8)
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
    let statusProvider: (SwingPhase) -> KeyframeValidationStatus

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(proxy.size.width, 1)

            ZStack {
                GarageInsetPanelBackground(
                    shape: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(garageReviewTrackFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    HStack(spacing: 0) {
                        ForEach(0...24, id: \.self) { index in
                            Rectangle()
                                .fill(index.isMultiple(of: 2) ? Color.white.opacity(0.06) : Color.clear)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .overlay(alignment: .trailing) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.10))
                                        .frame(width: 1)
                                }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    ForEach(markers) { marker in
                        if range.contains(marker.timestamp) {
                            let markerStatus = statusProvider(marker.keyFrame.phase)
                            let isActiveMarker = marker.keyFrame.phase == selectedPhase
                            Circle()
                                .fill(isActiveMarker ? garageReviewAccent : garageReviewReadableText.opacity(0.88))
                                .frame(width: isActiveMarker ? 14 : 8, height: isActiveMarker ? 14 : 8)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            marker.keyFrame.source == .adjusted
                                                ? Color.orange
                                                : markerStatus.reviewTint.opacity(isActiveMarker ? 0.0 : 0.55),
                                            lineWidth: isActiveMarker ? 0 : 1.3
                                        )
                                )
                                .shadow(color: isActiveMarker ? garageReviewAccent.opacity(0.5) : .clear, radius: 10)
                                .offset(x: max(0, markerX(for: marker.timestamp, in: trackWidth) - (isActiveMarker ? 7 : 4)))
                        }
                    }
                    Circle()
                        .fill(garageReviewAccent)
                        .frame(width: 18, height: 18)
                        .shadow(color: garageReviewAccent.opacity(0.58), radius: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.24), lineWidth: 1)
                        )
                        .offset(x: max(0, indicatorX(in: trackWidth) - 9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 18)
            }
            .frame(height: 74)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
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

private struct GarageCheckpointStatusBadge: View {
    let status: KeyframeValidationStatus

    var body: some View {
        Label(status.title, systemImage: iconName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(status.reviewTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                GarageInsetPanelBackground(
                    shape: Capsule(),
                    fill: status.reviewBackground
                )
            )
    }

    private var iconName: String {
        switch status {
        case .pending:
            "clock"
        case .approved:
            "checkmark.circle.fill"
        case .flagged:
            "flag.fill"
        }
    }
}

private struct GarageCheckpointProgressSummary: View {
    let record: SwingRecord

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("\(record.approvedCheckpointCount) of \(SwingPhase.allCases.count) approved")
                .font(.caption.weight(.semibold))
                .foregroundStyle(garageReviewReadableText)
                .fixedSize(horizontal: true, vertical: false)

            HStack(spacing: 6) {
                summaryPill(title: "Approved", value: record.approvedCheckpointCount, tint: garageReviewApproved)
                summaryPill(title: "Flagged", value: record.flaggedCheckpointCount, tint: garageReviewFlagged)
                summaryPill(title: "Pending", value: record.pendingCheckpointCount, tint: garageReviewMutedText)
            }
        }
    }

    private func summaryPill(title: String, value: Int, tint: Color) -> some View {
        Text("\(title) \(value)")
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                GarageInsetPanelBackground(
                    shape: Capsule(),
                    fill: tint.opacity(0.12)
                )
            )
    }
}

private struct GarageReviewToolRail: View {
    let selectedStatus: KeyframeValidationStatus
    let isEditingAnchor: Bool
    let canAdjustCurrentFrame: Bool
    let canMoveBetweenCheckpoints: Bool
    let onPrevious: () -> Void
    let onBeginAdjust: () -> Void
    let onCancelAdjust: () -> Void
    let onSaveAdjust: () -> Void
    let onApprove: () -> Void
    let onFlag: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                iconButton(
                    systemImage: "chevron.left",
                    activeTint: garageReviewReadableText,
                    inactiveTint: garageReviewMutedText,
                    filled: false,
                    disabled: canMoveBetweenCheckpoints == false,
                    action: onPrevious
                )
                iconButton(
                    systemImage: "chevron.right",
                    activeTint: garageReviewReadableText,
                    inactiveTint: garageReviewMutedText,
                    filled: false,
                    disabled: canMoveBetweenCheckpoints == false,
                    action: onNext
                )
            }
            .padding(4)
            .background(
                GarageInsetPanelBackground(shape: Capsule())
            )

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if isEditingAnchor {
                    iconButton(
                        systemImage: "xmark",
                        activeTint: garageReviewReadableText,
                        inactiveTint: garageReviewMutedText,
                        filled: false,
                        disabled: false,
                        action: onCancelAdjust
                    )
                }

                Button(action: isEditingAnchor ? onSaveAdjust : onBeginAdjust) {
                    HStack(spacing: 8) {
                        Image(systemName: isEditingAnchor ? "checkmark.circle.fill" : "hand.point.up.left.fill")
                        Text(isEditingAnchor ? "Save Anchor" : "Adjust")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isEditingAnchor ? Color.white : garageReviewMutedText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if isEditingAnchor {
                                Capsule()
                                    .fill(garageReviewMutedText)
                            } else {
                                GarageInsetPanelBackground(shape: Capsule())
                            }
                        }
                    )
                    .overlay {
                        if isEditingAnchor == false {
                            Capsule()
                                .stroke(garageReviewGlassBorder.opacity(0.12), lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(canAdjustCurrentFrame == false)
                .opacity(canAdjustCurrentFrame ? 1 : 0.45)
                .accessibilityLabel(isEditingAnchor ? "Save manual hand anchor" : "Adjust keyframe and hand anchor")
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                iconButton(
                    systemImage: "checkmark.circle.fill",
                    activeTint: garageReviewApproved,
                    inactiveTint: garageReviewMutedText,
                    filled: selectedStatus == .approved,
                    disabled: false,
                    action: onApprove
                )
                .accessibilityLabel("Approve checkpoint")

                iconButton(
                    systemImage: "flag.fill",
                    activeTint: garageReviewFlagged,
                    inactiveTint: garageReviewMutedText,
                    filled: selectedStatus == .flagged,
                    disabled: false,
                    action: onFlag
                )
                .accessibilityLabel("Flag checkpoint")
            }
        }
        .padding(10)
        .background(
            GarageInsetPanelBackground(
                shape: Capsule(),
                fill: garageReviewSurface
            )
        )
    }

    private func iconButton(
        systemImage: String,
        activeTint: Color,
        inactiveTint: Color,
        filled: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(filled ? Color.white : inactiveTint)
                .frame(width: 36, height: 36)
                .background(
                    Group {
                        if filled {
                            Circle()
                                .fill(activeTint)
                        } else {
                            GarageInsetPanelBackground(shape: Circle())
                        }
                    }
                )
                .overlay(
                    Circle()
                        .stroke(
                            filled ? activeTint.opacity(0.12) : inactiveTint.opacity(0.20),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

private let garageReviewBackground = Color(red: 0.10, green: 0.11, blue: 0.14)
private let garageReviewSurface = Color(red: 0.16, green: 0.17, blue: 0.20)
private let garageReviewSurfaceRaised = Color(red: 0.19, green: 0.20, blue: 0.24)
private let garageReviewInsetSurface = Color(red: 0.13, green: 0.14, blue: 0.17)
private let garageReviewTrackFill = Color(red: 0.11, green: 0.12, blue: 0.15)
private let garageReviewAccent = Color(red: 0.17, green: 0.86, blue: 0.96)
private let garageReviewReadableText = Color(red: 0.95, green: 0.96, blue: 0.98)
private let garageReviewMutedText = Color(red: 0.63, green: 0.68, blue: 0.74)
private let garageReviewApproved = Color(red: 0.33, green: 0.79, blue: 0.53)
private let garageReviewFlagged = Color(red: 0.94, green: 0.38, blue: 0.40)
private let garageReviewGlassBorder = Color.white.opacity(0.2)

private struct GarageInsetPanelBackground<S: Shape>: View {
    let shape: S
    var fill: Color = garageReviewInsetSurface

    var body: some View {
        shape
            .fill(fill)
            .overlay(
                shape
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .overlay {
                shape
                    .stroke(Color.white.opacity(0.12), lineWidth: 2)
                    .blur(radius: 2)
                    .offset(x: -1, y: -1)
                    .mask(
                        shape.fill(
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
            }
            .overlay {
                shape
                    .stroke(Color.black.opacity(0.42), lineWidth: 3)
                    .blur(radius: 3)
                    .offset(x: 2, y: 2)
                    .mask(
                        shape.fill(
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
            }
    }
}

private struct GarageMetadataBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                GarageInsetPanelBackground(shape: Capsule())
            )
    }
}

private struct GarageFrameStepButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(isEnabled ? garageReviewReadableText : garageReviewMutedText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                GarageInsetPanelBackground(shape: Capsule())
            )
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
        .opacity(isEnabled ? 1 : 0.48)
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
            GarageInsetPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous),
                fill: garageReviewSurface
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous)
                .stroke(iconTint.opacity(0.24), lineWidth: 1)
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

            Button("Play Slow Motion", action: replay)
                .buttonStyle(.borderedProminent)
                .tint(AppModule.garage.theme.primary)
        }
        .padding()
        .background(AppModule.garage.theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct GarageReviewStatusPill: View {
    let status: KeyframeValidationStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(status.reviewTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                GarageInsetPanelBackground(
                    shape: Capsule(),
                    fill: status.reviewBackground
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
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.garage.theme.primary)
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

    private var visibleSamples: [GarageHandPathSample] {
        pathSamples.filter { $0.timestamp <= currentTime + 0.0001 }
    }

    var body: some View {
        GeometryReader { proxy in
            let containerRect = CGRect(origin: .zero, size: proxy.size)
            let videoRect = aspectFitRect(videoSize: videoSize, in: containerRect)

            Canvas { context, _ in
                guard videoRect.isEmpty == false, visibleSamples.count >= 2 else {
                    return
                }

                let maxSpeed = max(visibleSamples.map(\.speed).max() ?? 0.001, 0.001)
                for segmentIndex in 1..<visibleSamples.count {
                    let previous = visibleSamples[segmentIndex - 1]
                    let current = visibleSamples[segmentIndex]
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

                if let lastSample = visibleSamples.last {
                    let point = mappedPoint(x: lastSample.x, y: lastSample.y, in: videoRect)
                    let outerRect = CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)
                    let innerRect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                    context.fill(Ellipse().path(in: outerRect), with: .color(Color.white))
                    context.fill(Ellipse().path(in: innerRect), with: .color(garageReviewAccent))
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


#Preview("Garage") {
    PreviewScreenContainer {
        GarageView()
    }
    .modelContainer(for: SwingRecord.self, inMemory: true)
}
