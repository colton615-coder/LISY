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
    let onOpenEnvironment: (PracticeEnvironment) -> Void
    let onStartTempoBuilder: () -> Void
    let onNewJournalEntry: () -> Void
    let onOpenJournalArchive: () -> Void

    var body: some View {
        ZStack {
            GaragePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    carryForwardHero
                    platformSection
                    quickActionsSection
                    vaultPreviewSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .tint(GaragePremiumPalette.gold)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Garage")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("Choose the work. Keep the session focused.")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(GaragePremiumPalette.mintText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(GaragePremiumPalette.emeraldGlass.opacity(0.76))
                    .frame(width: 62, height: 62)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(GaragePremiumPalette.gold.opacity(0.34), lineWidth: 1)
                    )
                    .shadow(color: GaragePremiumPalette.gold.opacity(0.18), radius: 16, x: 0, y: 0)

                Image(systemName: "figure.golf")
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(GaragePremiumPalette.gold)
            }
            .accessibilityHidden(true)
        }
    }

    private var carryForwardHero: some View {
        GarageHeroCard(
            eyebrow: "Last Cue",
            title: "Brush through and hold the finish.",
            subtitle: "Keep one clean carry-forward thought before choosing today's surface.",
            ctaTitle: "Open Archive",
            ctaSystemImage: "arrow.right",
            ctaAction: onOpenJournalArchive
        ) {
            ZStack {
                Circle()
                    .stroke(GaragePremiumPalette.gold.opacity(0.18), lineWidth: 1)
                    .frame(width: 92, height: 92)

                Circle()
                    .trim(from: 0.10, to: 0.82)
                    .stroke(
                        GaragePremiumPalette.gold.opacity(0.7),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 74, height: 74)
                    .rotationEffect(.degrees(-18))

                Image(systemName: "quote.opening")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(GaragePremiumPalette.gold)
            }
        }
    }

    private var platformSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GarageSectionHeader(eyebrow: "Choose Platform")

            VStack(spacing: 12) {
                ForEach(PracticeEnvironment.allCases) { environment in
                    GaragePlatformCard(environment: environment) {
                        onOpenEnvironment(environment)
                    }
                }
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GarageSectionHeader(eyebrow: "Quick Actions")

            GarageGlassPanel(cornerRadius: 28, padding: 14) {
                GarageGoldButton(
                    title: "Start Tempo Builder",
                    systemImage: "metronome.fill",
                    action: onStartTempoBuilder
                )

                HStack(spacing: 10) {
                    GarageQuickActionTile(
                        title: "New Entry",
                        subtitle: "Capture cue",
                        systemImage: "square.and.pencil",
                        isPrimary: true,
                        action: onNewJournalEntry
                    )

                    GarageQuickActionTile(
                        title: "Archive",
                        subtitle: "Read back",
                        systemImage: "archivebox.fill",
                        action: onOpenJournalArchive
                    )
                }
            }
        }
    }

    private var vaultPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GarageSectionHeader(
                eyebrow: "Vault Preview",
                actionTitle: "View All",
                actionSystemImage: "arrow.right",
                action: onOpenJournalArchive
            )

            GarageGlassPanel(cornerRadius: 28, padding: 14) {
                GarageRecentSessionRow(
                    title: "Range Session",
                    subtitle: "Memory cue",
                    detail: "Tempo held steady on approach.",
                    systemImage: "flag.fill",
                    score: "8.2",
                    action: onOpenJournalArchive
                )

                GarageRecentSessionRow(
                    title: "Putting Notes",
                    subtitle: "Carry forward",
                    detail: "Lag putting feels better with quiet hands.",
                    systemImage: "circle.grid.3x3.fill",
                    score: "7.4",
                    action: onOpenJournalArchive
                )
            }
        }
    }
}

private struct GaragePlatformCard: View {
    let environment: PracticeEnvironment
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            GarageGlassPanel(cornerRadius: 28, padding: 0, isProminent: environment == .range) {
                HStack(spacing: 14) {
                    surfaceThumbnail

                    Image(systemName: environment.systemImage)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(GaragePremiumPalette.gold)
                        .frame(width: 62, height: 62)
                        .background(GaragePremiumPalette.emeraldDeep.opacity(0.74), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 21, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(environment.displayName)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(GarageProTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)

                        Text(summary)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(GaragePremiumPalette.mintText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(GaragePremiumPalette.gold)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var surfaceThumbnail: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(surfaceGradient)
                .frame(width: 104, height: 94)
                .overlay(surfacePattern)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 10, height: 10)
                .padding(13)
        }
        .accessibilityHidden(true)
    }

    private var surfaceGradient: LinearGradient {
        switch environment {
        case .net:
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.30, blue: 0.15),
                    Color(red: 0.01, green: 0.10, blue: 0.07),
                    GaragePremiumPalette.gold.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .range:
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.42, blue: 0.14),
                    Color(red: 0.03, green: 0.16, blue: 0.08),
                    Color(red: 0.36, green: 0.50, blue: 0.16).opacity(0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .puttingGreen:
            LinearGradient(
                colors: [
                    Color(red: 0.23, green: 0.46, blue: 0.15),
                    Color(red: 0.04, green: 0.19, blue: 0.08),
                    Color(red: 0.01, green: 0.08, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var surfacePattern: some View {
        switch environment {
        case .net:
            Image(systemName: "scope")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(GaragePremiumPalette.gold.opacity(0.8))
        case .range:
            VStack(spacing: 9) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.11))
                        .frame(height: 1)
                }
            }
            .padding(.horizontal, 16)
        case .puttingGreen:
            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: 7)
                .frame(width: 34, height: 34)
                .offset(x: 24, y: -8)
        }
    }

    private var summary: String {
        switch environment {
        case .net:
            "Mechanics, contact, and tight feedback."
        case .range:
            "Ball flight, targets, and club-specific work."
        case .puttingGreen:
            "Start line, pace, and green-reading reps."
        }
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
