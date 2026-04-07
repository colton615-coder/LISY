import AVFoundation
import AVKit
import Combine
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
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

private struct GarageHandPathSample: Identifiable {
    let id: Int
    let timestamp: Double
    let x: Double
    let y: Double
    let speed: Double

    private static var nextGeneratedID: Int = 0

    private static func generateID() -> Int {
        let id = nextGeneratedID
        nextGeneratedID += 1
        return id
    }

    init(
        timestamp: Double,
        x: Double,
        y: Double,
        speed: Double,
        id: Int? = nil
    ) {
        self.id = id ?? Self.generateID()
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.speed = speed
    }
}

private extension KeyframeValidationStatus {
    var reviewTint: Color {
        switch self {
        case .pending:
            AppModule.garage.theme.primary
        case .approved:
            .green
        case .flagged:
            .red
        }
    }

    var reviewBackground: Color {
        switch self {
        case .pending:
            AppModule.garage.theme.chipBackground
        case .approved:
            Color.green.opacity(0.12)
        case .flagged:
            Color.red.opacity(0.12)
        }
    }
}

private func garageRecordSelectionKey(for record: SwingRecord) -> String {
    [
        record.createdAt.ISO8601Format(),
        record.title,
        record.preferredReviewFilename ?? "no-review-asset"
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
    @State private var addFlowLaunchMode: GarageAddFlowLaunchMode = .standard
    @State private var selectedTab: ModuleHubTab = .overview
    @State private var selectedReviewRecordKey: String?

    var body: some View {
        ModuleHubScaffold(
            module: .garage,
            title: "Store swing work without overclaiming analysis.",
            subtitle: "Review swing checkpoints with a calmer, accuracy-first workflow.",
            currentState: "\(swingRecords.count) swing records currently stored.",
            nextAttention: swingRecords.isEmpty ? "Import your first swing video to begin review." : "Use Review to validate checkpoints and refine the current swing.",
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

private struct GarageOverviewCard: View {
    let recordCount: Int
    let importVideo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            ModuleRowSurface(theme: AppModule.garage.theme) {
                Text("Swing Capture")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                Text("Choose a swing video, save it locally, then move directly into checkpoint review.")
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                Button("Select Video", action: importVideo)
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.garage.theme.primary)
            }

            ModuleVisualizationContainer(title: "Garage") {
                HStack(spacing: 12) {
                    ModuleMetricChip(theme: AppModule.garage.theme, title: "Records", value: "\(recordCount)")
                    ModuleMetricChip(theme: AppModule.garage.theme, title: "Mode", value: "Review")
                }
            }
        }
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
    @State private var isShowingDetails = false

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

                        Button("Details") {
                            isShowingDetails = true
                        }
                        .buttonStyle(.bordered)
                    }

                    GarageFocusedReviewWorkspace(record: selectedRecord)
                }
                .sheet(isPresented: $isShowingDetails) {
                    GarageReviewDetailsSheet(record: selectedRecord)
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

    private var reviewVideoURL: URL? {
        GarageMediaStore.resolvedReviewVideoURL(for: record)
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
        "\(garageRecordSelectionKey(for: record))::\(String(format: "%.4f", currentTime))"
    }

    private var fullHandPathSamples: [GarageHandPathSample] {
        garageHandPathSamples(from: record.swingFrames)
    }

    var body: some View {
        ModuleRowSurface(theme: AppModule.garage.theme) {
            GarageFocusedReviewFrame(
                image: reviewImage,
                isLoadingFrame: isLoadingFrame,
                currentFrame: currentFrame,
                selectedAnchor: selectedAnchor,
                highlightedStatus: selectedCheckpointStatus
            )

            VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedPhase.reviewTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppModule.garage.theme.textPrimary)

                        HStack(spacing: 8) {
                            GarageCheckpointStatusBadge(status: selectedCheckpointStatus)

                            if selectedKeyFrame?.source == .adjusted {
                                Label("Manual import", systemImage: "hand.draw")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    GarageCheckpointProgressSummary(record: record)
                }

                GarageCheckpointProgressStrip(
                    selectedPhase: selectedPhase,
                    markers: orderedKeyframes,
                    statusProvider: { record.reviewStatus(for: $0) }
                ) { phase in
                    selectedPhase = phase
                    seekToSelectedCheckpoint()
                }

                GarageTimelineScrubber(
                    range: 0...effectiveDuration,
                    currentTime: $currentTime,
                    markers: orderedKeyframes,
                    selectedPhase: selectedPhase,
                    statusProvider: { record.reviewStatus(for: $0) }
                )

                GarageReviewToolRail(
                    selectedStatus: selectedCheckpointStatus,
                    importIsManual: selectedKeyFrame?.source == .adjusted,
                    canImportCurrentFrame: currentFrameIndex != nil,
                    canMoveBetweenCheckpoints: orderedKeyframes.isEmpty == false,
                    onPrevious: previousCheckpoint,
                    onImportCurrentFrame: importCurrentFrame,
                    onApprove: approveCheckpoint,
                    onFlag: flagCheckpoint,
                    onNext: nextCheckpoint
                )

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
        moveCheckpointSelection(by: -1)
    }

    private func nextCheckpoint() {
        moveCheckpointSelection(by: 1)
    }

    private func moveCheckpointSelection(by offset: Int) {
        guard orderedKeyframes.isEmpty == false else { return }
        let currentIndex = orderedKeyframes.firstIndex(where: { $0.keyFrame.phase == selectedPhase }) ?? 0
        let targetIndex = min(max(currentIndex + offset, 0), orderedKeyframes.count - 1)
        selectedPhase = orderedKeyframes[targetIndex].keyFrame.phase
        seekToSelectedCheckpoint()
    }

    private func approveCheckpoint() {
        guard let keyframeIndex = record.keyFrames.firstIndex(where: { $0.phase == selectedPhase }) else { return }
        record.keyFrames[keyframeIndex].reviewStatus = .approved
        record.refreshKeyframeValidationStatus()
        try? modelContext.save()
        autoPresentCompletionPlaybackIfNeeded()
    }

    private func flagCheckpoint() {
        guard let keyframeIndex = record.keyFrames.firstIndex(where: { $0.phase == selectedPhase }) else { return }
        record.keyFrames[keyframeIndex].reviewStatus = .flagged
        record.refreshKeyframeValidationStatus()
        try? modelContext.save()
        didAutoPresentCompletionPlayback = false
    }

    private func importCurrentFrame() {
        guard let currentFrameIndex else { return }

        if let keyframeIndex = record.keyFrames.firstIndex(where: { $0.phase == selectedPhase }) {
            record.keyFrames[keyframeIndex].frameIndex = currentFrameIndex
            record.keyFrames[keyframeIndex].source = .adjusted
            record.keyFrames[keyframeIndex].reviewStatus = .pending
        } else {
            record.keyFrames.append(
                KeyFrame(phase: selectedPhase, frameIndex: currentFrameIndex, source: .adjusted, reviewStatus: .pending)
            )
        }

        record.keyFrames.sort { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }
        record.handAnchors = GarageAnalysisPipeline.deriveHandAnchors(from: record.swingFrames, keyFrames: record.keyFrames)
        record.pathPoints = GarageAnalysisPipeline.generatePathPoints(from: record.swingFrames, samplesPerSegment: 16)
        record.refreshKeyframeValidationStatus()
        try? modelContext.save()
        didAutoPresentCompletionPlayback = false
        seekToSelectedCheckpoint()
    }

    private func autoPresentCompletionPlaybackIfNeeded() {
        guard record.allCheckpointsApproved, didAutoPresentCompletionPlayback == false else { return }
        didAutoPresentCompletionPlayback = true
        isShowingCompletionPlayback = true
    }
}

private struct GarageFocusedReviewFrame: View {
    let image: CGImage?
    let isLoadingFrame: Bool
    let currentFrame: SwingFrame?
    let selectedAnchor: HandAnchor?
    let highlightedStatus: KeyframeValidationStatus

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                .fill(AppModule.garage.theme.surfaceSecondary)

            if let image {
                GarageReviewImageOverlay(
                    image: image,
                    currentFrame: currentFrame,
                    selectedAnchor: selectedAnchor,
                    highlightedStatus: highlightedStatus
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
                    Text("Garage needs the stored review video to render this checkpoint.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }
                .padding()
            }

            if isLoadingFrame {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppModule.garage.theme.primary)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
            }
        }
        .frame(minHeight: 420)
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
        )
    }
}

