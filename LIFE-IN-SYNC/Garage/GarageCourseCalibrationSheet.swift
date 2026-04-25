import SwiftData
import SwiftUI
import UIKit

private enum GarageCourseCalibrationStep: Int, CaseIterable, Identifiable {
    case tee
    case fairwayCheckpoint
    case greenCenter

    var id: Int { rawValue }

    var anchorKind: GarageMapAnchorKind {
        switch self {
        case .tee:
            .tee
        case .fairwayCheckpoint:
            .fairwayCheckpoint
        case .greenCenter:
            .greenCenter
        }
    }

    var title: String {
        switch self {
        case .tee:
            "Tee Anchor"
        case .fairwayCheckpoint:
            "Checkpoint Anchor"
        case .greenCenter:
            "Green Anchor"
        }
    }

    var detail: String {
        switch self {
        case .tee:
            "Pin where the hole begins. This becomes the starting tactical anchor."
        case .fairwayCheckpoint:
            "Drop the midpoint reference that stabilizes the routing math."
        case .greenCenter:
            "Finish with the center of the green so Garage can trust shot placement."
        }
    }

    var statusTitle: String {
        switch self {
        case .tee:
            "Start"
        case .fairwayCheckpoint:
            "Mid"
        case .greenCenter:
            "Finish"
        }
    }
}

private struct GarageCourseCalibrationDraft {
    var teeAnchor: GarageMapAnchor?
    var fairwayCheckpointAnchor: GarageMapAnchor?
    var greenCenterAnchor: GarageMapAnchor?

    init(hole: GarageHoleMap) {
        teeAnchor = hole.teeAnchor
        fairwayCheckpointAnchor = hole.fairwayCheckpointAnchor
        greenCenterAnchor = hole.greenCenterAnchor
    }

    var isComplete: Bool {
        teeAnchor != nil && fairwayCheckpointAnchor != nil && greenCenterAnchor != nil
    }

    mutating func setAnchor(_ anchor: GarageMapAnchor) {
        switch anchor.kind {
        case .tee:
            teeAnchor = anchor
        case .fairwayCheckpoint:
            fairwayCheckpointAnchor = anchor
        case .greenCenter:
            greenCenterAnchor = anchor
        }
    }

    func anchor(for step: GarageCourseCalibrationStep) -> GarageMapAnchor? {
        switch step {
        case .tee:
            teeAnchor
        case .fairwayCheckpoint:
            fairwayCheckpointAnchor
        case .greenCenter:
            greenCenterAnchor
        }
    }

    func anchor(for kind: GarageMapAnchorKind) -> GarageMapAnchor? {
        switch kind {
        case .tee:
            teeAnchor
        case .fairwayCheckpoint:
            fairwayCheckpointAnchor
        case .greenCenter:
            greenCenterAnchor
        }
    }
}

