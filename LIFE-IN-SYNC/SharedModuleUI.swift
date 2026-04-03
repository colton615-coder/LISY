import SwiftData
import SwiftUI

enum ModuleHubTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case entries = "Entries"
    case advisor = "Advisor"
    case builder = "Builder"
    case records = "Records"
    case review = "Review"

    var id: String { rawValue }
}

enum HubSectionSpacing {
    static let outer: CGFloat = 20
    static let content: CGFloat = 14
}

enum ModuleSpacing {
    static let xxSmall: CGFloat = 6
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 20
    static let xLarge: CGFloat = 24
    static let xxLarge: CGFloat = 32
}

enum ModuleCornerRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let card: CGFloat = 20
    static let hero: CGFloat = 28
    static let chip: CGFloat = 16
    static let row: CGFloat = 18
}

enum ModuleTypography {
    static let screenTitle: Font = .largeTitle.weight(.bold)
    static let screenSubtitle: Font = .subheadline
    static let sectionTitle: Font = .headline
    static let cardTitle: Font = .headline
    static let metricValue: Font = .title3.weight(.bold)
    static let supportingLabel: Font = .caption
}

struct ModuleScreen<Content: View>: View {
    let theme: ModuleTheme
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ModuleSpacing.large) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ModuleSpacing.medium)
            .padding(.top, ModuleSpacing.small)
            .padding(.bottom, ModuleSpacing.xxLarge)
        }
        .background(theme.screenGradient.ignoresSafeArea())
    }
}

struct ModuleHeader: View {
    let theme: ModuleTheme
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.xSmall) {
            Text(title)
                .font(ModuleTypography.screenTitle)
                .foregroundStyle(theme.textPrimary)

            if let subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(ModuleTypography.screenSubtitle)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
        }
    }
}

struct ModuleSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            VStack(alignment: .leading, spacing: ModuleSpacing.xxSmall) {
                Text(title)
                    .font(ModuleTypography.sectionTitle)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
    }
}

struct ModuleListSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ModuleSection(title: title, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: ModuleSpacing.small) {
                content
            }
        }
    }
}

struct ModuleRowSurface<Content: View>: View {
    let theme: ModuleTheme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(theme.surfacePrimary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}

struct ModuleMetricStrip<Content: View>: View {
    let theme: ModuleTheme
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: ModuleSpacing.small) {
            content
        }
        .padding(ModuleSpacing.small)
        .background(theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}

struct ModuleMetricItem: View {
    let theme: ModuleTheme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.xxSmall) {
            Text(value)
                .font(ModuleTypography.metricValue)
                .foregroundStyle(theme.textPrimary)
            Text(title)
                .font(ModuleTypography.supportingLabel)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, ModuleSpacing.xSmall)
        .padding(.horizontal, ModuleSpacing.small)
        .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous))
    }
}

struct ModuleInlineEmptyState: View {
    let theme: ModuleTheme
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ModuleRowSurface(theme: theme) {
            Text(title)
                .font(ModuleTypography.cardTitle)
                .foregroundStyle(theme.textPrimary)
            Text(message)
                .foregroundStyle(theme.textSecondary)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
        }
    }
}

struct ModuleDisclosureSection<Content: View>: View {
    let title: String
    let theme: ModuleTheme
    @State private var isExpanded: Bool
    @ViewBuilder let content: Content

    init(
        title: String,
        theme: ModuleTheme,
        initiallyExpanded: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.theme = theme
        _isExpanded = State(initialValue: initiallyExpanded)
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(ModuleTypography.sectionTitle)
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: ModuleSpacing.small) {
                    content
                }
            }
        }
    }
}

struct PreviewScreenContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            content
        }
    }
}

@MainActor
enum PreviewCatalog {
    static let emptyApp = makeContainer()
    static let populatedApp = makeContainer(seed: .populated)

    private enum SeedStyle {
        case empty
        case populated
    }

