import SwiftUI

struct GarageCommandCenterView: View {
    let records: [SwingRecord]

    private let fallbackScore = 82
    private let fallbackIssueTitle = "Build stable baseline"
    private let fallbackIssueDetail = "Import a swing in Analyzer, run the review checkpoints, and lock your next actionable focus."

    private var latestRecord: SwingRecord? {
        records.first
    }

    private var heroScore: Int {
        latestRecord?.analysisResult?.scorecard?.totalScore ?? fallbackScore
    }

    private var normalizedHeroScore: Double {
        min(max(Double(heroScore) / 100, 0), 1)
    }

    private var consistencyScore: String {
        String(format: "%.1f", Double(heroScore) / 10)
    }

    private var issueTitle: String {
        latestRecord?.analysisResult?.syncFlow?.primaryIssue?.title ?? fallbackIssueTitle
    }

    private var issueDetail: String {
        latestRecord?.analysisResult?.syncFlow?.primaryIssue?.detail ?? fallbackIssueDetail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Command Center")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            heroStatusSurface
            criticalActionSurface
        }
        .padding(.bottom, 90)
    }

    private var heroStatusSurface: some View {
        GarageTelemetrySurface(isActive: true, cornerRadius: 28, padding: 24) {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(ModuleTheme.garageTrack, lineWidth: 14)
                        .frame(width: 150, height: 150)

                    Circle()
                        .trim(from: 0, to: normalizedHeroScore)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    ModuleTheme.electricCyan,
                                    Color(hex: "#1AD0C8")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: ModuleTheme.electricCyan.opacity(0.16), radius: 8, x: 0, y: 0)

                    Circle()
                        .fill(ModuleTheme.garageSurfaceInset.opacity(0.96))
                        .frame(width: 118, height: 118)

                    VStack(spacing: 4) {
                        Text("\(heroScore)")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AppModule.garage.theme.textPrimary)

                        Text("SWING SCORE")
                            .font(.caption2.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(AppModule.garage.theme.textMuted)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Latest Total Score")
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(AppModule.garage.theme.textMuted)

                    Text("Most recent analyzed swing record")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    Text("A compact performance readout built from the latest scorecard and SyncFlow pass.")
                        .font(.footnote)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)

                    HStack(spacing: 10) {
                        metricCapsule(title: "\(consistencyScore) consistency", tint: ModuleTheme.electricCyan)
                        metricCapsule(title: "live baseline", tint: Color(hex: "#36D7FF"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var criticalActionSurface: some View {
        GarageTelemetrySurface(isActive: true, cornerRadius: 22, padding: 20) {
            Text("Critical Next Action")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(AppModule.garage.theme.primary)

            Text(issueTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            Text(issueDetail)
                .font(.footnote)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
        }
    }

    private func metricCapsule(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppModule.garage.theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.35), lineWidth: 0.5)
                    )
            )
    }
}
