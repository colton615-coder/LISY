import SwiftData
import SwiftUI
import UIKit

private let garageCourseMapSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)

private enum GarageCourseMapMode: Equatable {
    case review
    case shotEntry
    case calibration
}

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
            "Mid Anchor"
        case .greenCenter:
            "Green Anchor"
        }
    }

    var detail: String {
        switch self {
        case .tee:
            "Pin where the hole begins."
        case .fairwayCheckpoint:
            "Drop the mid anchor through the fairway corridor."
        case .greenCenter:
            "Finish at the center of the green."
        }
    }

    var statusTitle: String {
        switch self {
        case .tee:
            "Tee"
        case .fairwayCheckpoint:
            "Mid"
        case .greenCenter:
            "Green"
        }
    }
}

private struct GarageCourseCalibrationDraft: Equatable {
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
}

private struct GarageCourseShotDraft {
    var placement: GarageShotPlacement
    var club: GarageTacticalClub?
    var lieBeforeShot: GarageTacticalLie?
    var actualResult: GarageTacticalResult?

    init(hole: GarageHoleMap, selectedShot: GarageTacticalShot? = nil) {
        if let selectedShot {
            placement = selectedShot.placement
            club = selectedShot.club
            lieBeforeShot = selectedShot.lieBeforeShot
            actualResult = selectedShot.actualResult
            return
        }

        if let priorShot = hole.lastShot {
            placement = priorShot.placement
        } else if let checkpoint = hole.fairwayCheckpointAnchor {
            placement = GarageShotPlacement(
                normalizedX: checkpoint.normalizedX,
                normalizedY: checkpoint.normalizedY
            )
        } else if let green = hole.greenCenterAnchor {
            placement = GarageShotPlacement(
                normalizedX: green.normalizedX,
                normalizedY: green.normalizedY
            )
        } else {
            placement = GarageShotPlacement(normalizedX: 0.5, normalizedY: 0.7)
        }

        club = nil
        lieBeforeShot = hole.totalShots == 0 ? .tee : nil
        actualResult = nil
    }

    var canSave: Bool {
        club != nil && lieBeforeShot != nil && actualResult != nil
    }
}

