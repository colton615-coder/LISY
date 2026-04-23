import AVFoundation
import Combine
import SwiftData
import SwiftUI
import UIKit

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

private struct GarageResolvedEvidenceTarget {
    let frameIndex: Int?
    let phase: SwingPhase?
    let directional: Bool
    let prefersSkeleton: Bool
}

private struct GarageEvidenceArrival: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let tint: Color
    let isDirectional: Bool
}

private extension GarageEvidenceEmphasis {
    var prefersSkeleton: Bool {
        switch self {
        case .coachingCue, .metric:
            true
        case .blocker:
            false
        }
    }
}

private extension GarageEvidenceTarget {
    var arrivalTitle: String {
        switch self {
        case let .checkpoint(_, _, emphasis):
            "Evidence: \(emphasis.label)"
        case let .phaseWindow(_, _, _, _, emphasis):
            "Directional Evidence: \(emphasis.label)"
        case let .reliabilityIssue(kind, _, _):
            "Review Signal: \(kind.label)"
        case let .reviewNote(noteID, _, _):
            "Review Note: \(noteID)"
        }
    }

    var arrivalTint: Color {
        switch self {
        case .checkpoint:
            garageReviewAccent
        case .phaseWindow:
            garageReviewPending
        case .reliabilityIssue:
            garageReviewPending
        case .reviewNote:
            garageReviewMutedText.opacity(0.94)
        }
    }
}

private struct GarageEvidenceArrivalBanner: View {
    let arrival: GarageEvidenceArrival

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(arrival.tint.opacity(arrival.isDirectional ? 0.14 : 0.18))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .stroke(arrival.tint.opacity(0.32), lineWidth: 0.8)
                    )

                Image(systemName: arrival.isDirectional ? "waveform.path.ecg" : "scope")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(arrival.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(arrival.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(garageReviewReadableText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(arrival.detail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(garageReviewMutedText.opacity(0.96))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                fill: garageReviewSurfaceRaised.opacity(0.98),
                stroke: arrival.tint.opacity(0.28),
                glow: arrival.tint.opacity(arrival.isDirectional ? 0.18 : 0.28)
            )
        )
        .frame(maxWidth: 280, alignment: .leading)
    }
}