private struct GarageReviewImageOverlay: View {
    let image: CGImage
    let currentFrame: SwingFrame?
    let selectedAnchor: HandAnchor?
    let highlightedStatus: KeyframeValidationStatus

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

                    if let selectedAnchor {
                        let anchorPoint = mappedPoint(x: selectedAnchor.x, y: selectedAnchor.y, in: imageRect)
                        let anchorRect = CGRect(x: anchorPoint.x - 8, y: anchorPoint.y - 8, width: 16, height: 16)
                        context.fill(Ellipse().path(in: anchorRect), with: .color(highlightedStatus.reviewTint))
                    }

                    guard let currentFrame else {
                        return
                    }

                    let leftWrist = mappedPoint(point: currentFrame.point(named: .leftWrist), in: imageRect)
                    let rightWrist = mappedPoint(point: currentFrame.point(named: .rightWrist), in: imageRect)
                    let handCenter = CGPoint(x: (leftWrist.x + rightWrist.x) / 2, y: (leftWrist.y + rightWrist.y) / 2)

                    var wristLine = Path()
                    wristLine.move(to: leftWrist)
                    wristLine.addLine(to: rightWrist)
                    context.stroke(wristLine, with: .color(.cyan.opacity(0.95)), lineWidth: 3)

                    for point in [leftWrist, rightWrist, handCenter] {
                        let rect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
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
                    Button {
                        onSelect(phase)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(status.reviewTint)
                                .frame(width: 8, height: 8)

                            Text(shortTitle(for: phase))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppModule.garage.theme.textPrimary)

                            if marker?.keyFrame.source == .adjusted {
                                Image(systemName: "hand.draw")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedPhase == phase
                                ? AppModule.garage.theme.primary.opacity(0.14)
                                : AppModule.garage.theme.surfaceSecondary,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedPhase == phase ? AppModule.garage.theme.primary : status.reviewTint.opacity(status == .pending ? 0.2 : 0.45), lineWidth: selectedPhase == phase ? 2 : 1)
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
    let statusProvider: (SwingPhase) -> KeyframeValidationStatus

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(proxy.size.width, 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppModule.garage.theme.surfaceSecondary)

                Capsule()
                    .fill(AppModule.garage.theme.primary.opacity(0.18))
                    .frame(width: indicatorX(in: trackWidth))

                ForEach(markers) { marker in
                    if range.contains(marker.timestamp) {
                        let markerStatus = statusProvider(marker.keyFrame.phase)
                        Circle()
                            .fill(marker.keyFrame.phase == selectedPhase ? markerStatus.reviewTint : Color.white)
                            .frame(width: marker.keyFrame.phase == selectedPhase ? 12 : 8, height: marker.keyFrame.phase == selectedPhase ? 12 : 8)
                            .overlay(
                                Circle()
                                    .stroke(marker.keyFrame.source == .adjusted ? Color.orange : markerStatus.reviewTint, lineWidth: 1.5)
                            )
                            .offset(x: max(0, markerX(for: marker.timestamp, in: trackWidth) - (marker.keyFrame.phase == selectedPhase ? 6 : 4)))
                    }
                }

                Circle()
                    .fill(AppModule.garage.theme.primary)
                    .frame(width: 18, height: 18)
                    .offset(x: max(0, indicatorX(in: trackWidth) - 9))
            }
            .frame(height: 32)
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
        .frame(height: 32)
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

private struct GarageCheckpointStatusBadge: View {
    let status: KeyframeValidationStatus

