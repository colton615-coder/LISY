import SwiftData
import SwiftUI

struct SupplyListView: View {
    @Query(sort: \SupplyItem.category) private var items: [SupplyItem]
    @State private var isShowingAddItem = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModuleHeroCard(
                    module: .supplyList,
                    eyebrow: "Live Module",
                    title: "Keep the shopping list clean.",
                    message: "Supply List stays focused on what to buy, how it is grouped, and what has already been picked up."
                )

                SupplyOverviewCard(
                    totalCount: items.count,
                    remainingCount: remainingItems.count,
                    purchasedCount: purchasedItems.count
                )

                if groupedRemainingItems.isEmpty {
                    SupplyEmptyStateView {
                        isShowingAddItem = true
                    }
                } else {
                    ModuleActivityFeedSection(title: "Remaining By Category") {
                        ForEach(groupedRemainingItems.keys.sorted(), id: \.self) { category in
                            if let categoryItems = groupedRemainingItems[category] {
                                SupplyCategorySection(
                                    category: category,
                                    items: categoryItems
                                )
                            }
                        }
                    }
                }

                if purchasedItems.isEmpty == false {
                    ModuleActivityFeedSection(title: "Purchased") {
                        ForEach(purchasedItems) { item in
                            SupplyItemRow(item: item)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppModule.supplyList.theme.screenGradient)
        .safeAreaInset(edge: .bottom) {
            ModuleBottomActionBar(
                theme: AppModule.supplyList.theme,
                title: "Add Item",
                systemImage: "plus"
            ) {
                isShowingAddItem = true
            }
        }
        .sheet(isPresented: $isShowingAddItem) {
            AddSupplyItemSheet()
        }
    }

    private var remainingItems: [SupplyItem] {
        items.filter { $0.isPurchased == false }
    }

    private var purchasedItems: [SupplyItem] {
        items.filter(\.isPurchased)
    }

    private var groupedRemainingItems: [String: [SupplyItem]] {
        Dictionary(grouping: remainingItems) { $0.category }
    }
}

private struct SupplyOverviewCard: View {
    let totalCount: Int
    let remainingCount: Int
    let purchasedCount: Int

    var body: some View {
        ModuleVisualizationContainer(theme: AppModule.supplyList.theme, title: "List Snapshot") {
            HStack(spacing: 12) {
                ModuleMetricChip(theme: AppModule.supplyList.theme, title: "Total", value: "\(totalCount)")
                ModuleMetricChip(theme: AppModule.supplyList.theme, title: "Remaining", value: "\(remainingCount)")
                ModuleMetricChip(theme: AppModule.supplyList.theme, title: "Purchased", value: "\(purchasedCount)")
            }
        }
    }
}

private struct SupplyCategorySection: View {
    let category: String
    let items: [SupplyItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category)
                .font(.headline)

            ForEach(items) { item in
                SupplyItemRow(item: item)
            }
        }
    }
}

private struct SupplyItemRow: View {
    @Bindable var item: SupplyItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                item.isPurchased.toggle()
            } label: {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isPurchased ? AppModule.supplyList.theme.primary : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.isPurchased, color: .secondary)
                Text(item.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct SupplyEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.supplyList.theme,
            title: "No shopping items yet",
            message: "Add what you need to buy, group it by category, and mark items off as you go.",
            actionTitle: "Add First Item",
            action: action
        )
    }
}

private struct AddSupplyItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var category = "Groceries"

    private let categories = ["Groceries", "Household", "Personal", "Tech", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item name", text: $title)

                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("New Item")
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
                            SupplyItem(
                                title: trimmedTitle,
                                category: category
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

#Preview("Supply List Empty") {
    PreviewScreenContainer {
        SupplyListView()
    }
    .modelContainer(PreviewCatalog.emptyApp)
}

#Preview("Supply List Grouped") {
    PreviewScreenContainer {
        SupplyListView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
