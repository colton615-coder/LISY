import Foundation
import SwiftData
import SwiftUI

@MainActor
struct GarageView: View {
    @State private var path: [GarageNavigationDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            GarageHomeTabView(
                onOpenEnvironment: { environment in
                    garageTriggerSelection()
                    path.append(.drillPlans(environment))
                },
                onStartTempoBuilder: {
                    garageTriggerSelection()
                    path.append(.tempoBuilder)
                },
                onNewJournalEntry: {
                    garageTriggerSelection()
                    path.append(.journalNewEntry)
                },
                onOpenJournalArchive: {
                    garageTriggerSelection()
                    path.append(.journalArchive)
                }
            )
                .navigationDestination(for: GarageNavigationDestination.self) { destination in
                    switch destination {
                    case let .drillPlans(environment):
                        GarageEnvironmentDrillPlansView(
                            environment: environment,
                            onOpenSavedRoutines: {
                                garageTriggerSelection()
                                path.append(.savedRoutines(environment))
                            },
                            onGenerateRoutine: {
                                garageTriggerSelection()
                                path.append(.generateRoutine(environment))
                            },
                            onBuildRoutine: {
                                garageTriggerSelection()
                                path.append(.buildRoutine(environment))
                            }
                        )
                    case let .savedRoutines(environment):
                        GarageSavedRoutinesView(
                            environment: environment,
                            onReviewRoutine: { reviewPlan in
                                garageTriggerSelection()
                                path.append(.routineReview(reviewPlan))
                            },
                            onGenerateRoutine: {
                                garageTriggerSelection()
                                path.append(.generateRoutine(environment))
                            },
                            onBuildRoutine: {
                                garageTriggerSelection()
                                path.append(.buildRoutine(environment))
                            }
                        )
                    case let .generateRoutine(environment):
                        GarageGenerateRoutineView(
                            environment: environment,
                            onReviewPlan: { plan in
                                garageTriggerSelection()
                                path.append(.routineReview(GarageRoutineReviewPlan(generatedPlan: plan)))
                            },
                            onOpenSavedRoutines: {
                                garageTriggerSelection()
                                path.append(.savedRoutines(environment))
                            }
                        )
                    case let .buildRoutine(environment):
                        GarageTemplateBuilderWizard(initialEnvironment: environment)
                    case .tempoBuilder:
                        GarageTempoBuilderView()
                    case .journalNewEntry:
                        GarageJournalNewEntryView()
                    case .journalArchive:
                        GarageJournalArchiveView()
                    case .vault:
                        GarageSkillVaultView()
                    case .drillLibrary:
                        GarageDrillLibraryView { template in
                            garageTriggerSelection()
                            path.append(.activeSession(ActivePracticeSession(template: template)))
                        }
                    case let .routineReview(reviewPlan):
                        GarageRoutineReviewView(reviewPlan: reviewPlan) { reviewedPlan in
                            garageTriggerSelection()
                            path.append(.activeSession(ActivePracticeSession(template: reviewedPlan.makePracticeTemplate())))
                        }
                    case let .coachPlan(plan):
                        GarageCoachPlanReviewView(plan: plan) { reviewedPlan in
                            garageTriggerSelection()
                            path.append(.activeSession(ActivePracticeSession(template: reviewedPlan.makePracticeTemplate())))
                        }
                    case let .diagnostic(environment):
                        GarageDiagnosticView(initialEnvironment: environment) { drill in
                            garageTriggerSelection()
                            path.append(.activeSession(ActivePracticeSession(template: drill.makePracticeTemplate())))
                        }
                    case let .activeSession(session):
                        GarageActiveSessionView(
                            session: session,
                            onEndSession: {
                                path.removeAll()
                                path.append(.vault)
                            }
                        )
                    case let .sessionRecord(record):
                        GarageSessionDetailView(
                            record: record,
                            allowsInsightGeneration: false
                        )
                    }
                }
        }
        .garagePuttingGreenSheetChrome()
    }
}

private enum GarageNavigationDestination: Hashable {
    case drillPlans(PracticeEnvironment)
    case savedRoutines(PracticeEnvironment)
    case generateRoutine(PracticeEnvironment)
    case buildRoutine(PracticeEnvironment)
    case tempoBuilder
    case journalNewEntry
    case journalArchive
    case vault
    case drillLibrary
    case routineReview(GarageRoutineReviewPlan)
    case coachPlan(GarageGeneratedPracticePlan)
    case diagnostic(PracticeEnvironment?)
    case activeSession(ActivePracticeSession)
    case sessionRecord(PracticeSessionRecord)
}

#Preview("Garage v2 Root") {
    GarageView()
        .modelContainer(PreviewCatalog.populatedApp)
}
