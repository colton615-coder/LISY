import SwiftUI

struct ModuleMenuView: View {
    @Binding var selectedModule: AppModule
    @Environment(\.dismiss) private var dismiss

    private var theme: ModuleTheme {
        selectedModule.theme
    }

    var body: some View {
        ModuleScreen(theme: theme) {
            ModuleHeader(
                theme: theme,
                title: "Modules",
                subtitle: "Move through the app without leaving the current flow."
            )

            ModuleListSection(title: "All Modules") {
                ForEach(AppModule.allCases) { module in
                    Button {
                        selectedModule = module
                        dismiss()
                    } label: {
                        ModuleRowSurface(theme: themeForRow(module)) {
                            HStack(spacing: ModuleSpacing.medium) {
                                Image(systemName: module.systemImage)
                                    .font(.headline)
                                    .foregroundStyle(module.theme.primary)
                                    .frame(width: 32, height: 32)
                                    .background(module.theme.accentSoft, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.small, style: .continuous))

                                VStack(alignment: .leading, spacing: ModuleSpacing.xxSmall) {
                                    Text(module.title)
                                        .font(.headline)
                                        .foregroundStyle(theme.textPrimary)
                                    Text(module.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(theme.textSecondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                if selectedModule == module {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(module.theme.primary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("module-menu-\(module.rawValue)")
                }
            }
        }
        .navigationTitle("Modules")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.canvasBase.opacity(0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func themeForRow(_ module: AppModule) -> ModuleTheme {
        if selectedModule == module {
            return module.theme
        }

        return ModuleTheme(
            primary: theme.primary,
            secondary: theme.secondary,
            backgroundTop: theme.backgroundTop,
            backgroundBottom: theme.backgroundBottom,
            accentText: theme.accentText
        )
    }
}

#Preview("Module Menu Dashboard") {
    NavigationStack {
        ModuleMenuView(selectedModule: .constant(.dashboard))
    }
    .preferredColorScheme(.dark)
}

#Preview("Module Menu Calendar Selected") {
    NavigationStack {
        ModuleMenuView(selectedModule: .constant(.calendar))
    }
    .preferredColorScheme(.dark)
}
