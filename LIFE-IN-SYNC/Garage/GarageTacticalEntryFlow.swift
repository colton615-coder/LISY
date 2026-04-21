import SwiftData
import SwiftUI

private enum GarageTacticalEntryStep: Int, CaseIterable, Identifiable {
    case placement
    case plan
    case outcome

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .placement:
            "Placement"
        case .plan:
            "Plan"
        case .outcome:
            "Outcome"
        }
    }

    var subtitle: String {
        switch self {
        case .placement:
            "Tap the rough landing zone."
        case .plan:
            "Log what you tried to do."
        case .outcome:
            "Capture the lie and finish."
        }
    }
}

private struct GarageTacticalEntryDraft {
    var placement = GarageShotPlacement(normalizedX: 0.5, normalizedY: 0.74)
    var club: GarageTacticalClub?
    var shotType: GarageTacticalShotType?
    var intendedTarget = "Center Line"
    var lieBeforeShot: GarageTacticalLie?
    var actualResult: GarageTacticalResult?

    var canSave: Bool {
        club != nil && shotType != nil && lieBeforeShot != nil && actualResult != nil
    }
}

struct GarageTacticalEntryFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: GarageRoundSession
    let hole: GarageHoleMap
    var onSave: ((GarageTacticalShot) -> Void)?

    @State private var currentStep: GarageTacticalEntryStep = .placement
    @State private var draft = GarageTacticalEntryDraft()
    @State private var saveErrorMessage: String?

    private let targetOptions = [
        "Center Line",
        "Left Window",
        "Right Window",
        "Aggressive Line",
        "Safety Line"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                garageReviewBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard
                        stepRail
                        stepContent
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
                    Text("TACTICAL ENTRY")
                        .font(.caption.weight(.bold))
                        .tracking(1.3)
                        .foregroundStyle(Color.vibeElectricCyan)

                    Text("Hole \(hole.holeNumber) • \(session.courseName)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)

                    Text(currentStep.subtitle)
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
            ForEach(GarageTacticalEntryStep.allCases) { step in
                Button {
                    garageTriggerImpact(.light)
                    currentStep = step
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("0\(step.rawValue + 1)")
                            .font(.caption2.weight(.bold))
                            .tracking(1.0)
                            .foregroundStyle(currentStep == step ? Color.vibeElectricCyan : garageReviewMutedText)

                        Text(step.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(currentStep == step ? garageReviewReadableText : garageReviewMutedText)

                        Capsule()
                            .fill(currentStep == step ? Color.vibeElectricCyan : garageReviewStroke)
                            .frame(height: 3)
                            .shadow(color: currentStep == step ? Color.vibeElectricCyan.opacity(0.24) : .clear, radius: 8, x: 0, y: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        currentStep == step
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

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .placement:
            placementStep
        case .plan:
            planStep
        case .outcome:
            outcomeStep
        }
    }

    private var placementStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepSectionHeader(title: "Landing Pin", detail: "Tap once to drop the shot. Tap again to refine it.")

            GarageTacticalPlacementPad(placement: $draft.placement)
                .frame(height: 336)

            summaryStrip
        }
    }

    private var planStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepSectionHeader(title: "Club And Intent", detail: "Keep this fast. Big taps, no typing.")

            tacticalSelectionGrid(
                title: "Club",
                items: GarageTacticalClub.allCases,
                selection: $draft.club
            )

            tacticalSelectionGrid(
                title: "Shot Type",
                items: GarageTacticalShotType.allCases,
                selection: $draft.shotType
            )

            targetRail
        }
    }

    private var outcomeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepSectionHeader(title: "Lie And Result", detail: "Log the state cleanly, then save it into the round.")

            tacticalSelectionGrid(
                title: "Lie",
                items: GarageTacticalLie.allCases,
                selection: $draft.lieBeforeShot
            )

            tacticalSelectionGrid(
                title: "Result",
                items: GarageTacticalResult.allCases,
                selection: $draft.actualResult
            )

            summaryStrip
        }
    }

    private func stepSectionHeader(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(garageReviewReadableText)

            Text(detail)
                .font(.footnote.weight(.medium))
                .foregroundStyle(garageReviewMutedText)
        }
    }

    private func tacticalSelectionGrid<Item: CaseIterable & Identifiable & Hashable>(
        title: String,
        items: Item.AllCases,
        selection: Binding<Item?>
    ) -> some View where Item: GarageTacticalSelectable {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(garageReviewMutedText)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(items), id: \.id) { item in
                    let isSelected = selection.wrappedValue == item

                    Button {
                        garageTriggerImpact(.light)
                        selection.wrappedValue = item
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbolName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.vibeElectricCyan : garageReviewMutedText)
                                .frame(width: 20)

                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isSelected ? garageReviewReadableText : garageReviewMutedText)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(
                            isSelected
                            ? AnyView(
                                GarageRaisedPanelBackground(
                                    shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                    fill: garageReviewSurfaceRaised,
                                    stroke: Color.vibeElectricCyan.opacity(0.28),
                                    glow: Color.vibeElectricCyan.opacity(0.42)
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
    }

    private var targetRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Intent Target")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(garageReviewMutedText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(targetOptions, id: \.self) { option in
                        let isSelected = draft.intendedTarget == option

                        Button {
                            garageTriggerImpact(.light)
                            draft.intendedTarget = option
                        } label: {
                            Text(option)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isSelected ? garageReviewReadableText : garageReviewMutedText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.vibeElectricCyan.opacity(0.16) : garageReviewInsetSurface.opacity(0.96))
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? Color.vibeElectricCyan.opacity(0.28) : garageReviewStroke.opacity(0.92), lineWidth: 0.6)
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

    private var summaryStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Entry Summary")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(garageReviewMutedText)

            HStack(spacing: 10) {
                summaryPill(title: draft.club?.title ?? "Club", isActive: draft.club != nil)
                summaryPill(title: draft.shotType?.title ?? "Type", isActive: draft.shotType != nil)
                summaryPill(title: draft.lieBeforeShot?.title ?? "Lie", isActive: draft.lieBeforeShot != nil)
                summaryPill(title: draft.actualResult?.title ?? "Result", isActive: draft.actualResult != nil)
            }
        }
        .padding(16)
        .background(
            GarageInsetPanelBackground(
                shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                fill: garageReviewInsetSurface.opacity(0.96),
                stroke: garageReviewStroke.opacity(0.94)
            )
        )
    }

    private func summaryPill(title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? garageReviewReadableText : garageReviewMutedText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? Color.vibeElectricCyan.opacity(0.14) : garageReviewSurface.opacity(0.96))
                    .overlay(
                        Capsule()
                            .stroke(isActive ? Color.vibeElectricCyan.opacity(0.24) : garageReviewStroke.opacity(0.9), lineWidth: 0.6)
                    )
            )
    }

    private var footerDock: some View {
        HStack(spacing: 12) {
            Button {
                garageTriggerImpact(.light)
                moveStep(delta: -1)
            } label: {
                Text(currentStep == .placement ? "Cancel" : "Back")
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
                Text(currentStep == .outcome ? "Save Shot" : "Continue")
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
            .disabled(currentStep == .outcome && draft.canSave == false)
            .opacity(currentStep == .outcome && draft.canSave == false ? 0.55 : 1)
        }
    }

    private func moveStep(delta: Int) {
        if currentStep == .placement && delta < 0 {
            dismiss()
            return
        }

        let nextRawValue = min(max(currentStep.rawValue + delta, 0), GarageTacticalEntryStep.allCases.count - 1)
        if let nextStep = GarageTacticalEntryStep(rawValue: nextRawValue) {
            currentStep = nextStep
        }
    }

    private func handlePrimaryAction() {
        if currentStep != .outcome {
            moveStep(delta: 1)
            return
        }

        persistShot()
    }

    private func persistShot() {
        guard
            let club = draft.club,
            let shotType = draft.shotType,
            let lieBeforeShot = draft.lieBeforeShot,
            let actualResult = draft.actualResult
        else {
            saveErrorMessage = "Finish the tactical payload before saving this shot."
            return
        }

        saveErrorMessage = nil

        if session.modelContext == nil {
            modelContext.insert(session)
        }

        if hole.modelContext == nil {
            modelContext.insert(hole)
        }

        if session.holes.contains(where: { $0.id == hole.id }) == false {
            session.holes.append(hole)
        }

        let shot = GarageTacticalShot(
            sequenceIndex: session.shots.count + 1,
            holeNumber: hole.holeNumber,
            placement: draft.placement,
            club: club,
            shotType: shotType,
            intendedTarget: draft.intendedTarget,
            lieBeforeShot: lieBeforeShot,
            actualResult: actualResult,
            session: session,
            hole: hole
        )

        modelContext.insert(shot)
        session.updatedAt = .now
        hole.updatedAt = .now

        do {
            try modelContext.save()
            onSave?(shot)
            dismiss()
        } catch {
            saveErrorMessage = "Garage could not save this tactical shot yet."
        }
    }
}

