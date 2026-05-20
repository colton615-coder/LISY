import SwiftData
import SwiftUI

@MainActor
struct GarageDrillCatalogView: View {
    let environment: PracticeEnvironment

    @State private var grouping: GarageDrillCatalogGrouping = .category

    private var drills: [GarageDrill] {
        DrillVault.drills(in: environment)
    }

    private var groups: [GarageDrillCatalogGroup] {
        let grouped = Dictionary(grouping: drills) { drill in
            grouping.key(for: drill)
        }

        return grouped
            .map { key, drills in
                GarageDrillCatalogGroup(
                    title: key,
                    drills: drills.sorted { $0.id < $1.id }
                )
            }
            .sorted { $0.title < $1.title }
    }

    var body: some View {
        ZStack {
            GaragePracticeAtmosphereBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    groupingControl

                    if drills.isEmpty {
                        emptyState
                    } else {
                        groupList
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Drill Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .tint(GaragePremiumPalette.gold)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            GarageProSectionHeader(
                eyebrow: "Drill Catalog",
                title: "\(environment.displayName) Library"
            )

            HStack(spacing: 8) {
                GarageCatalogCountPill(value: "\(drills.count)", label: "Drills")
                GarageCatalogCountPill(value: "Net 10", label: "Source")
            }
        }
    }

    private var groupingControl: some View {
        Picker("Grouping", selection: $grouping) {
            ForEach(GarageDrillCatalogGrouping.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var groupList: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.title)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .foregroundStyle(GaragePremiumPalette.gold)

                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 152), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(group.drills) { drill in
                            GarageDrillCatalogCard(drill: drill)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        GarageProCard(cornerRadius: 24, padding: 18) {
            Text("No drills loaded.")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text("Phase 4A currently exposes Net 10 only.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GarageProTheme.textSecondary)
        }
    }
}

private enum GarageDrillCatalogGrouping: String, CaseIterable, Identifiable {
    case category
    case clubRange

    var id: Self { self }

    var title: String {
        switch self {
        case .category:
            return "Category"
        case .clubRange:
            return "Club"
        }
    }

    func key(for drill: GarageDrill) -> String {
        switch self {
        case .category:
            return drill.libraryCategory.displayName
        case .clubRange:
            return drill.clubRange.garageCompactDisplayName
        }
    }
}

private struct GarageDrillCatalogGroup: Identifiable {
    let title: String
    let drills: [GarageDrill]

    var id: String { title }
}

private struct GarageDrillCatalogCard: View {
    let drill: GarageDrill

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GarageDrillCatalogPlaceholder(category: drill.libraryCategory)

            Text(drill.title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            HStack(spacing: 8) {
                Text(drill.libraryCategory.displayName)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 25)
                    .background(GaragePremiumPalette.gold.opacity(0.10), in: Capsule())

                Spacer(minLength: 4)

                Text("\(drill.defaultRepCount) reps")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(GaragePremiumPalette.mintText)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 196, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(GarageProTheme.elevatedSurface.opacity(0.86), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(GaragePremiumPalette.mintText.opacity(0.11), lineWidth: 1)
        )
        .shadow(color: GarageProTheme.darkShadow, radius: 12, x: 0, y: 8)
    }
}

private struct GarageDrillCatalogPlaceholder: View {
    let category: GarageDrillLibraryCategory

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.36),
                            GaragePremiumPalette.emeraldGlass.opacity(0.34),
                            GaragePremiumPalette.emeraldDeep.opacity(0.80)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: symbol)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(GaragePremiumPalette.gold)
                .shadow(color: GaragePremiumPalette.gold.opacity(0.22), radius: 8, x: 0, y: 0)
        }
        .frame(height: 96)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.16), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private var symbol: String {
        switch category {
        case .ballStriking, .contact:
            return "scope"
        case .rotation:
            return "arrow.triangle.2.circlepath"
        case .tempo:
            return "metronome.fill"
        case .sequencing:
            return "point.3.connected.trianglepath.dotted"
        case .path, .delivery:
            return "arrow.up.left.and.arrow.down.right"
        case .faceControl:
            return "square.dashed"
        case .distanceControl:
            return "ruler.fill"
        case .pressure:
            return "target"
        case .putting:
            return "circle.grid.cross"
        }
    }

    private var tint: Color {
        switch category {
        case .ballStriking, .contact:
            return GaragePremiumPalette.goldDeep
        case .rotation:
            return GaragePremiumPalette.emerald
        case .tempo:
            return GarageProTheme.accent
        case .sequencing:
            return GaragePremiumPalette.mintText
        case .path, .delivery:
            return GaragePremiumPalette.gold
        case .faceControl, .distanceControl, .pressure, .putting:
            return GaragePremiumPalette.emerald
        }
    }
}

private struct GarageCatalogCountPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(GaragePremiumPalette.gold)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(GaragePremiumPalette.mintText)
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 38)
        .background(GaragePremiumPalette.emeraldGlass.opacity(0.36), in: Capsule())
        .overlay(Capsule().stroke(GaragePremiumPalette.mintText.opacity(0.12), lineWidth: 1))
    }
}

#Preview("Garage Drill Catalog") {
    NavigationStack {
        GarageDrillCatalogView(environment: .net)
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
