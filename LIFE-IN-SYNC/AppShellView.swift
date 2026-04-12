import SwiftData
import SwiftUI

struct AppShellView: View {
    @State private var selectedModule: AppModule = .dashboard
    @State private var isShowingModuleMenu = false

    init(initialModule: AppModule = .dashboard) {
        _selectedModule = State(initialValue: initialModule)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                selectedModule.theme.screenGradient
                    .ignoresSafeArea()

                currentModuleView
                    .navigationTitle(selectedModule.navigationTitle)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                isShowingModuleMenu = true
                            } label: {
                                Label("Modules", systemImage: "square.grid.2x2")
                            }
                            .accessibilityIdentifier("open-module-menu")
                        }

                        ToolbarItem(placement: .automatic) {
                            if selectedModule != .dashboard {
                                Button("Dashboard") {
                                    selectedModule = .dashboard
                                }
                                .accessibilityIdentifier("return-to-dashboard")
                            }
                        }
                    }
                    .tint(selectedModule.tintColor)
            }
        }
        .sheet(isPresented: $isShowingModuleMenu) {
            NavigationStack {
                ModuleMenuView(selectedModule: $selectedModule)
                    .tint(selectedModule.tintColor)
            }
        }
    }

    @ViewBuilder
    private var currentModuleView: some View {
        switch selectedModule {
        case .dashboard:
            DashboardView(selectedModule: $selectedModule)
        case .capitalCore:
            CapitalCoreView()
        case .ironTemple:
            IronTempleView()
        case .garage:
            GarageView()
        case .habitStack:
            HabitStackView()
        case .taskProtocol:
            TaskProtocolView()
        case .calendar:
            CalendarView()
        case .bibleStudy:
            BibleStudyView()
        case .supplyList:
            SupplyListView()
        }
    }
}

#Preview("Shell Dashboard") {
    AppShellView()
        .modelContainer(PreviewCatalog.populatedApp)
}

#Preview("Shell Calendar") {
    AppShellView(initialModule: .calendar)
        .modelContainer(PreviewCatalog.populatedApp)
}
