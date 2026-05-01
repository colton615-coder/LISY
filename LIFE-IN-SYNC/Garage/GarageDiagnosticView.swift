import SwiftUI

@MainActor
struct GarageDiagnosticView: View {
    private let initialEnvironment: PracticeEnvironment?
    private let onStartRehearsal: (GarageDrill) -> Void

    @State private var step: Int
    @State private var selectedEnv: PracticeEnvironment?
    @State private var selectedClub: ClubRange?
    @State private var selectedFault: FaultType?
    @State private var prescribedDrill: GarageDrill?

    init(
        initialEnvironment: PracticeEnvironment? = nil,
        onStartRehearsal: @escaping (GarageDrill) -> Void
    ) {
        self.initialEnvironment = initialEnvironment
        self.onStartRehearsal = onStartRehearsal
        _step = State(initialValue: initialEnvironment == nil ? 0 : 1)
        _selectedEnv = State(initialValue: initialEnvironment)
    }

    private var minimumStep: Int {
        initialEnvironment == nil ? 0 : 1
    }

    private var themePrimary: Color {
        GarageProTheme.accent
    }

    private var heroTitle: String {
        prescribedDrill == nil ? "The Prescription" : "Your Rehearsal"
    }

    private var heroSubtitle: String {
        if let prescribedDrill {
            return "\(prescribedDrill.environment.displayName) • \(prescribedDrill.clubRange.displayName)"
        }

        return stepSubtitle
    }

    private var progressValue: String {
        prescribedDrill == nil ? "\(stepIndex)" : "Ready"
    }

    private var progressLabel: String {
        prescribedDrill == nil ? "Step Of 3" : "Launch"
    }

    private var stepIndex: Int {
        min(max(step + 1 - minimumStep, 1), 3)
    }

