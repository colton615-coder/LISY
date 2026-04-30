import SwiftData
import SwiftUI

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
                    title: "Keep the next task obvious.",
                    message: "Task Protocol tracks priority, due dates, and completion state without turning into a full project manager."
                )

                ModuleVisualizationContainer(title: "Task Snapshot") {
                    HStack(spacing: 12) {
                        ModuleMetricChip(theme: AppModule.taskProtocol.theme, title: "Open", value: "\(openTasks.count)")
                        ModuleMetricChip(theme: AppModule.taskProtocol.theme, title: "Due Soon", value: "\(dueSoonTasks.count)")
                        ModuleMetricChip(theme: AppModule.taskProtocol.theme, title: "Done", value: "\(completedTasks.count)")
                    }
                }

                ModuleActivityFeedSection(title: "Current Tasks") {
                    if tasks.isEmpty {
                        ModuleEmptyStateCard(
                            theme: AppModule.taskProtocol.theme,
                            title: "No tasks yet",
                            message: "Capture the next important action and keep the list short enough to stay useful.",
                            actionTitle: "Add First Task"
                        ) {
                            isShowingAddTask = true
                        }
                    } else {
                        ForEach(tasks) { task in
                            TaskRow(task: task)
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
            AddTaskSheet()
        }
    }

    private var openTasks: [TaskItem] {
        tasks.filter { $0.isCompleted == false }
    }

    private var completedTasks: [TaskItem] {
        tasks.filter(\.isCompleted)
    }

    private var dueSoonTasks: [TaskItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        return openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate <= cutoff
        }
    }
}

private struct TaskRow: View {
    @Bindable var task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                task.isCompleted.toggle()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? AppModule.taskProtocol.theme.primary : ModuleTheme.secondaryText)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted, color: ModuleTheme.secondaryText)
                Text(taskMetaLine)
                    .font(.caption)
                    .foregroundStyle(ModuleTheme.secondaryText)
        }

            Spacer()
        }
        .padding()
        .puttingGreenSurface(cornerRadius: ModuleCornerRadius.row)
    }

    private var taskMetaLine: String {
        if let dueDate = task.dueDate {
            return "\(task.priority.capitalized) priority • due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }

        return "\(task.priority.capitalized) priority"
    }
}

private struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var priority = TaskPriority.medium
    @State private var includesDueDate = false
    @State private var dueDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)

                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { option in
                            Text(option.rawValue.capitalized).tag(option)
                        }
                    }

                    Toggle("Set due date", isOn: $includesDueDate)

                    if includesDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                .listRowBackground(ModuleTheme.elevatedSurface)
            }
            .puttingGreenFormChrome()
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedTitle.isEmpty == false else { return }

                        modelContext.insert(
                            TaskItem(
                                title: trimmedTitle,
                                priority: priority.rawValue,
                                dueDate: includesDueDate ? dueDate : nil
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .puttingGreenSheetChrome()
    }
}

#Preview("Task Protocol Empty") {
    PreviewScreenContainer {
        TaskProtocolView()
    }
    .modelContainer(PreviewCatalog.emptyApp)
}

#Preview("Task Protocol Populated") {
    PreviewScreenContainer {
        TaskProtocolView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
