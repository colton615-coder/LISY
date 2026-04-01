import SwiftUI

struct PreviewScreenContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            content
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
            .padding()
        }
        .tint(module.theme.primary)
        .background(module.theme.screenGradient)
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
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(module.theme.heroGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(module.theme.primary.opacity(0.18), lineWidth: 1)
        )
    }
}

struct ModuleFocusCard: View {
    let module: AppModule
    let highlights: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Current Focus")
                .font(.headline)

            ForEach(highlights, id: \.self) { highlight in
                HStack(spacing: 10) {
                    Circle()
                        .fill(module.theme.primary)
                        .frame(width: 8, height: 8)
                    Text(highlight)
                        .foregroundStyle(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ModuleSnapshotCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ModuleMetricChip: View {
    let theme: ModuleTheme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(theme.chipBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
