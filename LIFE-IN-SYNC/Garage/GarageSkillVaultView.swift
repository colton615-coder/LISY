import SwiftData
import SwiftUI

@MainActor
struct GarageSkillVaultView: View {
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]

    private var dashboardMetrics: GarageVaultDashboardMetrics {
        records.garageVaultDashboardMetrics()
    }

    private var coachingImpact: GarageCoachingImpactDashboard {
        records.coachingImpactDashboard()
    }

    var body: some View {
        GarageProScaffold(bottomPadding: 48) {
            if records.isEmpty {
                emptyState
            } else {
                heroCard
                vaultMetricGrid
                coachingImpactSection
                sessionsSection
            }
        }
        .navigationTitle("Skill Vault")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        GarageProHeroCard(
            eyebrow: "Skill Vault",
            title: "No sessions yet",
            subtitle: "Completed Garage sessions will appear here once you finish a practice routine.",
            value: "0",
            valueLabel: "Sessions"
        )
    }

    private var heroCard: some View {
        GarageProHeroCard(
            eyebrow: "Skill Vault",
            title: "Global Efficiency",
            subtitle: "\(dashboardMetrics.totalSuccess) successful reps across \(dashboardMetrics.totalAttempts) attempts.",
            value: dashboardMetrics.globalEfficiencyText,
            valueLabel: "Last 30 Days"
        ) {
            if dashboardMetrics.recordsInWindow > 0 {
                Text(dashboardMetrics.momentumText)
                    .font(.caption.weight(.black))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(dashboardMetrics.momentumTint)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(dashboardMetrics.momentumTint.opacity(0.32), lineWidth: 1)
                    )
            }
        }
    }

    private var vaultMetricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            GarageProMetricCard(
                title: "Sessions",
                value: "\(dashboardMetrics.recordsInWindow)",
                systemImage: "calendar.badge.clock",
                isActive: dashboardMetrics.recordsInWindow > 0
            )

            GarageProMetricCard(
                title: "Attempts",
                value: "\(dashboardMetrics.totalAttempts)",
                systemImage: "target",
                isActive: dashboardMetrics.totalAttempts > 0
            )
        }
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            Text("Recent Sessions")
                .font(.system(.title2, design: .rounded).weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)

            LazyVStack(spacing: ModuleSpacing.medium) {
                ForEach(records, id: \.id) { record in
                    NavigationLink {
                        GarageSessionDetailView(
                            record: record,
                            allowsInsightGeneration: false
                        )
                    } label: {
                        GarageSkillVaultSessionCard(
                            record: record,
                            trendValues: records.previousFiveSessionTrend(for: record)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var coachingImpactSection: some View {
        if coachingImpact.auditSnapshots.isEmpty == false {
            VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
                GarageTelemetrySurface(isActive: coachingImpact.weightedSuccessRatio > 0.5) {
                    Text("COACHING IMPACT")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .kerning(2.6)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)

                    Text(coachingImpact.efficacyText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Cue given vs resulting progress")
                        .font(.subheadline)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                VStack(spacing: ModuleSpacing.medium) {
                    ForEach(coachingImpact.auditSnapshots) { snapshot in
                        GarageCoachingImpactRow(snapshot: snapshot)
                    }
                }
            }
        }
    }
}

@MainActor
private struct GarageSkillVaultSessionCard: View {
    let record: PracticeSessionRecord
    let trendValues: [Double]

    private var performanceState: GarageVaultPerformanceState {
        GarageVaultPerformanceState(efficiency: record.aggregateEfficiency)
    }

    var body: some View {
        GarageTelemetrySurface(isActive: performanceState.shouldGlow) {
            HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        Text(record.templateName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppModule.garage.theme.textPrimary)
                            .multilineTextAlignment(.leading)

                        if record.isPersonalRecord {
                            GaragePersonalRecordBadge()
                        }
                    }

                    Text(record.environmentDisplayName)
                        .font(.subheadline)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(record.aggregateEfficiencyText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(performanceState.tint)

                    GarageEfficiencySparkline(values: trendValues)
                        .frame(width: 72, height: 24)

                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.footnote)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }
            }

            GarageSessionEfficiencyBar(
                efficiency: record.aggregateEfficiency,
                tint: performanceState.tint
            )
            .frame(height: 10)

            HStack {
                Text("\(record.totalSuccessfulReps)/\(record.totalAttemptedReps) successful reps")
                    .font(.footnote)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
            }
        }
    }
}

