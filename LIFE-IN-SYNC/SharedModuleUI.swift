import SwiftData
import SwiftUI

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let r, g, b, a: UInt64
        switch sanitized.count {
        case 8:
            (r, g, b, a) = ((value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
        default:
            (r, g, b, a) = ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF, 0xFF)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static let vibeBackground = ModuleTheme.garageBackground
    static let vibeSurface = ModuleTheme.garageSurfaceInset
    static let vibeElectricCyan = ModuleTheme.electricCyan
}

private struct GaragePuttingGreenSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(AppModule.garage.tintColor)
            .preferredColorScheme(.dark)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .presentationBackground(ModuleTheme.garageBackground)
            .background(ModuleTheme.garageBackground.ignoresSafeArea())
    }
}

private struct GaragePuttingGreenFormModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(ModuleTheme.garageBackground)
    }
}

private struct GaragePuttingGreenListModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(ModuleTheme.garageBackground)
    }
}

private struct GarageModalPresenter<ModalContent: View, BottomDock: View>: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    @ViewBuilder let modalContent: () -> ModalContent
    @ViewBuilder let bottomDock: () -> BottomDock

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    modalContent()
                        .navigationTitle(title)
                        .navigationBarTitleDisplayMode(.inline)
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            bottomDock()
                        }
                }
                .garagePuttingGreenSheetChrome()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func garagePuttingGreenSheetChrome() -> some View {
        modifier(GaragePuttingGreenSheetModifier())
    }

    func garagePuttingGreenFormChrome() -> some View {
        modifier(GaragePuttingGreenFormModifier())
    }

    func garagePuttingGreenListChrome() -> some View {
        modifier(GaragePuttingGreenListModifier())
    }

    func garageModal<ModalContent: View>(
        isPresented: Binding<Bool>,
        title: String,
        @ViewBuilder content: @escaping () -> ModalContent
    ) -> some View {
        modifier(
            GarageModalPresenter(
                isPresented: isPresented,
                title: title,
                modalContent: content,
                bottomDock: { EmptyView() }
            )
        )
    }

    func garageModal<ModalContent: View, BottomDock: View>(
        isPresented: Binding<Bool>,
        title: String,
        @ViewBuilder content: @escaping () -> ModalContent,
        @ViewBuilder bottomDock: @escaping () -> BottomDock
    ) -> some View {
        modifier(
            GarageModalPresenter(
                isPresented: isPresented,
                title: title,
                modalContent: content,
                bottomDock: bottomDock
            )
        )
    }
}

enum ModuleHubTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case entries = "Entries"
    case advisor = "Advisor"
    case builder = "Builder"
    case records = "Records"
    case review = "Review"
    case hub = "Command Center"
    case analyzer = "Analyzer"
    case drills = "Drills"
    case range = "Course Map"

    var id: String { rawValue }
}

enum HubSectionSpacing {
    static let outer: CGFloat = 20
    static let content: CGFloat = 14
}

enum ModuleSpacing {
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 20
    static let xLarge: CGFloat = 24
}

enum ModuleCornerRadius {
    static let card: CGFloat = 20
    static let chip: CGFloat = 16
    static let row: CGFloat = 18
    static let medium: CGFloat = 18
    static let hero: CGFloat = 24
}

enum ModuleTypography {
    static let sectionTitle: Font = .system(.title3, design: .rounded).weight(.bold)
    static let cardTitle: Font = .system(.headline, design: .rounded).weight(.bold)
    static let metricValue: Font = .system(size: 40, weight: .black, design: .monospaced)
    static let supportingLabel: Font = .caption2
    static let overline: Font = .caption2
    static let heroTitle: Font = .system(.title2, design: .rounded).weight(.bold)
}

private extension View {
    func moduleFloatingCard(
        theme: ModuleTheme? = nil,
        cornerRadius: CGFloat = ModuleCornerRadius.card,
        fill: Color? = nil,
        shadowColor: Color? = nil
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let resolvedFill = fill ?? theme?.cardBackground ?? Color(.secondarySystemGroupedBackground)
        let resolvedBorder = theme?.borderSubtle ?? Color.primary.opacity(0.05)
        let resolvedShadow = shadowColor ?? theme?.tintedShadow.opacity(0.22) ?? Color.black.opacity(0.03)

        return self
            .background(resolvedFill)
            .clipShape(shape)
            .overlay(shape.stroke(resolvedBorder, lineWidth: 1))
            .shadow(color: resolvedShadow, radius: 15, x: 0, y: 10)
    }

