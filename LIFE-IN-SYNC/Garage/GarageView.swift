import SwiftUI

@MainActor
struct GarageView: View {
    var body: some View {
        ZStack {
            AppModule.garage.theme.screenGradient
                .ignoresSafeArea()

            Text("GARAGE: UNDER RECONSTRUCTION")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppModule.garage.theme.primary)
                .padding(24)
        }
    }
}

#Preview("Garage Reconstruction Shell") {
    NavigationStack {
        GarageView()
    }
}
