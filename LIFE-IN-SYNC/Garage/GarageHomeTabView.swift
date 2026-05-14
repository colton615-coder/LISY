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

    @State private var selectedService: GarageHomeService = .drillPlans

    var body: some View {
        ZStack {
            GaragePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    servicePager
                    servicePageDots
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .tint(GaragePremiumPalette.gold)
    }

    private var servicePager: some View {
        TabView(selection: $selectedService) {
            GarageDrillPlansServicePage(onOpenEnvironment: onOpenEnvironment)
                .tag(GarageHomeService.drillPlans)

            GarageTempoServicePage(onStartTempoBuilder: onStartTempoBuilder)
                .tag(GarageHomeService.tempoBuilder)

            GarageJournalServicePage(
                onNewJournalEntry: onNewJournalEntry,
                onOpenJournalArchive: onOpenJournalArchive
            )
            .tag(GarageHomeService.journal)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: selectedService.pageHeight)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedService)
    }

    private var servicePageDots: some View {
        HStack(spacing: 8) {
            ForEach(GarageHomeService.allCases) { service in
                Circle()
                    .fill(selectedService == service ? GaragePremiumPalette.gold : GaragePremiumPalette.mintText.opacity(0.28))
                    .frame(width: selectedService == service ? 8 : 6, height: selectedService == service ? 8 : 6)
                    .overlay(
                        Circle()
                            .stroke(GaragePremiumPalette.gold.opacity(selectedService == service ? 0.32 : 0), lineWidth: 3)
                    )
                    .accessibilityLabel(service.label)
                    .accessibilityValue(selectedService == service ? "Selected" : "")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Garage")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("Choose the work. Keep the session focused.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(GaragePremiumPalette.mintText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(GaragePremiumPalette.emeraldGlass.opacity(0.76))
                    .frame(width: 50, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(GaragePremiumPalette.gold.opacity(0.34), lineWidth: 1)
                    )
                    .shadow(color: GaragePremiumPalette.gold.opacity(0.14), radius: 12, x: 0, y: 0)

                Image(systemName: "figure.golf")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(GaragePremiumPalette.gold)
            }
            .accessibilityHidden(true)
        }
    }
}

private enum GarageHomeService: String, CaseIterable, Identifiable {
    case drillPlans
    case tempoBuilder
    case journal

    var id: Self { self }

    var label: String {
        switch self {
        case .drillPlans:
            "Practice"
        case .tempoBuilder:
            "Rhythm"
        case .journal:
            "Memory"
        }
    }

    var pageHeight: CGFloat {
        switch self {
        case .drillPlans:
            610
        case .tempoBuilder:
            552
        case .journal:
            560
        }
    }
}

private struct GarageDrillPlansServicePage: View {
    let onOpenEnvironment: (PracticeEnvironment) -> Void

    var body: some View {
        GarageServiceCard(
            label: "Practice",
            title: "Drill Plans",
            subtitle: "Choose the surface, then start or create a repeatable routine.",
            artwork: GaragePracticeArtwork()
        ) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    GarageSectionHeader(eyebrow: "Choose Surface")

                    VStack(spacing: 0) {
                        ForEach(PracticeEnvironment.allCases) { environment in
                            GaragePlatformCard(environment: environment) {
                                onOpenEnvironment(environment)
                            }
                        }
                    }
                }

                Spacer(minLength: 24)

                GarageEditorialFooter(
                    label: "Today's Focus",
                    text: "Start with one clean rep. Pick the surface that matches today's work.",
                    hint: "Select a surface to continue",
                    systemImage: "scope"
                )
            }
        }
    }
}

private struct GarageTempoServicePage: View {
    let onStartTempoBuilder: () -> Void

    var body: some View {
        GarageServiceCard(
            label: "Rhythm",
            title: "Tempo Builder",
            subtitle: "Train swing rhythm and timing with a focused, standalone tool.",
            artwork: GarageRhythmArtwork()
        ) {
            VStack(alignment: .leading, spacing: 0) {
                GarageTempoPreview()

                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 14) {
                    GarageGoldButton(
                        title: "Start",
                        systemImage: "play.fill",
                        action: onStartTempoBuilder
                    )

                    GarageEditorialFooter(
                        label: "Coaching Cue",
                        text: "Let the beat shape the rehearsal. Keep the swing smooth before adding speed.",
                        hint: "Start Tempo Builder",
                        systemImage: "metronome.fill"
                    )
                }
            }
        }
    }
}

private struct GarageJournalServicePage: View {
    let onNewJournalEntry: () -> Void
    let onOpenJournalArchive: () -> Void