    func moduleHeroSurface(theme: ModuleTheme) -> some View {
        let shape = RoundedRectangle(cornerRadius: ModuleCornerRadius.hero, style: .continuous)

        return self
            .background(theme.heroGradient)
            .clipShape(shape)
            .overlay(shape.stroke(theme.borderSubtle, lineWidth: 1))
            .shadow(color: theme.tintedShadow.opacity(0.32), radius: 15, x: 0, y: 10)
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

struct ModuleScreen<Content: View>: View {
    let theme: ModuleTheme
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            theme.rootBackground
                .ignoresSafeArea()

            theme.screenGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: HubSectionSpacing.outer) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ModuleSpacing.medium)
                .padding(.vertical, ModuleSpacing.medium)
            }
        }
        .tint(theme.primary)
    }
}

struct ModuleHeader: View {
    let theme: ModuleTheme
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(ModuleTypography.heroTitle)
                .foregroundStyle(theme.textPrimary)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .moduleHeroSurface(theme: theme)
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
        .moduleFloatingCard(theme: theme, cornerRadius: ModuleCornerRadius.row, fill: theme.surfaceSecondary)
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
                for: Schema(LISYSchemaV8.models),
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

        let drillDefinitions = [
            PracticeDrillDefinition(
                title: "Carry Ladder",
                focusArea: "Distance Control",
                targetClub: "Wedge",
                defaultRepCount: 12
            ),
            PracticeDrillDefinition(
                title: "Start-Line Gate",
                focusArea: "Start Line",
                targetClub: "Putter",
                defaultRepCount: 10
            ),
            PracticeDrillDefinition(
                title: "Tempo Rehearsal",
                focusArea: "Tempo",
                targetClub: "7 Iron",
                defaultRepCount: 8
            ),
            PracticeDrillDefinition(
                title: "Start-Line Calibration",
                focusArea: "Start Line",
                targetClub: "Driver",
                defaultRepCount: 9
            )
        ]
        drillDefinitions.forEach(context.insert)

        let practiceTemplates = [
            PracticeTemplate(
                title: "Net Start-Line Calibration",
                environment: PracticeEnvironment.net.rawValue,
                drills: [
                    PracticeTemplateDrill(definition: drillDefinitions[3]),
                    PracticeTemplateDrill(definition: drillDefinitions[2])
                ]
            ),
            PracticeTemplate(
                title: "100-Yard Wedge Matrix",
                environment: PracticeEnvironment.range.rawValue,
                drills: [
                    PracticeTemplateDrill(definition: drillDefinitions[0]),
                    PracticeTemplateDrill(definition: drillDefinitions[2])
                ]
            ),
            PracticeTemplate(
                title: "Bench Putting Reset",
                environment: PracticeEnvironment.puttingGreen.rawValue,
                drills: [
                    PracticeTemplateDrill(definition: drillDefinitions[1])
                ]
            )
        ]
        practiceTemplates.forEach(context.insert)