struct GarageCourseMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var model: GarageCourseMappingModel
    @StateObject private var overlayModel = GarageCourseMapOverlayModel()
    @State private var blockerAlert: GarageCourseMapAlert?
    @State private var activeSession: GarageRoundSession?
    @State private var activeHole: GarageHoleMap?
    @State private var mapMode: GarageCourseMapMode = .review
    @State private var reviewModeEnabled = false
    @State private var canvasImage: UIImage?
    @State private var draft: GarageCourseShotDraft?
    @State private var editingShotID: UUID?
    @State private var calibrationDraft: GarageCourseCalibrationDraft?
    @State private var currentCalibrationStep: GarageCourseCalibrationStep = .tee
    @State private var calibrationSaveErrorMessage: String?
    @State private var saveErrorMessage: String?
    @State private var hasPresentedInitialCalibration = false

    private let bottomInset: CGFloat
    private let onExit: (() -> Void)?

    @MainActor
    init(
        bottomInset: CGFloat = 84,
        onExit: (() -> Void)? = nil
    ) {
        _model = StateObject(wrappedValue: .preview)
        self.bottomInset = bottomInset
        self.onExit = onExit
    }

    init(
        model: GarageCourseMappingModel,
        bottomInset: CGFloat = 84,
        onExit: (() -> Void)? = nil
    ) {
        _model = StateObject(wrappedValue: model)
        self.bottomInset = bottomInset
        self.onExit = onExit
    }

    private var overlayDescriptors: [GarageCourseShotOverlayDescriptor] {
        guard let activeHole else { return [] }
        return GarageCourseMapOverlayRenderer.descriptors(for: activeHole)
    }

    private var selectedDescriptor: GarageCourseShotOverlayDescriptor? {
        guard let selectedShotID = overlayModel.selectedShotID else { return nil }
        return overlayDescriptors.first(where: { $0.id == selectedShotID })
    }

    private var canvasAspectRatio: CGFloat {
        let width = activeHole?.imagePixelWidth ?? model.metadata.assetDescriptor?.imagePixelWidth ?? 1668
        let height = activeHole?.imagePixelHeight ?? model.metadata.assetDescriptor?.imagePixelHeight ?? 2388
        let safeHeight = max(height, 1)
        return max(CGFloat(width / safeHeight), 0.62)
    }

    private var windLabel: String? {
        let trimmed = model.metadata.dominantWind.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var activeDraftReadout: GarageCourseMapPrecisionReadout? {
        if let activeShotPlacement = overlayModel.activeShotPlacement {
            return overlayModel.precisionReadout(for: activeShotPlacement)
        }
        return overlayModel.precisionReadout(for: draft?.placement)
    }

    private var activeCalibrationReadout: GarageCourseMapPrecisionReadout? {
        overlayModel.activeAnchorReadout ?? overlayModel.precisionReadout(
            for: calibrationDraft?.anchor(for: currentCalibrationStep)
        )
    }

    var body: some View {
        ZStack {
            courseCanvas

            LinearGradient(
                colors: [
                    Color.black.opacity(0.34),
                    Color.black.opacity(0.12),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .background(garageReviewBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .animation(garageCourseMapSpring, value: mapMode)
        .animation(garageCourseMapSpring, value: reviewModeEnabled)
        .animation(garageCourseMapSpring, value: overlayModel.selectedShotID)
        .animation(garageCourseMapSpring, value: overlayModel.activeShotPlacement)
        .animation(garageCourseMapSpring, value: overlayModel.activeAnchor)
        .animation(garageCourseMapSpring, value: overlayModel.isInteracting)
        .animation(garageCourseMapSpring, value: currentCalibrationStep)
        .animation(garageCourseMapSpring, value: calibrationDraft)
        .animation(garageCourseMapSpring, value: draft?.placement)
        .safeAreaInset(edge: .top, spacing: 0) {
            topStrip
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomDock
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, max(bottomInset - 24, 12))
        }
        .alert(item: $blockerAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .task {
            refreshResolvedState(presentCalibrationIfNeeded: true)
        }
    }

    @ViewBuilder
    private var topStrip: some View {
        if mapMode == .calibration {
            calibrationTopStrip
        } else {
            normalTopStrip
        }
    }

    private var normalTopStrip: some View {
        HStack(spacing: 12) {
            Button {
                garageTriggerImpact(.light)
                if let onExit {
                    onExit()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(garageReviewReadableText)
                    .frame(width: 44, height: 44)
                    .background(garageMaterialSurface(Circle()))
            }
            .buttonStyle(.plain)
            .contentShape(Circle())

            HStack(spacing: 14) {
                GarageCourseTopMetric(
                    label: "Hole",
                    value: activeHole.map { "\($0.holeNumber)" } ?? model.metadata.holeLabel.replacingOccurrences(of: "Hole ", with: "")
                )
                GarageCourseTopMetric(label: "Par", value: "\(activeHole?.par ?? model.metadata.par)")
                GarageCourseTopMetric(
                    label: "Yds",
                    value: activeHole?.yardageLabel.isEmpty == false ? (activeHole?.yardageLabel ?? "") : model.metadata.yardageLabel
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                garageMaterialSurface(
                    RoundedRectangle(cornerRadius: 20, style: .continuous),
                    material: .regularMaterial
                )
            )

            Spacer(minLength: 0)

            if let windLabel {
                HStack(spacing: 6) {
                    Image(systemName: "wind")
                        .font(.caption.weight(.semibold))
                    Text(windLabel)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(garageReviewMutedText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(garageMaterialSurface(Capsule()))
            }
        }
    }

    private var calibrationTopStrip: some View {
        HStack(spacing: 12) {
            Button {
                garageTriggerImpact(.light)
                exitCalibration()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(garageReviewReadableText)
                    .frame(width: 44, height: 44)
                    .background(garageMaterialSurface(Circle()))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text("ANCHOR SETUP")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.vibeElectricCyan)

                Text(currentCalibrationStep.detail)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                garageMaterialSurface(
                    RoundedRectangle(cornerRadius: 20, style: .continuous),
                    material: .regularMaterial
                )
            )

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(GarageCourseCalibrationStep.allCases) { step in
                    calibrationStatusPill(step)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(garageMaterialSurface(Capsule()))
        }
    }

    private var courseCanvas: some View {
        GeometryReader { proxy in
            let imageRect = garageAspectFitRect(container: proxy.size, aspectRatio: canvasAspectRatio)

            ZStack {
                Color.black.opacity(0.96)
                    .ignoresSafeArea()

                GarageCourseCanvasSurface(
                    image: canvasImage,
                    hole: activeHole,
                    metadata: model.metadata,
                    imageRect: imageRect
                )

                GarageCourseCanvasOverlays(
                    overlayModel: overlayModel,
                    hole: activeHole,
                    rect: imageRect,
                    descriptors: overlayDescriptors,
                    selectedDescriptor: selectedDescriptor,
                    reviewModeEnabled: reviewModeEnabled,
                    activeDraftDescriptor: activeDraftOverlayDescriptor(in: activeHole),
                    activeDraftShotID: editingShotID,
                    isEditingPlacement: mapMode == .shotEntry,
                    mapMode: mapMode,
                    calibrationDraft: calibrationDraft,
                    activeCalibrationStep: currentCalibrationStep,
                    updateDraftPlacement: updateDraftPlacement,
                    finalizeDraftPlacement: finalizeDraftPlacement,
                    clearDraftInteraction: clearDraftInteraction,
                    updateCalibrationAnchor: updateCalibrationAnchor,
                    finalizeCalibrationAnchor: finalizeCalibrationAnchor,
                    endCalibrationInteraction: endCalibrationInteraction
                ) { descriptor in
                    garageTriggerImpact(.light)
                    withAnimation(garageCourseMapSpring) {
                        overlayModel.selectShot(descriptor.id)
                    }
                    saveErrorMessage = nil
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleCanvasTap(value.location, in: imageRect)
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        handleCanvasDragChanged(value, in: imageRect)
                    }
                    .onEnded { value in
                        handleCanvasDragEnded(value, in: imageRect)
                    }
            )
        }
        .ignoresSafeArea()
    }

    private var bottomDock: some View {
        VStack(spacing: 10) {
            if let saveErrorMessage, mapMode == .shotEntry {
                errorStrip(message: saveErrorMessage)
            }

            switch mapMode {
            case .review:
                reviewDock
            case .shotEntry:
                shotEntryDock
            case .calibration:
                calibrationDock
            }
        }
    }

    private var reviewDock: some View {
        GarageDockSurface {
            if let selectedDescriptor {
                selectedShotSummary(descriptor: selectedDescriptor)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("COURSE MAP")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.vibeElectricCyan)

                    Text("Tap a pin to inspect the saved shot, or add a new landing point directly on the map.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(garageReviewMutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GarageDockWideButton(
                title: "Add Shot",
                systemImage: "plus.circle.fill",
                isPrimary: true,
                isEnabled: true
            ) {
                handleAddShotTap()
            }

            if selectedDescriptor != nil {
                GarageDockWideButton(
                    title: "Edit Selected Shot",
                    systemImage: "slider.horizontal.3",
                    isPrimary: false,
                    isEnabled: true
                ) {
                    startEditingSelectedShot()
                }
            }

            HStack(spacing: 10) {
                reviewModeToggleButton
                anchorModeButton
            }
        }
    }

    private var shotEntryDock: some View {
        GarageDockSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(editingShotID == nil ? "TACTICAL ENTRY" : "EDIT SHOT")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.vibeElectricCyan)

                        Text("Tap or drag the pin above, then confirm the club, lie, and result.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(garageReviewMutedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    if let activeDraftReadout {
                        GarageCoursePrecisionReadoutStrip(
                            title: editingShotID == nil ? "Landing" : "Edited Shot",
                            readout: activeDraftReadout
                        )
                        .frame(maxWidth: 196)
                    }
                }

                if let draftBinding = draftBinding {
                    selectionRail(
                        title: "Club",
                        items: GarageTacticalClub.allCases,
                        selection: draftBinding.club
                    )

                    selectionRail(
                        title: "Lie",
                        items: GarageTacticalLie.allCases,
                        selection: draftBinding.lieBeforeShot
                    )

                    selectionRail(
                        title: "Result",
                        items: GarageTacticalResult.allCases,
                        selection: draftBinding.actualResult
                    )
                }

                HStack(spacing: 12) {
                    dockActionButton(
                        title: "Cancel",
                        isPrimary: false,
                        isEnabled: true,
                        action: cancelShotEntry
                    )

                    dockActionButton(
                        title: editingShotID == nil ? "Confirm Shot" : "Update Shot",
                        isPrimary: true,
                        isEnabled: draft?.canSave == true,
                        action: persistDraft
                    )
                }
            }
        }
    }

    private var calibrationDock: some View {
        GarageDockSurface {
            VStack(alignment: .leading, spacing: 14) {
                if let calibrationSaveErrorMessage {
                    errorStrip(message: calibrationSaveErrorMessage)
                }

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ANCHOR CALIBRATION")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.vibeElectricCyan)

                        Text("Tap the map to place the active anchor. Drag any handle to refine it.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(garageReviewMutedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    if let activeCalibrationReadout {
                        GarageCoursePrecisionReadoutStrip(
                            title: currentCalibrationStep.anchorKind.title,
                            readout: activeCalibrationReadout
                        )
                        .frame(maxWidth: 196)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(GarageCourseCalibrationStep.allCases) { step in
                        Button {
                            garageTriggerImpact(.light)
                            withAnimation(garageCourseMapSpring) {
                                currentCalibrationStep = step
                            }
                        } label: {
                            calibrationStepPill(step)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    dockActionButton(
                        title: currentCalibrationStep == .tee ? "Cancel" : "Back",
                        isPrimary: false,
                        isEnabled: true,
                        action: handleCalibrationBack
                    )

                    dockActionButton(
                        title: calibrationDraft?.isComplete == true ? "Confirm Anchors" : "Continue",
                        isPrimary: true,
                        isEnabled: primaryCalibrationButtonEnabled,
                        action: handleCalibrationPrimary
                    )
                }
            }
        }
    }

    private func selectedShotSummary(descriptor: GarageCourseShotOverlayDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(descriptor.sequenceIndex)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(garageReviewReadableText)

                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(descriptor.subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(garageReviewMutedText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                reviewTag(descriptor.detailLine)

                if let shot = activeHole?.shots.first(where: { $0.id == descriptor.id }) {
                    reviewTag(shot.lieBeforeShot.title)
                    reviewTag(shot.actualResult.title)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func reviewTag(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(garageReviewMutedText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(garageReviewSurface.opacity(0.88))
                    .overlay(
                        Capsule()
                            .stroke(garageReviewStroke.opacity(0.9), lineWidth: 0.6)
                    )
            )
    }

    private var reviewModeToggleButton: some View {
        Button {
            garageTriggerImpact(.light)
            reviewModeEnabled.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: reviewModeEnabled ? "waveform.path.ecg.rectangle.fill" : "waveform.path.ecg.rectangle")
                    .font(.caption.weight(.semibold))
                Text(reviewModeEnabled ? "Pattern On" : "Pattern")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(reviewModeEnabled ? garageReviewReadableText : garageReviewMutedText)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                garageMaterialSurface(
                    RoundedRectangle(cornerRadius: 18, style: .continuous),
                    material: reviewModeEnabled ? .regularMaterial : .ultraThinMaterial,
                    stroke: reviewModeEnabled ? Color.vibeElectricCyan.opacity(0.22) : garageReviewStroke.opacity(0.92)
                )
            )
        }
        .buttonStyle(.plain)
    }

    private var anchorModeButton: some View {
        Button {
            garageTriggerImpact(.light)
            if let activeHole {
                enterCalibration(for: activeHole)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.caption.weight(.semibold))
                Text("Anchors")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(garageReviewMutedText)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                garageMaterialSurface(
                    RoundedRectangle(cornerRadius: 18, style: .continuous),
                    material: .ultraThinMaterial,
                    stroke: garageReviewStroke.opacity(0.92)
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(activeHole == nil)
        .opacity(activeHole == nil ? 0.55 : 1)
    }

    private func errorStrip(message: String) -> some View {
        Text(message)
            .font(.caption.weight(.semibold))
            .foregroundStyle(garageReviewFlagged)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                garageMaterialSurface(
                    RoundedRectangle(cornerRadius: 18, style: .continuous),
                    material: .ultraThinMaterial,
                    stroke: garageReviewFlagged.opacity(0.22)
                )
            )
    }

    private func dockActionButton(
        title: String,
        isPrimary: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard isEnabled else { return }
            garageTriggerImpact(isPrimary ? .medium : .light)
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isPrimary ? garageReviewCanvasFill : garageReviewReadableText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    Group {
                        if isPrimary {
                            GarageRaisedPanelBackground(
                                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                fill: garageReviewAccent.opacity(isEnabled ? 1 : 0.34),
                                stroke: garageReviewAccent.opacity(isEnabled ? 0.34 : 0.18),
                                glow: isEnabled ? garageReviewAccent : nil
                            )
                        } else {
                            GarageInsetPanelBackground(
                                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                fill: garageReviewSurfaceDark.opacity(0.88),
                                stroke: garageReviewStroke.opacity(0.94)
                            )
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
        .opacity(isEnabled ? 1 : 0.55)
    }

    private func selectionRail<Item: CaseIterable & Identifiable & Hashable>(
        title: String,
        items: Item.AllCases,
        selection: Binding<Item?>
    ) -> some View where Item: GarageCourseMapSelectable {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(garageReviewMutedText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(items), id: \.id) { item in
                        let isSelected = selection.wrappedValue == item

                        Button {
                            garageTriggerImpact(.light)
                            selection.wrappedValue = item
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: item.symbolName)
                                    .font(.caption.weight(.semibold))
                                Text(item.title)
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(isSelected ? garageReviewReadableText : garageReviewMutedText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.vibeElectricCyan.opacity(0.14) : garageReviewSurface.opacity(0.9))
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                isSelected ? Color.vibeElectricCyan.opacity(0.26) : garageReviewStroke.opacity(0.92),
                                                lineWidth: 0.6
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var draftBinding: GarageCourseShotDraftBinding? {
        guard draft != nil else { return nil }
        return GarageCourseShotDraftBinding(
            club: Binding(
                get: { draft?.club },
                set: { draft?.club = $0 }
            ),
            lieBeforeShot: Binding(
                get: { draft?.lieBeforeShot },
                set: { draft?.lieBeforeShot = $0 }
            ),
            actualResult: Binding(
                get: { draft?.actualResult },
                set: { draft?.actualResult = $0 }
            )
        )
    }

    private func calibrationStepPill(_ step: GarageCourseCalibrationStep) -> some View {
        let isActive = currentCalibrationStep == step
        let isComplete = calibrationDraft?.anchor(for: step) != nil

        return HStack(spacing: 7) {
            Circle()
                .fill(isComplete ? Color.vibeElectricCyan : garageReviewMutedText.opacity(isActive ? 0.58 : 0.28))
                .frame(width: 7, height: 7)

            Text(step.statusTitle.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.9)
                .lineLimit(1)
        }
        .foregroundStyle(isActive ? garageReviewReadableText : garageReviewMutedText)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            garageMaterialSurface(
                Capsule(),
                material: isActive ? .regularMaterial : .ultraThinMaterial,
                stroke: isActive ? Color.vibeElectricCyan.opacity(0.28) : garageReviewStroke.opacity(0.88)
            )
        )
    }

    private func calibrationStatusPill(_ step: GarageCourseCalibrationStep) -> some View {
        let isActive = currentCalibrationStep == step
        let isComplete = calibrationDraft?.anchor(for: step) != nil

        return Circle()
            .fill(isComplete ? Color.vibeElectricCyan : garageReviewMutedText.opacity(isActive ? 0.66 : 0.28))
            .frame(width: isActive ? 9 : 7, height: isActive ? 9 : 7)
            .overlay {
                Circle()
                    .stroke(isActive ? Color.vibeElectricCyan.opacity(0.42) : .clear, lineWidth: 3)
            }
            .accessibilityLabel(Text("\(step.title) \(isComplete ? "placed" : "pending")"))
    }

    private var primaryCalibrationButtonEnabled: Bool {
        guard let calibrationDraft else { return false }
        return calibrationDraft.isComplete || calibrationDraft.anchor(for: currentCalibrationStep) != nil
    }

    @MainActor
    private func handleAddShotTap() {
        garageTriggerImpact(.medium)
        saveErrorMessage = nil
        refreshResolvedState(presentCalibrationIfNeeded: false)

        guard let activeHole else { return }
        guard activeHole.isCalibrated else {
            enterCalibration(for: activeHole)
            return
        }

        draft = GarageCourseShotDraft(hole: activeHole)
        editingShotID = nil
        overlayModel.syncDraftPlacement(draft?.placement)
        overlayModel.clearSelection()
        _ = overlayModel.endShotDrag()

        withAnimation(garageCourseMapSpring) {
            mapMode = .shotEntry
        }
    }

    @MainActor
    private func startEditingSelectedShot() {
        guard
            let activeHole,
            let selectedShotID = overlayModel.selectedShotID,
            let selectedShot = activeHole.shots.first(where: { $0.id == selectedShotID })
        else {
            return
        }

        garageTriggerImpact(.light)
        saveErrorMessage = nil
        draft = GarageCourseShotDraft(hole: activeHole, selectedShot: selectedShot)
        editingShotID = selectedShot.id
        overlayModel.syncDraftPlacement(draft?.placement)
        _ = overlayModel.endShotDrag()

        withAnimation(garageCourseMapSpring) {
            mapMode = .shotEntry
        }
    }

    @MainActor
    private func cancelShotEntry() {
        saveErrorMessage = nil
        draft = nil
        editingShotID = nil
        overlayModel.clearDraftPlacement()
        _ = overlayModel.endShotDrag()

        withAnimation(garageCourseMapSpring) {
            mapMode = .review
        }
    }

    @MainActor
    private func handleCanvasTap(_ location: CGPoint, in rect: CGRect) {
        guard garageNormalizedPoint(from: location, in: rect) != nil else { return }

        switch mapMode {
        case .calibration:
            let anchor = overlayModel.placeAnchor(
                kind: currentCalibrationStep.anchorKind,
                at: location,
                in: rect
            )
            placeCalibrationAnchor(anchor)
        case .shotEntry:
            let updatedPlacement = overlayModel.placeShot(
                at: location,
                shotID: editingShotID,
                in: rect
            )
            withAnimation(garageCourseMapSpring) {
                draft?.placement = updatedPlacement
            }
            saveErrorMessage = nil
            garageTriggerImpact(.light)
        case .review:
            break
        }
    }

    @MainActor
    private func handleCanvasDragChanged(_ value: DragGesture.Value, in rect: CGRect) {
        guard mapMode == .shotEntry, let draft else { return }

        if overlayModel.activeDragTarget == nil {
            guard rect.contains(value.startLocation) else { return }
            overlayModel.beginShotDrag(initialPlacement: draft.placement, shotID: editingShotID)
        }

        if let updatedPlacement = overlayModel.updateShotDrag(location: value.location, in: rect) {
            self.draft?.placement = updatedPlacement
            saveErrorMessage = nil
        }
    }

    @MainActor
    private func handleCanvasDragEnded(_ value: DragGesture.Value, in rect: CGRect) {
        guard mapMode == .shotEntry else { return }
        guard overlayModel.activeDragTarget != nil else { return }

        if let updatedPlacement = overlayModel.updateShotDrag(location: value.location, in: rect) {
            withAnimation(garageCourseMapSpring) {
                draft?.placement = updatedPlacement
            }
        }

        _ = overlayModel.endShotDrag()
    }

    @MainActor
    private func updateDraftPlacement(_ placement: GarageShotPlacement) {
        overlayModel.syncDraftPlacement(placement)
        draft?.placement = placement
        saveErrorMessage = nil
    }

    @MainActor
    private func finalizeDraftPlacement(_ placement: GarageShotPlacement) {
        withAnimation(garageCourseMapSpring) {
            draft?.placement = placement
        }
        overlayModel.syncDraftPlacement(placement)
        _ = overlayModel.endShotDrag()
        saveErrorMessage = nil
    }

    @MainActor
    private func clearDraftInteraction() {
        _ = overlayModel.endShotDrag()
    }

    @MainActor
    private func enterCalibration(for hole: GarageHoleMap) {
        calibrationDraft = GarageCourseCalibrationDraft(hole: hole)
        currentCalibrationStep = GarageCourseCalibrationStep.allCases.first(where: { calibrationDraft?.anchor(for: $0) == nil }) ?? .tee
        calibrationSaveErrorMessage = nil
        saveErrorMessage = nil
        draft = nil
        editingShotID = nil
        overlayModel.clearDraftPlacement()
        overlayModel.clearSelection()
        _ = overlayModel.endShotDrag()
        _ = overlayModel.endAnchorDrag()

        withAnimation(garageCourseMapSpring) {
            mapMode = .calibration
        }
    }

    @MainActor
    private func exitCalibration() {
        calibrationSaveErrorMessage = nil
        calibrationDraft = nil
        _ = overlayModel.endAnchorDrag()

        withAnimation(garageCourseMapSpring) {
            mapMode = .review
        }
    }

    @MainActor
    private func handleCalibrationBack() {
        garageTriggerImpact(.light)

        if currentCalibrationStep == .tee {
            exitCalibration()
        } else if let previous = GarageCourseCalibrationStep(rawValue: currentCalibrationStep.rawValue - 1) {
            withAnimation(garageCourseMapSpring) {
                currentCalibrationStep = previous
            }
        }
    }

    @MainActor
    private func handleCalibrationPrimary() {
        garageTriggerImpact(.medium)
        calibrationSaveErrorMessage = nil

        guard let calibrationDraft else {
            calibrationSaveErrorMessage = "Garage could not find the active calibration draft."
            return
        }

        if calibrationDraft.isComplete == false {
            guard calibrationDraft.anchor(for: currentCalibrationStep) != nil else {
                calibrationSaveErrorMessage = "Drop the \(currentCalibrationStep.title.lowercased()) before continuing."
                return
            }

            if let nextStep = nextIncompleteStep(in: calibrationDraft, after: currentCalibrationStep) {
                withAnimation(garageCourseMapSpring) {
                    currentCalibrationStep = nextStep
                }
            }
            return
        }

        persistCalibration()
    }

    private func nextIncompleteStep(
        in draft: GarageCourseCalibrationDraft,
        after step: GarageCourseCalibrationStep
    ) -> GarageCourseCalibrationStep? {
        let ordered = GarageCourseCalibrationStep.allCases
        if let nextUnfinished = ordered.dropFirst(step.rawValue + 1).first(where: { draft.anchor(for: $0) == nil }) {
            return nextUnfinished
        }
        return ordered.first(where: { draft.anchor(for: $0) == nil })
    }

    @MainActor
    private func placeCalibrationAnchor(_ anchor: GarageMapAnchor) {
        garageTriggerImpact(.light)
        calibrationSaveErrorMessage = nil
        calibrationDraft?.setAnchor(anchor)
        _ = overlayModel.endAnchorDrag()
    }

    @MainActor
    private func updateCalibrationAnchor(_ anchor: GarageMapAnchor) {
        calibrationSaveErrorMessage = nil
        calibrationDraft?.setAnchor(anchor)
    }

    @MainActor
    private func finalizeCalibrationAnchor(_ anchor: GarageMapAnchor) {
        withAnimation(garageCourseMapSpring) {
            calibrationDraft?.setAnchor(anchor)
        }
        calibrationSaveErrorMessage = nil
        _ = overlayModel.endAnchorDrag()
    }

    @MainActor
    private func endCalibrationInteraction() {
        _ = overlayModel.endAnchorDrag()
    }

    @MainActor
    private func persistCalibration() {
        guard
            let activeHole,
            let teeAnchor = calibrationDraft?.teeAnchor,
            let fairwayCheckpointAnchor = calibrationDraft?.fairwayCheckpointAnchor,
            let greenCenterAnchor = calibrationDraft?.greenCenterAnchor
        else {
            calibrationSaveErrorMessage = "All three anchors must be pinned before Garage unlocks shot entry."
            return
        }

        do {
            _ = try GarageCourseMappingPersistence.saveCalibrationAnchors(
                teeAnchor: teeAnchor,
                fairwayCheckpointAnchor: fairwayCheckpointAnchor,
                greenCenterAnchor: greenCenterAnchor,
                for: activeHole,
                in: modelContext
            )

            calibrationDraft = nil
            _ = overlayModel.endAnchorDrag()
            withAnimation(garageCourseMapSpring) {
                mapMode = .review
            }
            refreshResolvedState(presentCalibrationIfNeeded: false)
            overlayModel.selectShot(activeHole.lastShot?.id)
        } catch {
            calibrationSaveErrorMessage = GarageCourseMapAlert.message(for: error)
        }
    }

    private func activeDraftOverlayDescriptor(in hole: GarageHoleMap?) -> GarageCourseShotOverlayDescriptor? {
        guard let draft, let hole, mapMode == .shotEntry else { return nil }

        let sortedShots = hole.sortedShots
        let sequenceIndex: Int
        let startPlacement: GarageShotPlacement

        if let editingShotID,
           let editingIndex = sortedShots.firstIndex(where: { $0.id == editingShotID }) {
            sequenceIndex = sortedShots[editingIndex].sequenceIndex
            if editingIndex > 0 {
                startPlacement = sortedShots[editingIndex - 1].placement
            } else if let teeAnchor = hole.teeAnchor {
                startPlacement = GarageShotPlacement(
                    normalizedX: teeAnchor.normalizedX,
                    normalizedY: teeAnchor.normalizedY
                )
            } else {
                startPlacement = GarageShotPlacement(normalizedX: 0.5, normalizedY: 0.88)
            }
        } else {
            sequenceIndex = sortedShots.count + 1
            if let previousShot = sortedShots.last {
                startPlacement = previousShot.placement
            } else if let teeAnchor = hole.teeAnchor {
                startPlacement = GarageShotPlacement(
                    normalizedX: teeAnchor.normalizedX,
                    normalizedY: teeAnchor.normalizedY
                )
            } else {
                startPlacement = GarageShotPlacement(normalizedX: 0.5, normalizedY: 0.88)
            }
        }

        let inferredShotType = GarageCourseMappingPersistence.inferredShotType(for: draft.lieBeforeShot ?? .fairway)

        return GarageCourseShotOverlayDescriptor(
            id: editingShotID ?? UUID(),
            sequenceIndex: sequenceIndex,
            clubTitle: draft.club?.title ?? "Pending Club",
            shotTypeTitle: inferredShotType.title,
            resultTitle: draft.actualResult?.title ?? "Pending Result",
            flightShape: .straight,
            strikeQuality: .pure,
            startPlacement: startPlacement,
            endPlacement: draft.placement
        )
    }

    @MainActor
    private func persistDraft() {
        guard
            let activeSession,
            let activeHole,
            let draft,
            let club = draft.club,
            let lieBeforeShot = draft.lieBeforeShot,
            let actualResult = draft.actualResult
        else {
            saveErrorMessage = "Finish the tactical payload before saving this shot."
            return
        }

        do {
            let savedShot = try GarageCourseMappingPersistence.upsertShot(
                editingShotID: editingShotID,
                draft: GarageCourseShotSaveDraft(
                    placement: draft.placement,
                    club: club,
                    lieBeforeShot: lieBeforeShot,
                    actualResult: actualResult
                ),
                session: activeSession,
                hole: activeHole,
                in: modelContext
            )

            overlayModel.clearDraftPlacement()
            overlayModel.selectShot(savedShot.id)
            saveErrorMessage = nil
            self.draft = nil
            editingShotID = nil

            withAnimation(garageCourseMapSpring) {
                mapMode = .review
            }

            refreshResolvedState(presentCalibrationIfNeeded: false)
        } catch {
            saveErrorMessage = GarageCourseMapAlert.message(for: error)
            blockerAlert = GarageCourseMapAlert(error: error)
        }
    }

    @MainActor
    private func refreshResolvedState(presentCalibrationIfNeeded: Bool) {
        do {
            let session = try GarageCourseMappingPersistence.resolveActiveSession(
                for: model.metadata,
                in: modelContext
            )
            let hole = try GarageCourseMappingPersistence.resolveHole(
                for: model.metadata,
                session: session,
                in: modelContext
            )

            activeSession = session
            activeHole = hole
            loadCanvasImage()

            if let draft {
                overlayModel.syncDraftPlacement(draft.placement)
            } else {
                overlayModel.clearDraftPlacement()
            }

            let refreshedDescriptors = GarageCourseMapOverlayRenderer.descriptors(for: hole)
            if refreshedDescriptors.contains(where: { $0.id == overlayModel.selectedShotID }) == false {
                overlayModel.selectShot(refreshedDescriptors.last?.id)
            }

            if presentCalibrationIfNeeded, hole.isCalibrated == false, hasPresentedInitialCalibration == false {
                hasPresentedInitialCalibration = true
                enterCalibration(for: hole)
            }
        } catch {
            modelContext.rollback()
            blockerAlert = GarageCourseMapAlert(error: error)
        }
    }

    @MainActor
    private func loadCanvasImage() {
        canvasImage = garageLoadCourseMapImage(
            at: activeHole?.localAssetPath ?? model.metadata.assetDescriptor?.localAssetPath
        )
    }
}

private struct GarageCourseTopMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(garageReviewMutedText)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(garageReviewReadableText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct GarageCourseCanvasSurface: View {
    let image: UIImage?
    let hole: GarageHoleMap?
    let metadata: GarageCourseMetadata
    let imageRect: CGRect

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
            } else {
                GarageCourseFallbackHoleSurface(hole: hole)
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    .clear,
                    Color.black.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: imageRect.width, height: imageRect.height)
            .position(x: imageRect.midX, y: imageRect.midY)
            .allowsHitTesting(false)
        }
        .background(garageReviewSurfaceDark)
    }
}

private struct GarageCourseFallbackHoleSurface: View {
    let hole: GarageHoleMap?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
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
                    .frame(width: size.width * 0.46, height: size.height * 0.86)
                    .rotationEffect(.degrees(-6))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
                            .rotationEffect(.degrees(-6))
                    )

                Circle()
                    .fill(Color(hex: "#365C45").opacity(0.9))
                    .frame(width: size.width * 0.18, height: size.width * 0.18)
                    .offset(x: 0, y: -size.height * 0.34)

                Circle()
                    .fill(Color(hex: "#365C45").opacity(0.8))
                    .frame(width: size.width * 0.11, height: size.width * 0.11)
                    .offset(x: 0, y: size.height * 0.38)

                if let hole {
                    GarageCourseAnchorHints(hole: hole)
                }
            }
        }
    }
}

private struct GarageCourseAnchorHints: View {
    let hole: GarageHoleMap

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)

            ForEach(anchorPlacements, id: \.0) { title, placement in
                let point = GarageCourseMapOverlayRenderer.point(for: placement, in: rect)
                VStack(spacing: 6) {
                    Circle()
                        .stroke(Color.white.opacity(0.38), lineWidth: 1.2)
                        .frame(width: 10, height: 10)

                    Text(title)
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(garageReviewMutedText)
                }
                .position(point)
            }
        }
    }

    private var anchorPlacements: [(String, GarageShotPlacement)] {
        var values: [(String, GarageShotPlacement)] = []
        if let tee = hole.teeAnchor {
            values.append(("TEE", GarageShotPlacement(normalizedX: tee.normalizedX, normalizedY: tee.normalizedY)))
        }
        if let checkpoint = hole.fairwayCheckpointAnchor {
            values.append(("MID", GarageShotPlacement(normalizedX: checkpoint.normalizedX, normalizedY: checkpoint.normalizedY)))
        }
        if let green = hole.greenCenterAnchor {
            values.append(("GREEN", GarageShotPlacement(normalizedX: green.normalizedX, normalizedY: green.normalizedY)))
        }
        return values
    }
}

private struct GarageCourseCanvasOverlays: View {
    @ObservedObject var overlayModel: GarageCourseMapOverlayModel
    let hole: GarageHoleMap?
    let rect: CGRect
    let descriptors: [GarageCourseShotOverlayDescriptor]
    let selectedDescriptor: GarageCourseShotOverlayDescriptor?
    let reviewModeEnabled: Bool
    let activeDraftDescriptor: GarageCourseShotOverlayDescriptor?
    let activeDraftShotID: UUID?
    let isEditingPlacement: Bool
    let mapMode: GarageCourseMapMode
    let calibrationDraft: GarageCourseCalibrationDraft?
    let activeCalibrationStep: GarageCourseCalibrationStep
    let updateDraftPlacement: (GarageShotPlacement) -> Void
    let finalizeDraftPlacement: (GarageShotPlacement) -> Void
    let clearDraftInteraction: () -> Void
    let updateCalibrationAnchor: (GarageMapAnchor) -> Void
    let finalizeCalibrationAnchor: (GarageMapAnchor) -> Void
    let endCalibrationInteraction: () -> Void
    let selectShot: (GarageCourseShotOverlayDescriptor) -> Void

    var body: some View {
        ZStack {
            if let hole, rect.isEmpty == false {
                if mapMode == .calibration {
                    calibrationLayer(for: hole)
                } else {
                    faintSequencePath(for: hole)
                    generatedFlightPaths
                    markers
                    activeDraftMarker
                }
            }
        }
        .animation(garageCourseMapSpring, value: overlayModel.activeShotPlacement)
        .animation(garageCourseMapSpring, value: overlayModel.activeAnchor)
        .animation(garageCourseMapSpring, value: overlayModel.selectedShotID)
        .animation(garageCourseMapSpring, value: overlayModel.isInteracting)
    }

    private func faintSequencePath(for hole: GarageHoleMap) -> some View {
        GarageCourseMapOverlayRenderer.sequencePath(for: descriptors, in: rect)
            .stroke(
                Color.white.opacity(0.16),
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round, dash: [4, 8])
            )
            .overlay {
                if let teeAnchor = hole.teeAnchor {
                    let point = GarageCourseMapOverlayRenderer.point(
                        for: GarageShotPlacement(normalizedX: teeAnchor.normalizedX, normalizedY: teeAnchor.normalizedY),
                        in: rect
                    )
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 9, height: 9)
                        .position(point)
                }
            }
    }

    @ViewBuilder
    private func calibrationLayer(for hole: GarageHoleMap) -> some View {
        if let calibrationDraft {
            let anchorDescriptors = overlayModel.calibrationAnchorDescriptors(
                teeAnchor: calibrationDraft.teeAnchor,
                fairwayCheckpointAnchor: calibrationDraft.fairwayCheckpointAnchor,
                greenCenterAnchor: calibrationDraft.greenCenterAnchor,
                activeKind: activeCalibrationStep.anchorKind,
                in: rect
            )

            GarageCourseCalibrationGuidePath(descriptors: anchorDescriptors)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

            faintCalibrationReference(for: hole)

            ForEach(anchorDescriptors) { descriptor in
                if let point = descriptor.point {
                    GarageCourseCalibrationHandle(
                        descriptor: descriptor,
                        point: point,
                        isDragging: overlayModel.isDragging(kind: descriptor.kind)
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
                                    updateCalibrationAnchor(updatedAnchor)
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
                                    finalizeCalibrationAnchor(updatedAnchor)
                                } else {
                                    endCalibrationInteraction()
                                }
                            }
                    )
                    .zIndex(descriptor.isActive ? 3 : 2)
                }
            }
        }
    }

    @ViewBuilder
    private func faintCalibrationReference(for hole: GarageHoleMap) -> some View {
        if let teeAnchor = hole.teeAnchor {
            let point = GarageCourseMapOverlayRenderer.point(
                for: GarageShotPlacement(normalizedX: teeAnchor.normalizedX, normalizedY: teeAnchor.normalizedY),
                in: rect
            )
            Circle()
                .fill(Color.white.opacity(0.44))
                .frame(width: 8, height: 8)
                .position(point)
                .zIndex(1)
        }
    }

    @ViewBuilder
    private var generatedFlightPaths: some View {
        if reviewModeEnabled {
            ForEach(descriptors) { descriptor in
                GarageCourseMapOverlayRenderer.flightPath(for: descriptor, in: rect)
                    .stroke(
                        descriptor.id == overlayModel.selectedShotID ? Color.vibeElectricCyan.opacity(0.56) : Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: descriptor.id == overlayModel.selectedShotID ? 2.2 : 1.2, lineCap: .round, lineJoin: .round)
                    )
            }
        } else if let selectedDescriptor {
            GarageCourseMapOverlayRenderer.flightPath(for: selectedDescriptor, in: rect)
                .stroke(
                    Color.vibeElectricCyan.opacity(0.64),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
        }

        if let activeDraftDescriptor {
            GarageCourseMapOverlayRenderer.flightPath(for: activeDraftDescriptor, in: rect)
                .stroke(
                    Color.vibeElectricCyan.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round, dash: [4, 6])
                )
        }
    }

    private var markers: some View {
        ForEach(descriptors) { descriptor in
            let point = GarageCourseMapOverlayRenderer.point(for: descriptor.endPlacement, in: rect)
            let isSelected = descriptor.id == overlayModel.selectedShotID

            Button {
                selectShot(descriptor)
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: isSelected ? 40 : 30, height: isSelected ? 40 : 30)
                        .overlay(
                            Circle()
                                .fill(isSelected ? Color.vibeElectricCyan.opacity(0.12) : Color.clear)
                        )

                    Circle()
                        .stroke(isSelected ? Color.white.opacity(0.96) : Color.white.opacity(0.44), lineWidth: isSelected ? 2 : 1)
                        .frame(width: isSelected ? 40 : 30, height: isSelected ? 40 : 30)

                    Text("\(descriptor.sequenceIndex)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? garageReviewReadableText : garageReviewMutedText)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(GarageCourseMapPinButtonStyle(isSelected: isSelected))
            .position(point)
            .opacity(activeDraftShotID == descriptor.id && isEditingPlacement ? 0.35 : 1)
            .zIndex(isSelected ? 2 : 1)
        }
    }

    @ViewBuilder
    private var activeDraftMarker: some View {
        if let activeDraftDescriptor {
            let draftPlacement = overlayModel.activeShotPlacement ?? activeDraftDescriptor.endPlacement
            let point = GarageCourseMapOverlayRenderer.point(for: draftPlacement, in: rect)
            let isDragging = overlayModel.isDragging(shotID: activeDraftShotID)

            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .fill(Color.vibeElectricCyan.opacity(0.16))
                    )

                Circle()
                    .stroke(Color.vibeElectricCyan.opacity(0.98), lineWidth: 2.4)
                    .frame(width: 38, height: 38)

                Circle()
                    .fill(Color.black.opacity(0.36))
                    .frame(width: 26, height: 26)

                Text("\(activeDraftDescriptor.sequenceIndex)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(garageReviewReadableText)
            }
            .frame(width: 60, height: 60)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Text(isEditingPlacement ? "DRAG" : "SHOT")
                    .font(.caption2.weight(.bold))
                    .tracking(0.9)
                    .foregroundStyle(garageReviewReadableText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(garageMaterialSurface(Capsule()))
                    .offset(y: 34)
            }
            .position(point)
            .scaleEffect(isDragging ? 1.15 : 1.0)
            .shadow(color: .black.opacity(0.12), radius: isDragging ? 16 : 8, x: 0, y: isDragging ? 8 : 4)
            .animation(garageCourseMapSpring, value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEditingPlacement else { return }
                        if overlayModel.activeDragTarget == nil {
                            overlayModel.beginShotDrag(
                                initialPlacement: activeDraftDescriptor.endPlacement,
                                shotID: activeDraftShotID
                            )
                        }
                        if let updatedPlacement = overlayModel.updateShotDrag(translation: value.translation, in: rect) {
                            updateDraftPlacement(updatedPlacement)
                        }
                    }
                    .onEnded { value in
                        guard isEditingPlacement else { return }
                        if overlayModel.activeDragTarget == nil {
                            overlayModel.beginShotDrag(
                                initialPlacement: activeDraftDescriptor.endPlacement,
                                shotID: activeDraftShotID
                            )
                        }
                        if let updatedPlacement = overlayModel.updateShotDrag(translation: value.translation, in: rect) {
                            finalizeDraftPlacement(updatedPlacement)
                        } else {
                            clearDraftInteraction()
                        }
                    }
            )
            .allowsHitTesting(isEditingPlacement)
            .zIndex(3)
        }
    }
}

