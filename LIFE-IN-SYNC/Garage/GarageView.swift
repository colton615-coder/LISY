import SwiftData
import SwiftUI

@MainActor
struct GarageView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingClubSelection = false
    @State private var distanceToGreen: Int = 142

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                darkMatterBackground

                VStack(spacing: 0) {
                    Spacer(minLength: proxy.size.height * 0.12)

                    yardageCard(maxWidth: min(proxy.size.width - 32, 420))

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)

                blindTapZone(height: proxy.size.height * 0.4)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .sensoryFeedback(.impact, trigger: isShowingClubSelection) { _, newValue in
            newValue
        }
        .sheet(isPresented: $isShowingClubSelection) {
            GarageClubSelectionSheet { _ in
                isShowingClubSelection = false
            }
            .presentationDetents([.height(350), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            isShowingClubSelection = false
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var darkMatterBackground: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    ModuleTheme.electricCyan.opacity(0.15),
                    ModuleTheme.electricCyan.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    private func yardageCard(maxWidth: CGFloat) -> some View {
        VStack(spacing: 14) {
            Text("Distance to Green")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            Text("\(distanceToGreen)")
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text("Yards")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ModuleTheme.electricCyan.opacity(0.92))
        }
        .frame(maxWidth: maxWidth)
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(ModuleTheme.garageSurfaceRaised.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: ModuleTheme.electricCyan.opacity(0.2), radius: 32, x: 0, y: 0)
                .shadow(color: ModuleTheme.garageShadowDark.opacity(0.9), radius: 28, x: 0, y: 18)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Distance to green, \(distanceToGreen) yards")
    }

    private func blindTapZone(height: CGFloat) -> some View {
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .onTapGesture {
                isShowingClubSelection = true
            }
            .accessibilityLabel("Open club selection")
            .accessibilityAddTraits(.isButton)
    }
}

@MainActor
private struct GarageClubSelectionSheet: View {
    let onSelect: (GarageTacticalClub) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 14)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Select Club")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    Text("Tap the club you pulled from the cart.")
                        .font(.subheadline)
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(GarageTacticalClub.allCases) { club in
                        Button {
                            onSelect(club)
                        } label: {
                            GarageClubCard(club: club)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .background(Color.black.opacity(0.92))
    }
}

@MainActor
private struct GarageClubCard: View {
    let club: GarageTacticalClub

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: club.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ModuleTheme.electricCyan)

            Text(club.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(ModuleTheme.garageSurfaceRaised.opacity(0.28))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: ModuleTheme.garageShadowLight.opacity(0.32), radius: 6, x: -2, y: -2)
                .shadow(color: ModuleTheme.garageShadowDark.opacity(0.8), radius: 18, x: 10, y: 12)
        )
    }
}

#Preview("Garage Cart Dashboard") {
    NavigationStack {
        GarageView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
