import SwiftData
import SwiftUI

struct CapitalCoreView: View {
    @Query(sort: \ExpenseRecord.recordedAt, order: .reverse) private var expenses: [ExpenseRecord]
    @Query(sort: \BudgetRecord.title) private var budgets: [BudgetRecord]
    @State private var isShowingAddExpense = false
    @State private var isShowingAddBudget = false
    @State private var selectedTab: ModuleHubTab = .overview

    init(initialTab: ModuleHubTab = .overview) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ModuleScreen(theme: AppModule.capitalCore.theme) {
            ModuleHeader(
                theme: AppModule.capitalCore.theme,
                title: "Capital Core",
                subtitle: "Track money without extra noise and keep this month readable."
            )

            ModuleHeroCard(
                module: .capitalCore,
                eyebrow: "Month View",
                title: monthlySpendTitle,
                message: budgets.isEmpty ? "Add a budget target when you want tighter guardrails." : "\(currentMonthExpenses.count) expense entries logged this month."
            )

            HubTabPicker(tabs: [.overview, .entries, .advisor], selectedTab: $selectedTab, theme: AppModule.capitalCore.theme)

            switch selectedTab {
            case .overview:
                CapitalOverviewTab(
                    monthlySpend: currentMonthExpenses.reduce(0) { $0 + $1.amount },
                    expenseCount: currentMonthExpenses.count,
                    budgets: budgets,
                    spentAmount: spentAmount(for:)
                ) {
                    isShowingAddBudget = true
                }
            case .entries:
                CapitalEntriesTab(expenses: expenses) {
                    isShowingAddExpense = true
                }
            case .advisor:
                ModuleRowSurface(theme: AppModule.capitalCore.theme) {
                    Text("Advisor remains user-triggered")
                        .font(ModuleTypography.cardTitle)
                        .foregroundStyle(AppModule.capitalCore.theme.textPrimary)
                    Text("Use this tab for guided prompts only. No autonomous writes happen without explicit confirmation.")
                        .foregroundStyle(AppModule.capitalCore.theme.textSecondary)
                    Button("Add Expense") {
                        isShowingAddExpense = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.capitalCore.theme.primary)
                }
            default:
                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            ModuleBottomActionBar(
                theme: AppModule.capitalCore.theme,
                title: "Add Expense",
                systemImage: "plus"
            ) {
                isShowingAddExpense = true
            }
        }
        .sheet(isPresented: $isShowingAddExpense) {
            AddExpenseSheet()
        }
        .sheet(isPresented: $isShowingAddBudget) {
            AddBudgetSheet()
        }
    }

    private var monthlySpendTitle: String {
        let total = currentMonthExpenses.reduce(0) { $0 + $1.amount }
        return total.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    private var currentMonthExpenses: [ExpenseRecord] {
        expenses.filter { Calendar.current.isDate($0.recordedAt, equalTo: .now, toGranularity: .month) }
    }

    private func spentAmount(for budget: BudgetRecord) -> Double {
        currentMonthExpenses
            .filter { $0.category == budget.title }
            .reduce(0) { $0 + $1.amount }
    }
}

private struct CapitalOverviewTab: View {
    let monthlySpend: Double
    let expenseCount: Int
    let budgets: [BudgetRecord]
    let spentAmount: (BudgetRecord) -> Double
    let createBudget: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.large) {
            CapitalOverviewCard(
                monthlySpend: monthlySpend,
                expenseCount: expenseCount,
                budgetCount: budgets.count
            )

            ModuleListSection(title: "Current Budgets") {
                if budgets.isEmpty {
                    CapitalEmptyStateView(
                        title: "No budgets yet",
                        message: "Set a simple target to keep spending visible.",
                        actionTitle: "Create Budget",
                        action: createBudget
                    )
                } else {
                    ForEach(budgets) { budget in
                        BudgetCard(budget: budget, spentAmount: spentAmount(budget))
                    }
                }
            }
        }
    }
}

private struct CapitalEntriesTab: View {
    let expenses: [ExpenseRecord]
    let addExpense: () -> Void

    var body: some View {
        ModuleListSection(title: "Recent Expenses") {
            if expenses.isEmpty {
                CapitalEmptyStateView(
                    title: "No expenses logged",
                    message: "Add the first expense to start building your monthly picture.",
                    actionTitle: "Add Expense",
                    action: addExpense
                )
            } else {
                ForEach(expenses.prefix(8)) { expense in
                    ExpenseCard(expense: expense)
                }
            }
        }
    }
}