    var body: some View {
        GarageServiceCard(
            label: "Memory",
            title: "Journal",
            subtitle: "Capture the cues, feels, and course lessons worth carrying forward.",
            artwork: GarageJournalArtwork()
        ) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    GarageSectionHeader(eyebrow: "Quick Capture")

                    HStack(spacing: 12) {
                        GarageCaptureButton(title: "Swing Feel", systemImage: "quote.opening", action: onNewJournalEntry)
                        GarageCaptureButton(title: "Scorecard", systemImage: "chart.bar.fill", action: onNewJournalEntry)
                        GarageCaptureButton(title: "Course Note", systemImage: "pencil.tip.crop.circle.fill", action: onNewJournalEntry)
                    }
                }

                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 0) {
                        GarageHubActionButton(
                            title: "New Entry",
                            systemImage: "square.and.pencil",
                            isPrimary: true,
                            action: onNewJournalEntry
                        )

                        GarageHubActionButton(
                            title: "Archive",
                            systemImage: "archivebox.fill",
                            isPrimary: false,
                            action: onOpenJournalArchive
                        )
                    }

                    GarageEditorialFooter(
                        label: "Carry Forward",
                        text: "Save the feel while it is fresh. One clear note is enough.",
                        hint: "New Entry keeps today's cue alive",
                        systemImage: "quote.opening"
                    )
                }
            }
        }
    }
}

private struct GarageServiceCard<Artwork: View, Content: View>: View {
    let label: String
    let title: String
    let subtitle: String
    let artwork: Artwork
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(4)
                        .foregroundStyle(GaragePremiumPalette.gold)

                    Text(title)
                        .font(.system(.largeTitle, design: .default).weight(.bold))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(subtitle)
                        .font(.body.weight(.medium))
                        .foregroundStyle(GaragePremiumPalette.mintText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                artwork
                    .frame(width: 104, height: 96)
                    .accessibilityHidden(true)
            }

            Rectangle()
                .fill(GaragePremiumPalette.mintText.opacity(0.12))
                .frame(height: 1)

            content
        }
        .padding(.top, 8)
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .topTrailing) {
            LinearGradient(
                colors: [
                    GaragePremiumPalette.emerald.opacity(0.22),
                    GaragePremiumPalette.emeraldDeep.opacity(0)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .blur(radius: 22)
            .frame(width: 170, height: 126)
            .offset(x: 34, y: -22)
        }
    }
}

private struct GarageEditorialFooter: View {
    let label: String
    let text: String
    let hint: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(GaragePremiumPalette.mintText.opacity(0.12))
                .frame(height: 1)

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(GaragePremiumPalette.gold.opacity(0.11))
                        .frame(width: 34, height: 34)

                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(GaragePremiumPalette.gold)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 7) {
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(2.2)
                        .foregroundStyle(GaragePremiumPalette.gold)

                    Text(text)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(hint)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GaragePremiumPalette.mintText.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottomTrailing) {
            Circle()
                .fill(GaragePremiumPalette.gold.opacity(0.07))
                .blur(radius: 18)
                .frame(width: 86, height: 86)
                .offset(x: 28, y: 28)
        }
    }
}

private struct GaragePracticeArtwork: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(GaragePremiumPalette.emerald.opacity(0.24))
                .blur(radius: 12)
                .frame(width: 96, height: 72)
                .offset(x: 18, y: 10)

            ZStack(alignment: .topLeading) {
                ForEach(0..<4, id: \.self) { index in
                    Ellipse()
                        .stroke(GaragePremiumPalette.mintText.opacity(0.10), lineWidth: 1)
                        .frame(width: 84 - CGFloat(index * 12), height: 34 - CGFloat(index * 3))
                        .offset(x: CGFloat(index * 8), y: CGFloat(index * 10))
                }
            }

            Path { path in
                path.move(to: CGPoint(x: 46, y: 20))
                path.addLine(to: CGPoint(x: 46, y: 84))
            }
            .stroke(GaragePremiumPalette.gold.opacity(0.65), lineWidth: 1.4)

            Path { path in
                path.move(to: CGPoint(x: 47, y: 20))
                path.addLine(to: CGPoint(x: 67, y: 27))
                path.addLine(to: CGPoint(x: 47, y: 35))
                path.closeSubpath()
            }
            .fill(GaragePremiumPalette.gold)

            Ellipse()
                .fill(GaragePremiumPalette.emerald.opacity(0.46))
                .frame(width: 92, height: 36)
                .offset(x: 14, y: 48)
        }
    }
}

private struct GarageRhythmArtwork: View {
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(GaragePremiumPalette.emerald.opacity(0.14))
                    .frame(width: 1, height: 78)
                    .offset(x: CGFloat(index * 18 - 36))
            }

            GarageWaveLine(amplitude: 24, cycles: 2.8)
                .stroke(GaragePremiumPalette.gold.opacity(0.82), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .frame(width: 118, height: 70)

            GarageWaveLine(amplitude: 17, cycles: 3.4)
                .stroke(GaragePremiumPalette.mintText.opacity(0.24), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                .frame(width: 118, height: 62)
                .offset(x: -6)
        }
    }
}

