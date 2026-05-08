import Combine
import Foundation
import SwiftUI

struct GarageFocusDrillPresentation {
    let id: UUID
    let title: String
    let metadata: String
    let objective: String
    let executionCommand: String
    let executionSteps: [String]
    let passCheck: String
    let passCriteria: [String]
    let repTarget: String
    let targetCount: Int
    let diagram: GarageDrillDiagram
    let setup: [String]
    let commonMisses: [String]
    let resetCue: String
    let equipment: [String]
    let isCompleted: Bool
}

struct GarageFocusRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRoutineVisible = false
    @State private var activeDrillID: UUID?
    @State private var elapsedSeconds = 0
    @State private var goodHits = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    let sessionTitle: String
    let environment: PracticeEnvironment
    let drillPositionText: String
    let completedCount: Int
    let totalCount: Int
    let drill: GarageFocusDrillPresentation?
    let railItems: [GarageFocusDrillRailItem]
    let isDetailExpanded: Bool
    let noteTitle: String
    let primaryCtaTitle: String
    let onToggleDetail: () -> Void
    let onSelectRailDrill: (Int) -> Void
    let onNote: () -> Void
    let onPrimary: () -> Void
    let onExitEmptyRoutine: () -> Void

    var body: some View {
        if let drill {
            ZStack {
                FocusRoomBackground()

                VStack(spacing: 0) {
                    FocusRoomHeader(
                        isRoutineVisible: isRoutineVisible,
                        onBack: { dismiss() },
                        onToggleRoutine: toggleRoutineVisibility
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            FocusRoomDrillHero(
                                drillTitle: drill.title,
                                metadata: drill.metadata,
                                drillPositionText: drillPositionText,
                                completedCount: completedCount,
                                totalCount: totalCount,
                                diagram: drill.diagram
                            )

                            FocusRoomSetupSteps(steps: checklistSteps(for: drill))

                            FocusRoomPassCondition(
                                primaryText: primaryPassText(for: drill),
                                secondaryText: secondaryPassText(for: drill)
                            )

                            FocusRoomTimerCard(
                                elapsedSeconds: elapsedSeconds,
                                goodHits: goodHits,
                                targetCount: drill.targetCount,
                                onGoodHit: recordGoodHit
                            )

                            FocusRoomWatchForBand(text: drill.commonMisses.first ?? "Keep the setup honest and stop the set if the feedback gets unclear.")

                            if isRoutineVisible {
                                GarageFocusDrillStackRail(
                                    items: railItems,
                                    onSelectDrill: onSelectRailDrill
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 10)
                        .padding(.bottom, GarageFocusRoomLayout.contentBottomInset)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .tint(FocusRoomPalette.green)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FocusRoomBottomActions(
                    noteTitle: noteTitle,
                    isNextEnabled: drill.isCompleted || goodHits >= drill.targetCount,
                    onNote: onNote,
                    onNext: onPrimary
                )
            }
            .onAppear {
                resetStateIfNeeded(for: drill.id)
            }
            .onChange(of: drill.id) { _, newValue in
                resetStateIfNeeded(for: newValue)
            }
            .onReceive(timer) { _ in
                elapsedSeconds += 1
            }
        } else {
            GarageProScaffold(bottomPadding: 40) {
                GarageProCard(isActive: true) {
                    Text("No drills in this routine")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Return to Garage and choose a routine with at least one drill.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    GarageProPrimaryButton(
                        title: GarageFocusRoomCopy.focusRoomBackCta,
                        systemImage: "chevron.left",
                        action: onExitEmptyRoutine
                    )
                }
            }
        }
    }
}

private enum GarageFocusRoomLayout {
    static let contentBottomInset: CGFloat = 128
}

private enum FocusRoomPalette {
    static let background = Color(red: 0.012, green: 0.035, blue: 0.026)
    static let backgroundLift = Color(red: 0.025, green: 0.105, blue: 0.07)
    static let panel = Color(red: 0.025, green: 0.082, blue: 0.058)
    static let green = Color(red: 0.23, green: 0.96, blue: 0.49)
    static let greenSoft = Color(red: 0.47, green: 0.91, blue: 0.59)
    static let yellow = Color(red: 1.0, green: 0.78, blue: 0.22)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.68)
    static let border = Color(red: 0.23, green: 0.96, blue: 0.49).opacity(0.18)
}

private extension GarageFocusRoomView {
    func resetStateIfNeeded(for drillID: UUID) {
        guard activeDrillID != drillID else {
            return
        }

        activeDrillID = drillID
        elapsedSeconds = 0
        goodHits = 0
        isRoutineVisible = false
    }

    func toggleRoutineVisibility() {
        garageTriggerSelection()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isRoutineVisible.toggle()
        }
    }

    func recordGoodHit() {
        garageTriggerSelection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            goodHits += 1
        }
    }

    func checklistSteps(for drill: GarageFocusDrillPresentation) -> [String] {
        let steps = (drill.setup + drill.executionSteps)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        if steps.isEmpty {
            return ["Set the station.", "Make the assigned swing.", "Count only clear reps.", "Reset before the next ball."]
        }

        return Array(steps.prefix(4))
    }

    func primaryPassText(for drill: GarageFocusDrillPresentation) -> String {
        let primary = drill.passCriteria.first ?? drill.passCheck
        return primary.trimmingCharacters(in: .whitespacesAndNewlines).garageFocusRoomSentenceTrimmed
    }

    func secondaryPassText(for drill: GarageFocusDrillPresentation) -> String {
        let secondaryItems = drill.passCriteria.dropFirst()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).garageFocusRoomSentenceTrimmed }
            .filter { $0.isEmpty == false }

        if secondaryItems.isEmpty {
            return drill.executionCommand.trimmingCharacters(in: .whitespacesAndNewlines).garageFocusRoomSentenceTrimmed
        }

        return secondaryItems.joined(separator: " and ").garageFocusRoomSentenceTrimmed
    }
}

