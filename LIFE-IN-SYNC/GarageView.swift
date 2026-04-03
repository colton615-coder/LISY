import AVKit
import Combine
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct GarageView: View {
    @Query(sort: \SwingRecord.createdAt, order: .reverse) private var swingRecords: [SwingRecord]
    @State private var isShowingAddRecord = false

    var body: some View {
        ModuleScreen(theme: AppModule.garage.theme) {
            ModuleHeader(
                theme: AppModule.garage.theme,
                title: "Garage",
                subtitle: "Upload one swing, verify 8 keyframes, mark the grip midpoint, and validate the path before insights."
            )

            if let latestRecord = swingRecords.first {
                GarageAnalysisWorkflowView(record: latestRecord)
            } else {
                GarageAnalyzerEmptyState {
                    isShowingAddRecord = true
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ModuleBottomActionBar(
                theme: AppModule.garage.theme,
                title: swingRecords.isEmpty ? "Import Swing Video" : "Add Swing Record",
                systemImage: "plus"
            ) {
                isShowingAddRecord = true
            }
        }
        .sheet(isPresented: $isShowingAddRecord) {
            AddSwingRecordSheet()
        }
    }
}

private struct GarageAnalysisWorkflowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var record: SwingRecord

    @State private var player = AVPlayer()
    @State private var selectedPhase: SwingPhase
    @State private var scrubPosition: Double
    @State private var isScrubbing = false

    private let playbackTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    init(record: SwingRecord) {
        self.record = record
        _selectedPhase = State(initialValue: record.keyFrames.first?.phase ?? .address)
        _scrubPosition = State(initialValue: record.swingFrames.first?.timestamp ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.large) {
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

            GarageValidationSection(
                status: record.keyframeValidationStatus,
                selectedPhase: $selectedPhase,
                keyFrames: record.keyFrames,
                videoURL: videoURL,
                timestampForPhase: timestamp(for:),
                setStatus: updateValidationStatus(_:),
                stepFrame: stepKeyFrame(phase:direction:)
            )

            if record.keyframeValidationStatus == .flagged {
                GarageWarningCard(
                    title: "Validation flagged",
                    message: "Continue to hand marking if needed, but treat downstream results as less reliable until the keyframes are corrected."
                )
            }

            GarageHandAnchorSection(
                videoURL: videoURL,
                keyFrames: record.keyFrames,
                handAnchors: record.handAnchors,
                selectedPhase: $selectedPhase,
                timestampForPhase: timestamp(for:),
                setAnchor: saveAnchor(phase:point:)
            )

            GaragePathReviewSection(
                selectedPhase: selectedPhase,
                videoURL: videoURL,
                timestamp: timestamp(for: selectedPhase),
                handAnchors: record.handAnchors,
                pathPoints: record.pathPoints
            )

            GarageInsightsSection(report: insightReport)
            GarageTechnicalPanel(record: record, report: insightReport, timestampForPhase: timestamp(for:))
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
    }

    private var videoURL: URL? {
        GarageMediaStore.persistedVideoURL(for: record.mediaFilename)
    }

    private var duration: Double {
        max(record.swingFrames.last?.timestamp ?? 0, 0.1)
    }

    private var insightReport: GarageInsightReport {
        GarageInsights.report(for: record)
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

        let currentIndex = record.keyFrames[keyFrameIndex].frameIndex
        let updatedIndex = max(0, min(currentIndex + direction, record.swingFrames.count - 1))
        guard updatedIndex != currentIndex else { return }

        record.keyFrames[keyFrameIndex].frameIndex = updatedIndex
        record.keyFrames[keyFrameIndex].source = .adjusted

        if selectedPhase == phase {
            scrubPosition = record.swingFrames[updatedIndex].timestamp
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

    private func timestamp(for phase: SwingPhase) -> Double {
        guard
            let keyFrame = record.keyFrames.first(where: { $0.phase == phase }),
            record.swingFrames.indices.contains(keyFrame.frameIndex)
        else {
            return 0
        }

        return record.swingFrames[keyFrame.frameIndex].timestamp
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

private struct GarageValidationSection: View {
    let status: KeyframeValidationStatus
    @Binding var selectedPhase: SwingPhase
    let keyFrames: [KeyFrame]
    let videoURL: URL?
    let timestampForPhase: (SwingPhase) -> Double
    let setStatus: (KeyframeValidationStatus) -> Void
    let stepFrame: (SwingPhase, Int) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: ModuleSpacing.small),
        GridItem(.flexible(), spacing: ModuleSpacing.small)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            DashboardLikeSectionTitle(
                title: "1. Review the 8 keyframes",
                subtitle: "Confirm the checkpoints look right before deeper analysis."
            )

            if status == .flagged {
                GarageWarningCard(
                    title: "Keyframes flagged for review",
                    message: "You can continue in V1, but review and correct any wrong checkpoints before trusting the anchor path."
                )
            }

            if let selectedKeyFrame {
                ModuleRowSurface(theme: AppModule.garage.theme) {
                    HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                        GarageFrameCanvas(
                            videoURL: videoURL,
                            timestamp: timestampForPhase(selectedKeyFrame.phase),
                            anchor: nil,
                            pathPoints: [],
                            interactive: false,
                            onPlaceAnchor: nil
                        )
                        .frame(width: 132, height: 132)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                GarageStatusPill(title: selectedKeyFrame.source.title)
                                Spacer()
                                Text(selectedKeyFrame.phase.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                            }

                            Text(selectedKeyFrame.phase.reviewTitle)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppModule.garage.theme.textPrimary)

                            Text("Frame \(selectedKeyFrame.frameIndex + 1)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppModule.garage.theme.textSecondary)

                            Text(String(format: "%.2fs", timestampForPhase(selectedKeyFrame.phase)))
                                .font(.caption)
                                .foregroundStyle(AppModule.garage.theme.textMuted)

                            HStack(spacing: 10) {
                                Button {
                                    stepFrame(selectedKeyFrame.phase, -1)
                                } label: {
                                    Label("Earlier", systemImage: "chevron.left")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(AppModule.garage.theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    stepFrame(selectedKeyFrame.phase, 1)
                                } label: {
                                    Label("Later", systemImage: "chevron.right")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(AppModule.garage.theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(KeyframeValidationStatus.allCases) { candidate in
                    Button(candidate.title) {
                        setStatus(candidate)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(status == candidate ? AppModule.garage.theme.textPrimary : AppModule.garage.theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous)
                            .fill(status == candidate ? AppModule.garage.theme.surfaceInteractive : AppModule.garage.theme.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous)
                            .stroke(status == candidate ? AppModule.garage.theme.borderStrong : AppModule.garage.theme.borderSubtle, lineWidth: 1)
                    )
                    .buttonStyle(.plain)
                }
            }

            LazyVGrid(columns: columns, spacing: ModuleSpacing.small) {
                ForEach(keyFrames) { keyFrame in
                    Button {
                        selectedPhase = keyFrame.phase
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            GarageFrameCanvas(
                                videoURL: videoURL,
                                timestamp: timestampForPhase(keyFrame.phase),
                                anchor: nil,
                                pathPoints: [],
                                interactive: false,
                                onPlaceAnchor: nil
                            )
                            .frame(height: 120)

                            Text(keyFrame.phase.reviewTitle)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppModule.garage.theme.textPrimary)
                            Text(keyFrame.phase.title)
                                .font(.caption)
                                .foregroundStyle(AppModule.garage.theme.textSecondary)
                            HStack {
                                GarageStatusPill(title: keyFrame.source.title)
                                Spacer()
                                Text("Select to adjust")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppModule.garage.theme.textMuted)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                                .fill(selectedPhase == keyFrame.phase ? AppModule.garage.theme.surfaceInteractive : AppModule.garage.theme.surfacePrimary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                                .stroke(selectedPhase == keyFrame.phase ? AppModule.garage.theme.borderStrong : AppModule.garage.theme.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var selectedKeyFrame: KeyFrame? {
        keyFrames.first(where: { $0.phase == selectedPhase })
    }
}

private struct GarageHandAnchorSection: View {
    let videoURL: URL?
    let keyFrames: [KeyFrame]
    let handAnchors: [HandAnchor]
    @Binding var selectedPhase: SwingPhase
    let timestampForPhase: (SwingPhase) -> Double
    let setAnchor: (SwingPhase, CGPoint) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: ModuleSpacing.small),
        GridItem(.flexible(), spacing: ModuleSpacing.small)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            HStack {
                DashboardLikeSectionTitle(
                    title: "2. Mark the grip midpoint",
                    subtitle: "Tap the middle of both hands where they connect on the grip in each image. Tap again anytime to replace."
                )
                Spacer()
                GarageStatusPill(title: "\(handAnchors.count)/8")
            }

            if let selectedKeyFrame {
                ModuleRowSurface(theme: AppModule.garage.theme) {
                    HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                        GarageFrameCanvas(
                            videoURL: videoURL,
                            timestamp: timestampForPhase(selectedKeyFrame.phase),
                            anchor: handAnchors.first(where: { $0.phase == selectedKeyFrame.phase }),
                            pathPoints: [],
                            interactive: true
                        ) { point in
                            setAnchor(selectedKeyFrame.phase, point)
                            selectedPhase = selectedKeyFrame.phase
                        }
                        .frame(width: 132, height: 132)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(selectedKeyFrame.phase.reviewTitle)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                                Spacer()
                                GarageStatusPill(title: anchorExists(for: selectedKeyFrame.phase) ? "Placed" : "Needed")
                            }

                            Text("Frame \(selectedKeyFrame.frameIndex + 1)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppModule.garage.theme.textSecondary)

                            Text(anchorExists(for: selectedKeyFrame.phase) ? "Tap the image to replace the saved grip midpoint." : "Tap the image to place the grip midpoint.")
                                .font(.caption)
                                .foregroundStyle(AppModule.garage.theme.textSecondary)

                            ProgressView(value: Double(handAnchors.count), total: 8)
                                .tint(AppModule.garage.theme.primary)

                            Text("\(handAnchors.count) of 8 anchors complete")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppModule.garage.theme.textMuted)
                        }
                    }
                }
            }

            LazyVGrid(columns: columns, spacing: ModuleSpacing.small) {
                ForEach(keyFrames) { keyFrame in
                    VStack(alignment: .leading, spacing: 10) {
                        GarageFrameCanvas(
                            videoURL: videoURL,
                            timestamp: timestampForPhase(keyFrame.phase),
                            anchor: handAnchors.first(where: { $0.phase == keyFrame.phase }),
                            pathPoints: [],
                            interactive: true
                        ) { point in
                            setAnchor(keyFrame.phase, point)
                            selectedPhase = keyFrame.phase
                        }
                        .frame(height: 118)

                        HStack {
                            Text(keyFrame.phase.reviewTitle)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppModule.garage.theme.textPrimary)
                            Spacer()
                            Image(systemName: handAnchors.contains(where: { $0.phase == keyFrame.phase }) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(handAnchors.contains(where: { $0.phase == keyFrame.phase }) ? AppModule.garage.theme.primary : AppModule.garage.theme.textMuted)
                        }

                        HStack {
                            GarageStatusPill(title: handAnchors.contains(where: { $0.phase == keyFrame.phase }) ? "Placed" : "Needed")
                            Spacer()
                            Text("Tap to \(handAnchors.contains(where: { $0.phase == keyFrame.phase }) ? "replace" : "place")")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppModule.garage.theme.textMuted)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                            .fill(selectedPhase == keyFrame.phase ? AppModule.garage.theme.surfaceInteractive : AppModule.garage.theme.surfacePrimary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                            .stroke(selectedPhase == keyFrame.phase ? AppModule.garage.theme.borderStrong : AppModule.garage.theme.borderSubtle, lineWidth: 1)
                    )
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
}

private struct GaragePathReviewSection: View {
    let selectedPhase: SwingPhase
    let videoURL: URL?
    let timestamp: Double
    let handAnchors: [HandAnchor]
    let pathPoints: [PathPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            DashboardLikeSectionTitle(
                title: "3. Review the hand path",
                subtitle: pathPoints.isEmpty ? "Complete all 8 grip anchors to generate the simple V1 interpolation path." : "The current path is a simple 8-point interpolation through your verified grip anchors."
            )

            ModuleRowSurface(theme: AppModule.garage.theme) {
                GarageFrameCanvas(
                    videoURL: videoURL,
                    timestamp: timestamp,
                    anchor: handAnchors.first(where: { $0.phase == selectedPhase }),
                    pathPoints: pathPoints,
                    interactive: false,
                    onPlaceAnchor: nil
                )
                .frame(height: 220)

                Text(selectedPhase.reviewTitle)
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                Text(pathPoints.isEmpty ? "Path status: pending" : "Path status: ready")
                    .font(.subheadline)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)

                if pathPoints.isEmpty {
                    Text(missingAnchorsText)
                        .font(.caption)
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                } else {
                    Text("The selected frame shows the current interpolated path alongside the saved grip anchor for that checkpoint.")
                        .font(.caption)
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                }
            }

            if pathPoints.isEmpty {
                ModuleRowSurface(theme: AppModule.garage.theme) {
                    Text("Resume Progress")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    Text("You can stop and resume later. The analyzer keeps your saved anchors and continues from the remaining checkpoints.")
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                    Text(missingAnchorsTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.primary)
                }
            } else {
                ModuleRowSurface(theme: AppModule.garage.theme) {
                    Text("Path Ready")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    Text("All 8 anchors are saved, so the V1 interpolated hand path is now ready for review.")
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                    Text("\(pathPoints.count) generated path points")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.primary)
                }
            }
        }
    }

    private var missingPhases: [SwingPhase] {
        let anchoredPhases = Set(handAnchors.map(\.phase))
        return SwingPhase.allCases.filter { anchoredPhases.contains($0) == false }
    }

    private var missingAnchorsTitle: String {
        if missingPhases.isEmpty {
            return "All anchors complete"
        }

        return "Remaining: \(missingPhases.map(\.reviewTitle).joined(separator: ", "))"
    }

    private var missingAnchorsText: String {
        if missingPhases.isEmpty {
            return "All 8 anchors are complete."
        }

        return "\(missingPhases.count) anchor\(missingPhases.count == 1 ? "" : "s") still needed: \(missingPhases.map(\.reviewTitle).joined(separator: ", "))."
    }
}

private struct GarageTechnicalPanel: View {
    let record: SwingRecord
    let report: GarageInsightReport
    let timestampForPhase: (SwingPhase) -> Double

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
                GarageFieldRow(label: "Adjusted keyframes", value: "\(record.keyFrames.filter { $0.source == .adjusted }.count)")
            }

            ModuleRowSurface(theme: AppModule.garage.theme) {
                Text("Checkpoint timing")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                ForEach(record.keyFrames) { keyFrame in
                    GarageFieldRow(
                        label: keyFrame.phase.reviewTitle,
                        value: "\(keyFrame.source.title) • Frame \(keyFrame.frameIndex + 1) • \(String(format: "%.2fs", timestampForPhase(keyFrame.phase)))"
                    )
                }
            }
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
    let videoURL: URL?
    let timestamp: Double
    let anchor: HandAnchor?
    let pathPoints: [PathPoint]
    let interactive: Bool
    let onPlaceAnchor: ((CGPoint) -> Void)?

    @State private var thumbnail: CGImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: ModuleCornerRadius.medium, style: .continuous)
                    .fill(AppModule.garage.theme.surfaceSecondary)

                if let thumbnail {
                    Image(decorative: thumbnail, scale: 1)
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
                thumbnail = nil
                return
            }

            thumbnail = await GarageMediaStore.thumbnail(for: videoURL, at: timestamp)
        }
    }

    private var thumbnailTaskKey: String {
        "\(videoURL?.absoluteString ?? "none")-\(timestamp)"
    }
}

private struct AddSwingRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedVideoURL: URL?
    @State private var isShowingImporter = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Swing Record") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }

                Section("Video Import") {
                    Button(selectedVideoURL == nil ? "Choose Swing Video" : "Replace Swing Video") {
                        isShowingImporter = true
                    }

                    if let selectedVideoURL {
                        Text(selectedVideoURL.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(AppModule.garage.theme.primary)
                    }

                    Text("Save runs the current 2D pipeline, stores 8 deterministic keyframes, and prepares the swing for validation and hand-anchor review.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isSaving {
                    Section {
                        ProgressView("Analyzing swing video…")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Swing Record")
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    selectedVideoURL = urls.first
                    errorMessage = nil
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRecord()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedVideoURL == nil || isSaving)
                }
            }
        }
    }

    private func saveRecord() {
        guard let selectedVideoURL else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else { return }

        errorMessage = nil
        isSaving = true

        Task {
            do {
                let hasAccess = selectedVideoURL.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        selectedVideoURL.stopAccessingSecurityScopedResource()
                    }
                }

                let persistedVideoURL = try GarageMediaStore.persistVideo(from: selectedVideoURL)
                let output = try await GarageAnalysisPipeline.analyzeVideo(at: persistedVideoURL)

                let record = SwingRecord(
                    title: trimmedTitle,
                    mediaFilename: persistedVideoURL.lastPathComponent,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    frameRate: output.frameRate,
                    swingFrames: output.swingFrames,
                    keyFrames: output.keyFrames,
                    analysisResult: output.analysisResult
                )

                modelContext.insert(record)
                try? modelContext.save()
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
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