private struct GarageJournalArtwork: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            GaragePremiumPalette.emerald.opacity(0.62),
                            GaragePremiumPalette.emeraldDeep.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 78, height: 92)
                .rotationEffect(.degrees(16))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(GaragePremiumPalette.mintText.opacity(0.18), lineWidth: 1)
                        .rotationEffect(.degrees(16))
                )
                .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 8)

            Image(systemName: "figure.golf")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(GaragePremiumPalette.gold.opacity(0.22))
                .rotationEffect(.degrees(16))

            Capsule()
                .fill(GaragePremiumPalette.gold.opacity(0.78))
                .frame(width: 6, height: 80)
                .rotationEffect(.degrees(26))
                .offset(x: 44, y: 12)

            Capsule()
                .fill(GaragePremiumPalette.goldDeep.opacity(0.82))
                .frame(width: 5, height: 66)
                .rotationEffect(.degrees(58))
                .offset(x: 58, y: 30)
        }
    }
}

private struct GarageWaveLine: Shape {
    let amplitude: CGFloat
    let cycles: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let steps = 72

        for step in 0...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let x = rect.minX + rect.width * progress
            let y = midY + sin(progress * cycles * .pi * 2) * amplitude * (0.45 + progress * 0.55)

            if step == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

private struct GarageTempoPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GarageSectionHeader(eyebrow: "Current Tempo")

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("72")
                            .font(.system(size: 58, weight: .bold))
                            .foregroundStyle(GarageProTheme.textPrimary)
                            .lineLimit(1)

                        Text("BPM")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(GaragePremiumPalette.gold)
                    }
                    .layoutPriority(1)

                    GarageRhythmArtwork()
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 10) {
                    ForEach([0.78, 0.54, 0.38], id: \.self) { value in
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(GaragePremiumPalette.emerald.opacity(0.24))

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                GaragePremiumPalette.gold,
                                                GaragePremiumPalette.gold.opacity(0.62)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: proxy.size.width * value)
                            }
                        }
                        .frame(height: 9)
                    }
                }

                HStack(spacing: 10) {
                    ForEach(["Full Swing", "Short Game", "Putting"], id: \.self) { chip in
                        Text(chip)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(chip == "Full Swing" ? GaragePremiumPalette.gold : GaragePremiumPalette.mintText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                            .padding(.horizontal, 13)
                            .frame(minHeight: 42)
                            .background(chip == "Full Swing" ? GaragePremiumPalette.gold.opacity(0.10) : GaragePremiumPalette.emeraldGlass.opacity(0.24), in: Capsule())
                    }
                }
            }
        }
    }
}

private struct GarageCaptureButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .frame(height: 28)

                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(GaragePremiumPalette.mintText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 104)
            .background(
                Circle()
                    .fill(GaragePremiumPalette.emeraldGlass.opacity(0.52))
            )
            .overlay(
                Circle()
                    .stroke(GaragePremiumPalette.mintText.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageHubActionButton: View {
    let title: String
    let systemImage: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(isPrimary ? GaragePremiumPalette.gold : GarageProTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                .padding(.horizontal, 2)
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(GaragePremiumPalette.gold.opacity(isPrimary ? 1 : 0.62))
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(GaragePremiumPalette.mintText.opacity(0.10))
                        .frame(height: 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(GaragePremiumPalette.mintText.opacity(isPrimary ? 0.10 : 0.06))
                        .frame(height: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            HStack(spacing: 16) {
                surfaceThumbnail

                VStack(alignment: .leading, spacing: 5) {
                    Text(environment.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(summary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GaragePremiumPalette.mintText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .frame(width: 18)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        GaragePremiumPalette.emeraldGlass.opacity(0.18),
                        GaragePremiumPalette.emeraldDeep.opacity(0.02)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(GaragePremiumPalette.mintText.opacity(0.10))
                    .frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(GaragePremiumPalette.mintText.opacity(0.06))
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var surfaceThumbnail: some View {
        ZStack {
            Capsule()
                .fill(surfaceGradient)
                .frame(width: 46, height: 46)

            Image(systemName: environment.systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(GaragePremiumPalette.gold)
        }
        .frame(width: 46, height: 46)
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

    private var summary: String {
        switch environment {
        case .net:
            "Mechanics, contact, and tight-space reps."
        case .range:
            "Ball flight, targets, and club work."
        case .puttingGreen:
            "Start line, pace, and green-reading feel."
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
