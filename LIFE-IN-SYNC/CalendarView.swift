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
        ModuleScreen(theme: AppModule.calendar.theme) {
            ModuleHeader(
                theme: AppModule.calendar.theme,
                title: "Calendar",
                subtitle: "Keep the day visible without turning the screen into a planner dashboard."
            )

            ModuleHeroCard(
                module: .calendar,
                eyebrow: "Selected Day",
                title: daySectionTitle,
                message: "\(eventsForSelectedDate.count) event\(eventsForSelectedDate.count == 1 ? "" : "s") and \(dueTasksForSelectedDate.count) due task\(dueTasksForSelectedDate.count == 1 ? "" : "s")."
            )

            HubTabPicker(tabs: [.overview, .entries, .review], selectedTab: $selectedTab, theme: AppModule.calendar.theme)

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
        VStack(alignment: .leading, spacing: ModuleSpacing.large) {
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
        ModuleListSection(title: daySectionTitle) {
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
        VStack(alignment: .leading, spacing: ModuleSpacing.large) {
            if dueTasksForSelectedDate.isEmpty == false {
                ModuleListSection(title: "Tasks Due") {
                    ForEach(dueTasksForSelectedDate) { task in
                        CalendarTaskCard(task: task)
                    }
                }
            }

            if upcomingEvents.isEmpty == false {
                ModuleDisclosureSection(title: "Upcoming", theme: AppModule.calendar.theme) {
                    ForEach(upcomingEvents.prefix(5)) { event in
                        CalendarEventCard(event: event)
                    }
                }
            } else if dueTasksForSelectedDate.isEmpty {
                ModuleInlineEmptyState(
                    theme: AppModule.calendar.theme,
                    title: "Nothing urgent beyond this day",
                    message: "Future blocks will appear here when the schedule extends past the selected date.",
                    actionTitle: "Add Event",
                    action: {}
                )
            }
        }
    }
}

private struct CalendarOverviewCard: View {
    let eventCount: Int
    let taskCount: Int

    var body: some View {
        ModuleMetricStrip(theme: AppModule.calendar.theme) {
            ModuleMetricChip(theme: AppModule.calendar.theme, title: "Events", value: "\(eventCount)")
            ModuleMetricChip(theme: AppModule.calendar.theme, title: "Due Tasks", value: "\(taskCount)")
        }
    }
}

private struct CalendarDateCard: View {
    @Binding var selectedDate: Date

    var body: some View {
        ModuleRowSurface(theme: AppModule.calendar.theme) {
            Text("Selected Day")
                .font(ModuleTypography.cardTitle)
                .foregroundStyle(AppModule.calendar.theme.textPrimary)
            DatePicker(
                "Day",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .colorScheme(.dark)
        }
    }
}

private struct CalendarEventCard: View {
    let event: CalendarEvent

    var body: some View {
        ModuleRowSurface(theme: AppModule.calendar.theme) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 6) {
                    Text(event.startDate.formatted(.dateTime.hour().minute()))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppModule.calendar.theme.textPrimary)
                    Rectangle()
                        .fill(AppModule.calendar.theme.primary.opacity(0.4))
                        .frame(width: 2, height: 36)
                }
                .frame(width: 56)

                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(AppModule.calendar.theme.textPrimary)
                    Text(timeRangeText)
                        .font(.subheadline)
                        .foregroundStyle(AppModule.calendar.theme.textSecondary)
                }

                Spacer()
            }
        }
    }

    private var timeRangeText: String {
        "\(event.startDate.formatted(.dateTime.hour().minute())) - \(event.endDate.formatted(.dateTime.hour().minute()))"
    }
}

private struct CalendarTaskCard: View {
    let task: TaskItem

    var body: some View {
        ModuleRowSurface(theme: AppModule.calendar.theme) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(AppModule.taskProtocol.theme.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(AppModule.calendar.theme.textPrimary)
                    if let dueDate = task.dueDate {
                        Text(dueDate.formatted(date: .omitted, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(AppModule.calendar.theme.textSecondary)
                    }
                }
                Spacer()
            }
        }
    }
}

private struct CalendarEmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ModuleInlineEmptyState(
            theme: AppModule.calendar.theme,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
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
    .preferredColorScheme(.dark)
}

#Preview("Calendar Agenda") {
    PreviewScreenContainer {
        CalendarView(initialTab: .entries)
    }
    .modelContainer(PreviewCatalog.populatedApp)
    .preferredColorScheme(.dark)
}

#Preview("Calendar Empty") {
    PreviewScreenContainer {
        CalendarView(initialTab: .entries)
    }
    .modelContainer(PreviewCatalog.emptyApp)
    .preferredColorScheme(.dark)
}