private struct GarageVaultDashboardMetrics {
    let totalSuccess: Int
    let totalAttempts: Int
    let recordsInWindow: Int
    let previousTotalSuccess: Int
    let previousTotalAttempts: Int

    var globalEfficiency: Double {
        guard totalAttempts > 0 else {
            return 0
        }

        return Double(totalSuccess) / Double(totalAttempts)
    }

    var previousWindowEfficiency: Double {
        guard previousTotalAttempts > 0 else {
            return 0
        }

        return Double(previousTotalSuccess) / Double(previousTotalAttempts)
    }

    var globalEfficiencyText: String {
        "\(Int((globalEfficiency * 100).rounded()))%"
    }

    var momentumDeltaPercentagePoints: Int {
        Int(((globalEfficiency - previousWindowEfficiency) * 100).rounded())
    }

    var momentumText: String {
        guard previousTotalAttempts > 0 else {
            return "First tracked window"
        }

        let sign = momentumDeltaPercentagePoints > 0 ? "+" : ""
        return "\(sign)\(momentumDeltaPercentagePoints)% vs Last Month"
    }

    var momentumTint: Color {
        if previousTotalAttempts == 0 {
            return AppModule.garage.theme.textSecondary
        }

        if momentumDeltaPercentagePoints > 0 {
            return GarageVaultPalette.emerald
        }

        if momentumDeltaPercentagePoints < 0 {
            return GarageVaultPalette.zinc
        }

        return AppModule.garage.tintColor
    }
}

struct GarageVaultPerformanceState {
    let tint: Color
    let shouldGlow: Bool

    init(efficiency: Double) {
        if efficiency > 0.75 {
            tint = GarageVaultPalette.emerald
            shouldGlow = true
        } else if efficiency < 0.5 {
            tint = GarageVaultPalette.zinc
            shouldGlow = false
        } else {
            tint = AppModule.garage.tintColor
            shouldGlow = false
        }
    }
}

enum GarageVaultPalette {
    static let emerald = Color(hex: "#10B981")
    static let zinc = Color(hex: "#71717A")
    static let gold = Color(hex: "#FBBF24")
    static let impact = Color(hex: "#60A5FA")
}

@MainActor
private struct GaragePersonalRecordBadge: View {
    @State private var shimmerXOffset: CGFloat = -72

    var body: some View {
        Text("PR")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .kerning(1.4)
            .foregroundStyle(GarageVaultPalette.gold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(ModuleTheme.garageSurfaceInset.opacity(0.9))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(GarageVaultPalette.gold.opacity(0.78), lineWidth: 1)
                    )
                    .overlay(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        Color.white.opacity(0.38),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 28)
                            .offset(x: shimmerXOffset)
                            .blur(radius: 0.5)
                            .mask(Capsule(style: .continuous))
                    }
                    .shadow(color: GarageVaultPalette.gold.opacity(0.16), radius: 8, x: 0, y: 0)
            )
            .onAppear {
                shimmerXOffset = -72
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    shimmerXOffset = 72
                }
            }
    }
}

@MainActor
private struct GarageCoachingImpactRow: View {
    let snapshot: GarageCoachingAuditSnapshot

    private var tint: Color {
        if snapshot.averageDelta > 0 {
            return GarageVaultPalette.impact
        }

        if snapshot.averageDelta < 0 {
            return GarageVaultPalette.zinc
        }

        return AppModule.garage.theme.textSecondary
    }

