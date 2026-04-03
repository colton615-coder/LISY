import SwiftUI

struct ContentView: View {
    @State private var isShowingLaunchAffirmation = !LaunchAffirmationConfiguration.shouldSkip

    var body: some View {
        ZStack {
            if isShowingLaunchAffirmation {
                LaunchAffirmationView()
                    .transition(.opacity)
            } else {
                AppShellView()
                    .transition(.opacity)
            }
        }
        .task(id: isShowingLaunchAffirmation) {
            guard isShowingLaunchAffirmation else { return }

            try? await Task.sleep(nanoseconds: LaunchAffirmationConfiguration.durationNanoseconds)
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                isShowingLaunchAffirmation = false
            }
        }
    }
}

private enum LaunchAffirmationConfiguration {
    static let durationNanoseconds: UInt64 = 4_000_000_000
    static let skipArgument = "SKIP_LAUNCH_AFFIRMATION"

    static var shouldSkip: Bool {
        ProcessInfo.processInfo.arguments.contains(skipArgument)
    }
}

#Preview("App Shell") {
    ContentView()
}
