import AVKit
import Combine
import OSLog
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct GarageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SwingRecord.createdAt, order: .reverse) private var swingRecords: [SwingRecord]
    @State private var isShowingVideoPicker = false
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var isAnalyzingVideo = false
    @State private var importErrorMessage: String?

    var body: some View {
        ModuleScreen(theme: AppModule.garage.theme) {
            ModuleHeader(
                theme: AppModule.garage.theme,
                title: "Garage",
                subtitle: "Upload a swing, verify the 8 positions, place the grip midpoint on a large review canvas, then read the output once trust is earned."
            )

            if let latestRecord = swingRecords.first {
                GarageAnalysisWorkflowView(record: latestRecord)
            } else {
                GarageAnalyzerEmptyState {
                    isShowingVideoPicker = true
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if swingRecords.isEmpty {
                ModuleBottomActionBar(
                    theme: AppModule.garage.theme,
                    title: "Analyze Swing Video",
                    systemImage: "video.badge.plus"
                ) {
                    isShowingVideoPicker = true
                }
                .disabled(isAnalyzingVideo)
            }
        }
        .overlay {
            if isAnalyzingVideo {
                GarageAnalyzingOverlay()
            }
        }
        .overlay(alignment: .top) {
            if let importErrorMessage {
                GarageImportErrorBanner(message: importErrorMessage)
                    .padding(.horizontal, ModuleSpacing.medium)
                    .padding(.top, ModuleSpacing.medium)
            }
        }
        .photosPicker(
            isPresented: $isShowingVideoPicker,
            selection: $selectedVideoItem,
            matching: nil,
            preferredItemEncoding: .current
        )
        .onChange(of: selectedVideoItem) { _, newItem in
            guard let newItem else { return }
            importErrorMessage = nil
            analyzeVideoSelection(newItem)
        }
    }

    @MainActor
    private func analyzeVideoSelection(_ item: PhotosPickerItem) {
        isAnalyzingVideo = true

        Task {
            do {
                guard let movie = try await item.loadTransferable(type: GaragePickedMovie.self) else {
                    throw GarageImportError.unableToLoadSelection
                }

                try await processImportedVideo(at: movie.url)
            } catch {
                await MainActor.run {
                    selectedVideoItem = nil
                    isAnalyzingVideo = false
                    importErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func processImportedVideo(at url: URL) async throws {
        let persistedVideoURL = try GarageMediaStore.persistVideo(from: url)
        let output = try await GarageAnalysisPipeline.analyzeVideo(at: persistedVideoURL)
        let record = SwingRecord(
            title: recordTitle(for: persistedVideoURL),
            mediaFilename: persistedVideoURL.lastPathComponent,
            frameRate: output.frameRate,
            decodedFrames: output.decodedFrames,
            decodedFrameTimestamps: output.decodedFrameTimestamps,
            swingFrames: output.swingFrames,
            keyFrames: output.keyFrames,
            analysisResult: output.analysisResult
        )

        await MainActor.run {
            modelContext.insert(record)
            try? modelContext.save()
            selectedVideoItem = nil
            isAnalyzingVideo = false
        }
    }

    private func recordTitle(for videoURL: URL) -> String {
        let stem = videoURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if stem.isEmpty == false {
            return stem
        }

        return "Swing \(Date.now.formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct GarageAnalysisWorkflowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var record: SwingRecord

    @State private var player = AVPlayer()
    @State private var selectedPhase: SwingPhase
    @State private var scrubPosition: Double
    @State private var isScrubbing = false
    @State private var evaluationDocument: GarageEvaluationDocument?
    @State private var isShowingEvaluationExporter = false
    @State private var isShowingPathPlayback = false

    private let playbackTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    init(record: SwingRecord) {
        self.record = record
        _selectedPhase = State(initialValue: record.keyFrames.first?.phase ?? .address)
        _scrubPosition = State(initialValue: record.decodedFrames.first?.presentationTimestamp ?? record.swingFrames.first?.timestamp ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.large) {
            if reviewFramesAvailable {
                GaragePrimaryReviewSection(
                    selectedPhase: $selectedPhase,
                    recordIdentifier: recordIdentifier,
                    keyFrames: record.keyFrames,
                    videoURL: videoURL,
                    handAnchors: record.handAnchors,
                    timestampForPhase: timestamp(for:),
                    videoFrameIndexForPhase: videoFrameIndex(for:),
                    canonicalPoseExistsForPhase: canonicalPoseExists(for:),
                    stepFrame: stepKeyFrame(phase:direction:),
                    setAnchor: saveAnchor(phase:point:),
                    confirmPhase: confirmCurrentPhase,
                    jumpToPhase: jumpToPhase(_:),
                    pathPoints: record.pathPoints
                )

            } else {
                GarageLegacyReviewUnavailableSection()
            }

            if workflowProgress.nextAction.stage == .reviewInsights || workflowProgress.completedCount == workflowProgress.stages.count {
                GarageCoachingSection(report: coachingReport)
                GarageInsightsSection(report: insightReport)
            } else {
                GarageOutputHoldSection(
                    nextAction: workflowProgress.nextAction,
                    reliabilityReport: reliabilityReport,
                    captureQualityReport: captureQualityReport
                )
            }

            ModuleDisclosureSection(
                title: "Full Swing Video",
                theme: AppModule.garage.theme,
                initiallyExpanded: false
            ) {
                GarageVideoSection(
                    player: player,
                    duration: duration,
                    scrubPosition: $scrubPosition,
                    isScrubbing: $isScrubbing,
                    keyFrames: record.keyFrames,
                    timestampForPhase: timestamp(for:),
                    onTogglePlayback: togglePlayback,
                    onSeekToPhase: jumpToPhase(_:),
                    isVideoAvailable: videoURL != nil,
                    selectedPhase: selectedPhase
                )
            }

            ModuleDisclosureSection(
                title: "Analyzer Details",
                theme: AppModule.garage.theme,
                initiallyExpanded: false
            ) {
                GarageTechnicalPanel(
                    record: record,
                    report: insightReport,
                    reliabilityReport: reliabilityReport,
                    timestampForPhase: timestamp(for:),
                    videoFrameIndexForPhase: videoFrameIndex(for:)
                )
            }

            ModuleDisclosureSection(
                title: "Evaluation Harness",
                theme: AppModule.garage.theme,
                initiallyExpanded: false
            ) {
                if reviewFramesAvailable {
                    GarageEvaluationHarnessSection(
                        record: record,
                        snapshot: evaluationSnapshot,
                        recordIdentifier: recordIdentifier,
                        videoURL: videoURL,
                        timestampForPhase: timestamp(for:),
                        canonicalPoseExistsForPhase: canonicalPoseExists(for:),
                        exportSnapshot: exportEvaluationSnapshot
                    )
                } else {
                    GarageLegacyReviewUnavailableSection()
                }
            }
        }
        .onAppear(perform: configurePlayer)
        .onDisappear {
            player.pause()
        }
        .onReceive(playbackTimer) { _ in
            guard isScrubbing == false else { return }
            let currentSeconds = player.currentTime().seconds
            if currentSeconds.isFinite {
                scrubPosition = max(0, min(currentSeconds, duration))
            }
        }
        .fileExporter(
            isPresented: $isShowingEvaluationExporter,
            document: evaluationDocument,
            contentType: .json,
            defaultFilename: evaluationFilename
        ) { _ in }
        .fullScreenCover(isPresented: $isShowingPathPlayback) {
            GaragePathPlaybackView(
                player: player,
                videoURL: videoURL,
                duration: duration,
                pathPoints: record.pathPoints,
                dismiss: { isShowingPathPlayback = false }
            )
        }
    }

    private var videoURL: URL? {
        GarageMediaStore.persistedVideoURL(for: record.mediaFilename)
    }

    private var recordIdentifier: String {
        [record.mediaFilename, record.title, ISO8601DateFormatter().string(from: record.createdAt)]
            .compactMap { $0 }
            .joined(separator: "|")
    }

    private var reviewFramesAvailable: Bool {
        record.decodedFrames.isEmpty == false && videoURL != nil
    }

    private var duration: Double {
        max(record.decodedFrames.last?.presentationTimestamp ?? record.swingFrames.last?.timestamp ?? 0, 0.1)
    }

    private var insightReport: GarageInsightReport {
        GarageInsights.report(for: record)
    }

    private var reliabilityReport: GarageReliabilityReport {
        GarageReliability.report(for: record)
    }

    private var captureQualityReport: GarageCaptureQualityReport {
        GarageCaptureQuality.report(for: record)
    }

    private var coachingReport: GarageCoachingReport {
        GarageCoaching.report(for: record)
    }

    private var evaluationSnapshot: GarageEvaluationSnapshot {
        GarageEvaluationHarness.snapshot(for: record)
    }

    private var workflowProgress: GarageWorkflowProgress {
        GarageWorkflow.progress(for: record)
    }

    private func configurePlayer() {
        guard let videoURL else { return }
        let currentURL = (player.currentItem?.asset as? AVURLAsset)?.url
        guard currentURL != videoURL else { return }

        player.replaceCurrentItem(with: AVPlayerItem(url: videoURL))
        player.pause()
        seek(to: scrubPosition)
    }

    private func togglePlayback() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    private func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func jumpToPhase(_ phase: SwingPhase) {
        selectedPhase = phase
        let seconds = timestamp(for: phase)
        scrubPosition = seconds
        seek(to: seconds)
    }

    private func updateValidationStatus(_ status: KeyframeValidationStatus) {
        record.keyframeValidationStatus = status
        persistChanges()
    }

    private func stepKeyFrame(phase: SwingPhase, direction: Int) {
        guard let keyFrameIndex = record.keyFrames.firstIndex(where: { $0.phase == phase }) else {
            return
        }

        let currentFrameNumber = resolvedVideoFrameIndex(for: record.keyFrames[keyFrameIndex])
        let maximumFrameNumber = max(decodedFrameCount - 1, 0)
        let updatedFrameNumber = max(0, min(currentFrameNumber + direction, maximumFrameNumber))
        guard updatedFrameNumber != currentFrameNumber else { return }

        let currentTimestamp = timestamp(for: phase)
        let updatedTimestamp = decodedTimestamp(for: updatedFrameNumber)
        record.keyFrames[keyFrameIndex].decodedFrameIndex = updatedFrameNumber
        record.keyFrames[keyFrameIndex].source = .adjusted

        logFrameNavigation(
            phase: phase,
            previousDecodedFrameIndex: currentFrameNumber,
            updatedDecodedFrameIndex: updatedFrameNumber,
            previousTimestamp: currentTimestamp,
            updatedTimestamp: updatedTimestamp
        )

        if selectedPhase == phase {
            scrubPosition = updatedTimestamp
            seek(to: scrubPosition)
        }

        persistChanges()
    }

    private func saveAnchor(phase: SwingPhase, point: CGPoint) {
        let clampedPoint = CGPoint(
            x: max(0, min(point.x, 1)),
            y: max(0, min(point.y, 1))
        )

        let anchor = HandAnchor(phase: phase, x: clampedPoint.x, y: clampedPoint.y)
        if let index = record.handAnchors.firstIndex(where: { $0.phase == phase }) {
            record.handAnchors[index] = anchor
        } else {
            record.handAnchors.append(anchor)
        }

        record.handAnchors.sort { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }

        record.pathPoints = record.handAnchors.count == SwingPhase.allCases.count
            ? GarageAnalysisPipeline.generatePathPoints(from: record.handAnchors)
            : []

        selectedPhase = phase
        persistChanges()
    }

    private func persistChanges() {
        try? modelContext.save()
    }

    private func handleNextAction() {
        guard let stage = workflowProgress.nextAction.stage else { return }

        switch stage {
        case .importVideo:
            break
        case .validateKeyframes:
            selectedPhase = firstReviewPhaseNeedingAttention ?? .address
            jumpToPhase(selectedPhase)
        case .markAnchors:
            selectedPhase = firstMissingAnchorPhase ?? selectedPhase
            jumpToPhase(selectedPhase)
        case .reviewInsights:
            selectedPhase = .impact
            jumpToPhase(.impact)
        }
    }

    private var firstMissingAnchorPhase: SwingPhase? {
        let anchored = Set(record.handAnchors.map(\.phase))
        return SwingPhase.allCases.first(where: { anchored.contains($0) == false })
    }

    private var firstReviewPhaseNeedingAttention: SwingPhase? {
        firstMissingAnchorPhase ?? record.keyFrames.first?.phase
    }

    private func timestamp(for phase: SwingPhase) -> Double {
        guard let keyFrame = record.keyFrames.first(where: { $0.phase == phase }) else {
            return 0
        }

        if record.decodedFrames.indices.contains(keyFrame.decodedFrameIndex) {
            return record.decodedFrames[keyFrame.decodedFrameIndex].presentationTimestamp
        }

        if canonicalDecodedFrameTimestamps.indices.contains(keyFrame.decodedFrameIndex) {
            return canonicalDecodedFrameTimestamps[keyFrame.decodedFrameIndex]
        }

        guard record.swingFrames.indices.contains(keyFrame.decodedFrameIndex) else {
            return 0
        }

        return record.swingFrames[keyFrame.decodedFrameIndex].timestamp
    }

    private func resolvedVideoFrameIndex(for keyFrame: KeyFrame) -> Int {
        if record.decodedFrames.indices.contains(keyFrame.decodedFrameIndex) {
            return record.decodedFrames[keyFrame.decodedFrameIndex].decodedFrameIndex
        }

        if record.decodedFrameTimestamps.isEmpty == false {
            let targetTimestamp = timestamp(for: keyFrame.phase)
            return GarageDecodedFrameNavigation.nearestDecodedFrameIndex(
                to: targetTimestamp,
                timestamps: canonicalDecodedFrameTimestamps,
                fallbackFrameRate: record.frameRate
            )
        }

        return max(Int(round(timestamp(for: keyFrame.phase) * max(record.frameRate, 1))), keyFrame.decodedFrameIndex)
    }

    private func videoFrameIndex(for phase: SwingPhase) -> Int {
        guard let keyFrame = record.keyFrames.first(where: { $0.phase == phase }) else {
            return 0
        }

        return resolvedVideoFrameIndex(for: keyFrame)
    }

    private func canonicalPoseExists(for phase: SwingPhase) -> Bool {
        guard let keyFrame = record.keyFrames.first(where: { $0.phase == phase }) else {
            return false
        }

        return record.decodedFrames.indices.contains(keyFrame.decodedFrameIndex)
            && record.decodedFrames[keyFrame.decodedFrameIndex].poseSample != nil
    }

    private var decodedFrameCount: Int {
        GarageDecodedFrameNavigation.decodedFrameCount(
            timestamps: canonicalDecodedFrameTimestamps,
            fallbackDuration: duration,
            fallbackFrameRate: record.frameRate
        )
    }

    private func decodedTimestamp(for decodedFrameIndex: Int) -> Double {
        GarageDecodedFrameNavigation.timestamp(
            for: decodedFrameIndex,
            timestamps: canonicalDecodedFrameTimestamps,
            fallbackFrameRate: record.frameRate,
            fallbackDuration: duration
        )
    }

    private var canonicalDecodedFrameTimestamps: [Double] {
        if record.decodedFrames.isEmpty == false {
            return record.decodedFrames.map(\.presentationTimestamp)
        }

        return record.decodedFrameTimestamps
    }

    private func logFrameNavigation(
        phase: SwingPhase,
        previousDecodedFrameIndex: Int,
        updatedDecodedFrameIndex: Int,
        previousTimestamp: Double,
        updatedTimestamp: Double
    ) {
        let timestampDelta = abs(updatedTimestamp - previousTimestamp)
        let landmarkDisplacement = landmarkDisplacementBetweenNearestPoseFrames(
            previousTimestamp: previousTimestamp,
            updatedTimestamp: updatedTimestamp
        )
        let continuityError = continuityError(
            timestampDelta: timestampDelta,
            landmarkDisplacement: landmarkDisplacement
        )

        garageFrameLogger.log(
            """
            frame-step phase=\(phase.rawValue) requestedFrameIndex=\(updatedDecodedFrameIndex) requestedTimestamp=\(updatedTimestamp, format: .fixed(precision: 6)) actualReturnedTimestamp=pending decodedFrameIndex=\(updatedDecodedFrameIndex) exactDecode=pending roi=(0.0,0.0,1.0,1.0) landmarkDisplacement=\(landmarkDisplacement, format: .fixed(precision: 6)) continuityError=\(String(continuityError))
            """
        )

        #if DEBUG
        if continuityError {
            assertionFailure("Garage continuity error: adjacent UI frames diverged unexpectedly.")
        }
        #endif
    }

    private func landmarkDisplacementBetweenNearestPoseFrames(previousTimestamp: Double, updatedTimestamp: Double) -> Double {
        if
            let previousPoseSample = nearestPoseSample(to: previousTimestamp),
            let updatedPoseSample = nearestPoseSample(to: updatedTimestamp)
        {
            let previousFrame = SwingFrame(
                timestamp: previousTimestamp,
                joints: previousPoseSample.joints,
                confidence: previousPoseSample.confidence
            )
            let updatedFrame = SwingFrame(
                timestamp: updatedTimestamp,
                joints: updatedPoseSample.joints,
                confidence: updatedPoseSample.confidence
            )
            return GarageAnalysisPipeline.distance(
                from: GarageAnalysisPipeline.handCenter(in: previousFrame),
                to: GarageAnalysisPipeline.handCenter(in: updatedFrame)
            )
        }

        guard
            let previousFrame = record.swingFrames.min(by: { abs($0.timestamp - previousTimestamp) < abs($1.timestamp - previousTimestamp) }),
            let updatedFrame = record.swingFrames.min(by: { abs($0.timestamp - updatedTimestamp) < abs($1.timestamp - updatedTimestamp) })
        else {
            garageFrameLogger.log(
                "fallback-trace path=continuitySparseFrameFallback record=\(recordIdentifier, privacy: .public) previousTimestamp=\(previousTimestamp, format: .fixed(precision: 6)) updatedTimestamp=\(updatedTimestamp, format: .fixed(precision: 6)) result=none"
            )
            return 0
        }

        garageFrameLogger.log(
            "fallback-trace path=continuitySparseFrameFallback record=\(recordIdentifier, privacy: .public) previousTimestamp=\(previousTimestamp, format: .fixed(precision: 6)) previousSparseTimestamp=\(previousFrame.timestamp, format: .fixed(precision: 6)) updatedTimestamp=\(updatedTimestamp, format: .fixed(precision: 6)) updatedSparseTimestamp=\(updatedFrame.timestamp, format: .fixed(precision: 6)) reason=nearestSparseTimestamp"
        )
        return GarageAnalysisPipeline.distance(
            from: GarageAnalysisPipeline.handCenter(in: previousFrame),
            to: GarageAnalysisPipeline.handCenter(in: updatedFrame)
        )
    }

    private func nearestPoseSample(to timestamp: Double) -> PoseSampleAttachment? {
        record.decodedFrames
            .compactMap { frame -> (timestampDelta: Double, poseSample: PoseSampleAttachment)? in
                guard let poseSample = frame.poseSample else {
                    return nil
                }
                return (timestampDelta: abs(frame.presentationTimestamp - timestamp), poseSample: poseSample)
            }
            .min(by: { $0.timestampDelta < $1.timestampDelta })?
            .poseSample
    }

    private func continuityError(timestampDelta: Double, landmarkDisplacement: Double) -> Bool {
        GarageDecodedFrameNavigation.continuityError(
            timestampDelta: timestampDelta,
            landmarkDisplacement: landmarkDisplacement,
            decodedFrameTimestamps: canonicalDecodedFrameTimestamps,
            fallbackFrameRate: record.frameRate
        )
    }

    private func confirmCurrentPhase() {
        guard record.handAnchors.contains(where: { $0.phase == selectedPhase }) else {
            return
        }

        if let nextPhase = nextPhase(after: selectedPhase) {
            selectedPhase = nextPhase
            jumpToPhase(nextPhase)
        } else {
            record.keyframeValidationStatus = .approved
            player.pause()
            seek(to: 0)
            scrubPosition = 0
            isShowingPathPlayback = true
        }

        persistChanges()
    }

    private func nextPhase(after phase: SwingPhase) -> SwingPhase? {
        guard let index = SwingPhase.allCases.firstIndex(of: phase) else {
            return nil
        }

        let nextIndex = SwingPhase.allCases.index(after: index)
        guard SwingPhase.allCases.indices.contains(nextIndex) else {
            return nil
        }

        return SwingPhase.allCases[nextIndex]
    }

    private func exportEvaluationSnapshot() {
        if let document = try? GarageEvaluationDocument(snapshot: evaluationSnapshot) {
            evaluationDocument = document
            isShowingEvaluationExporter = true
        }
    }

    private var evaluationFilename: String {
        let sanitizedTitle = record.title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return "\(sanitizedTitle.isEmpty ? "garage-evaluation" : sanitizedTitle)-evaluation"
    }
}

private struct GarageVideoSection: View {
    let player: AVPlayer
    let duration: Double
    @Binding var scrubPosition: Double
    @Binding var isScrubbing: Bool
    let keyFrames: [KeyFrame]
    let timestampForPhase: (SwingPhase) -> Double
    let onTogglePlayback: () -> Void
    let onSeekToPhase: (SwingPhase) -> Void
    let isVideoAvailable: Bool
    let selectedPhase: SwingPhase

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            DashboardLikeSectionTitle(title: "Swing Video", subtitle: "Primary reference object for the full review flow.")

            ZStack {
                RoundedRectangle(cornerRadius: ModuleCornerRadius.hero, style: .continuous)
                    .fill(AppModule.garage.theme.surfaceSecondary)

                if isVideoAvailable {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.hero, style: .continuous))
                } else {
                    ContentUnavailableView(
                        "Video Missing",
                        systemImage: "video.slash",
                        description: Text("Import a swing video to begin the analyzer workflow.")
                    )
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                }
            }
            .frame(height: 250)
            .overlay(
                RoundedRectangle(cornerRadius: ModuleCornerRadius.hero, style: .continuous)
                    .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
            )

            HStack(spacing: ModuleSpacing.small) {
                Button(action: onTogglePlayback) {
                    Image(systemName: player.timeControlStatus == .playing ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(AppModule.garage.theme.surfaceInteractive, in: Circle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    Slider(
                        value: $scrubPosition,
                        in: 0...duration,
                        onEditingChanged: { editing in
                            isScrubbing = editing
                            if editing == false {
                                let time = CMTime(seconds: scrubPosition, preferredTimescale: 600)
                                player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
                            }
                        }
                    )
                    .tint(AppModule.garage.theme.primary)
                    .overlay(alignment: .bottomLeading) {
                        GarageTimelineMarkersView(
                            duration: duration,
                            keyFrames: keyFrames,
                            timestampForPhase: timestampForPhase,
                            onSelect: onSeekToPhase,
                            selectedPhase: selectedPhase
                        )
                        .padding(.top, 18)
                    }

                    HStack {
                        Text(formatTime(scrubPosition))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.caption)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let totalSeconds = max(Int(seconds.rounded()), 0)
        let minutes = totalSeconds / 60
        let remainder = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", remainder))"
    }
}

private struct GarageTimelineMarkersView: View {
    let duration: Double
    let keyFrames: [KeyFrame]
    let timestampForPhase: (SwingPhase) -> Double
    let onSelect: (SwingPhase) -> Void
    let selectedPhase: SwingPhase

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                ForEach(keyFrames) { keyFrame in
                    Button {
                        onSelect(keyFrame.phase)
                    } label: {
                        Capsule()
                            .fill(markerColor(for: keyFrame))
                            .frame(width: selectedPhase == keyFrame.phase ? 6 : 4, height: selectedPhase == keyFrame.phase ? 12 : 10)
                    }
                    .buttonStyle(.plain)
                    .offset(x: markerOffset(in: proxy.size.width, for: keyFrame.phase))
                }
            }
        }
        .frame(height: 10)
    }

    private func markerOffset(in width: CGFloat, for phase: SwingPhase) -> CGFloat {
        guard duration > 0 else { return 0 }
        let ratio = min(max(timestampForPhase(phase) / duration, 0), 1)
        return (width - 6) * CGFloat(ratio)
    }

    private func markerColor(for keyFrame: KeyFrame) -> Color {
        if selectedPhase == keyFrame.phase {
            return AppModule.garage.theme.textPrimary
        }

        if keyFrame.source == .adjusted {
            return AppModule.garage.theme.secondary
        }

        return AppModule.garage.theme.primary
    }
}

private struct GarageWorkflowSummarySection: View {
    let progress: GarageWorkflowProgress
    let reliabilityReport: GarageReliabilityReport
    let captureQualityReport: GarageCaptureQualityReport
    let selectedPhase: SwingPhase
    let confirmedCount: Int
    let nextAction: () -> Void

    var body: some View {
        ModuleRowSurface(theme: AppModule.garage.theme) {
            HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                VStack(alignment: .leading, spacing: ModuleSpacing.xSmall) {
                    Text("8-Frame Review")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                    Text(selectedPhase.reviewTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    Text("Work through one dominant frame at a time. Place the grip point, confirm it, then move to the next checkpoint.")
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: ModuleSpacing.xSmall) {
                    GarageStatusPill(title: "\(confirmedCount)/8 confirmed")
                    Text(captureQualityReport.benchmark)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                    Text(reliabilityReport.status.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(summaryColor)
                }
            }

            ProgressView(value: Double(confirmedCount), total: 8)
                .tint(AppModule.garage.theme.primary)

            Button(progress.nextAction.actionLabel, action: nextAction)
                .buttonStyle(.borderedProminent)
                .tint(AppModule.garage.theme.primary)
        }
    }

    private var summaryColor: Color {
        switch reliabilityReport.status {
        case .trusted:
            AppModule.garage.theme.primary
        case .review:
            .orange
        case .provisional:
            .red
        }
    }
}

private struct GarageCaptureQualitySection: View {
    let report: GarageCaptureQualityReport

    var body: some View {
        ModuleRowSurface(theme: AppModule.garage.theme) {
            HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                VStack(alignment: .leading, spacing: ModuleSpacing.xxSmall) {
                    Text("Capture And Sequence Audit")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                    Text(report.headline)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    Text(report.summary)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }
                Spacer()
                Text(report.status.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
            }

            Text(report.benchmark)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(statusColor)

            ForEach(report.findings.prefix(3)) { finding in
                HStack(alignment: .top, spacing: ModuleSpacing.small) {
                    Image(systemName: iconName(for: finding.severity))
                        .foregroundStyle(color(for: finding.severity))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(finding.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppModule.garage.theme.textPrimary)
                        Text(finding.detail)
                            .font(.caption)
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        color(for: report.status)
    }

    private func iconName(for severity: GarageCaptureSeverity) -> String {
        switch severity {
        case .good:
            "checkmark.circle.fill"
        case .review:
            "exclamationmark.triangle.fill"
        case .poor:
            "xmark.octagon.fill"
        }
    }

    private func color(for severity: GarageCaptureSeverity) -> Color {
        switch severity {
        case .good:
            AppModule.garage.theme.primary
        case .review:
            .orange
        case .poor:
            .red
        }
    }
}

private struct GaragePrimaryReviewSection: View {
    @Binding var selectedPhase: SwingPhase
    let recordIdentifier: String
    let keyFrames: [KeyFrame]
    let videoURL: URL?
    let handAnchors: [HandAnchor]
    let timestampForPhase: (SwingPhase) -> Double
    let videoFrameIndexForPhase: (SwingPhase) -> Int
    let canonicalPoseExistsForPhase: (SwingPhase) -> Bool
    let stepFrame: (SwingPhase, Int) -> Void
    let setAnchor: (SwingPhase, CGPoint) -> Void
    let confirmPhase: () -> Void
    let jumpToPhase: (SwingPhase) -> Void
    let pathPoints: [PathPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            DashboardLikeSectionTitle(
                title: "Primary Frame Workspace",
                subtitle: "The analyzer should show one frame at a time. Adjust the checkpoint if needed, place the grip point, confirm, and move to the next phase."
            )

            if let selectedKeyFrame {
                ModuleRowSurface(theme: AppModule.garage.theme) {
                    GarageFrameCanvas(
                        recordIdentifier: recordIdentifier,
                        phaseLabel: selectedKeyFrame.phase.rawValue,
                        videoURL: videoURL,
                        decodedFrameIndex: videoFrameIndexForPhase(selectedKeyFrame.phase),
                        canonicalPoseExists: canonicalPoseExistsForPhase(selectedKeyFrame.phase),
                        anchor: handAnchors.first(where: { $0.phase == selectedKeyFrame.phase }),
                        pathPoints: [],
                        interactive: true
                    ) { point in
                        setAnchor(selectedKeyFrame.phase, point)
                        selectedPhase = selectedKeyFrame.phase
                    }
                    .frame(height: 430)

                    HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                        VStack(alignment: .leading, spacing: ModuleSpacing.xSmall) {
                            HStack {
                                GarageStatusPill(title: "\(phaseNumber(for: selectedKeyFrame.phase))/8")
                                GarageStatusPill(title: selectedKeyFrame.phase.reviewTitle)
                                GarageStatusPill(title: "Frame \(videoFrameIndexForPhase(selectedKeyFrame.phase) + 1)")
                            }
                            Text(selectedKeyFrame.phase.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppModule.garage.theme.textPrimary)
                            Text(anchorGuidance(for: selectedKeyFrame.phase))
                                .foregroundStyle(AppModule.garage.theme.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: ModuleSpacing.xSmall) {
                            Text(String(format: "%.2fs", timestampForPhase(selectedKeyFrame.phase)))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppModule.garage.theme.textMuted)
                            GarageStatusPill(title: anchorExists(for: selectedKeyFrame.phase) ? "Placed" : "Needed")
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            stepFrame(selectedKeyFrame.phase, -1)
                        } label: {
                            Label("Earlier", systemImage: "chevron.left")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppModule.garage.theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            stepFrame(selectedKeyFrame.phase, 1)
                        } label: {
                            Label("Later", systemImage: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppModule.garage.theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 10) {
                        Button {
                            if let previousPhase {
                                jumpToPhase(previousPhase)
                            }
                        } label: {
                            Label("Previous", systemImage: "arrow.left")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppModule.garage.theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(previousPhase == nil)

                        Button(action: confirmPhase) {
                            Text(nextPhase == nil ? "Finish 8 Frames" : "Confirm \(selectedKeyFrame.phase.reviewTitle)")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppModule.garage.theme.primary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous))
                                .foregroundStyle(Color.black.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .disabled(anchorExists(for: selectedKeyFrame.phase) == false)
                    }

                    ProgressView(value: Double(handAnchors.count), total: Double(SwingPhase.allCases.count))
                        .tint(AppModule.garage.theme.primary)

                    Text(pathPoints.isEmpty
                        ? "\(handAnchors.count) of \(SwingPhase.allCases.count) grip points confirmed. The hand path appears after all 8 frames are done."
                        : "All 8 grip points are confirmed. The analyzer can now draw the hand path back to you.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                }
            }
        }
    }

    private var selectedKeyFrame: KeyFrame? {
        keyFrames.first(where: { $0.phase == selectedPhase })
    }

    private func anchorExists(for phase: SwingPhase) -> Bool {
        handAnchors.contains(where: { $0.phase == phase })
    }

    private func anchorGuidance(for phase: SwingPhase) -> String {
        anchorExists(for: phase)
            ? "Tap the image to replace the saved grip midpoint, then confirm this frame and move on."
            : "Tap the middle of the hands on the grip. This frame should dominate the screen until you confirm it."
    }

    private func phaseNumber(for phase: SwingPhase) -> Int {
        (SwingPhase.allCases.firstIndex(of: phase) ?? 0) + 1
    }

    private var previousPhase: SwingPhase? {
        guard let index = SwingPhase.allCases.firstIndex(of: selectedPhase), index > 0 else {
            return nil
        }

        return SwingPhase.allCases[index - 1]
    }

    private var nextPhase: SwingPhase? {
        guard let index = SwingPhase.allCases.firstIndex(of: selectedPhase) else {
            return nil
        }

        let nextIndex = index + 1
        guard SwingPhase.allCases.indices.contains(nextIndex) else {
            return nil
        }

        return SwingPhase.allCases[nextIndex]
    }
}

private struct GaragePathPlaybackView: View {
    let player: AVPlayer
    let videoURL: URL?
    let duration: Double
    let pathPoints: [PathPoint]
    let dismiss: () -> Void

    @State private var pathTrim: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    if let videoURL {
                        VideoPlayer(player: player)
                            .ignoresSafeArea()
                            .onAppear {
                                player.replaceCurrentItem(with: AVPlayerItem(url: videoURL))
                                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                                player.playImmediately(atRate: 0.35)
                                pathTrim = 0
                                withAnimation(.linear(duration: max(duration / 0.35, 1.2))) {
                                    pathTrim = 1
                                }
                            }
                            .onDisappear {
                                player.pause()
                            }
                    } else {
                        ContentUnavailableView(
                            "Video Missing",
                            systemImage: "video.slash",
                            description: Text("The slow-motion hand-path playback needs the original swing video.")
                        )
                        .foregroundStyle(.white.opacity(0.7))
                    }

                    GeometryReader { proxy in
                        Path { path in
                            for (index, point) in pathPoints.enumerated() {
                                let resolved = CGPoint(x: proxy.size.width * point.x, y: proxy.size.height * point.y)
                                if index == 0 {
                                    path.move(to: resolved)
                                } else {
                                    path.addLine(to: resolved)
                                }
                            }
                        }
                        .trim(from: 0, to: pathTrim)
                        .stroke(
                            AppModule.garage.theme.primary,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: AppModule.garage.theme.accentGlow, radius: 8)
                    }
                    .allowsHitTesting(false)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Swing Playback Result")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Garage replays the full swing in slow motion and draws the confirmed hand path across the motion, not on a static screenshot.")
                        .foregroundStyle(.white.opacity(0.78))
                    Button("Replay") {
                        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                        player.playImmediately(atRate: 0.35)
                        pathTrim = 0
                        withAnimation(.linear(duration: max(duration / 0.35, 1.2))) {
                            pathTrim = 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.garage.theme.primary)
                    .foregroundStyle(Color.black.opacity(0.85))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.75))
            }

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .padding()
        }
    }
}

private struct GarageEvaluationHarnessSection: View {
    let record: SwingRecord
    let snapshot: GarageEvaluationSnapshot
    let recordIdentifier: String
    let videoURL: URL?
    let timestampForPhase: (SwingPhase) -> Double
    let canonicalPoseExistsForPhase: (SwingPhase) -> Bool
    let exportSnapshot: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            ModuleRowSurface(theme: AppModule.garage.theme) {
                Text("Real-Swing Evaluation")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                Text("Use this debug layer to compare Garage's actual 8 selected frames against a known-good benchmark grid.")
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                GarageFieldRow(label: "Capture status", value: snapshot.captureStatus)
                GarageFieldRow(label: "Primary cause", value: snapshot.capturePrimaryCause)
                GarageFieldRow(label: "Reliability", value: "\(snapshot.reliabilityStatus) • \(snapshot.reliabilityScore)%")
                if snapshot.weakestPhases.isEmpty == false {
                    GarageFieldRow(label: "Weakest phases", value: snapshot.weakestPhases.prefix(3).joined(separator: ", "))
                }
                Button("Export Evaluation JSON", action: exportSnapshot)
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.garage.theme.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ModuleSpacing.small) {
                    ForEach(record.keyFrames.sorted { lhs, rhs in
                        (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
                    }) { keyFrame in
                        ModuleRowSurface(theme: AppModule.garage.theme) {
                            GarageFrameCanvas(
                                recordIdentifier: recordIdentifier,
                                phaseLabel: keyFrame.phase.rawValue,
                                videoURL: videoURL,
                                decodedFrameIndex: videoFrameIndex(for: keyFrame),
                                canonicalPoseExists: canonicalPoseExistsForPhase(keyFrame.phase),
                                anchor: nil,
                                pathPoints: [],
                                interactive: false,
                                onPlaceAnchor: nil
                            )
                            .frame(width: 154, height: 180)

                            Text(keyFrame.phase.reviewTitle)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppModule.garage.theme.textPrimary)
                            Text(phaseSnapshot(for: keyFrame.phase)?.health ?? "Review")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(phaseHealthColor(for: phaseSnapshot(for: keyFrame.phase)?.health))
                            Text("Frame \(videoFrameIndex(for: keyFrame) + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppModule.garage.theme.textSecondary)
                            Text(String(format: "%.2fs", timestampForPhase(keyFrame.phase)))
                                .font(.caption)
                                .foregroundStyle(AppModule.garage.theme.textMuted)
                            if let phaseSnapshot = phaseSnapshot(for: keyFrame.phase),
                               let firstNote = phaseSnapshot.notes.first {
                                Text(firstNote)
                                    .font(.caption2)
                                    .foregroundStyle(AppModule.garage.theme.textMuted)
                            }
                        }
                        .frame(width: 182)
                    }
                }
            }
        }
    }

    private func phaseSnapshot(for phase: SwingPhase) -> GarageEvaluationPhaseSnapshot? {
        snapshot.phases.first(where: { $0.phase == phase.rawValue })
    }

    private func videoFrameIndex(for keyFrame: KeyFrame) -> Int {
        phaseSnapshot(for: keyFrame.phase)?.frameIndex ?? keyFrame.decodedFrameIndex
    }

    private func phaseHealthColor(for health: String?) -> Color {
        switch health {
        case GaragePhaseHealth.strong.rawValue:
            AppModule.garage.theme.primary
        case GaragePhaseHealth.weak.rawValue:
            .red
        default:
            .orange
        }
    }
}

private struct GarageTechnicalPanel: View {
    let record: SwingRecord
    let report: GarageInsightReport
    let reliabilityReport: GarageReliabilityReport
    let timestampForPhase: (SwingPhase) -> Double
    let videoFrameIndexForPhase: (SwingPhase) -> Int

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            DashboardLikeSectionTitle(
                title: "Technical Validation",
                subtitle: "Keep correctness visible while the analyzer workflow is still maturing."
            )

            ModuleRowSurface(theme: AppModule.garage.theme) {
                GarageFieldRow(label: "Total video frames", value: "\(record.swingFrames.count)")
                GarageFieldRow(label: "Detected keyframes", value: "\(record.keyFrames.count)")
                GarageFieldRow(label: "Validation status", value: record.keyframeValidationStatus.title)
                GarageFieldRow(label: "Hand anchors", value: "\(record.handAnchors.count)/8")
                GarageFieldRow(label: "Path generation", value: record.pathPoints.isEmpty ? "Pending" : "Ready")
                GarageFieldRow(label: "Metrics readiness", value: report.readiness)
                GarageFieldRow(label: "Reliability", value: "\(reliabilityReport.status.rawValue) • \(reliabilityReport.score)%")
                GarageFieldRow(label: "Adjusted keyframes", value: "\(record.keyFrames.filter { $0.source == .adjusted }.count)")
            }

            ModuleRowSurface(theme: AppModule.garage.theme) {
                Text("Checkpoint timing")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                ForEach(record.keyFrames) { keyFrame in
                    GarageFieldRow(
                        label: keyFrame.phase.reviewTitle,
                        value: "\(keyFrame.source.title) • Frame \(videoFrameIndexForPhase(keyFrame.phase) + 1) • \(String(format: "%.2fs", timestampForPhase(keyFrame.phase)))"
                    )
                }
            }
        }
    }
}

private struct GarageOutputHoldSection: View {
    let nextAction: GarageWorkflowNextAction
    let reliabilityReport: GarageReliabilityReport
    let captureQualityReport: GarageCaptureQualityReport

    var body: some View {
        ModuleRowSurface(theme: AppModule.garage.theme) {
            Text("Outputs Are Held Back")
                .font(.headline)
                .foregroundStyle(AppModule.garage.theme.textPrimary)
            Text("Garage should not ask you to interpret coaching while the 8-frame result still needs work. Finish the current review task first.")
                .foregroundStyle(AppModule.garage.theme.textSecondary)
            HStack {
                GarageStatusPill(title: nextAction.title)
                Spacer()
                Text(reliabilityReport.status.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(outputColor)
            }
            Text(nextAction.body)
                .font(.caption)
                .foregroundStyle(AppModule.garage.theme.textMuted)
            Text("Primary cause: \(captureQualityReport.primaryCause)")
                .font(.caption)
                .foregroundStyle(AppModule.garage.theme.textMuted)
        }
    }

    private var outputColor: Color {
        switch reliabilityReport.status {
        case .trusted:
            AppModule.garage.theme.primary
        case .review:
            .orange
        case .provisional:
            .red
        }
    }
}

private struct GarageLegacyReviewUnavailableSection: View {
    var body: some View {
        ModuleRowSurface(theme: AppModule.garage.theme) {
            Text("Frame Review Unavailable")
                .font(.headline)
                .foregroundStyle(AppModule.garage.theme.textPrimary)
            Text("This swing record does not contain canonical decoded frames. Re-analyze the source video to unlock exact frame-by-frame review.")
                .foregroundStyle(AppModule.garage.theme.textSecondary)
            Text("Garage no longer reconstructs review identity from timestamps or sparse pose samples.")
                .font(.caption)
                .foregroundStyle(AppModule.garage.theme.textMuted)
        }
    }
}

private struct GarageReliabilitySection: View {
    let report: GarageReliabilityReport

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            DashboardLikeSectionTitle(
                title: "Reliability",
                subtitle: "A trust check for the current swing before you lean on the downstream output."
            )

            ModuleRowSurface(theme: AppModule.garage.theme) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.status.rawValue)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(statusColor)
                        Text(report.summary)
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                    Spacer()
                    Text("\(report.score)%")
                        .font(.title2.weight(.black))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                }

                ProgressView(value: Double(report.score), total: 100)
                    .tint(statusColor)

                ForEach(report.checks) { check in
                    HStack(alignment: .top, spacing: ModuleSpacing.small) {
                        Image(systemName: check.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(check.passed ? AppModule.garage.theme.primary : .orange)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppModule.garage.theme.textPrimary)
                            Text(check.detail)
                                .font(.caption)
                                .foregroundStyle(AppModule.garage.theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        switch report.status {
        case .trusted:
            AppModule.garage.theme.primary
        case .review:
            .orange
        case .provisional:
            .red
        }
    }
}

private struct GarageInsightsSection: View {
    let report: GarageInsightReport

    private let columns = [
        GridItem(.flexible(), spacing: ModuleSpacing.small),
        GridItem(.flexible(), spacing: ModuleSpacing.small)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            DashboardLikeSectionTitle(
                title: "4. Output layer insights",
                subtitle: "Derived from the saved keyframes, pose frames, and grip path you validated."
            )

            ModuleRowSurface(theme: AppModule.garage.theme) {
                Text(report.readiness)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppModule.garage.theme.primary)
                Text(report.summary)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: ModuleSpacing.small) {
                ForEach(report.metrics) { metric in
                    ModuleRowSurface(theme: AppModule.garage.theme) {
                        Text(metric.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                        Text(metric.value)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppModule.garage.theme.textPrimary)
                        Text(metric.detail)
                            .font(.caption)
                            .foregroundStyle(AppModule.garage.theme.textMuted)
                    }
                }
            }

            if report.highlights.isEmpty == false {
                ModuleRowSurface(theme: AppModule.garage.theme) {
                    Text("Highlights")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    ForEach(report.highlights, id: \.self) { highlight in
                        Text("• \(highlight)")
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                }
            }

            if report.issues.isEmpty == false {
                ModuleRowSurface(theme: AppModule.garage.theme) {
                    Text("Review Notes")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    ForEach(report.issues, id: \.self) { issue in
                        Text("• \(issue)")
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                }
            }
        }
    }
}

private struct GarageCoachingSection: View {
    let report: GarageCoachingReport

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            DashboardLikeSectionTitle(
                title: "Coaching",
                subtitle: "Actionable interpretation built on the current metrics and reliability state."
            )

            ModuleRowSurface(theme: AppModule.garage.theme) {
                Text(report.confidenceLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(confidenceColor)
                Text(report.headline)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                Text(report.nextBestAction)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
            }

            if report.cues.isEmpty == false {
                ModuleRowSurface(theme: AppModule.garage.theme) {
                    Text("Coaching Cues")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    ForEach(report.cues) { cue in
                        HStack(alignment: .top, spacing: ModuleSpacing.small) {
                            Image(systemName: iconName(for: cue.severity))
                                .foregroundStyle(color(for: cue.severity))
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cue.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                                Text(cue.message)
                                    .font(.caption)
                                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                            }
                        }
                    }
                }
            }

            if report.blockers.isEmpty == false {
                ModuleRowSurface(theme: AppModule.garage.theme) {
                    Text("Blockers")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    ForEach(report.blockers, id: \.self) { blocker in
                        Text("• \(blocker)")
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                }
            }
        }
    }

    private var confidenceColor: Color {
        switch report.confidenceLabel {
        case GarageReliabilityStatus.trusted.rawValue:
            AppModule.garage.theme.primary
        case GarageReliabilityStatus.review.rawValue:
            .orange
        default:
            .red
        }
    }

    private func iconName(for severity: GarageCoachingSeverity) -> String {
        switch severity {
        case .positive:
            "checkmark.circle.fill"
        case .info:
            "info.circle.fill"
        case .caution:
            "exclamationmark.triangle.fill"
        }
    }

    private func color(for severity: GarageCoachingSeverity) -> Color {
        switch severity {
        case .positive:
            AppModule.garage.theme.primary
        case .info:
            AppModule.garage.theme.textSecondary
        case .caution:
            .orange
        }
    }
}

private struct GarageWorkflowProgressSection: View {
    let progress: GarageWorkflowProgress
    let nextAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            DashboardLikeSectionTitle(
                title: "Workflow Progress",
                subtitle: "Finish each Garage stage in order so the downstream output stays readable and trustworthy."
            )

            ModuleRowSurface(theme: AppModule.garage.theme) {
                HStack {
                    Text("\(progress.completedCount)/\(progress.stages.count) complete")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    Spacer()
                    Text(progress.completedCount == progress.stages.count ? "Ready" : "In Progress")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppModule.garage.theme.primary)
                }

                ForEach(progress.stages) { stage in
                    HStack(alignment: .top, spacing: ModuleSpacing.small) {
                        Image(systemName: iconName(for: stage.status))
                            .foregroundStyle(color(for: stage.status))
                            .font(.headline)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(stage.stage.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                                Spacer()
                                Text(stage.status.rawValue)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(color(for: stage.status))
                            }

                            Text(stage.summary)
                                .font(.caption)
                                .foregroundStyle(AppModule.garage.theme.textSecondary)
                        }
                    }
                }
            }

            ModuleRowSurface(theme: AppModule.garage.theme) {
                Text("Next Action")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                Text(progress.nextAction.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppModule.garage.theme.primary)
                Text(progress.nextAction.body)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                Button(progress.nextAction.actionLabel, action: nextAction)
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.garage.theme.primary)
            }
        }
    }

    private func iconName(for status: GarageWorkflowStatus) -> String {
        switch status {
        case .incomplete:
            "circle"
        case .complete:
            "checkmark.circle.fill"
        case .needsAttention:
            "exclamationmark.triangle.fill"
        }
    }

    private func color(for status: GarageWorkflowStatus) -> Color {
        switch status {
        case .incomplete:
            AppModule.garage.theme.textMuted
        case .complete:
            AppModule.garage.theme.primary
        case .needsAttention:
            .orange
        }
    }
}