private struct CapitalOverviewCard: View {
    let monthlySpend: Double
    let expenseCount: Int
    let budgetCount: Int

    var body: some View {
        ModuleMetricStrip(theme: AppModule.capitalCore.theme) {
            CapitalMetricChip(title: "Spent", value: monthlySpend, currency: true)
            CapitalMetricChip(title: "Expenses", value: Double(expenseCount), currency: false)
            CapitalMetricChip(title: "Budgets", value: Double(budgetCount), currency: false)
        }
    }
}

private struct CapitalMetricChip: View {
    let title: String
    let value: Double
    let currency: Bool

    var body: some View {
        ModuleMetricItem(theme: AppModule.capitalCore.theme, title: title, value: formattedValue)
    }

    private var formattedValue: String {
        if currency {
            value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        } else {
            Int(value).formatted()
        }
    }
}

private struct BudgetCard: View {
    let budget: BudgetRecord
    let spentAmount: Double

    private var progress: Double {
        guard budget.limitAmount > 0 else { return 0 }
        return min(spentAmount / budget.limitAmount, 1)
    }

    var body: some View {
        ModuleRowSurface(theme: AppModule.capitalCore.theme) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.title)
                        .font(.headline)
                        .foregroundStyle(AppModule.capitalCore.theme.textPrimary)
                    Text(budget.periodLabel)
                        .font(.caption)
                        .foregroundStyle(AppModule.capitalCore.theme.textSecondary)
                }
                Spacer()
                Text("\(spentAmount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))) / \(budget.limitAmount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))")
                    .font(.caption)
                    .foregroundStyle(AppModule.capitalCore.theme.textSecondary)
            }

            ProgressView(value: progress)
                .tint(AppModule.capitalCore.theme.primary)
        }
    }
}

private struct ExpenseCard: View {
    let expense: ExpenseRecord

    var body: some View {
        ModuleRowSurface(theme: AppModule.capitalCore.theme) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.title)
                        .font(.headline)
                        .foregroundStyle(AppModule.capitalCore.theme.textPrimary)
                    Text(expense.category)
                        .font(.caption)
                        .foregroundStyle(AppModule.capitalCore.theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(expense.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                        .font(.headline)
                        .foregroundStyle(AppModule.capitalCore.theme.textPrimary)
                    Text(expense.recordedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(AppModule.capitalCore.theme.textSecondary)
                }
            }
        }
    }
}

private struct CapitalEmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.capitalCore.theme,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
    }
}

private struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var amount = ""
    @State private var category = "General"

    private let categories = ["General", "Food", "Transport", "Bills", "Health", "Shopping"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Expense title", text: $title)
                    TextField("Amount", text: $amount)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("New Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedTitle.isEmpty == false, let amountValue = Double(amount) else {
                            return
                        }

                        modelContext.insert(
                            ExpenseRecord(
                                title: trimmedTitle,
                                amount: amountValue,
                                category: category
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Double(amount) == nil)
                }
            }
        }
    }
}

private struct AddBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = "General"
    @State private var limitAmount = ""
    @State private var periodLabel = "Monthly"

    private let categories = ["General", "Food", "Transport", "Bills", "Health", "Shopping"]
    private let periods = ["Weekly", "Monthly"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget Details") {
                    Picker("Category", selection: $title) {
                        ForEach(categories, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }

                    TextField("Limit Amount", text: $limitAmount)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif

                    Picker("Period", selection: $periodLabel) {
                        ForEach(periods, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("New Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let limitValue = Double(limitAmount) else {
                            return
                        }

                        modelContext.insert(
                            BudgetRecord(
                                title: title,
                                limitAmount: limitValue,
                                periodLabel: periodLabel
                            )
                        )
                        dismiss()
                    }
                    .disabled(Double(limitAmount) == nil)
                }
            }
        }
    }
}

#Preview("Capital Core Overview") {
    PreviewScreenContainer {
        CapitalCoreView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
    .preferredColorScheme(.dark)
}

#Preview("Capital Core Entries") {
    PreviewScreenContainer {
        CapitalCoreView(initialTab: .entries)
    }
    .modelContainer(PreviewCatalog.populatedApp)
    .preferredColorScheme(.dark)
}

#Preview("Capital Core Empty") {
    PreviewScreenContainer {
        CapitalCoreView(initialTab: .overview)
    }
    .modelContainer(PreviewCatalog.emptyApp)
    .preferredColorScheme(.dark)
}