private struct GarageCourseCalibrationGuidePath: View {
    let descriptors: [GarageCourseCalibrationAnchorDescriptor]

    var body: some View {
        Canvas { context, _ in
            let points = descriptors.compactMap(\.point)
            guard points.count > 1 else { return }

            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            context.stroke(
                path,
                with: .color(Color.vibeElectricCyan.opacity(0.32)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 7])
            )
        }
    }
}

private struct GarageCourseCalibrationHandle: View {
    let descriptor: GarageCourseCalibrationAnchorDescriptor
    let point: CGPoint
    let isDragging: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: descriptor.isActive ? 56 : 44, height: descriptor.isActive ? 56 : 44)
                    .overlay(
                        Circle()
                            .fill(Color.vibeElectricCyan.opacity(descriptor.isActive ? 0.18 : 0.1))
                    )

                Circle()
                    .stroke(
                        descriptor.isActive ? Color.vibeElectricCyan.opacity(0.96) : Color.white.opacity(0.58),
                        lineWidth: descriptor.isActive ? 2.6 : 1.8
                    )
                    .frame(width: descriptor.isActive ? 36 : 28, height: descriptor.isActive ? 36 : 28)

                Circle()
                    .fill(descriptor.isActive ? Color.vibeElectricCyan : Color.white.opacity(0.88))
                    .frame(width: 9, height: 9)
            }

            Text(descriptor.title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(garageReviewReadableText)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    garageMaterialSurface(
                        Capsule(),
                        material: descriptor.isActive ? .regularMaterial : .ultraThinMaterial,
                        stroke: descriptor.isActive ? Color.vibeElectricCyan.opacity(0.24) : garageReviewStroke.opacity(0.92)
                    )
                )
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .position(point)
        .scaleEffect(isDragging ? 1.15 : 1.0)
        .shadow(color: .black.opacity(0.14), radius: isDragging ? 18 : 9, x: 0, y: isDragging ? 9 : 4)
        .animation(garageCourseMapSpring, value: isDragging)
    }
}

