import SwiftUI

@MainActor
struct GarageView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose where you are practicing right now. Garage will only show the routines that make sense for that environment.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Section("Practice Environment") {
                    ForEach(PracticeEnvironment.allCases) { environment in
                        NavigationLink {
                            destination(for: environment)
                        } label: {
                            GarageEnvironmentSelectionRow(environment: environment)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Garage")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func destination(for environment: PracticeEnvironment) -> some View {
        switch environment {
        case .net:
            GarageNetDashboardView()
        case .range:
            GarageRangeDashboardView()
        case .puttingGreen:
            GaragePuttingDashboardView()
        }
    }
}

@MainActor
struct GarageNetDashboardView: View {
    var body: some View {
        GarageEnvironmentDashboardView(environment: .net)
    }
}

@MainActor
struct GarageRangeDashboardView: View {
    var body: some View {
        GarageEnvironmentDashboardView(environment: .range)
    }
}

@MainActor
struct GaragePuttingDashboardView: View {
    var body: some View {
        GarageEnvironmentDashboardView(environment: .puttingGreen)
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
                    .foregroundStyle(.primary)

                Text(environment.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        }
    }
}

@MainActor
private struct GarageEnvironmentDashboardView: View {
    let environment: PracticeEnvironment

    private var templates: [PracticeTemplate] {
        PracticeTemplate.starterTemplates.filter { $0.environments.contains(environment) }
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
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }

            ForEach(templates) { template in
                Section(template.title) {
                    ForEach(template.drills) { drill in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(drill.title)
                                    .font(.headline)
                                Text(drill.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(environment.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Garage Environment Selector") {
    GarageView()
}

#Preview("Garage Net Dashboard") {
    NavigationStack {
        GarageNetDashboardView()
    }
}
