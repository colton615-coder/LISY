import Foundation
import SwiftData
import SwiftUI

@MainActor
struct GarageView: View {
    @State private var path: [GarageNavigationDestination] = []
    @State private var selectedTab: GarageRootTab = .home

    var body: some View {
        NavigationStack(path: $path) {
            tabRoot
                .navigationDestination(for: GarageNavigationDestination.self) { destination in
                    switch destination {
                    case let .environment(environment):
                        GarageEnvironmentFocusView(
                            environment: environment,
                            onGeneratePlan: { plan in
                                garageTriggerSelection()
                                path.append(.coachPlan(plan))
                            },
                            onSelectTemplate: { template in
                                garageTriggerSelection()
                                path.append(.activeSession(ActivePracticeSession(template: template)))
                            },
                            onOpenDiagnostic: {
                                garageTriggerSelection()
                                path.append(.diagnostic(environment))
                            }
                        )
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
                                selectedTab = .vault
                            }
                        )
                    case let .sessionRecord(record):
                        GarageSessionDetailView(
                            record: record,
                            allowsInsightGeneration: false
                        )
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if path.isEmpty && selectedTab != .home {
                        GarageInternalTabBar(selectedTab: $selectedTab)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                    }
                }
        }
        .garagePuttingGreenSheetChrome()
    }

    @ViewBuilder
    private var tabRoot: some View {
        switch selectedTab {
        case .home:
            GarageHomeTabView(
                selectedTab: $selectedTab,
                onStartRoutine: { routine in
                    garageTriggerSelection()
                    path.append(.activeSession(ActivePracticeSession(template: routine.makePracticeTemplate())))
                },
                onGenerateRoutine: { environment, recentRecords in
                    garageTriggerSelection()
                    path.append(.coachPlan(GarageLocalCoachPlanner.generatePlan(for: environment, recentRecords: recentRecords)))
                },
                onOpenLatestSession: { record in
                    garageTriggerSelection()
                    path.append(.sessionRecord(record))
                }
            )
        case .vault:
            GarageSkillVaultView()
        case .drills:
            GarageDrillLibraryView { template in
                garageTriggerSelection()
                path.append(.activeSession(ActivePracticeSession(template: template)))
            }
        }
    }
}

private enum GarageNavigationDestination: Hashable {
    case environment(PracticeEnvironment)
    case coachPlan(GarageGeneratedPracticePlan)
    case diagnostic(PracticeEnvironment?)
    case activeSession(ActivePracticeSession)
    case sessionRecord(PracticeSessionRecord)
}

enum GarageRootTab: String, CaseIterable, Identifiable {
    case home
    case vault
    case drills

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            "Home"
        case .vault:
            "Vault"
        case .drills:
            "Drills"
        }
    }

    var navigationTitle: String {
        switch self {
        case .home:
            "Garage"
        case .vault:
            "Vault"
        case .drills:
            "Drill Library"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house.fill"
        case .vault:
            "archivebox.fill"
        case .drills:
            "book.closed.fill"
        }
    }
}

#Preview("Garage v2 Root") {
    GarageView()
        .modelContainer(PreviewCatalog.populatedApp)
}
