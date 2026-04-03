import SwiftData
import SwiftUI

struct SupplyListView: View {
    @Query(sort: \SupplyItem.category) private var items: [SupplyItem]
    @State private var isShowingAddItem = false

    var body: some View {
        ModuleScreen(theme: AppModule.supplyList.theme) {
            ModuleHeader(
                theme: AppModule.supplyList.theme,
                title: "Supply List",
                subtitle: "Keep the shopping list clean and focused on what still needs to be bought."
            )

            if groupedRemainingItems.isEmpty {
                if purchasedItems.isEmpty {
                    SupplyEmptyStateView {
                        isShowingAddItem = true
                    }
                } else {
                    ModuleInlineEmptyState(
                        theme: AppModule.supplyList.theme,
                        title: "Nothing left to buy",
                        message: "All current items are marked purchased. Add something new when the list starts building again.",
                        actionTitle: "Add Item",
                        action: { isShowingAddItem = true }
                    )
                }
            } else {
                ModuleListSection(title: "To Buy") {
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
                ModuleDisclosureSection(title: "Purchased", theme: AppModule.supplyList.theme) {
                    ForEach(purchasedItems) { item in
                        SupplyItemRow(item: item)
                    }
                }
            }
        }
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

private struct SupplyCategorySection: View {
    let category: String
    let items: [SupplyItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category)
                .font(.headline)
                .foregroundStyle(AppModule.supplyList.theme.textPrimary)

            ForEach(items) { item in
                SupplyItemRow(item: item)
            }
        }
    }
}

private struct SupplyItemRow: View {
    @Bindable var item: SupplyItem

    var body: some View {
        ModuleRowSurface(theme: AppModule.supplyList.theme) {
            HStack(spacing: 12) {
                Button {
                    item.isPurchased.toggle()
                } label: {
                    Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(item.isPurchased ? AppModule.supplyList.theme.primary : AppModule.supplyList.theme.textSecondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(AppModule.supplyList.theme.textPrimary)
                        .strikethrough(item.isPurchased, color: .secondary)
                    Text(item.category)
                        .font(.caption)
                        .foregroundStyle(AppModule.supplyList.theme.textSecondary)
                }

                Spacer()
            }
        }
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
    .preferredColorScheme(.dark)
}

#Preview("Supply List Grouped") {
    PreviewScreenContainer {
        SupplyListView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
    .preferredColorScheme(.dark)
}