        let practiceSessions = [
            PracticeSessionRecord(
                date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                templateName: "Net Start-Line Calibration",
                environment: PracticeEnvironment.net.rawValue,
                completedDrills: 2,
                totalDrills: 3,
                drillResults: [
                    DrillResult(name: "Start-Line Calibration", successfulReps: 7, totalReps: 9),
                    DrillResult(name: "Tempo Rehearsal", successfulReps: 6, totalReps: 8)
                ],
                sessionFeelNote: "Best when the chest stayed quiet through the strike.",
                aiCoachingInsight: "{\"keyCues\":[\"Keep the chest quieter through impact to preserve your start line.\",\"Begin the next session with tempo rehearsals before calibration reps.\"],\"focusDrills\":[\"Start-Line Calibration\"]}",
                coachingEfficacyScore: nil,
                isPersonalRecord: true,
                aggregatedNotes: "Face-to-path rehearsal: Stayed synced when I slowed the transition."
            ),
            PracticeSessionRecord(
                date: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                templateName: "100-Yard Wedge Matrix",
                environment: PracticeEnvironment.range.rawValue,
                completedDrills: 3,
                totalDrills: 3,
                drillResults: [
                    DrillResult(name: "Carry Ladder", successfulReps: 8, totalReps: 12),
                    DrillResult(name: "Tempo Rehearsal", successfulReps: 7, totalReps: 8)
                ],
                sessionFeelNote: "Center contact stayed reliable when tempo stayed soft.",
                aiCoachingInsight: "{\"keyCues\":[\"Hold the softer tempo that kept center contact stable.\",\"Start the next wedge ladder with the same stock window before pushing speed.\"],\"focusDrills\":[\"Carry Ladder\"]}",
                coachingEfficacyScore: 0.208,
                isPersonalRecord: true,
                aggregatedNotes: "Distance audit: 100-yard stock shot carried 97-101."
            ),
            PracticeSessionRecord(
                date: calendar.date(byAdding: .day, value: -6, to: now) ?? now,
                templateName: "100-Yard Wedge Matrix",
                environment: PracticeEnvironment.range.rawValue,
                completedDrills: 2,
                totalDrills: 3,
                drillResults: [
                    DrillResult(name: "Carry Ladder", successfulReps: 5, totalReps: 12),
                    DrillResult(name: "Tempo Rehearsal", successfulReps: 6, totalReps: 8)
                ],
                sessionFeelNote: "Wind exposed the high-window miss quickly.",
                aiCoachingInsight: "{\"keyCues\":[\"Keep the chest quieter through transition to flatten the launch window.\",\"Start with three carry-ladder reps before adding speed.\"],\"focusDrills\":[\"Carry Ladder\"]}",
                coachingEfficacyScore: nil,
                isPersonalRecord: false,
                aggregatedNotes: "Window discipline: High window got loose into the wind."
            )
        ]
        practiceSessions.forEach(context.insert)

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
    var showsCommandCenterChrome = true
    let tabs: [ModuleHubTab]
    @Binding var selectedTab: ModuleHubTab
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubSectionSpacing.outer) {
                if showsCommandCenterChrome {
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
                }

                HubTabPicker(tabs: tabs, selectedTab: $selectedTab, theme: module.theme)

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ModuleSpacing.medium)
            .padding(.vertical, ModuleSpacing.medium)
        }
        .tint(module.theme.primary)
        .background {
            ZStack {
                module.theme.rootBackground
                    .ignoresSafeArea()
                module.theme.screenGradient
                    .ignoresSafeArea()
            }
        }
    }
}

struct GarageCustomScaffold<Content: View>: View {
    let module: AppModule
    let tabs: [ModuleHubTab]
    @Binding var selectedTab: ModuleHubTab
    let content: (CGSize) -> Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: HubSectionSpacing.outer) {
                    GarageModuleHeaderBar()

                    if tabs.isEmpty == false {
                        HubTabPicker(tabs: tabs, selectedTab: $selectedTab, theme: module.theme)
                    }

                    content(proxy.size)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ModuleSpacing.medium)
                .padding(.vertical, ModuleSpacing.medium)
            }
            .tint(module.theme.primary)
            .background {
                ZStack {
                    module.theme.rootBackground
                        .ignoresSafeArea()
                    module.theme.screenGradient
                        .ignoresSafeArea()
                }
            }
        }
    }
}

struct GarageModuleHeaderBar: View {
    var body: some View {
        HStack(alignment: .center, spacing: ModuleSpacing.medium) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Garage")
                    .font(ModuleTypography.overline.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(1.8)
                    .foregroundStyle(AppModule.garage.theme.textMuted)

                Text("GARAGE")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                GarageHeaderIconButton(systemImage: "gearshape.fill")

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ModuleTheme.electricCyan.opacity(0.9),
                                    Color(hex: "#138DB1")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("CT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ModuleTheme.garageSurfaceInset)
                }
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(ModuleTheme.electricCyan.opacity(0.55), lineWidth: 0.5)
                )
                .shadow(color: AppModule.garage.theme.tintedShadow.opacity(0.28), radius: 15, x: 0, y: 10)
            }
        }
    }
}

private struct GarageHeaderIconButton: View {
    let systemImage: String

    var body: some View {
        Button(action: {}) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous)
                        .stroke(ModuleTheme.electricCyan.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .shadow(color: AppModule.garage.theme.tintedShadow.opacity(0.24), radius: 15, x: 0, y: 10)
    }
}

