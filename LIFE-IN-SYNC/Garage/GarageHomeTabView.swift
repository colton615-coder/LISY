import Foundation
import SwiftData
import SwiftUI

struct GarageProSectionHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(GarageProTheme.accent)

            Text(title)
                .font(.system(.title2, design: .rounded).weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)
        }
    }
}

@MainActor
struct GarageHomeTabView: View {
    @State private var activeCard: GarageHomeCardKind? = .drillPlans

    let onOpenEnvironment: (PracticeEnvironment) -> Void
    let onStartTempoBuilder: () -> Void
    let onNewJournalEntry: () -> Void
    let onOpenJournalArchive: () -> Void

    private let cards = GarageHomeCardKind.allCases

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                GarageProTheme.background
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        ModuleTheme.garageBackgroundLift.opacity(0.96),
                        ModuleTheme.garageBackground.opacity(0.99),
                        ModuleTheme.garageSurfaceDark.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 18)

                    cardDeck(in: proxy)

                    GarageHomePageIndicator(cards: cards, activeCard: activeCard ?? .drillPlans)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 18)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .tint(GarageProTheme.accent)
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Garage")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text("Choose the work. Keep the session focused.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }

            Spacer(minLength: 12)

            Image(systemName: "figure.golf")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(GarageProTheme.accent)
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        }
    }

    private func cardDeck(in proxy: GeometryProxy) -> some View {
        let cardWidth = max(proxy.size.width - 54, 300)
        let cardHeight = max(proxy.size.height - 168, 500)

        return ScrollView(.horizontal) {
            LazyHStack(spacing: 14) {
                ForEach(cards) { card in
                    GarageHomeSwipeCard(
                        card: card,
                        onOpenEnvironment: onOpenEnvironment,
                        onStartTempoBuilder: onStartTempoBuilder,
                        onNewJournalEntry: onNewJournalEntry,
                        onOpenJournalArchive: onOpenJournalArchive
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .id(card)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $activeCard)
    }
}

private enum GarageHomeCardKind: String, CaseIterable, Identifiable, Hashable {
    case drillPlans
    case tempoBuilder
    case journal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drillPlans:
            "Drill Plans"
        case .tempoBuilder:
            "Tempo Builder"
        case .journal:
            "Journal"
        }
    }

    var eyebrow: String {
        switch self {
        case .drillPlans:
            "Practice"
        case .tempoBuilder:
            "Rhythm"
        case .journal:
            "Memory"
        }
    }

    var subtitle: String {
        switch self {
        case .drillPlans:
            "Choose the surface first, then select or create a repeatable routine."
        case .tempoBuilder:
            "Train swing rhythm and timing with a focused, standalone practice tool."
        case .journal:
            "Capture the cues, feels, and course lessons worth carrying forward."
        }
    }

    var systemImage: String {
        switch self {
        case .drillPlans:
            "square.grid.2x2.fill"
        case .tempoBuilder:
            "metronome.fill"
        case .journal:
            "book.closed.fill"
        }
    }
}

private struct GarageHomeSwipeCard: View {
    let card: GarageHomeCardKind
    let onOpenEnvironment: (PracticeEnvironment) -> Void
    let onStartTempoBuilder: () -> Void
    let onNewJournalEntry: () -> Void
    let onOpenJournalArchive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            cardHeader

            Spacer(minLength: 12)

            switch card {
            case .drillPlans:
                environmentActions
            case .tempoBuilder:
                GarageRevampPrimaryActionButton(
                    title: "Start",
                    systemImage: "play.fill",
                    action: onStartTempoBuilder
                )
            case .journal:
                VStack(spacing: 12) {
                    GarageRevampPrimaryActionButton(
                        title: "New Entry",
                        systemImage: "square.and.pencil",
                        action: onNewJournalEntry
                    )

                    GarageRevampSecondaryActionButton(
                        title: "Archive",
                        systemImage: "archivebox.fill",
                        action: onOpenJournalArchive
                    )
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ModuleTheme.garageTurfSurface.opacity(0.86),
                            GarageProTheme.elevatedSurface.opacity(0.94),
                            GarageProTheme.insetSurface.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: GarageProTheme.darkShadow.opacity(0.95), radius: 24, x: 0, y: 18)
        .shadow(color: GarageProTheme.glow.opacity(0.18), radius: 22, x: 0, y: 0)
    }

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: card.systemImage)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 62, height: 62)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(GarageProTheme.accent.opacity(0.28), lineWidth: 1)
                    )

                Spacer(minLength: 12)

                Text(card.eyebrow)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(2.1)
                    .foregroundStyle(GarageProTheme.accent.opacity(0.86))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(GarageProTheme.insetSurface.opacity(0.78), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(GarageProTheme.border, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(card.title)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)

                Text(card.subtitle)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var environmentActions: some View {
        VStack(spacing: 12) {
            ForEach(PracticeEnvironment.allCases) { environment in
                GarageRevampEnvironmentButton(environment: environment) {
                    onOpenEnvironment(environment)
                }
            }
        }
    }
}

private struct GarageRevampEnvironmentButton: View {
    let environment: PracticeEnvironment
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: environment.systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(environment.displayName)
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(environment.description)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.black))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .background(GarageProTheme.insetSurface.opacity(0.86), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(GarageProTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageRevampPrimaryActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerImpact(.heavy)
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(.headline, design: .rounded).weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(ModuleTheme.garageSurfaceDark)
                .frame(maxWidth: .infinity, minHeight: 66)
                .background(
                    LinearGradient(
                        colors: [
                            GarageProTheme.accent,
                            GarageProTheme.accent.opacity(0.76)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .shadow(color: GarageProTheme.glow.opacity(0.32), radius: 16, x: 0, y: 10)
    }
}

private struct GarageRevampSecondaryActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(GarageProTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 62)
                .background(GarageProTheme.insetSurface.opacity(0.86), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageHomePageIndicator: View {
    let cards: [GarageHomeCardKind]
    let activeCard: GarageHomeCardKind

    var body: some View {
        HStack(spacing: 8) {
            ForEach(cards) { card in
                Capsule()
                    .fill(card == activeCard ? GarageProTheme.accent : GarageProTheme.textSecondary.opacity(0.24))
                    .frame(width: card == activeCard ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: activeCard)
            }
        }
        .accessibilityLabel("\(activeIndex + 1) of \(cards.count)")
    }

    private var activeIndex: Int {
        cards.firstIndex(of: activeCard) ?? 0
    }
}

#Preview("Garage Revamp Home") {
    GarageHomeTabView(
        onOpenEnvironment: { _ in },
        onStartTempoBuilder: {},
        onNewJournalEntry: {},
        onOpenJournalArchive: {}
    )
    .modelContainer(PreviewCatalog.populatedApp)
}
