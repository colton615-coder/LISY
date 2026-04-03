import SwiftData
import SwiftUI

struct DashboardView: View {
    @Binding var selectedModule: AppModule
    @State private var hasAnimatedIn = false
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
    private let moduleColumns = [
        GridItem(.flexible(), spacing: ModuleSpacing.small),
        GridItem(.flexible(), spacing: ModuleSpacing.small)
    ]

    var body: some View {
        ModuleScreen(theme: AppModule.dashboard.theme) {
            DashboardPanel {
                DashboardHeader(summary: dailyFocusSummary)
                    .opacity(hasAnimatedIn ? 1 : 0)
                    .offset(y: hasAnimatedIn ? 0 : 10)

                VStack(alignment: .leading, spacing: ModuleSpacing.small) {
                    DashboardSectionHeading(
                        eyebrow: "Daily Pulse",
                        title: nil,
                        subtitle: nil
                    )
                    DashboardSignalStrip(
                        openTasksCount: openTasksCount,
                        eventsTodayCount: eventsTodayCount,
                        completedHabitsToday: completedHabitsToday
                    )
                }
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 14)

                VStack(alignment: .leading, spacing: ModuleSpacing.small) {
                    DashboardSectionHeading(
                        eyebrow: nil,
                        title: "Module Grid",
                        subtitle: "Command cards for what matters today."
                    )
                    LazyVGrid(columns: moduleColumns, spacing: ModuleSpacing.small) {
                        ForEach(Array(rankedModules.enumerated()), id: \.element.id) { index, module in
                            DashboardModuleWidgetCard(
                                module: module,
                                progressSummary: statusText(for: module)
                            ) {
                                selectedModule = module
                            }
                            .opacity(hasAnimatedIn ? 1 : 0)
                            .offset(y: hasAnimatedIn ? 0 : CGFloat(14 + (index * 4)))
                        }
                    }
                }
            }
            .padding(.top, -44)
        }
        .task {
            guard hasAnimatedIn == false else { return }
            withAnimation(.easeOut(duration: 0.45)) {
                hasAnimatedIn = true
            }
        }
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

    private var dailyFocusSummary: String {
        if openTasksCount > 0 {
            return "\(openTasksCount) open task\(openTasksCount == 1 ? "" : "s") with \(eventsTodayCount) event\(eventsTodayCount == 1 ? "" : "s") on the calendar."
        }

        if completedHabitsToday > 0 {
            return "\(completedHabitsToday) habit\(completedHabitsToday == 1 ? "" : "s") already completed today."
        }

        if remainingSupplyCount > 0 {
            return "\(remainingSupplyCount) supply item\(remainingSupplyCount == 1 ? "" : "s") still pending."
        }

        return "Quiet routing across your modules with only the signals that matter."
    }
}

private struct DashboardPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(.top, 4)
    }
}

private struct DashboardHeader: View {
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("TODAY'S COMMAND")
                    .font(.caption.weight(.bold))
                    .tracking(1.6)
            } icon: {
                Image(systemName: "bolt.fill")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(AppModule.dashboard.theme.primary)

            DashboardWordmark()

            Text(summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppModule.dashboard.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DashboardWordmark: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Life In ")
                .foregroundStyle(AppModule.dashboard.theme.textPrimary)
            Text("Sync")
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .blue, .indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .font(.system(size: 34, weight: .black, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private struct DashboardSectionHeading: View {
    let eyebrow: String?
    let title: String?
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AppModule.dashboard.theme.textMuted)
            }

            if let title {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppModule.dashboard.theme.textPrimary)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppModule.dashboard.theme.textSecondary)
            }
        }
    }
}

private struct DashboardSignalStrip: View {
    let openTasksCount: Int
    let eventsTodayCount: Int
    let completedHabitsToday: Int

    var body: some View {
        HStack(spacing: ModuleSpacing.small) {
            DashboardSignalPill(
                title: "Open",
                value: "\(openTasksCount)",
                systemImage: "sparkles",
                accent: .teal
            )
            DashboardSignalPill(
                title: "Today",
                value: "\(eventsTodayCount)",
                systemImage: "calendar",
                accent: .red
            )
            DashboardSignalPill(
                title: "Habits",
                value: "\(completedHabitsToday)",
                systemImage: "checklist",
                accent: .indigo
            )
        }
    }
}

private struct DashboardSignalPill: View {
    let title: String
    let value: String
    let systemImage: String
    let accent: Color

    private var accessibilityID: String {
        "dashboard-signal-\(title.lowercased())"
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.16))
                    .frame(width: 28, height: 28)

                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
            }

            Text(value)
                .font(.title3.weight(.black))
                .foregroundStyle(AppModule.dashboard.theme.textPrimary)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppModule.dashboard.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    AppModule.dashboard.theme.surfaceSecondary.opacity(0.95),
                    accent.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                .stroke(AppModule.dashboard.theme.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityID)
    }
}

private struct DashboardModuleWidgetCard: View {
    let module: AppModule
    let progressSummary: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(module.theme.primary.opacity(0.18))
                        .frame(width: 54, height: 54)
                        .blur(radius: 8)

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    module.theme.accentSoft.opacity(0.95),
                                    module.theme.primary.opacity(0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)

                    Image(systemName: module.systemImage)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(module.theme.primary)
                }

                VStack(spacing: 4) {
                    Text(module.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppModule.dashboard.theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(progressSummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppModule.dashboard.theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 138)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        AppModule.dashboard.theme.surfacePrimary.opacity(0.9),
                        module.theme.surfaceSecondary.opacity(0.78),
                        module.theme.accentSoft.opacity(0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .stroke(module.theme.primary.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: module.theme.accentGlow.opacity(0.16), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard-module-\(module.rawValue)")
    }
}

#Preview("Dashboard Empty") {
    PreviewScreenContainer {
        DashboardView(selectedModule: .constant(.dashboard))
    }
    .modelContainer(PreviewCatalog.emptyApp)
    .preferredColorScheme(.dark)
}

#Preview("Dashboard Live") {
    PreviewScreenContainer {
        DashboardView(selectedModule: .constant(.dashboard))
    }
    .modelContainer(PreviewCatalog.populatedApp)
    .preferredColorScheme(.dark)
}