struct GarageTelemetrySurface<Content: View>: View {
    var isActive = false
    var cornerRadius: CGFloat = ModuleCornerRadius.card
    var padding: CGFloat = ModuleSpacing.large
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .moduleFloatingCard(
            theme: AppModule.garage.theme,
            cornerRadius: cornerRadius,
            fill: AppModule.garage.theme.elevatedCardBackground,
            shadowColor: isActive ? AppModule.garage.theme.tintedShadow.opacity(0.28) : AppModule.garage.theme.shadowDark.opacity(0.22)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    isActive ? ModuleTheme.electricCyan.opacity(0.22) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

private struct HubStatusCard: View {
    let module: AppModule
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: HubSectionSpacing.content) {
            Text(title)
                .font(ModuleTypography.cardTitle)
            Text(bodyText)
                .foregroundStyle(module.theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .moduleFloatingCard(theme: module.theme)
    }
}

private struct HubTabPicker: View {
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
                            .foregroundStyle(selectedTab == tab ? theme.primary : theme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous)
                                    .fill(selectedTab == tab ? theme.pillBackground : theme.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous)
                                    .stroke(selectedTab == tab ? theme.primary.opacity(0.18) : theme.borderSubtle, lineWidth: 1)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ModuleHeroCard(
                    module: module,
                    eyebrow: "Module Root",
                    title: module.title,
                    message: description
                )

                ModuleFocusCard(module: module, highlights: highlights)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ModuleSpacing.medium)
            .padding(.vertical, ModuleSpacing.medium)
        }
        .tint(module.theme.primary)
        .background {
            ZStack {
                module.theme.rootBackground
                    .ignoresSafeArea()
                module.theme.screenGradient
                    .ignoresSafeArea()
            }
        }
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
                .font(ModuleTypography.overline.weight(.bold))
                .tracking(2)
                .foregroundStyle(module.theme.accentText)
            Text(title)
                .font(ModuleTypography.heroTitle)
                .foregroundStyle(module.theme.textPrimary)
            Text(message)
                .foregroundStyle(module.theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .moduleHeroSurface(theme: module.theme)
    }
}

struct ModuleFocusCard: View {
    let module: AppModule
    let highlights: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Current Focus")
                .font(ModuleTypography.cardTitle)

            ForEach(highlights, id: \.self) { highlight in
                HStack(spacing: 10) {
                    Circle()
                        .fill(module.theme.pillBackground)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(module.theme.primary.opacity(0.18), lineWidth: 1)
                        )
                    Text(highlight)
                        .foregroundStyle(module.theme.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .moduleFloatingCard(theme: module.theme)
    }
}

struct ModuleSnapshotCard<Content: View>: View {
    var theme: ModuleTheme? = nil
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            Text(title)
                .font(ModuleTypography.cardTitle)
            content
        }
        .padding(ModuleSpacing.medium)
        .moduleFloatingCard(theme: theme)
    }
}

struct ModuleMetricChip: View {
    let theme: ModuleTheme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(ModuleTypography.metricValue)
                .tracking(-1)
                .foregroundStyle(theme.textPrimary)
            Text(title)
                .font(ModuleTypography.supportingLabel.weight(.bold))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .moduleFloatingCard(
            theme: theme,
            cornerRadius: ModuleCornerRadius.chip,
            fill: theme.pillBackground,
            shadowColor: theme.tintedShadow.opacity(0.16)
        )
    }
}

struct ModuleEmptyStateCard: View {
    let theme: ModuleTheme
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(ModuleTypography.cardTitle)
            Text(message)
                .foregroundStyle(theme.textSecondary)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .moduleFloatingCard(theme: theme)
    }
}

struct ModuleVisualizationContainer<Content: View>: View {
    var theme: ModuleTheme? = nil
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            Text(title)
                .font(ModuleTypography.cardTitle)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .moduleFloatingCard(theme: theme)
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
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(theme.pillBackground, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .stroke(theme.primary.opacity(0.18), lineWidth: 1)
            )
            .foregroundStyle(theme.primary)
        }
        .padding(.horizontal, ModuleSpacing.medium)
        .padding(.vertical, ModuleSpacing.small)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.borderSubtle)
                .frame(height: 1)
        }
    }
}