    var body: some View {
        GarageProScaffold(bottomPadding: prescribedDrill == nil ? 124 : 96) {
            GarageProHeroCard(
                eyebrow: "Vibe-Based Coach",
                title: heroTitle,
                subtitle: heroSubtitle,
                value: progressValue,
                valueLabel: progressLabel
            ) {
                Image(systemName: prescribedDrill == nil ? "waveform.path.ecg" : "checkmark.seal.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(themePrimary)
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(themePrimary.opacity(0.3), lineWidth: 1)
                    )
            }

            if let drill = prescribedDrill {
                PrescriptionResultCard(
                    drill: drill,
                    onStart: { onStartRehearsal(drill) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                GarageDiagnosticStepCard(
                    title: stepTitle,
                    subtitle: stepSubtitle
                ) {
                    switch step {
                    case 0:
                        DiagnosticOptionGrid(options: PracticeEnvironment.allCases) { env in
                            selectEnvironment(env)
                        } label: { env in
                            OptionContent(
                                title: env.displayName,
                                subtitle: env.description,
                                icon: env.systemImage
                            )
                        }
                    case 1:
                        DiagnosticOptionGrid(options: availableClubs) { club in
                            selectedClub = club
                            selectedFault = nil
                            advance()
                        } label: { club in
                            OptionContent(
                                title: club.displayName,
                                subtitle: "Choose the tool in your hands.",
                                icon: club == .putter ? "circle.grid.2x2.fill" : "suit.club.fill"
                            )
                        }
                    default:
                        DiagnosticOptionGrid(options: FaultType.allCases) { fault in
                            selectedFault = fault
                            prescribe()
                        } label: { fault in
                            OptionContent(
                                title: fault.sensoryDescription,
                                subtitle: "Tell the coach what the rep feels like.",
                                icon: "sparkles"
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Prescription")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if prescribedDrill == nil && step > minimumStep {
                HStack {
                    Button {
                        backOneStep()
                    } label: {
                        Label("Back One Step", systemImage: "chevron.left")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(GarageProTheme.insetSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(GarageProTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case 0:
            return "Choose The Surface"
        case 1:
            return "Choose The Tool"
        default:
            return "Name The Struggle"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 0:
            return "Start with the practice environment so the prescription stays grounded in the actual rep."
        case 1:
            return "Match the club to the current rep so the drill recommendation stays believable."
        default:
            return "Use the sensory language, not the technical fault label."
        }
    }

    private var availableClubs: [ClubRange] {
        guard let selectedEnv else {
            return ClubRange.allCases
        }

        if selectedEnv == .puttingGreen {
            return [.putter]
        }

        return ClubRange.allCases.filter { $0 != .putter }
    }

    private func selectEnvironment(_ environment: PracticeEnvironment) {
        selectedEnv = environment
        selectedClub = nil
        selectedFault = nil
        prescribedDrill = nil
        advance()
    }

    private func advance() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            step += 1
        }
    }

    private func backOneStep() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            switch step {
            case 1:
                if minimumStep == 0 {
                    selectedEnv = nil
                }
                selectedClub = nil
            case 2:
                selectedClub = nil
                selectedFault = nil
            default:
                break
            }

            prescribedDrill = nil
            step = max(minimumStep, step - 1)
        }
    }

    private func prescribe() {
        guard let selectedEnv else {
            return
        }

        let playbook = DrillVault.masterPlaybook

        if let exactMatch = playbook.first(where: {
            $0.environment == selectedEnv &&
            $0.clubRange == selectedClub &&
            $0.faultType == selectedFault
        }) {
            prescribedDrill = exactMatch
        } else if let faultMatch = playbook.first(where: {
            $0.environment == selectedEnv &&
            $0.faultType == selectedFault
        }) {
            prescribedDrill = faultMatch
        } else if let environmentMatch = playbook.first(where: {
            $0.environment == selectedEnv
        }) {
            prescribedDrill = environmentMatch
        } else {
            prescribedDrill = playbook.first
        }

        advance()
    }
}

private struct GarageDiagnosticStepCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 28, padding: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
    }
}

private struct DiagnosticOptionGrid<T: Hashable, Content: View>: View {
    let options: [T]
    let onSelect: (T) -> Void
    let label: (T) -> Content

    var body: some View {
        VStack(spacing: 14) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    GarageProCard(cornerRadius: 22, padding: 18) {
                        label(option)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct OptionContent: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(GarageProTheme.accent)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(GarageProTheme.accent.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.headline.weight(.bold))
                .foregroundStyle(GarageProTheme.textSecondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PrescriptionResultCard: View {
    let drill: GarageDrill
    let onStart: () -> Void

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 28, padding: 20) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prescribed Drill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.8)
                        .foregroundStyle(GarageProTheme.accent)

                    Text(drill.title)
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(drill.environment.displayName) • \(drill.clubRange.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("The Feeling")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.8)
                    .foregroundStyle(GarageProTheme.textSecondary)

                Text(drill.abstractFeelCue)
                    .font(.system(size: 18, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(GarageProTheme.accent.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(GarageProTheme.accent.opacity(0.2), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Execution")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.8)
                    .foregroundStyle(GarageProTheme.textSecondary)

                ForEach(Array(drill.executionSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.black))
                            .foregroundStyle(ModuleTheme.garageSurfaceDark)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(GarageProTheme.accent))

                        Text(step)
                            .font(.body.weight(.medium))
                            .foregroundStyle(GarageProTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Button(action: onStart) {
                HStack {
                    Spacer()

                    Label("Start Rehearsal", systemImage: "play.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(ModuleTheme.garageSurfaceDark)

                    Spacer()
                }
                .frame(minHeight: 60)
                .background(
                    LinearGradient(
                        colors: [
                            GarageProTheme.accent,
                            GarageProTheme.accent.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .shadow(color: GarageProTheme.glow.opacity(0.34), radius: 18, x: 0, y: 12)
        }
    }
}

#Preview("Garage Diagnostic") {
    NavigationStack {
        GarageDiagnosticView { _ in }
    }
}

#Preview("Garage Diagnostic Preset Environment") {
    NavigationStack {
        GarageDiagnosticView(initialEnvironment: .range) { _ in }
    }
}
