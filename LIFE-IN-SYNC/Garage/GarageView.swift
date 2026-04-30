import SwiftData
import SwiftUI

@MainActor
struct GarageView: View {
    @State private var path: [GarageNavigationDestination] = []
    @State private var isShowingTemplateBuilder = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Text("Choose where you are practicing right now. Garage will only show the routines that make sense for that environment.")
                        .font(.body)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }
                .listRowBackground(ModuleTheme.garageSurface)

                Section("Practice Environment") {
                    ForEach(PracticeEnvironment.allCases) { environment in
                        NavigationLink(value: GarageNavigationDestination.environment(environment)) {
                            GarageEnvironmentSelectionRow(environment: environment)
                        }
                    }
                }
                .listRowBackground(ModuleTheme.garageSurface)
            }
            .listStyle(.insetGrouped)
            .garagePuttingGreenListChrome()
            .navigationTitle("Garage")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        path.append(.skillVault)
                    } label: {
                        Label("Skill Vault", systemImage: "archivebox")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingTemplateBuilder = true
                    } label: {
                        Label("New Template", systemImage: "plus")
                    }
                }
            }
            .tint(AppModule.garage.tintColor)
            .navigationDestination(for: GarageNavigationDestination.self) { destination in
                switch destination {
                case let .environment(environment):
                    environmentDashboard(for: environment)
                case let .activeSession(session):
                    GarageActiveSessionView(
                        session: session,
                        onEndSession: { path.removeAll() }
                    )
                case .skillVault:
                    GarageSkillVaultView()
                }
            }
            .sheet(isPresented: $isShowingTemplateBuilder) {
                GarageTemplateBuilderWizard()
            }
        }
        .garagePuttingGreenSheetChrome()
    }

    @ViewBuilder
    private func environmentDashboard(for environment: PracticeEnvironment) -> some View {
        switch environment {
        case .net:
            GarageNetDashboardView { template in
                path.append(.activeSession(ActivePracticeSession(template: template)))
            }
        case .range:
            GarageRangeDashboardView { template in
                path.append(.activeSession(ActivePracticeSession(template: template)))
            }
        case .puttingGreen:
            GaragePuttingDashboardView { template in
                path.append(.activeSession(ActivePracticeSession(template: template)))
            }
        }
    }
}

@MainActor
struct GarageNetDashboardView: View {
    let onSelectTemplate: (PracticeTemplate) -> Void

    var body: some View {
        GarageEnvironmentDashboardView(
            environment: .net,
            onSelectTemplate: onSelectTemplate
        )
    }
}

@MainActor
struct GarageRangeDashboardView: View {
    let onSelectTemplate: (PracticeTemplate) -> Void

    var body: some View {
        GarageEnvironmentDashboardView(
            environment: .range,
            onSelectTemplate: onSelectTemplate
        )
    }
}

@MainActor
struct GaragePuttingDashboardView: View {
    let onSelectTemplate: (PracticeTemplate) -> Void

    var body: some View {
        GarageEnvironmentDashboardView(
            environment: .puttingGreen,
            onSelectTemplate: onSelectTemplate
        )
    }
}

@MainActor
private struct GarageEnvironmentSelectionRow: View {
    let environment: PracticeEnvironment

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: environment.systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppModule.garage.tintColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 6) {
                Text(environment.displayName)
                    .font(.system(.title3, design: .default).weight(.bold))
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                Text(environment.description)
                    .font(.subheadline)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        }
    }
}

@MainActor
private struct GarageEnvironmentDashboardView: View {
    @Query(sort: \PracticeTemplate.title) private var allTemplates: [PracticeTemplate]

    let environment: PracticeEnvironment
    let onSelectTemplate: (PracticeTemplate) -> Void

    private var templates: [PracticeTemplate] {
        allTemplates.filter { $0.environment == environment.rawValue }
    }

    var body: some View {
        List {
            Section("Current Focus") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: environment.systemImage)
                        .foregroundStyle(AppModule.garage.tintColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(environment.displayName)
                            .font(.headline)
                        Text(environment.description)
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(ModuleTheme.garageSurface)

            Section("Templates") {
                if templates.isEmpty {
                    Text("No templates exist for this environment yet. Use the + button to build one.")
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                } else {
                    ForEach(templates, id: \.id) { template in
                        Button {
                            onSelectTemplate(template)
                        } label: {
                            GarageTemplateRow(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowBackground(ModuleTheme.garageSurface)
        }
        .listStyle(.insetGrouped)
        .garagePuttingGreenListChrome()
        .navigationTitle(environment.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
private struct GarageTemplateRow: View {
    let template: PracticeTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(template.title)
                .font(.headline)

            Text("\(template.drills.count) drills")
                .font(.subheadline)
                .foregroundStyle(AppModule.garage.theme.textSecondary)

            if let firstDrill = template.drills.first {
                Text(firstDrill.title)
                    .font(.footnote)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Garage Environment Selector") {
    GarageView()
        .modelContainer(PreviewCatalog.populatedApp)
}

#Preview("Garage Net Dashboard") {
    NavigationStack {
        GarageNetDashboardView { _ in }
    }
    .modelContainer(PreviewCatalog.populatedApp)
}

private enum GarageNavigationDestination: Hashable {
    case environment(PracticeEnvironment)
    case activeSession(ActivePracticeSession)
    case skillVault
}
