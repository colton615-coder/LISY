import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum GarageAddFlowLaunchMode {
    case standard
    case autoPresentPicker
}

private struct GarageTimelineMarker: Identifiable {
    let keyFrame: KeyFrame
    let timestamp: Double

    var id: SwingPhase { keyFrame.phase }
}

private func garageRecordSelectionKey(for record: SwingRecord) -> String {
    [
        record.createdAt.ISO8601Format(),
        record.title,
        record.preferredReviewFilename ?? "no-review-asset"
    ].joined(separator: "::")
}

struct GarageView: View {
    @Query(sort: \SwingRecord.createdAt, order: .reverse) private var swingRecords: [SwingRecord]
    @State private var isShowingAddRecord = false
    @State private var addFlowLaunchMode: GarageAddFlowLaunchMode = .standard
    @State private var selectedTab: ModuleHubTab = .overview
    @State private var selectedReviewRecordKey: String?

    var body: some View {
        ModuleHubScaffold(
            module: .garage,
            title: "Store swing work without overclaiming analysis.",
            subtitle: "Track records and review sessions with local-first consistency.",
            currentState: "\(swingRecords.count) swing records currently stored.",
            nextAttention: swingRecords.isEmpty ? "Import your first swing video to initialize Garage." : "Review recent records and tag what to repeat.",
            tabs: [.overview, .records, .review],
            selectedTab: $selectedTab
        ) {
            switch selectedTab {
            case .overview:
                GarageOverviewCard(recordCount: swingRecords.count) {
                    presentAddRecord(autoPresentPicker: true)
                }
            case .records:
                GarageRecordsTab(records: swingRecords) {
                    presentAddRecord(autoPresentPicker: true)
                }
            case .review:
                GarageReviewTab(records: swingRecords, selectedRecordKey: $selectedReviewRecordKey) {
                    presentAddRecord(autoPresentPicker: true)
                }
            default:
                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            ModuleBottomActionBar(
                theme: AppModule.garage.theme,
                title: "Add Swing Record",
                systemImage: "plus"
            ) {
                presentAddRecord()
            }
        }
        .sheet(isPresented: $isShowingAddRecord) {
            AddSwingRecordSheet(autoPresentPicker: addFlowLaunchMode == .autoPresentPicker) { record in
                selectedReviewRecordKey = garageRecordSelectionKey(for: record)
                selectedTab = .review
            }
        }
    }

    private func presentAddRecord(autoPresentPicker: Bool = false) {
        addFlowLaunchMode = autoPresentPicker ? .autoPresentPicker : .standard
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
                    Text("Video Input")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    Text("Import another swing clip from Photos, review the selected asset, then save it as a local-first swing record.")
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

private struct GarageOverviewCard: View {
    let recordCount: Int
    let importVideo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            ModuleRowSurface(theme: AppModule.garage.theme) {
                Text("Video Input")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                Text("Select a swing clip first, review the chosen asset, then add optional notes before saving the record.")
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                Button("Select Video", action: importVideo)
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.garage.theme.primary)
            }

            ModuleVisualizationContainer(title: "Review Snapshot") {
                HStack(spacing: 12) {
                    ModuleMetricChip(theme: AppModule.garage.theme, title: "Records", value: "\(recordCount)")
                    ModuleMetricChip(theme: AppModule.garage.theme, title: "Mode", value: "Review")
                }
            }
        }
    }
}

private struct SwingRecordCard: View {
    let record: SwingRecord

    private var workflowProgress: GarageWorkflowProgress {
        GarageWorkflow.progress(for: record)
    }

    private var workflowStateLabel: String {
        workflowProgress.nextAction.stage == nil ? "Ready" : workflowProgress.nextAction.actionLabel
    }

    private var assetModeLabel: String {
        record.isUsingLegacySingleAsset ? "Legacy Review Asset" : "Review Master"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.title)
                .font(.headline)

            if let mediaFilename = record.preferredReviewFilename {
                Label(mediaFilename, systemImage: "video")
                    .font(.caption)
                    .foregroundStyle(AppModule.garage.theme.primary)
            }