    var body: some View {
        GarageTelemetrySurface(isActive: snapshot.averageDelta > 0) {
            HStack(alignment: .top, spacing: ModuleSpacing.medium) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cue Given")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textSecondary)

                    Text(snapshot.cueGivenText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(snapshot.progressSummaryText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(tint)

                    Text(snapshot.impactDirectionText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint)
                }
            }

            HStack {
                Text(snapshot.templateName)
                    .font(.footnote)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)

                Spacer()

                if snapshot.isPersonalRecord {
                    GaragePersonalRecordBadge()
                }
            }
        }
    }
}

struct GarageEfficiencySparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let normalizedValues = values.isEmpty ? [0] : values
            let points = normalizedValues.sparklinePoints(in: proxy.size)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ModuleTheme.garageSurfaceInset.opacity(0.72))

                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [
                                GarageVaultPalette.zinc.opacity(0.7),
                                GarageVaultPalette.emerald
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                }

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(sparkDotColor(for: index, total: points.count))
                        .frame(width: index == points.count - 1 ? 6 : 4, height: index == points.count - 1 ? 6 : 4)
                        .position(point)
                }
            }
        }
    }

    private func sparkDotColor(for index: Int, total: Int) -> Color {
        guard total > 1 else {
            return GarageVaultPalette.emerald
        }

        let progress = Double(index) / Double(max(total - 1, 1))
        return Color(
            red: 0.443 + ((0.063 - 0.443) * progress),
            green: 0.443 + ((0.725 - 0.443) * progress),
            blue: 0.478 + ((0.506 - 0.478) * progress)
        )
    }
}

private extension Array where Element == PracticeSessionRecord {
    func garageVaultDashboardMetrics(referenceDate: Date = .now) -> GarageVaultDashboardMetrics {
        let calendar = Calendar.current
        let currentWindowStart = calendar.date(byAdding: .day, value: -30, to: referenceDate) ?? referenceDate
        let previousWindowStart = calendar.date(byAdding: .day, value: -60, to: referenceDate) ?? currentWindowStart

        let currentWindowRecords = filter { $0.date >= currentWindowStart }
        let previousWindowRecords = filter { $0.date >= previousWindowStart && $0.date < currentWindowStart }

        let totalSuccess = currentWindowRecords.reduce(0) { partialResult, record in
            partialResult + record.totalSuccessfulReps
        }
        let totalAttempts = currentWindowRecords.reduce(0) { partialResult, record in
            partialResult + record.totalAttemptedReps
        }
        let previousTotalSuccess = previousWindowRecords.reduce(0) { partialResult, record in
            partialResult + record.totalSuccessfulReps
        }
        let previousTotalAttempts = previousWindowRecords.reduce(0) { partialResult, record in
            partialResult + record.totalAttemptedReps
        }

        return GarageVaultDashboardMetrics(
            totalSuccess: totalSuccess,
            totalAttempts: totalAttempts,
            recordsInWindow: currentWindowRecords.count,
            previousTotalSuccess: previousTotalSuccess,
            previousTotalAttempts: previousTotalAttempts
        )
    }

    func previousFiveSessionTrend(for record: PracticeSessionRecord) -> [Double] {
        filter { candidate in
            candidate.templateName == record.templateName && candidate.date <= record.date
        }
        .sorted { $0.date < $1.date }
        .suffix(5)
        .map(\.aggregateEfficiency)
    }
}

private extension Array where Element == Double {
    func sparklinePoints(in size: CGSize) -> [CGPoint] {
        guard isEmpty == false else {
            return []
        }

        if count == 1 {
            return [CGPoint(x: size.width / 2, y: size.height / 2)]
        }

        return enumerated().map { index, value in
            let xStep = size.width / CGFloat(Swift.max(count - 1, 1))
            let clampedValue = Swift.min(Swift.max(value, 0), 1)
            let y = size.height - (CGFloat(clampedValue) * size.height)
            return CGPoint(x: CGFloat(index) * xStep, y: y)
        }
    }
}

#Preview("Garage Skill Vault") {
    NavigationStack {
        GarageSkillVaultView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