private struct GarageAnalyzerEmptyState: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.large) {
            ModuleHeroCard(
                module: .garage,
                eyebrow: "Swing Analyzer",
                title: "Start with one swing video",
                message: "Garage will detect 8 keyframes, guide you through review, capture the grip midpoint on each frame, and generate a simple path before insights."
            )

            ModuleEmptyStateCard(
                theme: AppModule.garage.theme,
                title: "No swing analysis yet",
                message: "Import a swing video to begin the video-first validation workflow.",
                actionTitle: "Import Swing Video",
                action: action
            )
        }
    }
}

private struct GarageAnalyzingOverlay: View {
    var body: some View {
        ZStack {
            AppModule.garage.theme.canvasBase.opacity(0.92)
                .ignoresSafeArea()

            ModuleRowSurface(theme: AppModule.garage.theme) {
                VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
                    HStack(alignment: .center, spacing: ModuleSpacing.medium) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(AppModule.garage.theme.primary)

                        VStack(alignment: .leading, spacing: ModuleSpacing.xxSmall) {
                            Text("Analyzing Swing Video")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppModule.garage.theme.textPrimary)
                            Text("Pulling the swing from Photos, extracting 8 keyframes, and preparing the review canvas.")
                                .foregroundStyle(AppModule.garage.theme.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        GarageStatusPill(title: "Buffering")
                        Text("The keyframe confirmation view will appear here automatically as soon as analysis is ready.")
                            .font(.subheadline)
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                }
                .frame(maxWidth: 520, alignment: .leading)
            }
            .padding(.horizontal, ModuleSpacing.large)
        }
    }
}