struct GarageFocusedReviewWorkspace: View {
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
    @State private var isCoachingReportExpanded = false
    @State private var isExportingCoachingReport = false
    @State private var exportedCoachingReportURL: URL?
    @State private var coachingReportExportError: String?
    @State private var evidenceArrival: GarageEvidenceArrival?
    @State private var skeletonOverlayMode: GarageOverlayMode = .clean

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
            reliabilityReport: reliabilityReport,
            scorecard: swingScorecard,
            stabilityScore: stabilityScore,
            evidenceContext: GarageEvidenceContext(
                frames: swingFrames,
                keyFrames: keyFrames,
                syncFlow: syncFlowReport,
                reviewFrameSource: reviewFrameSource
            )
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
                swingFrames: swingFrames,
                keyFrames: keyFrames,
                totalFrameCount: swingFrames.count,
                selectedAnchor: displayedAnchor,
                highlightTint: selectedAnchorTint,
                showsAnchorGuides: isDraggingAnchor,
                reviewMode: reviewMode,
                skeletonOverlayMode: skeletonOverlayMode,
                reviewSurface: reviewSurface,
                handPathSamples: fullHandPathSamples,
                currentTime: currentFrameTimestamp ?? currentTime,
                scorecard: swingScorecard,
                syncFlow: syncFlowReport,
                summaryPresentation: summaryPresentation,
                preferredHeight: activeVideoHeight,
                onSelectReviewMode: selectReviewMode,
                onSelectOverlayMode: selectOverlayMode,
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
            .overlay(alignment: .bottomLeading) {
                if let evidenceArrival {
                    GarageEvidenceArrivalBanner(arrival: evidenceArrival)
                        .padding(.leading, 14)
                        .padding(.bottom, 14)
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottomLeading)))
                }
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
                        reviewFrameSource: reviewFrameSource,
                        onCoachingExpansionChange: { isExpanded in
                            isCoachingReportExpanded = isExpanded
                        },
                        isExportingReport: isExportingCoachingReport,
                        onDownloadFullReport: exportCoachingReport,
                        onNavigateToEvidence: navigateToEvidence
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
                    showsDownloadReport: isCoachingReportExpanded,
                    isExportingReport: isExportingCoachingReport,
                    onContinue: {
                        isShowingCompletionPlayback = true
                    },
                    onSkeletonReview: {
                        isShowingSkeletonPlayback = true
                    },
                    onDownloadReport: exportCoachingReport
                )
            }
        }
        .sheet(isPresented: shareSheetIsPresented) {
            if let exportedCoachingReportURL {
                GarageShareSheet(activityItems: [exportedCoachingReportURL])
            }
        }
        .alert("Unable to Export Report", isPresented: exportErrorIsPresented) {
            Button("OK", role: .cancel) {
                coachingReportExportError = nil
            }
        } message: {
            Text(coachingReportExportError ?? "The report could not be exported right now.")
        }
        .overlay {
            if let reviewVideoURL {
                GarageSlowMotionPlaybackSheet(
                    isPresented: $isShowingCompletionPlayback,
                    videoURL: reviewVideoURL,
                    pathSamples: fullHandPathSamples,
                    frames: swingFrames,
                    syncFlow: syncFlowReport,
                    initialMode: .handPath
                )
            }
        }
        .overlay {
            GarageRecordMetadataEditorSheet(
                isPresented: $isShowingMetadataEditor,
                record: record
            )
        }
        .overlay {
            if let reviewVideoURL {
                GarageSkeletonReviewView(
                    isPresented: $isShowingSkeletonPlayback,
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

    private var shareSheetIsPresented: Binding<Bool> {
        Binding(
            get: { exportedCoachingReportURL != nil },
            set: { newValue in
                if newValue == false {
                    exportedCoachingReportURL = nil
                }
            }
        )
    }

    private var exportErrorIsPresented: Binding<Bool> {
        Binding(
            get: { coachingReportExportError != nil },
            set: { newValue in
                if newValue == false {
                    coachingReportExportError = nil
                }
            }
        )
    }

    private func exportCoachingReport() {
        guard isExportingCoachingReport == false else { return }

        Task { @MainActor in
            isExportingCoachingReport = true
            coachingReportExportError = nil

            do {
                exportedCoachingReportURL = try GarageCoachingReportPDFExporter.export(
                    presentation: coachingPresentation
                )
            } catch {
                coachingReportExportError = error.localizedDescription
            }

            isExportingCoachingReport = false
        }
    }

    private func navigateToEvidence(_ target: GarageEvidenceTarget) {
        guard swingFrames.isEmpty == false else {
            presentEvidenceArrival(for: target, resolvedFrameIndex: nil, directional: true)
            return
        }

        let resolution = resolveEvidenceTarget(target)

        if let resolvedFrameIndex = resolution.frameIndex {
            currentTime = swingFrames[resolvedFrameIndex].timestamp
        }

        if let phase = resolution.phase {
            selectedPhase = phase
        } else if let resolvedFrameIndex = resolution.frameIndex,
                  let nearestPhase = nearestPhase(for: resolvedFrameIndex) {
            selectedPhase = nearestPhase
        }

        if resolution.prefersSkeleton {
            reviewMode = .skeleton
        }

        presentEvidenceArrival(
            for: target,
            resolvedFrameIndex: resolution.frameIndex,
            directional: resolution.directional
        )
    }

    private func resolveEvidenceTarget(_ target: GarageEvidenceTarget) -> GarageResolvedEvidenceTarget {
        switch target {
        case let .checkpoint(frameIndex, phase, emphasis):
            let clampedIndex = clampedFrameIndex(frameIndex)
            return GarageResolvedEvidenceTarget(
                frameIndex: clampedIndex,
                phase: phase,
                directional: clampedIndex != frameIndex,
                prefersSkeleton: emphasis.prefersSkeleton
            )
        case let .phaseWindow(startFrameIndex, endFrameIndex, selectedFrameIndex, phase, emphasis):
            let lowerBound = min(startFrameIndex, endFrameIndex)
            let upperBound = max(startFrameIndex, endFrameIndex)
            let boundedSelection = min(max(selectedFrameIndex, lowerBound), upperBound)
            let clampedIndex = clampedFrameIndex(boundedSelection)
            let directional = clampedIndex != selectedFrameIndex || startFrameIndex != endFrameIndex
            return GarageResolvedEvidenceTarget(
                frameIndex: clampedIndex,
                phase: phase,
                directional: directional,
                prefersSkeleton: emphasis.prefersSkeleton
            )
        case let .reliabilityIssue(_, relatedFrameIndex, phase):
            let clampedIndex = relatedFrameIndex.map(clampedFrameIndex)
            return GarageResolvedEvidenceTarget(
                frameIndex: clampedIndex,
                phase: phase,
                directional: true,
                prefersSkeleton: false
            )
        case let .reviewNote(_, relatedFrameIndex, phase):
            let clampedIndex = relatedFrameIndex.map(clampedFrameIndex)
            return GarageResolvedEvidenceTarget(
                frameIndex: clampedIndex,
                phase: phase,
                directional: true,
                prefersSkeleton: false
            )
        }
    }

    private func clampedFrameIndex(_ frameIndex: Int) -> Int {
        min(max(frameIndex, 0), max(swingFrames.count - 1, 0))
    }

    private func presentEvidenceArrival(
        for target: GarageEvidenceTarget,
        resolvedFrameIndex: Int?,
        directional: Bool
    ) {
        let arrival = GarageEvidenceArrival(
            title: target.arrivalTitle,
            detail: evidenceArrivalDetail(
                target: target,
                resolvedFrameIndex: resolvedFrameIndex,
                directional: directional
            ),
            tint: target.arrivalTint,
            isDirectional: directional
        )

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            evidenceArrival = arrival
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard evidenceArrival?.id == arrival.id else { return }

            withAnimation(.easeOut(duration: 0.24)) {
                evidenceArrival = nil
            }
        }
    }

    private func evidenceArrivalDetail(
        target: GarageEvidenceTarget,
        resolvedFrameIndex: Int?,
        directional: Bool
    ) -> String {
        let frameLabel = resolvedFrameIndex.map { "Frame \($0 + 1) of \(swingFrames.count)" } ?? "No exact frame available"

        switch target {
        case .checkpoint:
            return directional ? "\(frameLabel) - clamped evidence" : "\(frameLabel) - exact checkpoint"
        case .phaseWindow:
            return "\(frameLabel) - directional sequence"
        case let .reliabilityIssue(kind, _, _):
            return "\(kind.label) - review signal"
        case .reviewNote:
            return "\(frameLabel) - review note"
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

    private func selectOverlayMode(_ mode: GarageOverlayMode) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            skeletonOverlayMode = mode
        }
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
    var onCoachingExpansionChange: (Bool) -> Void = { _ in }
    var isExportingReport: Bool = false
    var onDownloadFullReport: () -> Void = {}
    var onNavigateToEvidence: (GarageEvidenceTarget) -> Void = { _ in }
    @State private var isCoachingExpanded = false

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
                    GarageCoachingDisclosureCard(
                        presentation: coachingPresentation,
                        isExpanded: $isCoachingExpanded,
                        isExportingReport: isExportingReport,
                        onDownloadFullReport: onDownloadFullReport,
                        onNavigateToEvidence: handleEvidenceNavigation
                    )
                }
            case let .unavailable(presentation):
                GarageStep2UnavailableCard(presentation: presentation)
                GarageCoachingDisclosureCard(
                    presentation: coachingPresentation,
                    isExpanded: $isCoachingExpanded,
                    isExportingReport: isExportingReport,
                    onDownloadFullReport: onDownloadFullReport,
                    onNavigateToEvidence: handleEvidenceNavigation
                )
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
        .task(id: coachingResetKey) {
            isCoachingExpanded = false
        }
        .onChange(of: isCoachingExpanded) { _, newValue in
            onCoachingExpansionChange(newValue)
        }
    }

    private var coachingResetKey: String {
        coachingPresentation.animationIdentityKey
    }

    private func handleEvidenceNavigation(_ target: GarageEvidenceTarget) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            isCoachingExpanded = false
        }
        onCoachingExpansionChange(false)
        onNavigateToEvidence(target)
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
    var showsDownloadReport: Bool = false
    var isExportingReport: Bool = false
    let onContinue: () -> Void
    let onSkeletonReview: () -> Void
    var onDownloadReport: () -> Void = {}

    var body: some View {
        GarageDockSurface {
            if showsDownloadReport {
                GarageDockWideButton(
                    title: isExportingReport ? "Preparing Full Report" : "Download Full Report",
                    systemImage: isExportingReport ? "hourglass" : "arrow.down.doc.fill",
                    isPrimary: true,
                    isEnabled: isExportingReport == false,
                    action: onDownloadReport
                )

                Text("Creates a shareable PDF with the critique, the metrics, and all 3 redesigned UI assets.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(garageReviewMutedText.opacity(0.96))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GarageDockWideButton(
                title: canContinue ? "Review Hand Path" : "Slow Motion Review Unavailable",
                systemImage: canContinue ? "play.fill" : "exclamationmark.triangle.fill",
                isPrimary: showsDownloadReport == false,
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

private struct GarageCoachingDisclosureCard: View {
    let presentation: GarageCoachingPresentation
    @Binding var isExpanded: Bool
    var isExportingReport: Bool = false
    var onDownloadFullReport: () -> Void = {}
    var onNavigateToEvidence: (GarageEvidenceTarget) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("Coaching Deep Dive")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(garageReviewReadableText)

                            Text(presentation.reliabilityStatus.rawValue.uppercased())
                                .font(.caption2.weight(.bold))
                                .tracking(0.8)
                                .foregroundStyle(coachingConfidenceTint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(coachingConfidenceTint.opacity(0.12))
                                        .overlay(
                                            Capsule()
                                                .stroke(coachingConfidenceTint.opacity(0.28), lineWidth: 0.8)
                                        )
                                )
                        }

                        HStack(spacing: 8) {
                            Circle()
                                .fill(ModuleTheme.electricCyan)
                                .frame(width: 7, height: 7)

                            Text(presentation.phase.reviewTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(garageReviewMutedText)
                                .lineLimit(1)
                        }

                        Text(presentation.hero.headline)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(garageReviewReadableText)
                            .lineLimit(1)

                        Text(presentation.hero.body)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(garageReviewMutedText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isExpanded ? ModuleTheme.electricCyan : garageReviewMutedText.opacity(0.92))
                        .shadow(
                            color: isExpanded ? ModuleTheme.electricCyan.opacity(0.22) : .clear,
                            radius: 8,
                            x: 0,
                            y: 0
                        )
                        .padding(.top, 2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GarageRaisedPanelBackground(
                        shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                        fill: garageReviewSurfaceRaised,
                        stroke: garageReviewStroke.opacity(0.92)
                    )
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                GarageCoachingReportView(
                    presentation: presentation,
                    isExportingReport: isExportingReport,
                    onDownloadFullReport: onDownloadFullReport,
                    onNavigateToEvidence: onNavigateToEvidence
                )
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
            }
        }
    }

    private var coachingConfidenceTint: Color {
        presentation.reliabilityStatus.tint
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
    let swingFrames: [SwingFrame]
    let keyFrames: [KeyFrame]
    let totalFrameCount: Int
    let selectedAnchor: HandAnchor?
    let highlightTint: Color
    let showsAnchorGuides: Bool
    let reviewMode: GarageReviewMode
    let skeletonOverlayMode: GarageOverlayMode
    let reviewSurface: GarageReviewSurface
    let handPathSamples: [GarageHandPathSample]
    let currentTime: Double
    let scorecard: GarageSwingScorecard?
    let syncFlow: GarageSyncFlowReport?
    let summaryPresentation: GarageReviewSummaryPresentation
    let preferredHeight: CGFloat
    let onSelectReviewMode: (GarageReviewMode) -> Void
    let onSelectOverlayMode: (GarageOverlayMode) -> Void
    let onAnchorDragChanged: (CGPoint) -> Void
    let onAnchorDragEnded: (CGPoint) -> Void

    init(
        image: CGImage?,
        isLoadingFrame: Bool,
        currentFrame: SwingFrame?,
        currentFrameIndex: Int?,
        swingFrames: [SwingFrame],
        keyFrames: [KeyFrame],
        totalFrameCount: Int,
        selectedAnchor: HandAnchor?,
        highlightTint: Color,
        showsAnchorGuides: Bool,
        reviewMode: GarageReviewMode,
        skeletonOverlayMode: GarageOverlayMode,
        reviewSurface: GarageReviewSurface,
        handPathSamples: [GarageHandPathSample],
        currentTime: Double,
        scorecard: GarageSwingScorecard?,
        syncFlow: GarageSyncFlowReport?,
        summaryPresentation: GarageReviewSummaryPresentation,
        preferredHeight: CGFloat,
        onSelectReviewMode: @escaping (GarageReviewMode) -> Void,
        onSelectOverlayMode: @escaping (GarageOverlayMode) -> Void,
        onAnchorDragChanged: @escaping (CGPoint) -> Void,
        onAnchorDragEnded: @escaping (CGPoint) -> Void
    ) {
        self.image = image
        self.isLoadingFrame = isLoadingFrame
        self.currentFrame = currentFrame
        self.currentFrameIndex = currentFrameIndex
        self.swingFrames = swingFrames
        self.keyFrames = keyFrames
        self.totalFrameCount = totalFrameCount
        self.selectedAnchor = selectedAnchor
        self.highlightTint = highlightTint
        self.showsAnchorGuides = showsAnchorGuides
        self.reviewMode = reviewMode
        self.skeletonOverlayMode = skeletonOverlayMode
        self.reviewSurface = reviewSurface
        self.handPathSamples = handPathSamples
        self.currentTime = currentTime
        self.scorecard = scorecard
        self.syncFlow = syncFlow
        self.summaryPresentation = summaryPresentation
        self.preferredHeight = preferredHeight
        self.onSelectReviewMode = onSelectReviewMode
        self.onSelectOverlayMode = onSelectOverlayMode
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
                    swingFrames: swingFrames,
                    keyFrames: keyFrames,
                    totalFrameCount: totalFrameCount,
                    selectedAnchor: selectedAnchor,
                    highlightTint: highlightTint,
                    showsAnchorGuides: showsAnchorGuides,
                    reviewMode: reviewMode,
                    skeletonOverlayMode: skeletonOverlayMode,
                    reviewSurface: reviewSurface,
                    handPathSamples: handPathSamples,
                    currentTime: currentTime,
                    scorecard: scorecard,
                    syncFlow: syncFlow,
                    skeletonOverlayOpacity: limitedSkeletonInspection ? 0.72 : 1,
                    onSelectOverlayMode: onSelectOverlayMode,
                    onAnchorDragChanged: onAnchorDragChanged,
                    onAnchorDragEnded: onAnchorDragEnded
                )
            } else if let currentFrame {
                GaragePoseFallbackOverlay(
                    currentFrame: currentFrame,
                    currentFrameIndex: currentFrameIndex,
                    swingFrames: swingFrames,
                    keyFrames: keyFrames,
                    totalFrameCount: totalFrameCount,
                    selectedAnchor: selectedAnchor,
                    highlightTint: highlightTint,
                    showsAnchorGuides: showsAnchorGuides,
                    reviewMode: reviewMode,
                    skeletonOverlayMode: skeletonOverlayMode,
                    reviewSurface: reviewSurface,
                    handPathSamples: handPathSamples,
                    currentTime: currentTime,
                    scorecard: scorecard,
                    syncFlow: syncFlow,
                    skeletonOverlayOpacity: limitedSkeletonInspection ? 0.72 : 1,
                    onSelectOverlayMode: onSelectOverlayMode,
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
    let swingFrames: [SwingFrame]
    let keyFrames: [KeyFrame]
    let totalFrameCount: Int
    let selectedAnchor: HandAnchor?
    let highlightTint: Color
    let showsAnchorGuides: Bool
    let reviewMode: GarageReviewMode
    let skeletonOverlayMode: GarageOverlayMode
    let reviewSurface: GarageReviewSurface
    let handPathSamples: [GarageHandPathSample]
    let currentTime: Double
    let scorecard: GarageSwingScorecard?
    let syncFlow: GarageSyncFlowReport?
    let skeletonOverlayOpacity: Double
    let onSelectOverlayMode: (GarageOverlayMode) -> Void
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
                        presentation: GarageOverlayAdapter.makePresentation(
                            mode: skeletonOverlayMode,
                            drawSize: imageRect.size,
                            frames: swingFrames,
                            currentFrameIndex: currentFrameIndex,
                            currentFrame: currentFrame,
                            keyFrames: keyFrames,
                            currentTime: currentTime,
                            pulseProgress: pulseProgress,
                            scorecard: scorecard,
                            syncFlow: syncFlow
                        ),
                        onSelectMode: onSelectOverlayMode
                    )
                    .opacity(skeletonOverlayOpacity)
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
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
    let swingFrames: [SwingFrame]
    let keyFrames: [KeyFrame]
    let totalFrameCount: Int
    let selectedAnchor: HandAnchor?
    let highlightTint: Color
    let showsAnchorGuides: Bool
    let reviewMode: GarageReviewMode
    let skeletonOverlayMode: GarageOverlayMode
    let reviewSurface: GarageReviewSurface
    let handPathSamples: [GarageHandPathSample]
    let currentTime: Double
    let scorecard: GarageSwingScorecard?
    let syncFlow: GarageSyncFlowReport?
    let skeletonOverlayOpacity: Double
    let onSelectOverlayMode: (GarageOverlayMode) -> Void
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
                        presentation: GarageOverlayAdapter.makePresentation(
                            mode: skeletonOverlayMode,
                            drawSize: drawRect.size,
                            frames: swingFrames,
                            currentFrameIndex: currentFrameIndex,
                            currentFrame: currentFrame,
                            keyFrames: keyFrames,
                            currentTime: currentTime,
                            pulseProgress: pulseProgress,
                            scorecard: scorecard,
                            syncFlow: syncFlow
                        ),
                        onSelectMode: onSelectOverlayMode
                    )
                    .opacity(skeletonOverlayOpacity)
                    .frame(width: drawRect.width, height: drawRect.height)
                    .position(x: drawRect.midX, y: drawRect.midY)
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
    @Binding var isPresented: Bool
    let videoURL: URL
    let pathSamples: [GarageHandPathSample]
    let frames: [SwingFrame]
    let syncFlow: GarageSyncFlowReport?
    let initialMode: GarageReviewMode

    @StateObject private var playbackController: GarageSlowMotionPlaybackController
    @State private var videoDisplaySize = CGSize(width: 1, height: 1)
    @State private var selectedSpeed: Float = 1.0
    @State private var reviewMode: GarageReviewMode
    @State private var skeletonOverlayMode: GarageOverlayMode = .clean
    @State private var isScrubbing = false

    init(
        isPresented: Binding<Bool>,
        videoURL: URL,
        pathSamples: [GarageHandPathSample],
        frames: [SwingFrame],
        syncFlow: GarageSyncFlowReport?,
        initialMode: GarageReviewMode
    ) {
        _isPresented = isPresented
        self.videoURL = videoURL
        self.pathSamples = pathSamples
        self.frames = frames
        self.syncFlow = syncFlow
        self.initialMode = initialMode
        _playbackController = StateObject(wrappedValue: GarageSlowMotionPlaybackController(url: videoURL))
        _reviewMode = State(initialValue: initialMode)
    }

    var body: some View {
        Color.clear
            .garageModal(
                isPresented: $isPresented,
                title: initialMode == .skeleton ? "Skeleton Review" : "Review Playback"
            ) {
                playbackContent
            } bottomDock: {
                GaragePlaybackActionBar(
                    onRecheck: {
                        playbackController.seek(0)
                        playbackController.startPlayback(at: selectedSpeed)
                    },
                    onFinish: {
                        isPresented = false
                    }
                )
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

    private var playbackContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Confirm motion flow before finishing.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textSecondary)

                Spacer(minLength: 0)

                Text("Approved")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.vibeSurface, in: Capsule())
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
                    skeletonOverlayMode: skeletonOverlayMode,
                    videoSize: videoDisplaySize,
                    isScrubbing: isScrubbing,
                    onSelectOverlayMode: { mode in
                        skeletonOverlayMode = mode
                    }
                )
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
        .background(Color.vibeBackground.ignoresSafeArea())
    }
}

