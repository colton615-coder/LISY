import SwiftData
import SwiftUI

struct CalendarView: View {
    @Query(sort: \CalendarEvent.startDate) private var events: [CalendarEvent]
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var isShowingAddEvent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModuleHeroCard(
                    module: .calendar,
                    eyebrow: "Live Module",
                    title: "Keep the day visible.",
                    message: "Calendar owns time-based planning. It stays simple here: choose a day, create events, and review tasks with due dates."
                )

                CalendarDateCard(selectedDate: $selectedDate)

                VStack(alignment: .leading, spacing: 12) {
                    Text(daySectionTitle)
                        .font(.headline)

                    if eventsForSelectedDate.isEmpty {
                        CalendarEmptyStateView(
                            title: "No events on this day",
                            message: "Add a time block or appointment to start shaping the agenda.",
                            actionTitle: "Add Event",
                            action: { isShowingAddEvent = true }
                        )
                    } else {
                        ForEach(eventsForSelectedDate) { event in
                            CalendarEventCard(event: event)
                        }
                    }
                }

                if dueTasksForSelectedDate.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tasks Due")
                            .font(.headline)

                        ForEach(dueTasksForSelectedDate) { task in
                            CalendarTaskCard(task: task)
                        }
                    }
                }

                if upcomingEvents.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming")
                            .font(.headline)

                        ForEach(upcomingEvents.prefix(5)) { event in
                            CalendarEventCard(event: event)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppModule.calendar.theme.screenGradient)
        .safeAreaInset(edge: .bottom) {
            ModuleBottomActionBar(
                theme: AppModule.calendar.theme,
                title: "Add Event",
                systemImage: "plus"
            ) {
                isShowingAddEvent = true
            }
        }
        .sheet(isPresented: $isShowingAddEvent) {
            AddEventSheet(defaultDate: selectedDate)
        }
    }

    private var daySectionTitle: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today's Agenda"
        }

        return selectedDate.formatted(date: .complete, time: .omitted)
    }

    private var eventsForSelectedDate: [CalendarEvent] {
        let calendar = Calendar.current
        return events.filter { calendar.isDate($0.startDate, inSameDayAs: selectedDate) }
    }

    private var dueTasksForSelectedDate: [TaskItem] {
        let calendar = Calendar.current
        return tasks.filter { task in
            guard let dueDate = task.dueDate else {
                return false
            }

            return calendar.isDate(dueDate, inSameDayAs: selectedDate) && task.isCompleted == false
        }
    }

    private var upcomingEvents: [CalendarEvent] {
        events.filter { $0.startDate >= .now && Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) == false }
    }
}

private struct CalendarDateCard: View {
    @Binding var selectedDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Selected Day")
                .font(.headline)
            DatePicker(
                "Day",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
        .padding()
        .puttingGreenSurface(cornerRadius: 20)
    }
}

private struct CalendarEventCard: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Text(event.startDate.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .fontWeight(.semibold)
                Rectangle()
                    .fill(AppModule.calendar.theme.primary.opacity(0.4))
                    .frame(width: 2, height: 36)
            }
            .frame(width: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.headline)
                Text(timeRangeText)
                    .font(.subheadline)
                    .foregroundStyle(ModuleTheme.secondaryText)
            }

            Spacer()
        }
        .padding()
        .puttingGreenSurface(cornerRadius: 20)
    }

    private var timeRangeText: String {
        "\(event.startDate.formatted(.dateTime.hour().minute())) - \(event.endDate.formatted(.dateTime.hour().minute()))"
    }
}

private struct CalendarTaskCard: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(AppModule.taskProtocol.theme.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                if let dueDate = task.dueDate {
                    Text(dueDate.formatted(date: .omitted, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(ModuleTheme.secondaryText)
        }
            }
            Spacer()
        }
        .padding()
        .puttingGreenSurface(cornerRadius: 18)
    }
}

private struct CalendarEmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(ModuleTheme.secondaryText)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(AppModule.calendar.theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .puttingGreenSurface(cornerRadius: 20)
    }
}

private struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var startDate: Date
    @State private var endDate: Date

    init(defaultDate: Date) {
        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: defaultDate) ?? defaultDate
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Event title", text: $title)
                    DatePicker("Start", selection: $startDate)
                    DatePicker("End", selection: $endDate, in: startDate...)
                }
                .listRowBackground(ModuleTheme.elevatedSurface)
            }
            .puttingGreenFormChrome()
            .navigationTitle("New Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedTitle.isEmpty == false else {
                            return
                        }

                        modelContext.insert(
                            CalendarEvent(
                                title: trimmedTitle,
                                startDate: startDate,
                                endDate: endDate
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

#Preview("Calendar") {
    PreviewScreenContainer {
        CalendarView()
    }
    .modelContainer(for: [CalendarEvent.self, TaskItem.self], inMemory: true)
}
