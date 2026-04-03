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
            currentModuleView
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(navigationTitleDisplayMode)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isShowingModuleMenu = true
                        } label: {
                            ModuleMenuToolbarButton(theme: selectedModule.theme)
                        }
                        .accessibilityLabel("Modules")
                        .accessibilityIdentifier("open-module-menu")
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        if selectedModule != .dashboard {
                            Button {
                                selectedModule = .dashboard
                            } label: {
                                Label("Dashboard", systemImage: "chevron.left")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .accessibilityIdentifier("return-to-dashboard")
                        }
                    }
                }
                .tint(selectedModule.tintColor)
                .toolbarBackground(toolbarBackgroundVisibility, for: .navigationBar)
                .toolbarBackground(toolbarBackgroundColor, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .background(selectedModule.theme.screenGradient.ignoresSafeArea())
        }
        .sheet(isPresented: $isShowingModuleMenu) {
            NavigationStack {
                ModuleMenuView(selectedModule: $selectedModule)
                    .tint(selectedModule.tintColor)
            }
            .presentationDragIndicator(.visible)
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

    private var toolbarBackgroundVisibility: Visibility {
        selectedModule == .dashboard ? .hidden : .visible
    }

    private var navigationTitle: String {
        selectedModule == .dashboard ? "" : selectedModule.navigationTitle
    }

    private var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode {
        selectedModule == .dashboard ? .inline : .large
    }

    private var toolbarBackgroundColor: Color {
        selectedModule == .dashboard
            ? .clear
            : selectedModule.theme.canvasBase.opacity(0.98)
    }
}

private struct ModuleMenuToolbarButton: View {
    let theme: ModuleTheme

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.surfaceInteractive.opacity(0.95),
                            theme.surfaceSecondary.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(theme.borderStrong.opacity(0.5), lineWidth: 1)

            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.textPrimary.opacity(0.92))
        }
        .frame(width: 40, height: 40)
        .shadow(color: theme.accentGlow.opacity(0.22), radius: 10, y: 4)
    }
}

#Preview("Shell Dashboard") {
    AppShellView()
        .modelContainer(PreviewCatalog.populatedApp)
        .preferredColorScheme(.dark)
}

#Preview("Shell Calendar") {
    AppShellView(initialModule: .calendar)
        .modelContainer(PreviewCatalog.populatedApp)
        .preferredColorScheme(.dark)
}
