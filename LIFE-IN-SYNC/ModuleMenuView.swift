import SwiftUI

struct ModuleMenuView: View {
    @Binding var selectedModule: AppModule
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(AppModule.allCases) { module in
            Button {
                selectedModule = module
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: module.systemImage)
                        .frame(width: 24)
                        .foregroundStyle(module.theme.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(module.title)
                            .font(.headline)
                        Text(module.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selectedModule == module {
                        Image(systemName: "checkmark")
                            .foregroundStyle(module.theme.primary)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("module-menu-\(module.rawValue)")
            .listRowBackground(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(module == selectedModule ? module.theme.chipBackground : .clear)
            )
        }
        .navigationTitle("Modules")
    }
}

#Preview("Module Menu Dashboard") {
    NavigationStack {
        ModuleMenuView(selectedModule: .constant(.dashboard))
    }
}

#Preview("Module Menu Calendar Selected") {
    NavigationStack {
        ModuleMenuView(selectedModule: .constant(.calendar))
    }
}
