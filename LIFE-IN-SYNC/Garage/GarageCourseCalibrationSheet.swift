import SwiftData
import SwiftUI

private enum GarageCourseCalibrationStep: Int, CaseIterable, Identifiable {
    case tee
    case fairwayCheckpoint
    case greenCenter

    var id: Int { rawValue }

    var anchorKind: GarageMapAnchorKind {
        switch self {
        case .tee:
            return .tee
        case .fairwayCheckpoint:
            return .fairwayCheckpoint
        case .greenCenter:
            return .greenCenter
        }
    }

    var title: String {
        switch self {
        case .tee:
            return "Tee Anchor"
        case .fairwayCheckpoint:
            return "Checkpoint Anchor"
        case .greenCenter:
            return "Green Anchor"
        }
    }

    var detail: String {
        switch self {
        case .tee:
            return "Drop the start of the hole first."
        case .fairwayCheckpoint:
            return "Pin the center checkpoint that stabilizes the routing math."
        case .greenCenter:
            return "Finish by locking the center of the green."
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
            return teeAnchor
        case .fairwayCheckpoint:
            return fairwayCheckpointAnchor
        case .greenCenter:
            return greenCenterAnchor
        }
    }
}

struct GarageCourseCalibrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let hole: GarageHoleMap
    var onComplete: (() -> Void)?

    @State private var currentStep: GarageCourseCalibrationStep = .tee
    @State private var draft: GarageCourseCalibrationDraft
    @State private var saveErrorMessage: String?

    init(
        hole: GarageHoleMap,
        onComplete: (() -> Void)? = nil
    ) {
        self.hole = hole
        self.onComplete = onComplete
        _draft = State(initialValue: GarageCourseCalibrationDraft(hole: hole))
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
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
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

    private var stepRail: some View {
        HStack(spacing: 10) {
            ForEach(GarageCourseCalibrationStep.allCases) { step in
                let isSelected = currentStep == step
                let isComplete = draft.anchor(for: step) != nil

                Button {
                    garageTriggerImpact(.light)
                    currentStep = step
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

                Text("Tap the map once for each anchor. Garage refuses shot logging until all three are pinned.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(garageReviewMutedText)
            }

            GarageCourseCalibrationPad(
                draft: draft,
                activeStep: currentStep,
                onSelectAnchor: { anchor in
                    garageTriggerImpact(.light)
                    draft.setAnchor(anchor)
                    if let nextStep = GarageCourseCalibrationStep(rawValue: min(currentStep.rawValue + 1, GarageCourseCalibrationStep.allCases.count - 1)) {
                        currentStep = nextStep
                    }
                }
            )
            .frame(height: 360)
        }
    }

    private var footerDock: some View {
        HStack(spacing: 12) {
            Button {
                garageTriggerImpact(.light)
                if currentStep == .tee {
                    dismiss()
                } else if let previous = GarageCourseCalibrationStep(rawValue: currentStep.rawValue - 1) {
                    currentStep = previous
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
            .disabled(draft.anchor(for: currentStep) == nil && draft.isComplete == false)
            .opacity(draft.anchor(for: currentStep) == nil && draft.isComplete == false ? 0.55 : 1)
        }
    }

    private func handlePrimaryAction() {
        if draft.isComplete == false {
            if let nextStep = GarageCourseCalibrationStep(rawValue: min(currentStep.rawValue + 1, GarageCourseCalibrationStep.allCases.count - 1)) {
                currentStep = nextStep
            }
            return
        }

        persistCalibration()
    }

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
            saveErrorMessage = GarageCourseCalibrationSheet.message(for: error)
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

private struct GarageCourseCalibrationPad: View {
    let draft: GarageCourseCalibrationDraft
    let activeStep: GarageCourseCalibrationStep
    let onSelectAnchor: (GarageMapAnchor) -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                GarageInsetPanelBackground(
                    shape: RoundedRectangle(cornerRadius: 28, style: .continuous),
                    fill: garageReviewInsetSurface.opacity(0.98),
                    stroke: garageReviewStroke.opacity(0.96)
                )

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                garageReviewSurface.opacity(0.86),
                                garageReviewSurfaceDark.opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(14)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#304236").opacity(0.84),
                                Color(hex: "#1B2B24").opacity(0.94)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width * 0.34, height: height * 0.78)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                    )

                Path { path in
                    path.move(to: CGPoint(x: width * 0.5, y: height * 0.14))
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.49, y: height * 0.84),
                        control: CGPoint(x: width * 0.44, y: height * 0.48)
                    )
                }
                .stroke(
                    Color.white.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [5, 6])
                )

                VStack {
                    HStack {
                        Text("GREEN")
                            .font(.caption2.weight(.bold))
                            .tracking(1.0)
                            .foregroundStyle(garageReviewMutedText)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Text("TEE")
                            .font(.caption2.weight(.bold))
                            .tracking(1.0)
                            .foregroundStyle(garageReviewMutedText)
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)

                ForEach(anchorMarkers(width: width, height: height), id: \.kind) { marker in
                    markerView(marker)
                        .position(x: marker.point.x, y: marker.point.y)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .onTapGesture { location in
                onSelectAnchor(
                    GarageMapAnchor(
                        kind: activeStep.anchorKind,
                        normalizedX: location.x / max(width, 1),
                        normalizedY: location.y / max(height, 1)
                    )
                )
            }
        }
    }

    private func anchorMarkers(width: CGFloat, height: CGFloat) -> [GarageCourseCalibrationMarker] {
        let anchors = [draft.teeAnchor, draft.fairwayCheckpointAnchor, draft.greenCenterAnchor].compactMap { $0 }
        return anchors.map { anchor in
            GarageCourseCalibrationMarker(
                kind: anchor.kind,
                point: CGPoint(
                    x: width * anchor.normalizedX,
                    y: height * anchor.normalizedY
                ),
                isActive: anchor.kind == activeStep.anchorKind
            )
        }
    }

    @ViewBuilder
    private func markerView(_ marker: GarageCourseCalibrationMarker) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.vibeElectricCyan.opacity(marker.isActive ? 0.22 : 0.14))
                    .frame(width: marker.isActive ? 42 : 34, height: marker.isActive ? 42 : 34)

                Circle()
                    .stroke(Color.vibeElectricCyan.opacity(0.96), lineWidth: marker.isActive ? 2.4 : 1.8)
                    .frame(width: marker.isActive ? 26 : 22, height: marker.isActive ? 26 : 22)

                Circle()
                    .fill(Color.vibeElectricCyan)
                    .frame(width: 8, height: 8)
            }

            Text(marker.kind.title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(garageReviewReadableText)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(garageReviewInsetSurface.opacity(0.96))
                        .overlay(
                            Capsule()
                                .stroke(garageReviewStroke.opacity(0.92), lineWidth: 0.6)
                        )
                )
        }
        .shadow(color: Color.vibeElectricCyan.opacity(marker.isActive ? 0.24 : 0.14), radius: 12, x: 0, y: 0)
    }
}

private struct GarageCourseCalibrationMarker {
    let kind: GarageMapAnchorKind
    let point: CGPoint
    let isActive: Bool
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
