import SwiftData
import SwiftUI

struct HabitStackView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query(sort: \HabitEntry.loggedAt, order: .reverse) private var entries: [HabitEntry]
    @State private var isShowingAddHabit = false

    var body: some View {
        ModuleScreen(theme: AppModule.habitStack.theme) {
            ModuleHeader(
                theme: AppModule.habitStack.theme,
                title: "Habit Stack",
                subtitle: "Build recurring momentum with daily habits and simple repeatable actions."
            )

            ModuleHeroCard(
                module: .habitStack,
                eyebrow: "Today",
                title: todayHabitSummaryTitle,
                message: habits.isEmpty ? "Start with one recurring behavior you want to reinforce daily." : "Track progress throughout the day and keep the focus on what still needs a rep."
            )

            HabitOverviewCard(
                habitCount: habits.count,
                completedTodayCount: habits.filter(isHabitCompletedToday).count,
                totalTodayProgress: entriesForToday.reduce(0) { $0 + $1.count }
            )

            ModuleListSection(title: "Today's Habits") {
                if habits.isEmpty {
                    HabitEmptyStateView {
                        isShowingAddHabit = true
                    }
                } else {
                    ForEach(habits) { habit in
                        HabitCard(
                            habit: habit,
                            progressCount: progressCount(for: habit),
                            streakCount: streakCount(for: habit),
                            lastLoggedAt: lastLoggedAt(for: habit),
                            incrementAction: { logProgress(for: habit) },
                            decrementAction: { removeProgress(for: habit) }
                        )
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ModuleBottomActionBar(
                theme: AppModule.habitStack.theme,
                title: "Add Habit",
                systemImage: "plus"
            ) {
                isShowingAddHabit = true
            }
        }
        .sheet(isPresented: $isShowingAddHabit) {
            AddHabitSheet { name, targetCount in
                addHabit(name: name, targetCount: targetCount)
            }
        }
    }

    private var todayHabitSummaryTitle: String {
        let completed = habits.filter(isHabitCompletedToday).count
        return "\(completed) of \(habits.count) complete"
    }

    private var entriesForToday: [HabitEntry] {
        entries.filter { Calendar.current.isDateInToday($0.loggedAt) }
    }

    private func progressCount(for habit: Habit) -> Int {
        entriesForToday
            .filter { $0.habitID == habit.id }
            .reduce(0) { $0 + $1.count }
    }

    private func isHabitCompletedToday(_ habit: Habit) -> Bool {
        progressCount(for: habit) >= habit.targetCount
    }

    private func lastLoggedAt(for habit: Habit) -> Date? {
        entries.first(where: { $0.habitID == habit.id })?.loggedAt
    }

    private func streakCount(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: entries.filter { $0.habitID == habit.id }) {
            calendar.startOfDay(for: $0.loggedAt)
        }

        var streak = 0
        var cursor = calendar.startOfDay(for: .now)

        while let dayEntries = groupedByDay[cursor] {
            let total = dayEntries.reduce(0) { $0 + $1.count }
            if total < habit.targetCount {
                break
            }
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return streak
    }

    private func addHabit(name: String, targetCount: Int) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            return
        }

        let habit = Habit(name: trimmedName, targetCount: targetCount)
        modelContext.insert(habit)
    }

    private func logProgress(for habit: Habit) {
        let entry = HabitEntry(habitID: habit.id, habitName: habit.name)
        modelContext.insert(entry)
    }

    private func removeProgress(for habit: Habit) {
        guard let latestEntry = entries.first(where: {
            $0.habitID == habit.id && Calendar.current.isDateInToday($0.loggedAt)
        }) else {
            return
        }

        modelContext.delete(latestEntry)
    }
}

private struct HabitOverviewCard: View {
    let habitCount: Int
    let completedTodayCount: Int
    let totalTodayProgress: Int

    var body: some View {
        ModuleMetricStrip(theme: AppModule.habitStack.theme) {
            ModuleMetricChip(theme: AppModule.habitStack.theme, title: "Habits", value: "\(habitCount)")
            ModuleMetricChip(theme: AppModule.habitStack.theme, title: "Completed", value: "\(completedTodayCount)")
            ModuleMetricChip(theme: AppModule.habitStack.theme, title: "Logs", value: "\(totalTodayProgress)")
        }
    }
}

private struct HabitEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.habitStack.theme,
            title: "No habits yet",
            message: "Start with one recurring behavior you want to reinforce daily. Habit Stack will track progress and streaks from there.",
            actionTitle: "Create First Habit",
            action: action
        )
    }
}

private struct HabitCard: View {
    let habit: Habit
    let progressCount: Int
    let streakCount: Int
    let lastLoggedAt: Date?
    let incrementAction: () -> Void
    let decrementAction: () -> Void

    private var progressValue: Double {
        guard habit.targetCount > 0 else { return 0 }
        return min(Double(progressCount) / Double(habit.targetCount), 1)
    }

    var body: some View {
        ModuleRowSurface(theme: AppModule.habitStack.theme) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(habit.name)
                        .font(.headline)
                        .foregroundStyle(AppModule.habitStack.theme.textPrimary)
                    Text("\(progressCount) of \(habit.targetCount) today")
                        .font(.subheadline)
                        .foregroundStyle(AppModule.habitStack.theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Label("\(streakCount) day streak", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(AppModule.habitStack.theme.primary)
                    if let lastLoggedAt {
                        Text(lastLoggedAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(AppModule.habitStack.theme.textSecondary)
                    }
                }
            }

            ProgressView(value: progressValue)
                .tint(AppModule.habitStack.theme.primary)

            HStack {
                Button {
                    decrementAction()
                } label: {
                    Label("Undo", systemImage: "minus")
                }
                .buttonStyle(.bordered)
                .disabled(progressCount == 0)

                Spacer()

                Button {
                    incrementAction()
                } label: {
                    Label("Log Progress", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppModule.habitStack.theme.primary)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous)
                .stroke(progressCount >= habit.targetCount ? AppModule.habitStack.theme.borderStrong : .clear, lineWidth: 1.5)
        )
    }
}

private struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var targetCount = 1
    let onSave: (String, Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit Details") {
                    TextField("Habit name", text: $name)

                    Stepper(value: $targetCount, in: 1 ... 12) {
                        Text("Daily target: \(targetCount)")
                    }
                }
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, targetCount)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview("Habit Stack Empty") {
    PreviewScreenContainer {
        HabitStackView()
    }
    .modelContainer(PreviewCatalog.emptyApp)
    .preferredColorScheme(.dark)
}

#Preview("Habit Stack Active") {
    PreviewScreenContainer {
        HabitStackView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
    .preferredColorScheme(.dark)
}