private struct GarageCourseShotDraftBinding {
    let club: Binding<GarageTacticalClub?>
    let lieBeforeShot: Binding<GarageTacticalLie?>
    let actualResult: Binding<GarageTacticalResult?>
}

private struct GarageCoursePrecisionReadoutStrip: View {
    let title: String
    let readout: GarageCourseMapPrecisionReadout

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(Color.vibeElectricCyan)

            Spacer(minLength: 0)

            precisionValue(label: "X", value: readout.formattedX)
            precisionValue(label: "Y", value: readout.formattedY)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            garageMaterialSurface(
                RoundedRectangle(cornerRadius: 16, style: .continuous),
                material: .regularMaterial,
                stroke: Color.vibeElectricCyan.opacity(0.14)
            )
        )
    }

    private func precisionValue(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(garageReviewMutedText)

            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(garageReviewReadableText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(garageReviewSurface.opacity(0.84))
                .overlay(
                    Capsule()
                        .stroke(garageReviewStroke.opacity(0.88), lineWidth: 0.6)
                )
        )
    }
}

private protocol GarageCourseMapSelectable {
    var title: String { get }
    var symbolName: String { get }
}

private struct GarageCourseMapPinButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.08 : (isSelected ? 1.02 : 1.0))
            .shadow(
                color: .black.opacity(0.12),
                radius: configuration.isPressed ? 14 : 8,
                x: 0,
                y: configuration.isPressed ? 8 : 4
            )
            .animation(garageCourseMapSpring, value: configuration.isPressed)
    }
}

extension GarageTacticalClub: GarageCourseMapSelectable {}
extension GarageTacticalLie: GarageCourseMapSelectable {}
extension GarageTacticalResult: GarageCourseMapSelectable {}

private struct GarageCourseMapAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(error: Error) {
        title = "Course Mapping Locked"
        message = Self.message(for: error)
    }

    static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let errorDescription = localizedError.errorDescription {
            if let recoverySuggestion = localizedError.recoverySuggestion {
                return "\(errorDescription) \(recoverySuggestion)"
            }
            return errorDescription
        }

        return (error as NSError).localizedDescription
    }
}

private func garageMaterialSurface<S: Shape>(
    _ shape: S,
    material: Material = .ultraThinMaterial,
    stroke: Color = Color.white.opacity(0.08)
) -> some View {
    shape
        .fill(material)
        .overlay(
            shape.stroke(stroke, lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
}

#Preview {
    PreviewScreenContainer {
        GarageCourseMapView()
    }
    .modelContainer(PreviewCatalog.emptyApp)
}
