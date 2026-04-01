import SwiftData
import SwiftUI

struct IronTempleView: View {
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.performedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var isShowingAddTemplate = false
    @State private var isShowingLogSession = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModuleHeroCard(
                    module: .ironTemple,
                    eyebrow: "Live Module",
                    title: "Keep training simple and repeatable.",
                    message: "Iron Temple starts with named workout templates, quick session logging, and a clear view of recent work."
                )

                IronTempleOverviewCard(
                    templateCount: templates.count,
                    sessionCount: sessions.count,
                    totalMinutes: sessions.reduce(0) { $0 + $1.durationMinutes }
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Workout Templates")
                            .font(.headline)
                        Spacer()
                        Button("Add Template") {
                            isShowingAddTemplate = true
                        }
                        .buttonStyle(.bordered)
                    }

                    if templates.isEmpty {
                        IronTempleEmptyStateView(
                            title: "No templates yet",
                            message: "Create a workout template so you can log sessions against a repeatable structure.",
                            actionTitle: "Create Template",
                            action: { isShowingAddTemplate = true }
                        )
                    } else {
                        ForEach(templates) { template in
                            WorkoutTemplateCard(template: template)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Sessions")
                        .font(.headline)

                    if sessions.isEmpty {
                        IronTempleEmptyStateView(
                            title: "No sessions logged",
                            message: "Record a recent workout to start building your history.",
                            actionTitle: "Log Session",
                            action: { isShowingLogSession = true }
                        )
                    } else {
                        ForEach(sessions.prefix(8)) { session in
                            WorkoutSessionCard(session: session)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppModule.ironTemple.theme.screenGradient)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    isShowingLogSession = true
                } label: {
                    Label("Log Session", systemImage: "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppModule.ironTemple.theme.primary)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $isShowingAddTemplate) {
            AddWorkoutTemplateSheet()
        }
        .sheet(isPresented: $isShowingLogSession) {
            LogWorkoutSessionSheet(templates: templates)
        }
    }
}

private struct IronTempleOverviewCard: View {
    let templateCount: Int
    let sessionCount: Int
    let totalMinutes: Int

    var body: some View {
        ModuleSnapshotCard(title: "Training Snapshot") {
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