struct GarageCourseCalibrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let hole: GarageHoleMap
    var onComplete: (() -> Void)?

    @StateObject private var overlayModel = GarageCourseMapOverlayModel()
    @State private var currentStep: GarageCourseCalibrationStep = .tee
    @State private var draft: GarageCourseCalibrationDraft
    @State private var saveErrorMessage: String?
    @State private var canvasImage: UIImage?

    init(
        hole: GarageHoleMap,
        onComplete: (() -> Void)? = nil
    ) {
        self.hole = hole
        self.onComplete = onComplete
        _draft = State(initialValue: GarageCourseCalibrationDraft(hole: hole))
        _canvasImage = State(initialValue: garageLoadCourseMapImage(at: hole.localAssetPath))
    }

    private var canvasAspectRatio: CGFloat {
        let safeHeight = max(hole.imagePixelHeight, 1)
        return max(CGFloat(hole.imagePixelWidth / safeHeight), 0.62)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                garageReviewBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard
                        stepRail
                        calibrationCanvas
                        footerDock
                    }
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draft.teeAnchor)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draft.fairwayCheckpointAnchor)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draft.greenCenterAnchor)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ANCHOR SETUP")
                        .font(.caption.weight(.bold))
                        .tracking(1.3)
                        .foregroundStyle(Color.vibeElectricCyan)

                    Text("Hole \(hole.holeNumber) • \(hole.holeName)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)

                    Text(currentStep.detail)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(garageReviewMutedText)
                }

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(garageReviewReadableText.opacity(0.92))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(garageReviewInsetSurface)
                                .overlay(
                                    Circle()
                                        .stroke(garageReviewStroke, lineWidth: 0.6)
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                ForEach(GarageCourseCalibrationStep.allCases) { step in
                    calibrationStatusPill(step: step)
                }
            }

            if let saveErrorMessage {
                Text(saveErrorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewFlagged)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        GarageInsetPanelBackground(
                            shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                            fill: garageReviewInsetSurface.opacity(0.96),
                            stroke: garageReviewFlagged.opacity(0.18)
                        )
                    )
            }
        }
        .padding(18)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
                fill: garageReviewSurfaceRaised,
                stroke: garageReviewStroke.opacity(0.92)
            )
        )
    }

    private func calibrationStatusPill(step: GarageCourseCalibrationStep) -> some View {
        let isActive = currentStep == step
        let isComplete = draft.anchor(for: step) != nil

        return HStack(spacing: 6) {
            Circle()
                .fill(isComplete ? Color.vibeElectricCyan : garageReviewMutedText.opacity(isActive ? 0.6 : 0.28))
                .frame(width: 7, height: 7)

            Text(step.statusTitle.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.9)
        }
        .foregroundStyle(isActive ? garageReviewReadableText : garageReviewMutedText)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(isActive ? Color.vibeElectricCyan.opacity(0.12) : garageReviewInsetSurface.opacity(0.94))
                .overlay(
                    Capsule()
                        .stroke(
                            isActive ? Color.vibeElectricCyan.opacity(0.28) : garageReviewStroke.opacity(0.92),
                            lineWidth: 0.6
                        )
                )
        )
    }

    private var stepRail: some View {
        HStack(spacing: 10) {
            ForEach(GarageCourseCalibrationStep.allCases) { step in
                let isSelected = currentStep == step
                let isComplete = draft.anchor(for: step) != nil

                Button {
                    garageTriggerImpact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentStep = step
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("0\(step.rawValue + 1)")
                            .font(.caption2.weight(.bold))
                            .tracking(1.0)
                            .foregroundStyle(isSelected ? Color.vibeElectricCyan : garageReviewMutedText)

                        Text(step.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? garageReviewReadableText : garageReviewMutedText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Capsule()
                            .fill(isSelected || isComplete ? Color.vibeElectricCyan : garageReviewStroke)
                            .frame(height: 3)
                            .shadow(color: isSelected ? Color.vibeElectricCyan.opacity(0.24) : .clear, radius: 8, x: 0, y: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        isSelected
                        ? AnyView(
                            GarageRaisedPanelBackground(
                                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                fill: garageReviewSurfaceRaised,
                                stroke: Color.vibeElectricCyan.opacity(0.28),
                                glow: Color.vibeElectricCyan.opacity(0.44)
                            )
                        )
                        : AnyView(
                            GarageInsetPanelBackground(
                                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                fill: garageReviewInsetSurface.opacity(0.96),
                                stroke: garageReviewStroke.opacity(0.94)
                            )
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var calibrationCanvas: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Calibration Surface")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)

                Text("Tap to drop the active anchor. Drag any placed handle to refine it. Garage keeps shot entry locked until all three anchors are saved.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(garageReviewMutedText)
            }

            GarageCourseCalibrationCanvas(
                overlayModel: overlayModel,
                hole: hole,
                image: canvasImage,
                draft: draft,
                activeStep: currentStep,
                aspectRatio: canvasAspectRatio,
                placeAnchor: placeAnchor,
                updateAnchor: updateAnchor,
                finalizeAnchor: finalizeAnchor,
                endAnchorInteraction: endAnchorInteraction
            )
            .frame(height: 430)
        }
    }

    private var footerDock: some View {
        HStack(spacing: 12) {
            Button {
                garageTriggerImpact(.light)
                if currentStep == .tee {
                    dismiss()
                } else if let previous = GarageCourseCalibrationStep(rawValue: currentStep.rawValue - 1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentStep = previous
                    }
                }
            } label: {
                Text(currentStep == .tee ? "Cancel" : "Back")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        GarageInsetPanelBackground(
                            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                            fill: garageReviewInsetSurface.opacity(0.96),
                            stroke: garageReviewStroke.opacity(0.94)
                        )
                    )
            }
            .buttonStyle(.plain)

            Button {
                garageTriggerImpact(.medium)
                handlePrimaryAction()
            } label: {
                Text(draft.isComplete ? "Save Anchors" : "Continue")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(garageReviewCanvasFill)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        GarageRaisedPanelBackground(
                            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                            fill: Color.vibeElectricCyan,
                            stroke: Color.vibeElectricCyan.opacity(0.34),
                            glow: Color.vibeElectricCyan
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(primaryButtonDisabled)
            .opacity(primaryButtonDisabled ? 0.55 : 1)
        }
    }

    private var primaryButtonDisabled: Bool {
        draft.isComplete == false && draft.anchor(for: currentStep) == nil
    }

    @MainActor
    private func handlePrimaryAction() {
        saveErrorMessage = nil

        if draft.isComplete == false {
            guard draft.anchor(for: currentStep) != nil else {
                saveErrorMessage = "Drop the \(currentStep.title.lowercased()) before continuing."
                return
            }

            if let nextStep = nextIncompleteStep(after: currentStep) ?? GarageCourseCalibrationStep(rawValue: currentStep.rawValue + 1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentStep = nextStep
                }
            }
            return
        }

        persistCalibration()
    }

    private func nextIncompleteStep(after step: GarageCourseCalibrationStep) -> GarageCourseCalibrationStep? {
        let ordered = GarageCourseCalibrationStep.allCases
        if let nextUnfinished = ordered.dropFirst(step.rawValue + 1).first(where: { draft.anchor(for: $0) == nil }) {
            return nextUnfinished
        }
        return ordered.first(where: { draft.anchor(for: $0) == nil })
    }

    @MainActor
    private func placeAnchor(_ anchor: GarageMapAnchor) {
        garageTriggerImpact(.light)
        saveErrorMessage = nil
        draft.setAnchor(anchor)
    }

    @MainActor
    private func updateAnchor(_ anchor: GarageMapAnchor) {
        saveErrorMessage = nil
        draft.setAnchor(anchor)
    }

    @MainActor
    private func finalizeAnchor(_ anchor: GarageMapAnchor) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            draft.setAnchor(anchor)
        }
        saveErrorMessage = nil
        _ = overlayModel.endAnchorDrag()
    }

    @MainActor
    private func endAnchorInteraction() {
        _ = overlayModel.endAnchorDrag()
    }

    @MainActor
    private func persistCalibration() {
        guard
            let teeAnchor = draft.teeAnchor,
            let fairwayCheckpointAnchor = draft.fairwayCheckpointAnchor,
            let greenCenterAnchor = draft.greenCenterAnchor
        else {
            saveErrorMessage = "All three anchors must be pinned before Garage unlocks shot entry."
            return
        }

        saveErrorMessage = nil

        do {
            try teeAnchor.validate(fieldName: "Tee anchor")
            try fairwayCheckpointAnchor.validate(fieldName: "Fairway checkpoint")
            try greenCenterAnchor.validate(fieldName: "Green center")

            hole.teeAnchor = teeAnchor
            hole.fairwayCheckpointAnchor = fairwayCheckpointAnchor
            hole.greenCenterAnchor = greenCenterAnchor
            hole.updatedAt = .now

            try hole.validateForShotLogging()
            try modelContext.save()

            onComplete?()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        let nsError = error as NSError
        if let localizedError = error as? LocalizedError, let errorDescription = localizedError.errorDescription {
            if let recoverySuggestion = localizedError.recoverySuggestion {
                return "\(errorDescription) \(recoverySuggestion)"
            }
            return errorDescription
        }

        return "Garage could not save these anchors yet. \(nsError.localizedDescription)"
    }
}

private struct GarageCourseCalibrationCanvas: View {
    @ObservedObject var overlayModel: GarageCourseMapOverlayModel
    let hole: GarageHoleMap
    let image: UIImage?
    let draft: GarageCourseCalibrationDraft
    let activeStep: GarageCourseCalibrationStep
    let aspectRatio: CGFloat
    let placeAnchor: (GarageMapAnchor) -> Void
    let updateAnchor: (GarageMapAnchor) -> Void
    let finalizeAnchor: (GarageMapAnchor) -> Void
    let endAnchorInteraction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let rect = garageAspectFitRect(container: proxy.size, aspectRatio: aspectRatio)
            let descriptors = overlayModel.calibrationAnchorDescriptors(
                teeAnchor: draft.teeAnchor,
                fairwayCheckpointAnchor: draft.fairwayCheckpointAnchor,
                greenCenterAnchor: draft.greenCenterAnchor,
                activeKind: activeStep.anchorKind,
                in: rect
            )

            ZStack {
                GarageInsetPanelBackground(
                    shape: RoundedRectangle(cornerRadius: 28, style: .continuous),
                    fill: garageReviewInsetSurface.opacity(0.98),
                    stroke: garageReviewStroke.opacity(0.96)
                )

                GarageCourseCalibrationSurface(image: image, hole: hole)
                    .frame(width: rect.width, height: rect.height)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                    )
                    .position(x: rect.midX, y: rect.midY)

                GarageCourseCalibrationGuidePath(descriptors: descriptors)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                ForEach(descriptors) { descriptor in
                    if let point = descriptor.point {
                        GarageCourseCalibrationHandle(
                            descriptor: descriptor,
                            point: point
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if overlayModel.activeDragTarget == nil, let anchor = descriptor.anchor {
                                        overlayModel.beginAnchorDrag(anchor)
                                    }
                                    if let updatedAnchor = overlayModel.updateAnchorDrag(
                                        translation: value.translation,
                                        kind: descriptor.kind,
                                        in: rect
                                    ) {
                                        updateAnchor(updatedAnchor)
                                    }
                                }
                                .onEnded { value in
                                    if overlayModel.activeDragTarget == nil, let anchor = descriptor.anchor {
                                        overlayModel.beginAnchorDrag(anchor)
                                    }
                                    if let updatedAnchor = overlayModel.updateAnchorDrag(
                                        translation: value.translation,
                                        kind: descriptor.kind,
                                        in: rect
                                    ) {
                                        finalizeAnchor(updatedAnchor)
                                    } else {
                                        endAnchorInteraction()
                                    }
                                }
                        )
                    }
                }

                VStack {
                    Spacer()

                    HStack(spacing: 8) {
                        ForEach(descriptors) { descriptor in
                            calibrationLegendPill(descriptor)
                        }
                    }
                    .padding(.bottom, 18)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard rect.contains(value.location) else { return }
                        let anchor = overlayModel.placeAnchor(
                            kind: activeStep.anchorKind,
                            at: value.location,
                            in: rect
                        )
                        placeAnchor(anchor)
                    }
            )
        }
    }

    private func calibrationLegendPill(_ descriptor: GarageCourseCalibrationAnchorDescriptor) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(descriptor.isPlaced ? Color.vibeElectricCyan : garageReviewMutedText.opacity(0.28))
                .frame(width: 7, height: 7)

            Text(descriptor.title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.8)
        }
        .foregroundStyle(descriptor.isActive ? garageReviewReadableText : garageReviewMutedText)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(descriptor.isActive ? garageReviewSurfaceDark.opacity(0.96) : garageReviewInsetSurface.opacity(0.94))
                .overlay(
                    Capsule()
                        .stroke(
                            descriptor.isActive ? Color.vibeElectricCyan.opacity(0.24) : garageReviewStroke.opacity(0.92),
                            lineWidth: 0.6
                        )
                )
        )
    }
}

