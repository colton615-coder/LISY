import SwiftData
import SwiftUI

struct IronTempleView: View {
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.performedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var isShowingAddTemplate = false
    @State private var isShowingLogSession = false
    @State private var selectedTab: ModuleHubTab = .overview

    var body: some View {
        ModuleHubScaffold(
            module: .ironTemple,
            title: "Keep training simple and repeatable.",
            subtitle: "Separate template building from session execution and keep entries clean.",
            currentState: "\(sessions.count) sessions logged and \(templates.count) templates available.",
            nextAttention: templates.isEmpty ? "Build your first template to remove friction." : "Log your next workout session today.",
            tabs: [.overview, .builder, .advisor],
            selectedTab: $selectedTab
        ) {
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
                ModuleEmptyStateCard(
                    theme: AppModule.ironTemple.theme,
                    title: "Advisor is optional",
                    message: "Use user-triggered prompts for workout decisions. Any write action requires explicit approval.",
                    actionTitle: "Log Session",
                    action: { isShowingLogSession = true }
                )
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
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            IronTempleOverviewCard(
                templateCount: templateCount,
                sessionCount: sessions.count,
                totalMinutes: sessions.reduce(0) { $0 + $1.durationMinutes }
            )

            ModuleActivityFeedSection(title: "Recent Sessions") {
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
        ModuleActivityFeedSection(title: "Workout Templates") {
            HStack {
                Spacer()
                Button("Add Template", action: addTemplate)
                    .buttonStyle(.bordered)
            }

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
        ModuleVisualizationContainer(title: "Training Snapshot") {
            HStack(spacing: 12) {
                ModuleMetricChip(theme: AppModule.ironTemple.theme, title: "Templates", value: "\(templateCount)")
                ModuleMetricChip(theme: AppModule.ironTemple.theme, title: "Sessions", value: "\(sessionCount)")
                ModuleMetricChip(theme: AppModule.ironTemple.theme, title: "Minutes", value: "\(totalMinutes)")
            }
        }
    }
}

private struct WorkoutTemplateCard: View {
    let template: WorkoutTemplate

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(AppModule.ironTemple.theme.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                Text(template.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct WorkoutSessionCard: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.templateName)
                    .font(.headline)
                Text(session.performedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(session.durationMinutes) min")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppModule.ironTemple.theme.primary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
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

#Preview("Iron Temple") {
    PreviewScreenContainer {
        IronTempleView()
    }
    .modelContainer(for: [WorkoutTemplate.self, WorkoutSession.self], inMemory: true)
}
