import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var isShowingLaunchAffirmation = !LaunchAffirmationConfiguration.shouldSkip

    init(showLaunchAffirmation: Bool = !LaunchAffirmationConfiguration.shouldSkip) {
        _isShowingLaunchAffirmation = State(initialValue: showLaunchAffirmation)
    }

    var body: some View {
        ZStack {
            #if DEBUG
            if LaunchAffirmationConfiguration.shouldRunGarageAuthorityQA {
                GarageDrillAuthorityQAView()
                    .transition(.opacity)
            } else if isShowingLaunchAffirmation {
                LaunchAffirmationView()
                    .transition(.opacity)
            } else {
                AppShellView()
                    .transition(.opacity)
            }
            #else
            if isShowingLaunchAffirmation {
                LaunchAffirmationView()
                    .transition(.opacity)
            } else {
                AppShellView()
                    .transition(.opacity)
            }
            #endif
        }
        .task(id: isShowingLaunchAffirmation) {
            guard isShowingLaunchAffirmation else { return }

            try? await Task.sleep(nanoseconds: LaunchAffirmationConfiguration.durationNanoseconds)
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                isShowingLaunchAffirmation = false
            }
        }
    }
}

private enum LaunchAffirmationConfiguration {
    static let durationNanoseconds: UInt64 = 4_000_000_000
    static let skipArgument = "SKIP_LAUNCH_AFFIRMATION"
    static let garageAuthorityQAArgument = "GARAGE_DRILL_AUTHORITY_QA"
    static let garageAuthorityQASummaryArgument = "GARAGE_DRILL_AUTHORITY_QA_SUMMARY"

    static var shouldSkip: Bool {
        ProcessInfo.processInfo.arguments.contains(skipArgument)
    }

    #if DEBUG
    static var shouldRunGarageAuthorityQA: Bool {
        ProcessInfo.processInfo.arguments.contains(garageAuthorityQAArgument)
        || ProcessInfo.processInfo.arguments.contains(garageAuthorityQASummaryArgument)
    }
    #endif
}

#if DEBUG
private struct GarageDrillAuthorityQAView: View {
    var body: some View {
        NavigationStack {
            GarageActiveSessionView(
                session: ActivePracticeSession(template: Self.template),
                onEndSession: {}
            )
        }
    }

    private static var template: PracticeTemplate {
        if ProcessInfo.processInfo.arguments.contains(LaunchAffirmationConfiguration.garageAuthorityQASummaryArgument) {
            return PracticeTemplate(
                title: "Garage Authority QA",
                environment: PracticeEnvironment.range.rawValue,
                drills: [
                    qaTimedDrill(
                        title: "QA Timed Block",
                        id: GarageDrillAuthorityQAIdentifiers.timedDrillID,
                        definitionID: GarageDrillAuthorityQAIdentifiers.timedDefinitionID
                    ),
                    qaPressureDrill,
                    qaTimedDrill(
                        title: "QA Timed Target",
                        id: GarageDrillAuthorityQAIdentifiers.timedTargetDrillID,
                        definitionID: GarageDrillAuthorityQAIdentifiers.timedTargetDefinitionID
                    )
                ]
            )
        }

        return PracticeTemplate(
            title: "Garage Authority QA",
            environment: PracticeEnvironment.range.rawValue,
            drills: [
                qaTimedDrill(
                    title: "QA Timed Block",
                    id: GarageDrillAuthorityQAIdentifiers.timedDrillID,
                    definitionID: GarageDrillAuthorityQAIdentifiers.timedDefinitionID
                ),
                qaPressureDrill,
                PracticeTemplateDrill(
                    id: GarageDrillAuthorityQAIdentifiers.repsDrillID,
                    definitionID: GarageDrillAuthorityQAIdentifiers.repsDefinitionID,
                    title: "QA Reps Target",
                    focusArea: "Authority QA",
                    targetClub: "Putter",
                    defaultRepCount: 1
                )
            ]
        )
    }

    private static func qaTimedDrill(
        title: String,
        id: UUID,
        definitionID: UUID
    ) -> PracticeTemplateDrill {
        PracticeTemplateDrill(
            id: id,
            definitionID: definitionID,
            title: title,
            focusArea: "Authority QA",
            targetClub: "Wedge",
            defaultRepCount: 0
        )
    }

    private static let qaPressureDrill = PracticeTemplateDrill(
        id: GarageDrillAuthorityQAIdentifiers.pressureDrillID,
        definitionID: GarageDrillAuthorityQAIdentifiers.pressureDefinitionID,
        title: "QA Pressure Standard",
        focusArea: "Authority QA",
        targetClub: "Driver",
        defaultRepCount: 1
    )
}
#endif

#Preview("Content Launch") {
    ContentView(showLaunchAffirmation: true)
        .modelContainer(PreviewCatalog.populatedApp)
}

#Preview("Content Shell") {
    ContentView(showLaunchAffirmation: false)
        .modelContainer(PreviewCatalog.populatedApp)
}