private struct GarageCourseCalibrationSurface: View {
    let image: UIImage?
    let hole: GarageHoleMap

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [
                        Color(hex: "#13221A"),
                        Color(hex: "#0D1813"),
                        Color(hex: "#09100D")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#2B4C39").opacity(0.92),
                                Color(hex: "#183022").opacity(0.98)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 58)
                    .padding(.vertical, 36)
                    .rotationEffect(.degrees(-6))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
                            .padding(.horizontal, 58)
                            .padding(.vertical, 36)
                            .rotationEffect(.degrees(-6))
                    )
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.1),
                    .clear,
                    Color.black.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .background(garageReviewSurfaceDark)
    }
}

private struct GarageCourseCalibrationGuidePath: View {
    let descriptors: [GarageCourseCalibrationAnchorDescriptor]

    var body: some View {
        Canvas { context, size in
            let points = descriptors.compactMap(\.point)
            guard points.count > 1 else { return }

            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            context.stroke(
                path,
                with: .color(Color.vibeElectricCyan.opacity(0.28)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 7])
            )
        }
    }
}

private struct GarageCourseCalibrationHandle: View {
    let descriptor: GarageCourseCalibrationAnchorDescriptor
    let point: CGPoint

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.vibeElectricCyan.opacity(descriptor.isActive ? 0.2 : 0.1))
                    .frame(width: descriptor.isActive ? 52 : 42, height: descriptor.isActive ? 52 : 42)

                Circle()
                    .stroke(
                        descriptor.isActive ? Color.vibeElectricCyan.opacity(0.96) : Color.white.opacity(0.58),
                        lineWidth: descriptor.isActive ? 2.6 : 1.8
                    )
                    .frame(width: descriptor.isActive ? 34 : 28, height: descriptor.isActive ? 34 : 28)

                Circle()
                    .fill(descriptor.isActive ? Color.vibeElectricCyan : Color.white.opacity(0.88))
                    .frame(width: 9, height: 9)
            }

            Text(descriptor.title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(garageReviewReadableText)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(garageReviewSurfaceDark.opacity(0.94))
                        .overlay(
                            Capsule()
                                .stroke(
                                    descriptor.isActive ? Color.vibeElectricCyan.opacity(0.24) : garageReviewStroke.opacity(0.92),
                                    lineWidth: 0.6
                                )
                        )
                )
        }
        .position(point)
        .shadow(color: Color.vibeElectricCyan.opacity(descriptor.isActive ? 0.3 : 0.14), radius: 14, x: 0, y: 0)
    }
}

#Preview {
    let session = GarageRoundSession(
        sessionTitle: "Evening Debrief",
        courseName: "North Ridge Links"
    )
    let hole = GarageHoleMap(
        holeNumber: 14,
        holeName: "Cliffside Splitter",
        par: 4,
        yardageLabel: "434",
        sourceType: .assistedWebImport,
        sourceReference: "https://example.com",
        localAssetPath: nil,
        imagePixelWidth: 1668,
        imagePixelHeight: 2388,
        session: session
    )

    PreviewScreenContainer {
        GarageCourseCalibrationSheet(hole: hole)
    }
    .modelContainer(PreviewCatalog.emptyApp)
}
