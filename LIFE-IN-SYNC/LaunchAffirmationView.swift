import SwiftUI

struct LaunchAffirmationView: View {
    private let entry = LaunchAffirmationEntry.dailySelection

    var body: some View {
        ZStack {
            ModuleTheme.rootBackground
                .ignoresSafeArea()

            VStack(spacing: ModuleSpacing.xLarge) {
                VStack(spacing: ModuleSpacing.medium) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(AppModule.dashboard.theme.primary)

                    Text("LIFE IN SYNC")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .tracking(3)
                        .foregroundStyle(AppModule.dashboard.theme.accentText)

                    Text(entry.title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(ModuleTheme.primaryText)
                        .multilineTextAlignment(.center)

                    Text(entry.message)
                        .font(.body)
                        .foregroundStyle(ModuleTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)

                    Text(entry.attribution)
                        .font(.caption)
                        .foregroundStyle(ModuleTheme.secondaryText)
                }

                ProgressView()
                    .tint(AppModule.dashboard.theme.primary)
                    .frame(width: 120)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, ModuleSpacing.xLarge)
        }
        .puttingGreenRootBackground()
        .accessibilityIdentifier("launch-affirmation-screen")
    }
}

private struct LaunchAffirmationEntry {
    let title: String
    let message: String
    let attribution: String

    static var dailySelection: LaunchAffirmationEntry {
        let entries = fallbackEntries
        let calendar = Calendar.autoupdatingCurrent
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .now
        let dayOffset = calendar.dateComponents([.day], from: referenceDate, to: .now).day ?? 0
        let index = abs(dayOffset) % entries.count
        return entries[index]
    }

    private static let fallbackEntries: [LaunchAffirmationEntry] = [
        LaunchAffirmationEntry(
            title: "Enter the day with order.",
            message: "Let the next right action be obvious, calm, and local to what matters.",
            attribution: "Offline fallback"
        ),
        LaunchAffirmationEntry(
            title: "Build quietly. Finish clearly.",
            message: "Progress compounds when your system stays dependable under ordinary days.",
            attribution: "Offline fallback"
        ),
        LaunchAffirmationEntry(
            title: "Keep the essentials in view.",
            message: "Attention is a limited asset. Give it to the work that keeps life aligned.",
            attribution: "Offline fallback"
        ),
        LaunchAffirmationEntry(
            title: "Move with clarity, not noise.",
            message: "A useful system should lower friction, shorten hesitation, and keep truth visible.",
            attribution: "Offline fallback"
        )
    ]
}

#Preview("Launch Affirmation") {
    LaunchAffirmationView()
}