private struct GarageSkeletonReviewView: View {
    @Binding var isPresented: Bool
    let videoURL: URL
    let pathSamples: [GarageHandPathSample]
    let frames: [SwingFrame]
    let syncFlow: GarageSyncFlowReport?

    var body: some View {
        GarageSlowMotionPlaybackSheet(
            isPresented: $isPresented,
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

private struct GarageSlowMotionVisualizationOverlay: View {
    let mode: GarageReviewMode
    let pathSamples: [GarageHandPathSample]
    let frames: [SwingFrame]
    let currentTime: Double
    let syncFlow: GarageSyncFlowReport?
    let skeletonOverlayMode: GarageOverlayMode
    let videoSize: CGSize
    let isScrubbing: Bool
    let onSelectOverlayMode: (GarageOverlayMode) -> Void

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
        guard let index = currentFrameIndex else { return nil }
        return frames[index]
    }

    private var currentFrameIndex: Int? {
        nearestFrameIndex(for: currentTime)
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
                    presentation: GarageOverlayAdapter.makePresentation(
                        mode: skeletonOverlayMode,
                        drawSize: videoRect.size,
                        frames: frames,
                        currentFrameIndex: currentFrameIndex,
                        currentFrame: currentFrame,
                        keyFrames: [],
                        currentTime: currentTime,
                        pulseProgress: pulseProgress,
                        scorecard: nil,
                        syncFlow: syncFlow
                    ),
                    onSelectMode: onSelectOverlayMode
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

struct GarageSlowMotionPlayerView: UIViewRepresentable {
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

final class GaragePlayerContainerView: UIView {
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
final class GarageSlowMotionPlaybackController: ObservableObject {
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

private enum GarageReviewWorkspacePreviewFixture {
    static let summaryRecord = makeRecord(allApproved: true)
    static let fallbackRecord = makeRecord(allApproved: false)

    static func makeRecord(allApproved: Bool) -> SwingRecord {
        let phases = SwingPhase.allCases
        let frames = phases.enumerated().map { index, _ in
            SwingFrame(
                timestamp: Double(index) * 0.12,
                joints: joints(for: index),
                confidence: 0.94
            )
        }

        let keyFrames = phases.enumerated().map { index, phase in
            KeyFrame(
                phase: phase,
                frameIndex: index,
                source: index.isMultiple(of: 3) ? .adjusted : .automatic,
                reviewStatus: allApproved ? .approved : .pending
            )
        }

        let anchors = phases.enumerated().map { index, phase in
            HandAnchor(
                phase: phase,
                x: min(max(0.34 + (Double(index) * 0.035), 0.18), 0.82),
                y: min(max(0.58 - (Double(index) * 0.03), 0.18), 0.84),
                source: index.isMultiple(of: 2) ? .automatic : .manual
            )
        }

        return SwingRecord(
            title: allApproved ? "Preview Summary Swing" : "Preview Review Swing",
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: allApproved ? .approved : .pending,
            handAnchors: anchors,
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 16)
        )
    }

    static func joints(for index: Int) -> [SwingJoint] {
        let xShift = Double(index) * 0.02
        let yShift = Double(index) * 0.01

        return [
            SwingJoint(name: .nose, x: 0.48 + (xShift * 0.15), y: 0.18 + (yShift * 0.1), confidence: 0.97),
            SwingJoint(name: .leftShoulder, x: 0.39 + xShift, y: 0.31 + yShift, confidence: 0.98),
            SwingJoint(name: .rightShoulder, x: 0.57 + xShift, y: 0.3 + yShift, confidence: 0.98),
            SwingJoint(name: .leftHip, x: 0.43 + (xShift * 0.7), y: 0.56 + (yShift * 0.6), confidence: 0.97),
            SwingJoint(name: .rightHip, x: 0.55 + (xShift * 0.7), y: 0.56 + (yShift * 0.6), confidence: 0.97),
            SwingJoint(name: .leftWrist, x: 0.32 + (xShift * 1.2), y: 0.52 - (yShift * 0.4), confidence: 0.96),
            SwingJoint(name: .rightWrist, x: 0.63 + (xShift * 1.4), y: 0.46 - (yShift * 0.5), confidence: 0.96),
            SwingJoint(name: .leftKnee, x: 0.44 + (xShift * 0.5), y: 0.76, confidence: 0.95),
            SwingJoint(name: .rightKnee, x: 0.56 + (xShift * 0.5), y: 0.76, confidence: 0.95),
            SwingJoint(name: .leftAnkle, x: 0.45 + (xShift * 0.35), y: 0.94, confidence: 0.94),
            SwingJoint(name: .rightAnkle, x: 0.55 + (xShift * 0.35), y: 0.94, confidence: 0.94)
        ]
    }
}

private struct GarageReviewWorkspacePreviewSurface: View {
    let record: SwingRecord

    var body: some View {
        GarageFocusedReviewWorkspace(
            record: record,
            viewportHeight: 852,
            onExitReview: {}
        )
    }
}

private struct GarageReviewSummaryPreviewSurface: View {
    let record: SwingRecord
    let reviewFrameSource: GarageReviewFrameSourceState

    private var handPathReviewReport: GarageHandPathReviewReport {
        GarageAnalysisPipeline.handPathReviewReport(for: record.swingFrames, keyFrames: record.keyFrames)
    }

    private var stabilityScore: Int? {
        GarageStability.score(for: record)
    }

    private var syncFlowReport: GarageSyncFlowReport? {
        record.analysisResult?.syncFlow
    }

    private var summaryPresentation: GarageReviewSummaryPresentation {
        GarageReviewSummaryPresentation.make(
            reviewMode: .handPath,
            handPathReviewReport: handPathReviewReport,
            stabilityScore: stabilityScore,
            reviewFrameSource: reviewFrameSource,
            syncFlow: syncFlowReport
        )
    }

    private var swingScorecard: GarageSwingScorecard? {
        record.analysisResult?.scorecard
            ?? GarageScorecardEngine.generate(frames: record.swingFrames, keyFrames: record.keyFrames)
    }

    private var coachingPresentation: GarageCoachingPresentation {
        GarageCoachingPresentation.make(
            report: GarageCoaching.report(for: record),
            selectedPhase: .impact,
            reliabilityReport: GarageReliability.report(for: record),
            scorecard: swingScorecard,
            stabilityScore: stabilityScore
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            GarageReviewSummaryControls(
                summaryPresentation: summaryPresentation,
                step2Presentation: GarageStep2Presentation.make(scorecard: swingScorecard),
                coachingPresentation: coachingPresentation,
                reviewRecoveryTitle: reviewFrameSource == .video ? "Stored video recovered" : "Pose fallback active",
                reviewRecoveryBody: reviewFrameSource == .video
                    ? "Garage found a stored review video for this checkpoint."
                    : "Stored footage is missing, so Garage is showing sampled pose data instead.",
                reviewFrameSource: reviewFrameSource
            )
            .padding(ModuleSpacing.large)
        }
        .background(garageReviewBackground.ignoresSafeArea())
    }
}

#Preview("Garage Review Workspace · Summary") {
    PreviewScreenContainer {
        GarageReviewWorkspacePreviewSurface(record: GarageReviewWorkspacePreviewFixture.summaryRecord)
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: SwingRecord.self, inMemory: true)
}

#Preview("Garage Review Workspace · Fallback") {
    PreviewScreenContainer {
        GarageReviewWorkspacePreviewSurface(record: GarageReviewWorkspacePreviewFixture.fallbackRecord)
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: SwingRecord.self, inMemory: true)
}

#Preview("Garage Review Summary Controls") {
    PreviewScreenContainer {
        GarageReviewSummaryPreviewSurface(
            record: GarageReviewWorkspacePreviewFixture.summaryRecord,
            reviewFrameSource: .video
        )
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: SwingRecord.self, inMemory: true)
}