private struct GarageImportErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.9), in: RoundedRectangle(cornerRadius: ModuleCornerRadius.medium, style: .continuous))
    }
}

private struct DashboardLikeSectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
        }
    }
}

private struct GarageFieldRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

private struct GarageStatusPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppModule.garage.theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppModule.garage.theme.surfaceInteractive, in: Capsule())
    }
}

private struct GarageWarningCard: View {
    let title: String
    let message: String

    var body: some View {
        ModuleRowSurface(theme: AppModule.garage.theme) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppModule.garage.theme.textPrimary)
            Text(message)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
        }
    }
}

private struct GarageFrameCanvas: View {
    let recordIdentifier: String
    let phaseLabel: String
    let videoURL: URL?
    let decodedFrameIndex: Int
    let canonicalPoseExists: Bool
    let anchor: HandAnchor?
    let pathPoints: [PathPoint]
    let interactive: Bool
    let onPlaceAnchor: ((CGPoint) -> Void)?

    @State private var renderedFrame: GarageRenderedFrameResult?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: ModuleCornerRadius.medium, style: .continuous)
                    .fill(AppModule.garage.theme.surfaceSecondary)

                if let renderedFrame {
                    Image(decorative: renderedFrame.image, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.medium, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "video")
                            .font(.title3)
                            .foregroundStyle(AppModule.garage.theme.textMuted)
                        Text("Frame Preview")
                            .font(.caption)
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Req \(decodedFrameIndex) -> Rend \(renderedFrame?.renderedDecodedFrameIndex ?? -1)")
                    Text("Src \(renderedFrame?.imageSource ?? "unavailable")")
                    Text("Pose \(canonicalPoseExists ? "yes" : "no")")
                    Text("Fallback \(renderedFrame?.fallbackUsed == true ? "yes" : "no")")
                    if let fallbackReason = renderedFrame?.fallbackReason {
                        Text(fallbackReason)
                    }
                }
                .font(.caption2.monospaced())
                .foregroundStyle(.white)
                .padding(8)
                .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if pathPoints.isEmpty == false {
                    Path { path in
                        for (index, point) in pathPoints.enumerated() {
                            let resolved = CGPoint(x: proxy.size.width * point.x, y: proxy.size.height * point.y)
                            if index == 0 {
                                path.move(to: resolved)
                            } else {
                                path.addLine(to: resolved)
                            }
                        }
                    }
                    .stroke(AppModule.garage.theme.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: AppModule.garage.theme.accentGlow, radius: 6)
                }

                if let anchor {
                    Circle()
                        .fill(AppModule.garage.theme.primary)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 2))
                        .shadow(color: AppModule.garage.theme.accentGlow, radius: 8)
                        .position(x: proxy.size.width * anchor.x, y: proxy.size.height * anchor.y)
                }

                if interactive {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let normalizedPoint = CGPoint(
                                        x: value.location.x / max(proxy.size.width, 1),
                                        y: value.location.y / max(proxy.size.height, 1)
                                    )
                                    onPlaceAnchor?(normalizedPoint)
                                }
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ModuleCornerRadius.medium, style: .continuous)
                    .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
            )
        }
        .task(id: thumbnailTaskKey) {
            guard let videoURL else {
                renderedFrame = nil
                return
            }

            garageFrameLogger.log(
                "frame-request record=\(recordIdentifier, privacy: .public) phase=\(phaseLabel, privacy: .public) requestedDecodedFrameIndex=\(decodedFrameIndex) canonicalPoseAttached=\(canonicalPoseExists, privacy: .public) fallbackUsed=false fallbackReason=none"
            )
            renderedFrame = await GarageMediaStore.thumbnail(for: videoURL, decodedFrameIndex: decodedFrameIndex)
            garageFrameLogger.log(
                "frame-response record=\(recordIdentifier, privacy: .public) phase=\(phaseLabel, privacy: .public) requestedDecodedFrameIndex=\(decodedFrameIndex) renderedDecodedFrameIndex=\(renderedFrame?.renderedDecodedFrameIndex ?? -1) canonicalPoseAttached=\(canonicalPoseExists, privacy: .public) fallbackUsed=\(renderedFrame?.fallbackUsed ?? true, privacy: .public) fallbackReason=\(renderedFrame?.fallbackReason ?? "renderUnavailable", privacy: .public)"
            )
        }
    }

    private var thumbnailTaskKey: String {
        "\(videoURL?.absoluteString ?? "none")-\(decodedFrameIndex)"
    }
}

private struct GaragePickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)

            if FileManager.default.fileExists(atPath: destinationURL.path()) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: received.file, to: destinationURL)
            return GaragePickedMovie(url: destinationURL)
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

private struct GarageEvaluationDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    @MainActor
    init(snapshot: GarageEvaluationSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        data = try encoder.encode(snapshot)
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview("Garage Empty") {
    PreviewScreenContainer {
        GarageView()
    }
    .modelContainer(PreviewCatalog.emptyApp)
    .preferredColorScheme(.dark)
}

#Preview("Garage Workflow") {
    PreviewScreenContainer {
        GarageView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
    .preferredColorScheme(.dark)
}
