import SwiftData
import SwiftUI

struct DashboardView: View {
    @Binding var selectedModule: AppModule
    @Query private var habits: [Habit]
    @Query private var habitEntries: [HabitEntry]
    @Query private var tasks: [TaskItem]
    @Query private var events: [CalendarEvent]
    @Query private var supplyItems: [SupplyItem]
    @Query private var expenses: [ExpenseRecord]
    @Query private var workoutSessions: [WorkoutSession]
    @Query private var studyEntries: [StudyEntry]
    @Query private var swingRecords: [SwingRecord]

    private let primaryModules: [AppModule] = [.habitStack, .taskProtocol, .calendar, .supplyList]
    private let secondaryModules: [AppModule] = [.capitalCore, .ironTemple, .bibleStudy, .garage]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DashboardHeroCard()

                DashboardSection(title: "Today") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        DashboardStatCard(
                            module: .habitStack,
                            title: "Habits",
                            value: "\(completedHabitsToday)",
                            detail: "completed today",
                            accessibilityID: "dashboard-stat-habits"
                        )
                        DashboardStatCard(
                            module: .taskProtocol,
                            title: "Tasks",
                            value: "\(openTasksCount)",
                            detail: "open",
                            accessibilityID: "dashboard-stat-tasks"
                        )
                        DashboardStatCard(
                            module: .calendar,
                            title: "Events",
                            value: "\(eventsTodayCount)",
                            detail: "scheduled today",
                            accessibilityID: "dashboard-stat-events"
                        )
                        DashboardStatCard(
                            module: .supplyList,
                            title: "Items",
                            value: "\(remainingSupplyCount)",
                            detail: "remaining to buy",
                            accessibilityID: "dashboard-stat-items"
                        )
                    }
                }

                DashboardSection(title: "Primary Modules") {
                    VStack(spacing: 10) {
                        ForEach(primaryModules) { module in
                            DashboardModuleRow(
                                module: module,
                                status: statusText(for: module)
                            ) {
                                selectedModule = module
                            }
                        }
                    }
                }

                DashboardSection(title: "Secondary Modules") {
                    VStack(spacing: 10) {
                        ForEach(secondaryModules) { module in
                            DashboardModuleRow(
                                module: module,
                                status: statusText(for: module)
                            ) {
                                selectedModule = module
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppModule.dashboard.theme.screenGradient)
    }

    private var completedHabitsToday: Int {
        habits.filter { habit in
            let progress = habitEntries
                .filter { $0.habitID == habit.id && Calendar.current.isDateInToday($0.loggedAt) }
                .reduce(0) { $0 + $1.count }
            return progress >= habit.targetCount
        }.count
    }

    private var openTasksCount: Int {
        tasks.filter { $0.isCompleted == false }.count
    }

    private var eventsTodayCount: Int {
        events.filter { Calendar.current.isDateInToday($0.startDate) }.count
    }

    private var remainingSupplyCount: Int {
        supplyItems.filter { $0.isPurchased == false }.count
    }

    private var currentMonthSpend: Double {
        expenses
            .filter { Calendar.current.isDate($0.recordedAt, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    private var workoutSessionsThisWeek: Int {
        workoutSessions.filter {
            Calendar.current.isDate($0.performedAt, equalTo: .now, toGranularity: .weekOfYear)
        }.count
    }

    private func statusText(for module: AppModule) -> String {
        switch module {
        case .dashboard:
            "Home"
        case .habitStack:
            "\(completedHabitsToday) completed today"
        case .taskProtocol:
            "\(openTasksCount) open"
        case .calendar:
            "\(eventsTodayCount) today"
        case .supplyList:
            "\(remainingSupplyCount) remaining"
        case .capitalCore:
            currentMonthSpend.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        case .ironTemple:
            "\(workoutSessionsThisWeek) sessions this week"
        case .bibleStudy:
            "\(studyEntries.count) entries"
        case .garage:
            "\(swingRecords.count) records"
        }
    }
}

private struct DashboardHeroCard: View {
    var body: some View {
        ModuleHeroCard(
            module: .dashboard,
            eyebrow: "Dashboard",
            title: "One place to enter every module.",
            message: "This surface stays intentionally light. It routes you into each module without becoming a second interface for their logic."
        )
    }
}

private struct DashboardSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            content
        }
    }
}

private struct DashboardModuleRow: View {
    let module: AppModule
    let status: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: module.systemImage)
                    .foregroundStyle(module.theme.primary)
                    .frame(width: 32, height: 32)
                    .background(module.theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(module.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard-module-\(module.rawValue)")
    }
}

private struct DashboardStatCard: View {
    let module: AppModule
    let title: String
    let value: String
    let detail: String
    let accessibilityID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(module.theme.primary.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityID)
    }
}

#Preview("Dashboard") {
    PreviewScreenContainer {
        DashboardView(selectedModule: .constant(.dashboard))
    }
}
