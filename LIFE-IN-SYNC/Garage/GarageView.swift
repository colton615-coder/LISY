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
                Color.black
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        ModuleTheme.electricCyan.opacity(0.15),
                        Color.black.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 400
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    yardageCard

                    Spacer()

                    blindTapZone(height: proxy.size.height * 0.40)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .sensoryFeedback(trigger: isShowingClubSelection) { _, newValue in
            newValue ? .impact(weight: .heavy) : nil
        }
        .sheet(isPresented: $isShowingClubSelection) {
            NavigationStack {
                GarageClubSelectionSheet {
                    isShowingClubSelection = false
                }
                .navigationTitle("Select Club")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.height(400), .medium])
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            isShowingClubSelection = false
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var yardageCard: some View {
        VStack(spacing: -8) {
            Text("HOLE 1 • PAR 4")
                .font(.caption.weight(.bold))
                .tracking(2.0)
                .foregroundStyle(.gray)
                .minimumScaleFactor(0.5)

            Text("\(distanceToGreen)")
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("YARDS")
                .font(.headline.weight(.semibold))
                .tracking(4.0)
                .foregroundStyle(ModuleTheme.electricCyan)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func blindTapZone(height: CGFloat) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(Rectangle())
            .onTapGesture {
                isShowingClubSelection = true
            }
    }
}

@MainActor
private struct GarageClubSelectionSheet: View {
    let onSelectClub: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 80))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(GarageTacticalClub.allCases) { club in
                    Button {
                        onSelectClub()
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: club.symbolName)
                                .font(.title3.weight(.semibold))

                            Text(club.title)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(white: 0.15))
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                }
            }
            .padding(16)
        }
    }
}

#Preview("Garage Cart Dashboard") {
    NavigationStack {
        GarageView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