    var body: some View {
        Label(status.title, systemImage: iconName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.reviewTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.reviewBackground, in: Capsule())
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
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            HStack(spacing: 6) {
                summaryPill(title: "Approved", value: record.approvedCheckpointCount, tint: .green)
                summaryPill(title: "Flagged", value: record.flaggedCheckpointCount, tint: .red)
                summaryPill(title: "Pending", value: record.pendingCheckpointCount, tint: AppModule.garage.theme.primary)
            }
        }
    }

    private func summaryPill(title: String, value: Int, tint: Color) -> some View {
        Text("\(title) \(value)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct GarageReviewToolRail: View {
    let selectedStatus: KeyframeValidationStatus
    let importIsManual: Bool
    let canImportCurrentFrame: Bool
    let canMoveBetweenCheckpoints: Bool
    let onPrevious: () -> Void
    let onImportCurrentFrame: () -> Void
    let onApprove: () -> Void
    let onFlag: () -> Void
    let onNext: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                toolButton(title: "Previous", systemImage: "chevron.left", tint: AppModule.garage.theme.textSecondary, filled: false, disabled: canMoveBetweenCheckpoints == false, action: onPrevious)
                toolButton(title: importIsManual ? "Reimport Frame" : "Import Frame", systemImage: "hand.draw", tint: .orange, filled: importIsManual, disabled: canImportCurrentFrame == false, action: onImportCurrentFrame)
                toolButton(title: "Approve", systemImage: "checkmark.circle.fill", tint: .green, filled: selectedStatus == .approved, disabled: false, action: onApprove)
                toolButton(title: "Flag", systemImage: "flag.fill", tint: .red, filled: selectedStatus == .flagged, disabled: false, action: onFlag)
                toolButton(title: "Next", systemImage: "chevron.right", tint: AppModule.garage.theme.textSecondary, filled: false, disabled: canMoveBetweenCheckpoints == false, action: onNext)
            }
            .padding(.vertical, 2)
        }
    }

    private func toolButton(
        title: String,
        systemImage: String,
        tint: Color,
        filled: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(filled ? Color.white : tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(filled ? tint : tint.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(filled ? 0 : 0.28), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
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
            .foregroundStyle(status.reviewTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.reviewBackground, in: Capsule())
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
                        with: .color(AppModule.garage.theme.primary.opacity(0.45 + (normalizedSpeed * 0.45))),
                        style: StrokeStyle(lineWidth: baseWidth, lineCap: .round, lineJoin: .round)
                    )
                }

                if let lastSample = visibleSamples.last {
                    let point = mappedPoint(x: lastSample.x, y: lastSample.y, in: videoRect)
                    let outerRect = CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)
                    let innerRect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                    context.fill(Ellipse().path(in: outerRect), with: .color(Color.white))
                    context.fill(Ellipse().path(in: innerRect), with: .color(AppModule.garage.theme.primary))
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

private struct GarageReviewDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let record: SwingRecord

    var body: some View {
        NavigationStack {
            List {
                Section("Session") {
                    LabeledContent("Title", value: record.title)
                    LabeledContent("Recorded", value: record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Status", value: record.keyframeValidationStatus.title)
                    LabeledContent("Approved", value: "\(record.approvedCheckpointCount)")
                    LabeledContent("Flagged", value: "\(record.flaggedCheckpointCount)")
                    LabeledContent("Pending", value: "\(record.pendingCheckpointCount)")
                }

                if record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    Section("Notes") {
                        Text(record.notes)
                    }
                }

                Section("Stored Assets") {
                    if let reviewFilename = record.preferredReviewFilename {
                        LabeledContent("Review Video", value: reviewFilename)
                    }
                    if let exportFilename = record.preferredExportFilename {
                        LabeledContent("Export Video", value: exportFilename)
                    }
                }
            }
            .navigationTitle("Swing Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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
            ScrollView {
                VStack(alignment: .leading, spacing: ModuleSpacing.large) {
                    ModuleRowSurface(theme: AppModule.garage.theme) {
                        if let selectedVideoURL {
                            GarageSelectedVideoPreview(
                                videoURL: selectedVideoURL,
                                filename: selectedVideoFilename,
                                replaceVideo: { isShowingVideoPicker = true },
                                removeVideo: removeSelectedVideo
                            )
                        } else {
                            VStack(alignment: .leading, spacing: ModuleSpacing.small) {
                                Text("Select a swing video")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                                Text("Start by choosing one clip. Garage will save it locally, then take you straight into review.")
                                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                                Button("Choose Video") {
                                    isShowingVideoPicker = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppModule.garage.theme.primary)
                            }
                        }
                    }

                    ModuleRowSurface(theme: AppModule.garage.theme) {
                        Text("Save Details")
                            .font(.headline)
                            .foregroundStyle(AppModule.garage.theme.textPrimary)

                        TextField("Title (optional)", text: $title)
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                    }
                }
                .padding(.horizontal, ModuleSpacing.large)
                .padding(.vertical, ModuleSpacing.medium)
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
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppModule.garage.theme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
            )

            Text(filename)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .lineLimit(1)

            HStack(spacing: ModuleSpacing.small) {
                Button("Choose Different Video", action: replaceVideo)
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
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            ModuleRowSurface(theme: AppModule.garage.theme) {
                HStack(alignment: .center, spacing: ModuleSpacing.medium) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppModule.garage.theme.primary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isSaving ? "Importing swing" : "Loading preview")
                            .font(.headline)
                            .foregroundStyle(AppModule.garage.theme.textPrimary)
                        Text("Please hold for a moment.")
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
