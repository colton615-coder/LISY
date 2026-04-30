import SwiftData
import SwiftUI

struct CapitalCoreView: View {
    @Query(sort: \ExpenseRecord.recordedAt, order: .reverse) private var expenses: [ExpenseRecord]
    @Query(sort: \BudgetRecord.title) private var budgets: [BudgetRecord]
    @State private var isShowingAddExpense = false
    @State private var isShowingAddBudget = false
    @State private var selectedTab: ModuleHubTab = .overview

    var body: some View {
        ModuleHubScaffold(
            module: .capitalCore,
            title: "Track money without extra noise.",
            subtitle: "Simple local capture for expenses and budgets with clear monthly visibility.",
            currentState: "\(currentMonthExpenses.count) expense entries logged this month.",
            nextAttention: budgets.isEmpty ? "Create your first budget target." : "Review categories running above target.",
            tabs: [.overview, .entries, .advisor],
            selectedTab: $selectedTab
        ) {
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
                ModuleEmptyStateCard(
                    theme: AppModule.capitalCore.theme,
                    title: "Advisor remains user-triggered",
                    message: "Use this tab for guided prompts only. No autonomous writes happen without explicit confirmation.",
                    actionTitle: "Add Expense",
                    action: { isShowingAddExpense = true }
                )
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
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            CapitalOverviewCard(
                monthlySpend: monthlySpend,
                expenseCount: expenseCount,
                budgetCount: budgets.count
            )

            ModuleActivityFeedSection(title: "Current Budgets") {
                HStack {
                    Spacer()
                    Button("Add Budget", action: createBudget)
                        .buttonStyle(MonochromeOutlineButtonStyle())
                }

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
        ModuleActivityFeedSection(title: "Recent Expenses") {
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
        ModuleVisualizationContainer(title: "Month Snapshot") {
            HStack(spacing: 12) {
                CapitalMetricChip(title: "Spent", value: monthlySpend, currency: true)
                CapitalMetricChip(title: "Expenses", value: Double(expenseCount), currency: false)
                CapitalMetricChip(title: "Budgets", value: Double(budgetCount), currency: false)
            }
        }
    }
}

private struct CapitalMetricChip: View {
    let title: String
    let value: Double
    let currency: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(formattedValue)
                .font(ModuleTypography.metricValue)
            Text(title)
                .font(ModuleTypography.supportingLabel)
                .foregroundStyle(ModuleTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(AppModule.capitalCore.theme.chipBackground, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.title)
                        .font(.headline)
                    Text(budget.periodLabel)
                        .font(.caption)
                        .foregroundStyle(ModuleTheme.secondaryText)
                }
                Spacer()
                Text("\(spentAmount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))) / \(budget.limitAmount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))")
                    .font(.caption)
                    .foregroundStyle(ModuleTheme.secondaryText)
            }

            ProgressView(value: progress)
                .tint(AppModule.capitalCore.theme.primary)
        }
        .padding()
        .puttingGreenSurface()
    }
}

private struct ExpenseCard: View {
    let expense: ExpenseRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.headline)
                Text(expense.category)
                    .font(.caption)
                    .foregroundStyle(ModuleTheme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(expense.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                    .font(.headline)
                Text(expense.recordedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(ModuleTheme.secondaryText)
        }
        }
        .padding()
        .puttingGreenSurface(cornerRadius: ModuleCornerRadius.row)
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
                .listRowBackground(ModuleTheme.elevatedSurface)
            }
            .puttingGreenFormChrome()
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
        .puttingGreenSheetChrome()
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
                .listRowBackground(ModuleTheme.elevatedSurface)
            }
            .puttingGreenFormChrome()
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
        .puttingGreenSheetChrome()
    }
}

#Preview("Capital Core") {
    PreviewScreenContainer {
        CapitalCoreView()
    }
    .modelContainer(for: [ExpenseRecord.self, BudgetRecord.self], inMemory: true)
}