    private static func makeContainer(seed: SeedStyle = .empty) -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: Schema([
                    Habit.self,
                    HabitEntry.self,
                    TaskItem.self,
                    CalendarEvent.self,
                    SupplyItem.self,
                    ExpenseRecord.self,
                    BudgetRecord.self,
                    WorkoutTemplate.self,
                    WorkoutSession.self,
                    StudyEntry.self,
                    SwingRecord.self
                ]),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )

            if seed == .populated {
                seedPopulatedData(into: container.mainContext)
            }

            return container
        } catch {
            fatalError("Unable to create preview container: \(error)")
        }
    }

    private static func seedPopulatedData(into context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        let morningPrayer = Habit(
            name: "Morning Prayer",
            targetCount: 1,
            createdAt: calendar.date(byAdding: .day, value: -21, to: now) ?? now
        )
        let walk = Habit(
            name: "Evening Walk",
            targetCount: 2,
            createdAt: calendar.date(byAdding: .day, value: -10, to: now) ?? now
        )

        let habits = [morningPrayer, walk]
        habits.forEach(context.insert)

        let habitEntries = [
            HabitEntry(habitID: morningPrayer.id, habitName: morningPrayer.name, loggedAt: calendar.date(byAdding: .hour, value: 7, to: startOfToday) ?? now),
            HabitEntry(habitID: walk.id, habitName: walk.name, loggedAt: calendar.date(byAdding: .hour, value: 18, to: startOfToday) ?? now),
            HabitEntry(habitID: walk.id, habitName: walk.name, loggedAt: calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .hour, value: 18, to: startOfToday) ?? now) ?? now),
            HabitEntry(habitID: walk.id, habitName: walk.name, loggedAt: calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .hour, value: 19, to: startOfToday) ?? now) ?? now)
        ]
        habitEntries.forEach(context.insert)

        let tasks = [
            TaskItem(
                title: "Ship preview workflow",
                priority: TaskPriority.high.rawValue,
                dueDate: calendar.date(byAdding: .hour, value: 6, to: now),
                createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            TaskItem(
                title: "Refine dashboard module pulse",
                priority: TaskPriority.medium.rawValue,
                dueDate: calendar.date(byAdding: .day, value: 1, to: now),
                createdAt: calendar.date(byAdding: .hour, value: -8, to: now) ?? now
            ),
            TaskItem(
                title: "Review launch affirmation tone",
                priority: TaskPriority.low.rawValue,
                dueDate: nil,
                isCompleted: true,
                createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now
            )
        ]
        tasks.forEach(context.insert)

        let standupStart = calendar.date(byAdding: .hour, value: 9, to: startOfToday) ?? now
        let workoutStart = calendar.date(byAdding: .hour, value: 17, to: startOfToday) ?? now
        let events = [
            CalendarEvent(
                title: "Project Standup",
                startDate: standupStart,
                endDate: calendar.date(byAdding: .minute, value: 30, to: standupStart) ?? standupStart
            ),
            CalendarEvent(
                title: "Gym Block",
                startDate: workoutStart,
                endDate: calendar.date(byAdding: .hour, value: 1, to: workoutStart) ?? workoutStart
            ),
            CalendarEvent(
                title: "Budget Review",
                startDate: calendar.date(byAdding: .day, value: 1, to: calendar.date(byAdding: .hour, value: 11, to: startOfToday) ?? now) ?? now,
                endDate: calendar.date(byAdding: .day, value: 1, to: calendar.date(byAdding: .hour, value: 12, to: startOfToday) ?? now) ?? now
            )
        ]
        events.forEach(context.insert)

        let supplyItems = [
            SupplyItem(title: "Greek yogurt", category: "Groceries"),
            SupplyItem(title: "Trash bags", category: "Household"),
            SupplyItem(title: "Protein powder", category: "Personal"),
            SupplyItem(title: "Paper towels", category: "Household", isPurchased: true)
        ]
        supplyItems.forEach(context.insert)

        let expenses = [
            ExpenseRecord(title: "Gas", amount: 48.20, category: "Transport", recordedAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now),
            ExpenseRecord(title: "Groceries", amount: 86.45, category: "Food", recordedAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
        ]
        expenses.forEach(context.insert)

        let budgets = [
            BudgetRecord(title: "Food", limitAmount: 500, periodLabel: "Monthly"),
            BudgetRecord(title: "Transport", limitAmount: 180, periodLabel: "Monthly")
        ]
        budgets.forEach(context.insert)

        let workoutTemplates = [
            WorkoutTemplate(name: "Upper Body Strength", createdAt: calendar.date(byAdding: .day, value: -14, to: now) ?? now),
            WorkoutTemplate(name: "Conditioning Circuit", createdAt: calendar.date(byAdding: .day, value: -8, to: now) ?? now)
        ]
        workoutTemplates.forEach(context.insert)

        let workouts = [
            WorkoutSession(templateName: "Upper Body", performedAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now, durationMinutes: 55),
            WorkoutSession(templateName: "Run", performedAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now, durationMinutes: 32)
        ]
        workouts.forEach(context.insert)

        let studyEntries = [
            StudyEntry(
                title: "Abide in the Vine",
                passageReference: "John 15:1-11",
                notes: "The strongest note is dependence before output.",
                createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            StudyEntry(
                title: "Renewing the Mind",
                passageReference: "Romans 12:1-2",
                notes: "Transformation feels more like steady surrender than one dramatic turn.",
                createdAt: calendar.date(byAdding: .day, value: -4, to: now) ?? now
            )
        ]
        studyEntries.forEach(context.insert)

        let swings = [
            SwingRecord(title: "7 Iron - Range Session", createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now, notes: "Best strikes came with slower tempo."),
            SwingRecord(title: "Driver - Tee Box Check", createdAt: calendar.date(byAdding: .day, value: -6, to: now) ?? now, notes: "Ball started right when setup drifted open.")
        ]
        swings.forEach(context.insert)

        try? context.save()
    }
}

struct ModuleHubScaffold<Content: View>: View {
    let module: AppModule
    let title: String
    let subtitle: String
    let currentState: String
    let nextAttention: String
    let tabs: [ModuleHubTab]
    @Binding var selectedTab: ModuleHubTab
    @ViewBuilder let content: Content

    var body: some View {
        ModuleScreen(theme: module.theme) {
            VStack(alignment: .leading, spacing: HubSectionSpacing.outer) {
                ModuleHeroCard(
                    module: module,
                    eyebrow: "Command Center",
                    title: title,
                    message: subtitle
                )

                HubStatusCard(
                    module: module,
                    title: "Current State",
                    bodyText: currentState
                )

                HubStatusCard(
                    module: module,
                    title: "Next Attention",
                    bodyText: nextAttention
                )

                HubTabPicker(tabs: tabs, selectedTab: $selectedTab, theme: module.theme)

                content
            }
        }
        .tint(module.theme.primary)
    }
}

private struct HubStatusCard: View {
    let module: AppModule
    let title: String
    let bodyText: String

    var body: some View {
        ModuleRowSurface(theme: module.theme) {
            Text(title)
                .font(ModuleTypography.cardTitle)
                .foregroundStyle(module.theme.textPrimary)
            Text(bodyText)
                .foregroundStyle(module.theme.textSecondary)
        }
    }
}

struct HubTabPicker: View {
    let tabs: [ModuleHubTab]
    @Binding var selectedTab: ModuleHubTab
    let theme: ModuleTheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(selectedTab == tab ? theme.textPrimary : theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, ModuleSpacing.xSmall)
                            .background(
                                RoundedRectangle(cornerRadius: ModuleSpacing.small, style: .continuous)
                                    .fill(selectedTab == tab ? theme.surfaceInteractive : theme.surfaceSecondary)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ModuleRootPlaceholderView: View {
    let module: AppModule
    let description: String
    let highlights: [String]

    var body: some View {
        ModuleScreen(theme: module.theme) {
            ModuleHeroCard(
                module: module,
                eyebrow: "Module Root",
                title: module.title,
                message: description
            )

            ModuleFocusCard(module: module, highlights: highlights)
        }
        .tint(module.theme.primary)
    }
}

struct ModuleHeroCard: View {
    let module: AppModule
    let eyebrow: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(module.theme.accentText)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(module.theme.textPrimary)
            Text(message)
                .foregroundStyle(module.theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(
            module.theme.heroGradient.opacity(0.9),
            in: RoundedRectangle(cornerRadius: ModuleCornerRadius.hero, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.hero, style: .continuous)
                .stroke(module.theme.borderStrong, lineWidth: 1)
        )
        .shadow(color: module.theme.accentGlow, radius: 20, y: 8)
    }
}

struct ModuleFocusCard: View {
    let module: AppModule
    let highlights: [String]

    var body: some View {
        ModuleRowSurface(theme: module.theme) {
            Text("Current Focus")
                .font(ModuleTypography.cardTitle)
                .foregroundStyle(module.theme.textPrimary)

            ForEach(highlights, id: \.self) { highlight in
                HStack(spacing: 10) {
                    Circle()
                        .fill(module.theme.primary)
                        .frame(width: 8, height: 8)
                    Text(highlight)
                        .foregroundStyle(module.theme.textPrimary)
                }
            }
        }
    }
}

struct ModuleSnapshotCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ModuleRowSurface(theme: ModuleTheme(
            primary: .white,
            secondary: .white,
            backgroundTop: .clear,
            backgroundBottom: .clear,
            accentText: .white
        )) {
            Text(title)
                .font(ModuleTypography.cardTitle)
            content
        }
    }
}

struct ModuleMetricChip: View {
    let theme: ModuleTheme
    let title: String
    let value: String

    var body: some View {
        ModuleMetricItem(theme: theme, title: title, value: value)
    }
}

struct ModuleEmptyStateCard: View {
    let theme: ModuleTheme
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ModuleInlineEmptyState(
            theme: theme,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
    }
}

struct ModuleVisualizationContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ModuleRowSurface(theme: ModuleTheme(
            primary: .white,
            secondary: .white,
            backgroundTop: .clear,
            backgroundBottom: .clear,
            accentText: .white
        )) {
            Text(title)
                .font(ModuleTypography.cardTitle)
            content
        }
    }
}

struct ModuleActivityFeedSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            Text(title)
                .font(ModuleTypography.sectionTitle)
            content
        }
    }
}

struct ModuleBottomActionBar: View {
    let theme: ModuleTheme
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
        }
        .padding(.horizontal, ModuleSpacing.medium)
        .padding(.vertical, ModuleSpacing.small)
        .background(theme.canvasBase.opacity(0.94))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.borderSubtle)
                .frame(height: 1)
        }
    }
}