private struct FocusRoomBackground: View {
    var body: some View {
        ZStack {
            FocusRoomPalette.background
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    FocusRoomPalette.backgroundLift.opacity(0.88),
                    FocusRoomPalette.background,
                    Color.black.opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(FocusRoomPalette.green.opacity(0.15))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -150, y: -260)

            Circle()
                .fill(FocusRoomPalette.green.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 100)
                .offset(x: 170, y: 220)
        }
    }
}

private struct FocusRoomHeader: View {
    let isRoutineVisible: Bool
    let onBack: () -> Void
    let onToggleRoutine: () -> Void

    var body: some View {
        ZStack {
            HStack {
                Button {
                    garageTriggerSelection()
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(FocusRoomPalette.primaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onToggleRoutine()
                } label: {
                    Image(systemName: isRoutineVisible ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isRoutineVisible ? FocusRoomPalette.green : FocusRoomPalette.secondaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text("Focus Room")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(FocusRoomPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

private struct FocusRoomDrillHero: View {
    let drillTitle: String
    let metadata: String
    let drillPositionText: String
    let completedCount: Int
    let totalCount: Int
    let diagram: GarageDrillDiagram

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(drillTitle)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(FocusRoomPalette.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)

                HStack(spacing: 8) {
                    Text(drillPositionText)
                    Text("\(completedCount)/\(totalCount) complete")
                    if metadata.isEmpty == false {
                        Text(metadata)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(FocusRoomPalette.secondaryText)
            }

            GarageDrillDiagramView(diagram: diagram)
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(FocusRoomPalette.border, lineWidth: 1)
                )
        }
    }
}

private struct FocusRoomSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .textCase(.uppercase)
            .tracking(1.7)
            .foregroundStyle(FocusRoomPalette.green)
    }
}

private struct FocusRoomSetupSteps: View {
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FocusRoomSectionLabel(title: "Setup")

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(FocusRoomPalette.background)
                            .frame(width: 25, height: 25)
                            .background(FocusRoomPalette.green, in: Circle())

                        Text(step.garageFocusRoomSentenceTrimmed)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(FocusRoomPalette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct FocusRoomPassCondition: View {
    let primaryText: String
    let secondaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle()
                .fill(FocusRoomPalette.green.opacity(0.32))
                .frame(height: 1)

            FocusRoomSectionLabel(title: "Pass Condition")

            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(FocusRoomPalette.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryText)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(FocusRoomPalette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(secondaryText)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(FocusRoomPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct FocusRoomTimerCard: View {
    let elapsedSeconds: Int
    let goodHits: Int
    let targetCount: Int
    let onGoodHit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FocusRoomSectionLabel(title: "Drill Timer")

            HStack(alignment: .center, spacing: 14) {
                FocusRoomTimerMetric(value: formattedTime, label: "Elapsed")

                Button {
                    onGoodHit()
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(FocusRoomPalette.yellow.opacity(0.38), lineWidth: 4)
                                .frame(width: 70, height: 70)

                            Circle()
                                .stroke(FocusRoomPalette.yellow, lineWidth: 2)
                                .frame(width: 58, height: 58)

                            Text("\(goodHits)")
                                .font(.system(size: 26, weight: .black, design: .monospaced))
                                .foregroundStyle(FocusRoomPalette.yellow)
                        }

                        Text("Tap after good hit")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .textCase(.uppercase)
                            .tracking(0.7)
                            .foregroundStyle(FocusRoomPalette.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                FocusRoomTimerMetric(value: "\(targetCount)", label: "Good Hits")
            }
            .padding(16)
            .background(FocusRoomPalette.panel.opacity(0.74), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(FocusRoomPalette.border, lineWidth: 1)
            )
        }
    }

    private var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

private struct FocusRoomTimerMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundStyle(FocusRoomPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(FocusRoomPalette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FocusRoomWatchForBand: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FocusRoomPalette.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("Watch For")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(FocusRoomPalette.yellow)

                Text(text.garageFocusRoomSentenceTrimmed)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(FocusRoomPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FocusRoomPalette.yellow.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct FocusRoomBottomActions: View {
    let noteTitle: String
    let isNextEnabled: Bool
    let onNote: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button {
                garageTriggerSelection()
                onNote()
            } label: {
                Label(noteTitle, systemImage: noteTitle == GarageFocusRoomCopy.focusRoomNoteAddCta ? "square.and.pencil" : "note.text")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(FocusRoomPalette.primaryText)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(FocusRoomPalette.panel.opacity(0.88), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(FocusRoomPalette.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Auto-advance")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(FocusRoomPalette.primaryText)
                        .lineLimit(1)

                    Text("Next drill when target met")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(FocusRoomPalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Button {
                    guard isNextEnabled else {
                        return
                    }

                    garageTriggerImpact(.medium)
                    onNext()
                } label: {
                    Image(systemName: "chevron.forward.2")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(isNextEnabled ? FocusRoomPalette.background : FocusRoomPalette.secondaryText)
                        .frame(width: 52, height: 52)
                        .background(isNextEnabled ? FocusRoomPalette.green : FocusRoomPalette.panel.opacity(0.9), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(isNextEnabled ? Color.white.opacity(0.16) : FocusRoomPalette.border, lineWidth: 1)
                        )
                        .shadow(color: isNextEnabled ? FocusRoomPalette.green.opacity(0.28) : .clear, radius: 14, x: 0, y: 0)
                }
                .buttonStyle(.plain)
                .disabled(isNextEnabled == false)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(FocusRoomPalette.background.opacity(0.94))
    }
}

private extension String {
    var garageFocusRoomSentenceTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}