private struct GarageTacticalPlacementPad: View {
    @Binding var placement: GarageShotPlacement

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let pinX = width * placement.normalizedX
            let pinY = height * placement.normalizedY

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
                                Color(hex: "#304236").opacity(0.86),
                                Color(hex: "#1B2B24").opacity(0.94)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width * 0.36, height: height * 0.78)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                    )

                VStack {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 28, height: 28)
                    Spacer()
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 36, height: 36)
                }
                .padding(.vertical, 34)

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

                ZStack {
                    Circle()
                        .fill(Color.vibeElectricCyan.opacity(0.18))
                        .frame(width: 42, height: 42)

                    Circle()
                        .stroke(Color.vibeElectricCyan.opacity(0.96), lineWidth: 2.4)
                        .frame(width: 26, height: 26)

                    Circle()
                        .fill(Color.vibeElectricCyan)
                        .frame(width: 8, height: 8)
                }
                .position(x: pinX, y: pinY)
                .shadow(color: Color.vibeElectricCyan.opacity(0.28), radius: 12, x: 0, y: 0)
            }
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .onTapGesture { location in
                garageTriggerImpact(.light)
                placement = GarageShotPlacement(
                    normalizedX: location.x / max(width, 1),
                    normalizedY: location.y / max(height, 1)
                )
            }
        }
    }
}

private protocol GarageTacticalSelectable {
    var title: String { get }
    var symbolName: String { get }
}

extension GarageTacticalClub: GarageTacticalSelectable {}
extension GarageTacticalShotType: GarageTacticalSelectable {}
extension GarageTacticalLie: GarageTacticalSelectable {}
extension GarageTacticalResult: GarageTacticalSelectable {}

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
        teeAnchor: GarageMapAnchor(kind: .tee, normalizedX: 0.48, normalizedY: 0.88),
        fairwayCheckpointAnchor: GarageMapAnchor(kind: .fairwayCheckpoint, normalizedX: 0.5, normalizedY: 0.48),
        greenCenterAnchor: GarageMapAnchor(kind: .greenCenter, normalizedX: 0.52, normalizedY: 0.14),
        session: session
    )

    PreviewScreenContainer {
        GarageTacticalEntryFlow(session: session, hole: hole)
    }
    .modelContainer(PreviewCatalog.emptyApp)
}