            if record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Text(record.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: ModuleSpacing.small) {
                Text(workflowStateLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppModule.garage.theme.chipBackground, in: Capsule())

                Text(assetModeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppModule.garage.theme.surfaceSecondary, in: Capsule())

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
    let importVideo: () -> Void

    private var selectedRecord: SwingRecord? {
        if let selectedRecordKey {
            return records.first(where: { garageRecordSelectionKey(for: $0) == selectedRecordKey }) ?? records.first
        }

        return records.first
    }

    var body: some View {
        ModuleActivityFeedSection(title: "Review Workspace") {
            if records.isEmpty {
                ModuleEmptyStateCard(
                    theme: AppModule.garage.theme,
                    title: "Review workflow is ready",
                    message: "Import a swing video to restore frame review, keyframe checkpoints, and hand-position inspection.",
                    actionTitle: "Import Swing Video",
                    action: importVideo
                )
            } else {
                VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
                    ModuleRowSurface(theme: AppModule.garage.theme) {
                        Text("Review Queue")
                            .font(.headline)
                            .foregroundStyle(AppModule.garage.theme.textPrimary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: ModuleSpacing.small) {
                                ForEach(records.prefix(12)) { record in
                                    let key = garageRecordSelectionKey(for: record)
                                    Button {
                                        selectedRecordKey = key
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(record.title)
                                                .font(.subheadline.weight(.semibold))
                                                .lineLimit(1)
                                            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(width: 180, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            key == selectedRecordKey
                                                ? AppModule.garage.theme.primary.opacity(0.16)
                                                : AppModule.garage.theme.surfaceSecondary,
                                            in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if let selectedRecord {
                        GarageReviewWorkspace(record: selectedRecord)
                    }
                }
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

private struct GarageReviewWorkspace: View {
    let record: SwingRecord

    @State private var currentTime = 0.0
    @State private var timelineZoom = 4.0
    @State private var assetMetadata: GarageVideoAssetMetadata?
    @State private var reviewImage: CGImage?
    @State private var isLoadingFrame = false

    private var reviewVideoURL: URL? {
        GarageMediaStore.resolvedReviewVideoURL(for: record)
    }

    private var exportVideoURL: URL? {
        GarageMediaStore.resolvedExportVideoURL(for: record)
    }

    private var orderedKeyframes: [GarageTimelineMarker] {
        record.keyFrames
            .sorted { lhs, rhs in
                (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
            }
            .compactMap { keyFrame in
                guard let timestamp = timestamp(for: keyFrame) else {
                    return nil
                }

                return GarageTimelineMarker(keyFrame: keyFrame, timestamp: timestamp)
            }
    }

    private var effectiveDuration: Double {
        let derivedDuration = max(record.swingFrames.map(\.timestamp).max() ?? 0, assetMetadata?.duration ?? 0)
        return max(derivedDuration, 0.1)
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

    private var currentKeyframe: GarageTimelineMarker? {
        orderedKeyframes.min { lhs, rhs in
            abs(lhs.timestamp - currentTime) < abs(rhs.timestamp - currentTime)
        }
    }

    private var currentHandAnchor: HandAnchor? {
        guard let phase = currentKeyframe?.keyFrame.phase else {
            return nil
        }

        return record.handAnchors.first(where: { $0.phase == phase })
    }

    private var leftWristPoint: CGPoint {
        currentFrame?.point(named: .leftWrist) ?? .zero
    }

    private var rightWristPoint: CGPoint {
        currentFrame?.point(named: .rightWrist) ?? .zero
    }

    private var precisionRange: ClosedRange<Double> {
        let zoomSpan = max(effectiveDuration / max(timelineZoom, 1), 0.05)
        let lowerBound = max(0, currentTime - (zoomSpan / 2))
        let upperBound = min(effectiveDuration, lowerBound + zoomSpan)
        let adjustedLower = max(0, upperBound - zoomSpan)
        return adjustedLower...upperBound
    }

    private var frameRequestID: String {
        let basis = currentFrame?.timestamp ?? currentTime
        return "\(garageRecordSelectionKey(for: record))::\(String(format: "%.4f", basis))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            ModuleRowSurface(theme: AppModule.garage.theme) {
                HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppModule.garage.theme.textPrimary)
                        Text("Review master is the default inspection asset. Export derivatives stay secondary so scrubbing and checkpoints remain stable.")
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 8) {
                        GarageReviewBadge(
                            title: record.isUsingLegacySingleAsset ? "Legacy Review Asset" : "Review Master",
                            value: record.preferredReviewFilename ?? "Missing"
                        )
                        GarageReviewBadge(
                            title: exportVideoURL == nil ? "Export Derivative" : "Export Ready",
                            value: record.preferredExportFilename ?? "Not generated"
                        )
                    }
                }
            }

            ViewThatFits {
                HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                    GarageReviewStage(
                        image: reviewImage,
                        isLoadingFrame: isLoadingFrame,
                        currentFrame: currentFrame,
                        currentPhase: currentKeyframe?.keyFrame.phase,
                        handAnchors: record.handAnchors,
                        pathPoints: record.pathPoints
                    )
                    .frame(maxWidth: .infinity)

                    GarageReviewInspector(
                        record: record,
                        currentTime: currentTime,
                        currentFrameIndex: currentFrameIndex,
                        currentPhase: currentKeyframe?.keyFrame.phase,
                        currentFrame: currentFrame,
                        currentHandAnchor: currentHandAnchor,
                        assetMetadata: assetMetadata
                    )
                    .frame(width: 320)
                }

                VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
                    GarageReviewStage(
                        image: reviewImage,
                        isLoadingFrame: isLoadingFrame,
                        currentFrame: currentFrame,
                        currentPhase: currentKeyframe?.keyFrame.phase,
                        handAnchors: record.handAnchors,
                        pathPoints: record.pathPoints
                    )

                    GarageReviewInspector(
                        record: record,
                        currentTime: currentTime,
                        currentFrameIndex: currentFrameIndex,
                        currentPhase: currentKeyframe?.keyFrame.phase,
                        currentFrame: currentFrame,
                        currentHandAnchor: currentHandAnchor,
                        assetMetadata: assetMetadata
                    )
                }
            }

            ModuleRowSurface(theme: AppModule.garage.theme) {
                HStack(spacing: ModuleSpacing.small) {
                    Button(action: { jumpKeyframe(by: -1) }) {
                        Label("Prev Keyframe", systemImage: "backward.end.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(orderedKeyframes.isEmpty)

                    Button(action: { stepFrame(by: -1) }) {
                        Label("Prev Frame", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .disabled(record.swingFrames.isEmpty)

                    Button(action: { stepFrame(by: 1) }) {
                        Label("Next Frame", systemImage: "chevron.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.garage.theme.primary)
                    .disabled(record.swingFrames.isEmpty)

                    Button(action: { jumpKeyframe(by: 1) }) {
                        Label("Next Keyframe", systemImage: "forward.end.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(orderedKeyframes.isEmpty)

                    Spacer(minLength: 0)

                    Text("Time \(formattedTimestamp(currentTime))")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: ModuleSpacing.small) {
                    Text("Full Timeline")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    GarageTimelineScrubber(
                        range: 0...effectiveDuration,
                        duration: effectiveDuration,
                        currentTime: $currentTime,
                        markers: orderedKeyframes
                    )
                    HStack {
                        Text("0:00")
                        Spacer()
                        Text(formattedTimestamp(effectiveDuration))
                    }
                    .font(.caption)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: ModuleSpacing.small) {
                    HStack {
                        Text("Precision Timeline")
                            .font(.headline)
                            .foregroundStyle(AppModule.garage.theme.textPrimary)
                        Spacer()
                        Text("\(Int(timelineZoom))x zoom")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppModule.garage.theme.primary)
                    }

                    Slider(value: $timelineZoom, in: 1...8, step: 1)
                        .tint(AppModule.garage.theme.primary)

                    GarageTimelineScrubber(
                        range: precisionRange,
                        duration: effectiveDuration,
                        currentTime: $currentTime,
                        markers: orderedKeyframes
                    )

                    HStack {
                        Text(formattedTimestamp(precisionRange.lowerBound))
                        Spacer()
                        Text(formattedTimestamp(precisionRange.upperBound))
                    }
                    .font(.caption)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                }
            }

            ModuleRowSurface(theme: AppModule.garage.theme) {
                Text("Keyframe Checkpoints")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                if orderedKeyframes.isEmpty {
                    Text("This session does not have pose-derived keyframes yet, so Garage can only show the stored review asset.")
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ModuleSpacing.small) {
                            ForEach(orderedKeyframes) { marker in
                                Button {
                                    seek(to: marker.timestamp)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(marker.keyFrame.phase.reviewTitle)
                                            .font(.subheadline.weight(.semibold))
                                        Text(formattedTimestamp(marker.timestamp))
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                        Text(marker.keyFrame.source.title)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(marker.keyFrame.source == .adjusted ? .orange : AppModule.garage.theme.primary)
                                    }
                                    .frame(width: 140, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        marker.keyFrame.phase == currentKeyframe?.keyFrame.phase
                                            ? AppModule.garage.theme.primary.opacity(0.18)
                                            : AppModule.garage.theme.surfaceSecondary,
                                        in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .task(id: garageRecordSelectionKey(for: record)) {
            await loadAssetMetadata()
            resetReviewPosition()
        }
        .task(id: frameRequestID) {
            await loadFrameImage()
        }
    }

    private func loadAssetMetadata() async {
        guard let reviewVideoURL else {
            await MainActor.run {
                assetMetadata = nil
            }
            return
        }

        let metadata = await GarageMediaStore.assetMetadata(for: reviewVideoURL)
        await MainActor.run {
            assetMetadata = metadata
        }
    }

    private func loadFrameImage() async {
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

        let requestedTime = currentFrame?.timestamp ?? currentTime
        let image = await GarageMediaStore.thumbnail(for: reviewVideoURL, at: requestedTime, maximumSize: CGSize(width: 1600, height: 1600))

        await MainActor.run {
            reviewImage = image
            isLoadingFrame = false
        }
    }

    private func resetReviewPosition() {
        if let firstTimestamp = record.swingFrames.first?.timestamp {
            currentTime = firstTimestamp
        } else {
            currentTime = 0
        }
    }

    private func seek(to requestedTime: Double) {
        currentTime = min(max(requestedTime, 0), effectiveDuration)
    }

    private func stepFrame(by offset: Int) {
        guard let currentFrameIndex else {
            let fallbackStep = record.frameRate > 0 ? (1 / record.frameRate) : (1 / 30)
            seek(to: currentTime + (Double(offset) * fallbackStep))
            return
        }

        let nextIndex = min(max(currentFrameIndex + offset, 0), max(record.swingFrames.count - 1, 0))
        guard record.swingFrames.indices.contains(nextIndex) else {
            return
        }

        seek(to: record.swingFrames[nextIndex].timestamp)
    }

    private func jumpKeyframe(by offset: Int) {
        guard orderedKeyframes.isEmpty == false else { return }

        let currentMarkerIndex = orderedKeyframes.enumerated().min { lhs, rhs in
            abs(lhs.element.timestamp - currentTime) < abs(rhs.element.timestamp - currentTime)
        }?.offset ?? 0

        let targetIndex = min(max(currentMarkerIndex + offset, 0), orderedKeyframes.count - 1)
        seek(to: orderedKeyframes[targetIndex].timestamp)
    }

    private func timestamp(for keyFrame: KeyFrame) -> Double? {
        guard record.swingFrames.indices.contains(keyFrame.frameIndex) else {
            return nil
        }

        return record.swingFrames[keyFrame.frameIndex].timestamp
    }

    private func formattedTimestamp(_ seconds: Double) -> String {
        let totalSeconds = max(Int(seconds.rounded(.down)), 0)
        let minutes = totalSeconds / 60
        let remainder = totalSeconds % 60
        let centiseconds = Int(((seconds - floor(seconds)) * 100).rounded())
        return String(format: "%d:%02d.%02d", minutes, remainder, centiseconds)
    }
}

private struct GarageReviewStage: View {
    let image: CGImage?
    let isLoadingFrame: Bool
    let currentFrame: SwingFrame?
    let currentPhase: SwingPhase?
    let handAnchors: [HandAnchor]
    let pathPoints: [PathPoint]

    var body: some View {
        ModuleRowSurface(theme: AppModule.garage.theme) {
            HStack {
                Text("Review Stage")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                Spacer()
                if let currentPhase {
                    Text(currentPhase.reviewTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppModule.garage.theme.chipBackground, in: Capsule())
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .fill(AppModule.garage.theme.surfaceSecondary)

                if let image {
                    GarageReviewImageOverlay(
                        image: image,
                        currentFrame: currentFrame,
                        currentPhase: currentPhase,
                        handAnchors: handAnchors,
                        pathPoints: pathPoints
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
                } else {
                    VStack(spacing: ModuleSpacing.small) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppModule.garage.theme.textMuted)
                        Text("Review master unavailable")
                            .font(.headline)
                            .foregroundStyle(AppModule.garage.theme.textPrimary)
                        Text("Garage needs the persisted review asset to render the frame inspection surface.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                    .padding()
                }

                if isLoadingFrame {
                    VStack(spacing: ModuleSpacing.small) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(AppModule.garage.theme.primary)
                        Text("Loading review frame")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppModule.garage.theme.textPrimary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
                }
            }
            .frame(minHeight: 380)
            .overlay(
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
            )
        }
    }
}

private struct GarageReviewImageOverlay: View {
    let image: CGImage
    let currentFrame: SwingFrame?
    let currentPhase: SwingPhase?
    let handAnchors: [HandAnchor]
    let pathPoints: [PathPoint]

    var body: some View {
        GeometryReader { proxy in
            let containerRect = CGRect(origin: .zero, size: proxy.size)
            let imageRect = aspectFitRect(
                imageSize: CGSize(width: image.width, height: image.height),
                in: containerRect
            )

            ZStack {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                Canvas { context, _ in
                    guard imageRect.isEmpty == false else {
                        return
                    }

                    if pathPoints.count >= 2 {
                        var path = Path()
                        let firstPoint = mappedPoint(
                            x: pathPoints[0].x,
                            y: pathPoints[0].y,
                            in: imageRect
                        )
                        path.move(to: firstPoint)

                        for point in pathPoints.dropFirst() {
                            path.addLine(to: mappedPoint(x: point.x, y: point.y, in: imageRect))
                        }

                        context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 3)
                    }

                    for anchor in handAnchors {
                        let point = mappedPoint(x: anchor.x, y: anchor.y, in: imageRect)
                        let isCurrent = anchor.phase == currentPhase
                        let rect = CGRect(x: point.x - (isCurrent ? 7 : 5), y: point.y - (isCurrent ? 7 : 5), width: isCurrent ? 14 : 10, height: isCurrent ? 14 : 10)
                        context.fill(Ellipse().path(in: rect), with: .color(isCurrent ? .orange : .yellow))
                    }

                    guard let currentFrame else {
                        return
                    }

                    let leftShoulder = mappedPoint(point: currentFrame.point(named: .leftShoulder), in: imageRect)
                    let rightShoulder = mappedPoint(point: currentFrame.point(named: .rightShoulder), in: imageRect)
                    let leftHip = mappedPoint(point: currentFrame.point(named: .leftHip), in: imageRect)
                    let rightHip = mappedPoint(point: currentFrame.point(named: .rightHip), in: imageRect)
                    let leftWrist = mappedPoint(point: currentFrame.point(named: .leftWrist), in: imageRect)
                    let rightWrist = mappedPoint(point: currentFrame.point(named: .rightWrist), in: imageRect)

                    var upperBody = Path()
                    upperBody.move(to: leftShoulder)
                    upperBody.addLine(to: rightShoulder)
                    upperBody.move(to: leftHip)
                    upperBody.addLine(to: rightHip)
                    upperBody.move(to: leftWrist)
                    upperBody.addLine(to: rightWrist)

                    context.stroke(upperBody, with: .color(.cyan.opacity(0.9)), lineWidth: 3)

                    for wrist in [leftWrist, rightWrist] {
                        let rect = CGRect(x: wrist.x - 6, y: wrist.y - 6, width: 12, height: 12)
                        context.fill(Ellipse().path(in: rect), with: .color(.cyan))
                    }
                }
            }
        }
    }

    private func aspectFitRect(imageSize: CGSize, in container: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, container.width > 0, container.height > 0 else {
            return .zero
        }

        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: container.midX - (scaledSize.width / 2),
            y: container.midY - (scaledSize.height / 2)
        )
        return CGRect(origin: origin, size: scaledSize)
    }

    private func mappedPoint(point: CGPoint, in rect: CGRect) -> CGPoint {
        mappedPoint(x: point.x, y: point.y, in: rect)
    }

    private func mappedPoint(x: Double, y: Double, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + (rect.width * x),
            y: rect.minY + (rect.height * y)
        )
    }
}

private struct GarageReviewInspector: View {
    let record: SwingRecord
    let currentTime: Double
    let currentFrameIndex: Int?
    let currentPhase: SwingPhase?
    let currentFrame: SwingFrame?
    let currentHandAnchor: HandAnchor?
    let assetMetadata: GarageVideoAssetMetadata?

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            ModuleRowSurface(theme: AppModule.garage.theme) {
                Text("Review Signals")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                HStack(spacing: ModuleSpacing.small) {
                    ModuleMetricChip(
                        theme: AppModule.garage.theme,
                        title: "Frames",
                        value: currentFrameIndex.map { "\($0 + 1)/\(max(record.swingFrames.count, 1))" } ?? "n/a"
                    )
                    ModuleMetricChip(
                        theme: AppModule.garage.theme,
                        title: "Keyframes",
                        value: "\(record.keyFrames.count)"
                    )
                    ModuleMetricChip(
                        theme: AppModule.garage.theme,
                        title: "Anchors",
                        value: "\(record.handAnchors.count)"
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    GarageInspectorLine(label: "Current time", value: formattedTimestamp(currentTime))
                    GarageInspectorLine(label: "Current phase", value: currentPhase?.reviewTitle ?? "Free scrub")
                    GarageInspectorLine(label: "Master FPS", value: formattedFrameRate(assetMetadata?.frameRate ?? record.frameRate))
                    if let size = assetMetadata?.naturalSize {
                        GarageInspectorLine(label: "Canvas", value: "\(Int(size.width)) x \(Int(size.height))")
                    }
                }
            }

            ModuleRowSurface(theme: AppModule.garage.theme) {
                Text("Hand Position Review")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                if let currentFrame {
                    GarageInspectorLine(label: "Left wrist", value: formattedPoint(currentFrame.point(named: .leftWrist)))
                    GarageInspectorLine(label: "Right wrist", value: formattedPoint(currentFrame.point(named: .rightWrist)))
                    GarageInspectorLine(label: "Hand center", value: formattedPoint(GarageAnalysisPipeline.handCenter(in: currentFrame)))
                } else {
                    Text("No pose frame is available for the current timestamp.")
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                GarageInspectorLine(
                    label: "Current anchor",
                    value: currentHandAnchor.map { formattedAnchor($0) } ?? "Not aligned to a saved checkpoint"
                )
            }

            ModuleRowSurface(theme: AppModule.garage.theme) {
                Text("Checkpoint Coverage")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(SwingPhase.allCases) { phase in
                        let anchor = record.handAnchors.first(where: { $0.phase == phase })
                        HStack {
                            Text(phase.reviewTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(phase == currentPhase ? AppModule.garage.theme.primary : AppModule.garage.theme.textPrimary)
                            Spacer()
                            Text(anchor == nil ? "Missing" : "Saved")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(anchor == nil ? .secondary : AppModule.garage.theme.primary)
                        }
                    }
                }
            }

            if record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || record.analysisResult != nil {
                ModuleRowSurface(theme: AppModule.garage.theme) {
                    Text("Notes")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    if record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        Text(record.notes)
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }

                    if let analysisResult = record.analysisResult {
                        Text(analysisResult.summary)
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                }
            }
        }
    }

    private func formattedTimestamp(_ seconds: Double) -> String {
        let totalSeconds = max(Int(seconds.rounded(.down)), 0)
        let minutes = totalSeconds / 60
        let remainder = totalSeconds % 60
        let centiseconds = Int(((seconds - floor(seconds)) * 100).rounded())
        return String(format: "%d:%02d.%02d", minutes, remainder, centiseconds)
    }

    private func formattedPoint(_ point: CGPoint) -> String {
        String(format: "(%.3f, %.3f)", point.x, point.y)
    }

    private func formattedAnchor(_ anchor: HandAnchor) -> String {
        "\(anchor.phase.reviewTitle) \(formattedPoint(CGPoint(x: anchor.x, y: anchor.y)))"
    }

    private func formattedFrameRate(_ value: Double) -> String {
        guard value > 0 else { return "Unknown" }
        return String(format: "%.1f", value)
    }
}

private struct GarageTimelineScrubber: View {
    let range: ClosedRange<Double>
    let duration: Double
    @Binding var currentTime: Double
    let markers: [GarageTimelineMarker]

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(proxy.size.width, 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppModule.garage.theme.surfaceSecondary)
                Capsule()
                    .fill(AppModule.garage.theme.primary.opacity(0.2))
                    .frame(width: indicatorX(in: trackWidth))

                ForEach(markers) { marker in
                    if range.contains(marker.timestamp) {
                        Capsule()
                            .fill(marker.keyFrame.source == .adjusted ? Color.orange : AppModule.garage.theme.primary)
                            .frame(width: 4, height: 22)
                            .offset(x: max(0, markerX(for: marker.timestamp, in: trackWidth) - 2))
                    }
                }

                Circle()
                    .fill(AppModule.garage.theme.primary)
                    .frame(width: 18, height: 18)
                    .offset(x: max(0, indicatorX(in: trackWidth) - 9))
            }
            .frame(height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = min(max(value.location.x / trackWidth, 0), 1)
                        let span = range.upperBound - range.lowerBound
                        currentTime = range.lowerBound + (span * progress)
                    }
            )
        }
        .frame(height: 28)
    }

    private func markerX(for timestamp: Double, in width: CGFloat) -> CGFloat {
        let span = max(range.upperBound - range.lowerBound, 0.0001)
        let progress = (timestamp - range.lowerBound) / span
        return width * min(max(progress, 0), 1)
    }

    private func indicatorX(in width: CGFloat) -> CGFloat {
        markerX(for: currentTime, in: width)
    }
}

private struct GarageReviewBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textMuted)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppModule.garage.theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct GarageInspectorLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
            Spacer()
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct GarageEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.garage.theme,
            title: "No swing records yet",
            message: "Select a swing video from Photos to begin tracking progress with a local-first record.",
            actionTitle: "Select First Video",
            action: action
        )
    }
}

private struct AddSwingRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let autoPresentPicker: Bool
    let onSaved: (SwingRecord) -> Void

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var selectedVideoURL: URL?
    @State private var selectedVideoFilename = ""
    @State private var isShowingVideoPicker = false
    @State private var isPreparingSelection = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Video") {
                    if let selectedVideoURL {
                        GarageSelectedVideoPreview(
                            videoURL: selectedVideoURL,
                            filename: selectedVideoFilename,
                            replaceVideo: { isShowingVideoPicker = true },
                            removeVideo: removeSelectedVideo
                        )

                        LabeledContent("Media filename") {
                            Text(selectedVideoFilename)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
                            Text("Select a swing video first")
                                .font(.headline)
                            Text("Choose a clip from Photos to unlock Save. You can add a title and notes after the asset is attached.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Select Video") {
                                isShowingVideoPicker = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppModule.garage.theme.primary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Details") {
                    TextField("Title (optional)", text: $title)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle("New Swing Record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveRecord()
                    }
                    .disabled(selectedVideoURL == nil || isPreparingSelection || isSaving)
                }
            }
            .photosPicker(
                isPresented: $isShowingVideoPicker,
                selection: $selectedVideoItem,
                matching: .videos,
                preferredItemEncoding: .current
            )
            .onChange(of: selectedVideoItem) { _, newItem in
                guard let newItem else { return }
                prepareSelectedVideo(newItem)
            }
            .task {
                guard autoPresentPicker, selectedVideoURL == nil, isShowingVideoPicker == false else { return }
                isShowingVideoPicker = true
            }
            .overlay {
                if isPreparingSelection || isSaving {
                    GarageAddRecordProgressOverlay(isSaving: isSaving)
                }
            }
            .alert(
                "Garage Video Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in
                        if isPresented == false {
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @MainActor
    private func prepareSelectedVideo(_ item: PhotosPickerItem) {
        isPreparingSelection = true
        errorMessage = nil

        Task {
            do {
                guard let movie = try await item.loadTransferable(type: GaragePickedMovie.self) else {
                    throw GarageImportError.unableToLoadSelection
                }

                await MainActor.run {
                    selectedVideoURL = movie.url
                    selectedVideoFilename = movie.displayName
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        title = suggestedTitle(for: movie.displayName)
                    }
                    isPreparingSelection = false
                }
            } catch {
                await MainActor.run {
                    selectedVideoItem = nil
                    selectedVideoURL = nil
                    selectedVideoFilename = ""
                    isPreparingSelection = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func removeSelectedVideo() {
        selectedVideoItem = nil
        selectedVideoURL = nil
        selectedVideoFilename = ""
    }

    private func saveRecord() {
        guard let selectedVideoURL else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let reviewMasterURL = try GarageMediaStore.persistReviewMaster(from: selectedVideoURL)
                async let analysisTask = GarageAnalysisPipeline.analyzeVideo(at: reviewMasterURL)
                async let exportTask = GarageMediaStore.createExportDerivative(from: reviewMasterURL)

                let output = try await analysisTask
                let exportURL = await exportTask
                let resolvedTitle = resolvedRecordTitle(fallbackURL: reviewMasterURL)
                let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

                let record = SwingRecord(
                    title: resolvedTitle,
                    mediaFilename: reviewMasterURL.lastPathComponent,
                    reviewMasterFilename: reviewMasterURL.lastPathComponent,
                    exportAssetFilename: exportURL?.lastPathComponent,
                    notes: trimmedNotes,
                    frameRate: output.frameRate,
                    swingFrames: output.swingFrames,
                    keyFrames: output.keyFrames,
                    handAnchors: output.handAnchors,
                    pathPoints: output.pathPoints,
                    analysisResult: output.analysisResult
                )

                await MainActor.run {
                    modelContext.insert(record)
                    try? modelContext.save()
                    isSaving = false
                    onSaved(record)
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

    private func resolvedRecordTitle(fallbackURL: URL) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty == false {
            return trimmedTitle
        }

        let preferredName = selectedVideoFilename.isEmpty ? fallbackURL.lastPathComponent : selectedVideoFilename
        return suggestedTitle(for: preferredName)
    }

    private func suggestedTitle(for filename: String) -> String {
        let stem = URL(filePath: filename).deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if stem.isEmpty == false {
            return stem
        }

        return "Swing \(Date.now.formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct GarageSelectedVideoPreview: View {
    let videoURL: URL
    let filename: String
    let replaceVideo: () -> Void
    let removeVideo: () -> Void

    @State private var previewImage: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .fill(AppModule.garage.theme.surfaceSecondary)

                if let previewImage {
                    Image(decorative: previewImage, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
                } else {
                    VStack(spacing: ModuleSpacing.small) {
                        Image(systemName: "video")
                            .font(.title2)
                            .foregroundStyle(AppModule.garage.theme.textMuted)
                        Text("Preparing preview")
                            .font(.caption)
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
            )

            Label(filename, systemImage: "video.fill")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: ModuleSpacing.small) {
                Button("Replace", action: replaceVideo)
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.garage.theme.primary)
                Button("Remove", role: .destructive, action: removeVideo)
                    .buttonStyle(.bordered)
            }
        }
        .task(id: videoURL) {
            previewImage = await GarageMediaStore.thumbnail(for: videoURL, at: 0)
        }
    }
}

private struct GarageAddRecordProgressOverlay: View {
    let isSaving: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            ModuleRowSurface(theme: AppModule.garage.theme) {
                HStack(alignment: .center, spacing: ModuleSpacing.medium) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppModule.garage.theme.primary)

                    VStack(alignment: .leading, spacing: ModuleSpacing.xSmall) {
                        Text(isSaving ? "Saving Swing Record" : "Loading Selected Video")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppModule.garage.theme.textPrimary)
                        Text(
                            isSaving
                                ? "Persisting the review master, generating a lightweight export derivative, and preparing review signals."
                                : "Pulling the selected asset into Garage so you can review it before saving."
                        )
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, ModuleSpacing.large)
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
