import SwiftData
import SwiftUI

enum TaskPriority: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .low:
            "arrow.down.circle"
        case .medium:
            "equal.circle"
        case .high:
            "arrow.up.circle"
        }
    }

    var color: Color {
        switch self {
        case .low:
            .green
        case .medium:
            .orange
        case .high:
            .red
        }
    }
}

struct TaskProtocolView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @State private var isShowingAddTask = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModuleHeroCard(
                    module: .taskProtocol,
                    eyebrow: "Live Module",
                    title: "Capture one-off work and keep it moving.",
                    message: "Task Protocol stays intentionally simple: add tasks, mark them complete, and keep due dates visible."
                )

                TaskOverviewCard(
                    openCount: openTasks.count,
                    completedCount: completedTasks.count,
                    overdueCount: overdueTasks.count
                )

                ModuleActivityFeedSection(title: "Open Tasks") {
                    if openTasks.isEmpty {
                        TaskEmptyStateView(
                            title: "No open tasks",
                            message: "Capture the next one-off action you want to move forward.",
                            actionTitle: "Add Task",
                            action: { isShowingAddTask = true }
                        )
                    } else {
                        ForEach(openTasks) { task in
                            TaskCard(
                                task: task,
                                priority: priority(for: task),
                                isOverdue: isOverdue(task),
                                toggleCompletion: { toggleCompletion(for: task) }
                            )
                        }
                    }
                }

                if completedTasks.isEmpty == false {
                    ModuleActivityFeedSection(title: "Completed") {
                        ForEach(completedTasks.prefix(5)) { task in
                            TaskCard(
                                task: task,
                                priority: priority(for: task),
                                isOverdue: false,
                                toggleCompletion: { toggleCompletion(for: task) }
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppModule.taskProtocol.theme.screenGradient)
        .safeAreaInset(edge: .bottom) {
            ModuleBottomActionBar(
                theme: AppModule.taskProtocol.theme,
                title: "Add Task",
                systemImage: "plus"
            ) {
                isShowingAddTask = true
            }
        }
        .sheet(isPresented: $isShowingAddTask) {
            AddTaskSheet { title, priority, dueDate in
                addTask(title: title, priority: priority, dueDate: dueDate)
            }
        }
    }

    private var openTasks: [TaskItem] {
        tasks.filter { $0.isCompleted == false }
    }

    private var completedTasks: [TaskItem] {
        tasks.filter(\.isCompleted)
    }

    private var overdueTasks: [TaskItem] {
        tasks.filter { isOverdue($0) && $0.isCompleted == false }
    }

    private func priority(for task: TaskItem) -> TaskPriority {
        TaskPriority(rawValue: task.priority) ?? .medium
    }

    private func isOverdue(_ task: TaskItem) -> Bool {
        guard let dueDate = task.dueDate else {
            return false
        }

        return dueDate < .now && task.isCompleted == false
    }

    private func addTask(title: String, priority: TaskPriority, dueDate: Date?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else {
            return
        }

        modelContext.insert(
            TaskItem(
                title: trimmedTitle,
                priority: priority.rawValue,
                dueDate: dueDate
            )
        )
    }

    private func toggleCompletion(for task: TaskItem) {
        task.isCompleted.toggle()
    }
}

private struct TaskOverviewCard: View {
    let openCount: Int
    let completedCount: Int
    let overdueCount: Int

    var body: some View {
        ModuleVisualizationContainer(title: "Queue Snapshot") {
            HStack(spacing: 12) {
                ModuleMetricChip(theme: AppModule.taskProtocol.theme, title: "Open", value: "\(openCount)")
                ModuleMetricChip(theme: AppModule.taskProtocol.theme, title: "Completed", value: "\(completedCount)")
                ModuleMetricChip(theme: AppModule.taskProtocol.theme, title: "Overdue", value: "\(overdueCount)")
            }
        }
    }
}

private struct TaskEmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.taskProtocol.theme,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
    }
}

private struct TaskCard: View {
    let task: TaskItem
    let priority: TaskPriority
    let isOverdue: Bool
    let toggleCompletion: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: toggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? AppModule.taskProtocol.theme.primary : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted, color: .secondary)

                HStack(spacing: 8) {
                    Label(priority.title, systemImage: priority.systemImage)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(priority.color.opacity(0.14), in: Capsule())

                    if let dueDate = task.dueDate {
                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isOverdue ? Color.red.opacity(0.16) : AppModule.taskProtocol.theme.chipBackground, in: Capsule())
                    }
                }

                if isOverdue {
                    Text("Overdue")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                .stroke(isOverdue ? Color.red.opacity(0.35) : .clear, lineWidth: 1.5)
        )
    }
}

private struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedPriority: TaskPriority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    let onSave: (String, TaskPriority, Date?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task title", text: $title)

                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }

                    Toggle("Add due date", isOn: $hasDueDate.animation())

                    if hasDueDate {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, selectedPriority, hasDueDate ? dueDate : nil)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview("Task Protocol Empty") {
    PreviewScreenContainer {
        TaskProtocolView()
    }
    .modelContainer(PreviewCatalog.emptyApp)
}

#Preview("Task Protocol Queue") {
    PreviewScreenContainer {
        TaskProtocolView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
