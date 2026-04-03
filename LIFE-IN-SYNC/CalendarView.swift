import SwiftData
import SwiftUI

struct CalendarView: View {
    @Query(sort: \CalendarEvent.startDate) private var events: [CalendarEvent]
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var isShowingAddEvent = false
    @State private var selectedTab: ModuleHubTab = .overview

    init(initialSelectedDate: Date = Calendar.current.startOfDay(for: .now), initialTab: ModuleHubTab = .overview) {
        _selectedDate = State(initialValue: initialSelectedDate)
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ModuleHubScaffold(
            module: .calendar,
            title: "Keep the day visible.",
            subtitle: "Calendar stays focused on time blocks, due dates, and a readable daily agenda.",
            currentState: "\(eventsForSelectedDate.count) events and \(dueTasksForSelectedDate.count) due tasks on the selected day.",
            nextAttention: eventsForSelectedDate.isEmpty ? "Add a time block to shape the day." : "Review the agenda and protect the next priority block.",
            tabs: [.overview, .entries, .review],
            selectedTab: $selectedTab
        ) {
            switch selectedTab {
            case .overview:
                CalendarOverviewTab(
                    selectedDate: $selectedDate,
                    eventsForSelectedDate: eventsForSelectedDate,
                    dueTasksForSelectedDate: dueTasksForSelectedDate
                )
            case .entries:
                CalendarAgendaTab(
                    daySectionTitle: daySectionTitle,
                    eventsForSelectedDate: eventsForSelectedDate
                ) {
                    isShowingAddEvent = true
                }
            case .review:
                CalendarReviewTab(
                    dueTasksForSelectedDate: dueTasksForSelectedDate,
                    upcomingEvents: upcomingEvents
                )
            default:
                EmptyView()
            }
        }
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

private struct CalendarOverviewTab: View {
    @Binding var selectedDate: Date
    let eventsForSelectedDate: [CalendarEvent]
    let dueTasksForSelectedDate: [TaskItem]

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            CalendarOverviewCard(
                eventCount: eventsForSelectedDate.count,
                taskCount: dueTasksForSelectedDate.count
            )
            CalendarDateCard(selectedDate: $selectedDate)
        }
    }
}

private struct CalendarAgendaTab: View {
    let daySectionTitle: String
    let eventsForSelectedDate: [CalendarEvent]
    let addEvent: () -> Void

    var body: some View {
        ModuleActivityFeedSection(title: daySectionTitle) {
            if eventsForSelectedDate.isEmpty {
                CalendarEmptyStateView(
                    title: "No events on this day",
                    message: "Add a time block or appointment to start shaping the agenda.",
                    actionTitle: "Add Event",
                    action: addEvent
                )
            } else {
                ForEach(eventsForSelectedDate) { event in
                    CalendarEventCard(event: event)
                }
            }
        }
    }
}

private struct CalendarReviewTab: View {
    let dueTasksForSelectedDate: [TaskItem]
    let upcomingEvents: [CalendarEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            if dueTasksForSelectedDate.isEmpty == false {
                ModuleActivityFeedSection(title: "Tasks Due") {
                    ForEach(dueTasksForSelectedDate) { task in
                        CalendarTaskCard(task: task)
                    }
                }
            }

            if upcomingEvents.isEmpty {
                ModuleEmptyStateCard(
                    theme: AppModule.calendar.theme,
                    title: "No upcoming events outside this day",
                    message: "Future blocks will show here so you can scan beyond the selected date without leaving the module hub.",
                    actionTitle: "Stay Focused",
                    action: {}
                )
            } else {
                ModuleActivityFeedSection(title: "Upcoming") {
                    ForEach(upcomingEvents.prefix(5)) { event in
                        CalendarEventCard(event: event)
                    }
                }
            }
        }
    }
}

private struct CalendarOverviewCard: View {
    let eventCount: Int
    let taskCount: Int

    var body: some View {
        ModuleVisualizationContainer(title: "Day Snapshot") {
            HStack(spacing: 12) {
                ModuleMetricChip(theme: AppModule.calendar.theme, title: "Events", value: "\(eventCount)")
                ModuleMetricChip(theme: AppModule.calendar.theme, title: "Due Tasks", value: "\(taskCount)")
            }
        }
    }
}

private struct CalendarDateCard: View {
    @Binding var selectedDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Selected Day")
                .font(ModuleTypography.cardTitle)
            DatePicker(
                "Day",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
        .padding(ModuleSpacing.medium)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
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
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
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
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
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
                .foregroundStyle(.secondary)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(AppModule.calendar.theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
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
            }
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
    }
}

#Preview("Calendar Overview") {
    PreviewScreenContainer {
        CalendarView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
}

#Preview("Calendar Agenda") {
    PreviewScreenContainer {
        CalendarView(initialTab: .entries)
    }
    .modelContainer(PreviewCatalog.populatedApp)
}

#Preview("Calendar Empty") {
    PreviewScreenContainer {
        CalendarView(initialTab: .entries)
    }
    .modelContainer(PreviewCatalog.emptyApp)
}
