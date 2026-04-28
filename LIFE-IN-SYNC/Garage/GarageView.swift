import SwiftData
import SwiftUI

@MainActor
struct GarageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didAppear = false

    private let activeHole = "Hole 1"
    private let trackingStatus = "Listening"

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                darkMatterBackground

                VStack(spacing: 18) {
                    GarageSilentTrackerRow(
                        title: "Active Hole",
                        value: activeHole,
                        systemImage: "flag.fill"
                    )

                    GarageSilentTrackerRow(
                        title: "Tracking Status",
                        value: trackingStatus,
                        systemImage: "dot.radiowaves.left.and.right"
                    )
                }
                .frame(maxWidth: min(proxy.size.width - 32, 520))
                .opacity(didAppear ? 1 : 0)
                .scaleEffect(didAppear ? 1 : 0.97)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86), value: didAppear)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task {
            didAppear = true
        }
        .toolbar(.visible, for: .navigationBar)
    }

    private var darkMatterBackground: some View {
        ZStack {
            AppModule.garage.theme.screenGradient

            RadialGradient(
                colors: [
                    ModuleTheme.electricCyan.opacity(0.14),
                    ModuleTheme.garageSurfaceDark.opacity(0.0)
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 520
            )

            ModuleTheme.garageCanvas
                .opacity(0.42)
                .blendMode(.multiply)
        }
        .ignoresSafeArea()
    }
}

private struct GarageSilentTrackerRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ModuleTheme.electricCyan)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                        .shadow(color: ModuleTheme.electricCyan.opacity(0.18), radius: 18, x: 0, y: 0)
                        .shadow(color: ModuleTheme.garageShadowDark.opacity(0.72), radius: 10, x: 8, y: 10)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(AppModule.garage.theme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(ModuleTheme.garageSurfaceRaised.opacity(0.34))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: ModuleTheme.garageShadowLight.opacity(0.45), radius: 8, x: -4, y: -4)
                .shadow(color: ModuleTheme.garageShadowDark.opacity(0.86), radius: 18, x: 12, y: 16)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("Garage Silent Tracker") {
    NavigationStack {
        GarageView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
