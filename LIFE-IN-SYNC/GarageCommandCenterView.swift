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
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest Total Score")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textMuted)

            Text("\(heroScore)")
                .font(.system(size: 84, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppModule.garage.theme.primary)
                .shadow(color: AppModule.garage.theme.primary.opacity(0.35), radius: 18, x: 0, y: 0)

            Text("Derived from the most recent analyzed swing record.")
                .font(.footnote)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppModule.garage.theme.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
                )
                .shadow(color: AppModule.garage.theme.shadowDark.opacity(0.35), radius: 14, x: 8, y: 8)
                .shadow(color: AppModule.garage.theme.shadowLight.opacity(0.18), radius: 8, x: -4, y: -4)
        )
    }

    private var criticalActionSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Critical Next Action")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.primary)

            Text(issueTitle)
                .font(.headline)
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            Text(issueDetail)
                .font(.footnote)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppModule.garage.theme.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppModule.garage.theme.primary.opacity(0.34), lineWidth: 1)
                )
                .shadow(color: AppModule.garage.theme.primary.opacity(0.2), radius: 14, x: 0, y: 0)
        )
    }
}
