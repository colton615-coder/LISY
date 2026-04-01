import SwiftData
import SwiftUI

struct CapitalCoreView: View {
    @Query(sort: \ExpenseRecord.recordedAt, order: .reverse) private var expenses: [ExpenseRecord]
    @Query(sort: \BudgetRecord.title) private var budgets: [BudgetRecord]
    @State private var isShowingAddExpense = false
    @State private var isShowingAddBudget = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModuleHeroCard(
                    module: .capitalCore,
                    eyebrow: "Live Module",
                    title: "Track money without extra noise.",
                    message: "Capital Core starts with simple expense capture, category visibility, and budget targets that stay local to the device."
                )

                CapitalOverviewCard(
                    monthlySpend: currentMonthExpenses.reduce(0) { $0 + $1.amount },
                    expenseCount: currentMonthExpenses.count,
                    budgetCount: budgets.count
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Current Budgets")
                            .font(.headline)
                        Spacer()
                        Button("Add Budget") {
                            isShowingAddBudget = true
                        }
                        .buttonStyle(.bordered)
                    }

                    if budgets.isEmpty {
                        CapitalEmptyStateView(
                            title: "No budgets yet",
                            message: "Set a simple target to keep spending visible.",
                            actionTitle: "Create Budget",
                            action: { isShowingAddBudget = true }
                        )
                    } else {
                        ForEach(budgets) { budget in
                            BudgetCard(
                                budget: budget,
                                spentAmount: spentAmount(for: budget)
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Expenses")
                        .font(.headline)

                    if expenses.isEmpty {
                        CapitalEmptyStateView(
                            title: "No expenses logged",
                            message: "Add the first expense to start building your monthly picture.",
                            actionTitle: "Add Expense",
                            action: { isShowingAddExpense = true }
                        )
                    } else {
                        ForEach(expenses.prefix(8)) { expense in
                            ExpenseCard(expense: expense)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppModule.capitalCore.theme.screenGradient)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    isShowingAddExpense = true
                } label: {
                    Label("Add Expense", systemImage: "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppModule.capitalCore.theme.primary)
            }
            .padding()
            .background(.ultraThinMaterial)
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

private struct CapitalOverviewCard: View {
    let monthlySpend: Double
    let expenseCount: Int
    let budgetCount: Int

    var body: some View {
        ModuleSnapshotCard(title: "Month Snapshot") {
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
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppModule.capitalCore.theme.chipBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(spentAmount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))) / \(budget.limitAmount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(AppModule.capitalCore.theme.primary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(expense.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                    .font(.headline)
                Text(expense.recordedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

#Preview("Capital Core") {
    PreviewScreenContainer {
        CapitalCoreView()
    }
    .modelContainer(for: [ExpenseRecord.self, BudgetRecord.self], inMemory: true)
}
