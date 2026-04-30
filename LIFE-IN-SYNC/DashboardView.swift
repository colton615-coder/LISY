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

    private let allModules: [AppModule] = [.habitStack, .taskProtocol, .calendar, .supplyList, .capitalCore, .ironTemple, .bibleStudy, .garage]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DashboardSection(title: "Daily Focus") {
                    DashboardHeroCard(
                        keyMetricTitle: "Open Tasks",
                        keyMetricValue: "\(openTasksCount)"
                    )
                }

                DashboardSection(title: "Module Pulse") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(rankedModules) { module in
                                DashboardModuleEntryCard(
                                    module: module,
                                    progressSummary: statusText(for: module),
                                    urgencyLabel: urgencyText(for: module),
                                    importanceLabel: importanceText(for: module)
                                ) {
                                    selectedModule = module
                                }
                                .frame(width: 230)
                            }
                        }
                    }
                }

                DashboardSection(title: "Timeline + Quiet Alerts") {
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

    private var rankedModules: [AppModule] {
        allModules.sorted { lhs, rhs in
            let lhsUrgency = urgencyScore(for: lhs)
            let rhsUrgency = urgencyScore(for: rhs)
            if lhsUrgency != rhsUrgency {
                return lhsUrgency > rhsUrgency
            }

            let lhsImportance = importanceScore(for: lhs)
            let rhsImportance = importanceScore(for: rhs)
            if lhsImportance != rhsImportance {
                return lhsImportance > rhsImportance
            }

            // Final deterministic tie-breaker: fall back to original allModules order
            let lhsIndex = allModules.firstIndex(of: lhs) ?? Int.max
            let rhsIndex = allModules.firstIndex(of: rhs) ?? Int.max
            return lhsIndex < rhsIndex
        }
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

    private func urgencyScore(for module: AppModule) -> Int {
        switch module {
        case .taskProtocol:
            min(openTasksCount, 10)
        case .supplyList:
            min(remainingSupplyCount, 10)
        case .calendar:
            max(0, 5 - eventsTodayCount)
        case .habitStack:
            max(0, 5 - completedHabitsToday)
        case .capitalCore, .ironTemple, .bibleStudy, .garage, .dashboard:
            2
        }
    }

    private func importanceScore(for module: AppModule) -> Int {
        switch module {
        case .habitStack, .taskProtocol, .calendar, .supplyList:
            3
        case .capitalCore, .ironTemple:
            2
        case .bibleStudy, .garage:
            1
        case .dashboard:
            0
        }
    }

    private func urgencyText(for module: AppModule) -> String {
        let rawScore = urgencyScore(for: module)
        let normalizedScore: Int
        switch module {
        case .calendar, .habitStack:
            // These modules currently cap urgency at 5; scale to a 0–10 range for text mapping.
            normalizedScore = rawScore * 2
        default:
            normalizedScore = rawScore
        }

        if normalizedScore >= 7 { return "Urgency: High" }
        if normalizedScore >= 4 { return "Urgency: Medium" }
        return "Urgency: Low"
    }

    private func importanceText(for module: AppModule) -> String {
        switch importanceScore(for: module) {
        case 3:
            "Importance: Core"
        case 2:
            "Importance: High"
        default:
            "Importance: Support"
        }
    }
}

private struct DashboardHeroCard: View {
    let keyMetricTitle: String
    let keyMetricValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(ModuleTheme.primaryText)
            Text("Progress-first routing with quiet urgency.")
                .font(.subheadline)
                .foregroundStyle(ModuleTheme.secondaryText)
            HStack {
                Text(keyMetricTitle)
                    .foregroundStyle(ModuleTheme.secondaryText)
                Spacer()
                Text(keyMetricValue)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(ModuleTheme.primaryText)
            }
        }
        .padding()
        .puttingGreenSurface(cornerRadius: 20)
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
                .foregroundStyle(ModuleTheme.primaryText)
            content
        }
    }
}

private struct DashboardModuleEntryCard: View {
    let module: AppModule
    let progressSummary: String
    let urgencyLabel: String
    let importanceLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: module.systemImage)
                    .foregroundStyle(module.theme.primary)
                    .frame(width: 32, height: 32)
                    .background(module.theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(module.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(ModuleTheme.primaryText)
                Text(progressSummary)
                    .font(.caption)
                    .foregroundStyle(ModuleTheme.secondaryText)
                HStack {
                    Text(urgencyLabel)
                        .font(.caption2)
                        .foregroundStyle(ModuleTheme.secondaryText)
                    Spacer()
                    Text(importanceLabel)
                        .font(.caption2)
                        .foregroundStyle(ModuleTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .puttingGreenSurface(cornerRadius: 16)
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
                .foregroundStyle(ModuleTheme.primaryText)
            Text(detail)
                .font(.caption)
                .foregroundStyle(ModuleTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .puttingGreenSurface(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(module.theme.primary.opacity(0.24), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityID)
    }
}

#Preview("Dashboard Empty") {
    PreviewScreenContainer {
        DashboardView(selectedModule: .constant(.dashboard))
    }
    .modelContainer(PreviewCatalog.emptyApp)
}

#Preview("Dashboard Live") {
    PreviewScreenContainer {
        DashboardView(selectedModule: .constant(.dashboard))
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
