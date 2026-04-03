import SwiftData
import SwiftUI

struct IronTempleView: View {
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.performedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var isShowingAddTemplate = false
    @State private var isShowingLogSession = false
    @State private var selectedTab: ModuleHubTab = .overview

    init(initialTab: ModuleHubTab = .overview) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ModuleScreen(theme: AppModule.ironTemple.theme) {
            ModuleHeader(
                theme: AppModule.ironTemple.theme,
                title: "Iron Temple",
                subtitle: "Keep training simple, repeatable, and easy to log."
            )

            ModuleHeroCard(
                module: .ironTemple,
                eyebrow: "Training",
                title: "\(sessions.count) session\(sessions.count == 1 ? "" : "s") logged",
                message: templates.isEmpty ? "Build your first template to remove friction before the next workout." : "\(templates.count) template\(templates.count == 1 ? "" : "s") ready for repeatable sessions."
            )

            HubTabPicker(tabs: [.overview, .builder, .advisor], selectedTab: $selectedTab, theme: AppModule.ironTemple.theme)

            switch selectedTab {
            case .overview:
                IronTempleOverviewTab(
                    sessions: sessions,
                    templateCount: templates.count
                ) {
                    isShowingLogSession = true
                }
            case .builder:
                IronTempleBuilderTab(templates: templates) {
                    isShowingAddTemplate = true
                }
            case .advisor:
                ModuleRowSurface(theme: AppModule.ironTemple.theme) {
                    Text("Advisor is optional")
                        .font(ModuleTypography.cardTitle)
                        .foregroundStyle(AppModule.ironTemple.theme.textPrimary)
                    Text("Use user-triggered prompts for workout decisions. Any write action requires explicit approval.")
                        .foregroundStyle(AppModule.ironTemple.theme.textSecondary)
                    Button("Log Session") {
                        isShowingLogSession = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.ironTemple.theme.primary)
                }
            default:
                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            ModuleBottomActionBar(
                theme: AppModule.ironTemple.theme,
                title: "Log Session",
                systemImage: "plus"
            ) {
                isShowingLogSession = true
            }
        }
        .sheet(isPresented: $isShowingAddTemplate) {
            AddWorkoutTemplateSheet()
        }
        .sheet(isPresented: $isShowingLogSession) {
            LogWorkoutSessionSheet(templates: templates)
        }
    }
}

private struct IronTempleOverviewTab: View {
    let sessions: [WorkoutSession]
    let templateCount: Int
    let logSession: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.large) {
            IronTempleOverviewCard(
                templateCount: templateCount,
                sessionCount: sessions.count,
                totalMinutes: sessions.reduce(0) { $0 + $1.durationMinutes }
            )

            ModuleListSection(title: "Recent Sessions") {
                if sessions.isEmpty {
                    IronTempleEmptyStateView(
                        title: "No sessions logged",
                        message: "Record a recent workout to start building your history.",
                        actionTitle: "Log Session",
                        action: logSession
                    )
                } else {
                    ForEach(sessions.prefix(8)) { session in
                        WorkoutSessionCard(session: session)
                    }
                }
            }
        }
    }
}

private struct IronTempleBuilderTab: View {
    let templates: [WorkoutTemplate]
    let addTemplate: () -> Void

    var body: some View {
        ModuleListSection(title: "Workout Templates") {
            if templates.isEmpty {
                IronTempleEmptyStateView(
                    title: "No templates yet",
                    message: "Create a workout template so you can log sessions against a repeatable structure.",
                    actionTitle: "Create Template",
                    action: addTemplate
                )
            } else {
                ForEach(templates) { template in
                    WorkoutTemplateCard(template: template)
                }
            }
        }
    }
}

private struct IronTempleOverviewCard: View {
    let templateCount: Int
    let sessionCount: Int
    let totalMinutes: Int

    var body: some View {
        ModuleMetricStrip(theme: AppModule.ironTemple.theme) {
            ModuleMetricChip(theme: AppModule.ironTemple.theme, title: "Templates", value: "\(templateCount)")
            ModuleMetricChip(theme: AppModule.ironTemple.theme, title: "Sessions", value: "\(sessionCount)")
            ModuleMetricChip(theme: AppModule.ironTemple.theme, title: "Minutes", value: "\(totalMinutes)")
        }
    }
}

private struct WorkoutTemplateCard: View {
    let template: WorkoutTemplate

    var body: some View {
        ModuleRowSurface(theme: AppModule.ironTemple.theme) {
            HStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(AppModule.ironTemple.theme.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(AppModule.ironTemple.theme.textPrimary)
                    Text(template.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(AppModule.ironTemple.theme.textSecondary)
                }
                Spacer()
            }
        }
    }
}

private struct WorkoutSessionCard: View {
    let session: WorkoutSession

    var body: some View {
        ModuleRowSurface(theme: AppModule.ironTemple.theme) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.templateName)
                        .font(.headline)
                        .foregroundStyle(AppModule.ironTemple.theme.textPrimary)
                    Text(session.performedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(AppModule.ironTemple.theme.textSecondary)
                }

                Spacer()

                Text("\(session.durationMinutes) min")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppModule.ironTemple.theme.primary)
            }
        }
    }
}

private struct IronTempleEmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.ironTemple.theme,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
    }
}

private struct AddWorkoutTemplateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Details") {
                    TextField("Template name", text: $name)
                }
            }
            .navigationTitle("New Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedName.isEmpty == false else {
                            return
                        }

                        modelContext.insert(WorkoutTemplate(name: trimmedName))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct LogWorkoutSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTemplateName = ""
    @State private var durationMinutes = 45
    @State private var performedAt = Date()
    let templates: [WorkoutTemplate]

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Details") {
                    Picker("Template", selection: $selectedTemplateName) {
                        ForEach(templates, id: \.name) { template in
                            Text(template.name).tag(template.name)
                        }
                    }

                    Stepper(value: $durationMinutes, in: 5 ... 180, step: 5) {
                        Text("Duration: \(durationMinutes) min")
                    }

                    DatePicker("Performed", selection: $performedAt)
                }
            }
            .navigationTitle("Log Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard selectedTemplateName.isEmpty == false else {
                            return
                        }

                        modelContext.insert(
                            WorkoutSession(
                                templateName: selectedTemplateName,
                                performedAt: performedAt,
                                durationMinutes: durationMinutes
                            )
                        )
                        dismiss()
                    }
                    .disabled(selectedTemplateName.isEmpty)
                }
            }
            .onAppear {
                if selectedTemplateName.isEmpty {
                    selectedTemplateName = templates.first?.name ?? ""
                }
            }
        }
    }
}

#Preview("Iron Temple Overview") {
    PreviewScreenContainer {
        IronTempleView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
    .preferredColorScheme(.dark)
}

#Preview("Iron Temple Builder") {
    PreviewScreenContainer {
        IronTempleView(initialTab: .builder)
    }
    .modelContainer(PreviewCatalog.populatedApp)
    .preferredColorScheme(.dark)
}

#Preview("Iron Temple Empty") {
    PreviewScreenContainer {
        IronTempleView(initialTab: .builder)
    }
    .modelContainer(PreviewCatalog.emptyApp)
    .preferredColorScheme(.dark)
}
