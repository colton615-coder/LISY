import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var isShowingLaunchAffirmation = !LaunchAffirmationConfiguration.shouldSkip

    init(showLaunchAffirmation: Bool = !LaunchAffirmationConfiguration.shouldSkip) {
        _isShowingLaunchAffirmation = State(initialValue: showLaunchAffirmation)
    }

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

#Preview("Content Launch") {
    ContentView(showLaunchAffirmation: true)
        .modelContainer(PreviewCatalog.populatedApp)
        .preferredColorScheme(.dark)
}

#Preview("Content Shell") {
    ContentView(showLaunchAffirmation: false)
        .modelContainer(PreviewCatalog.populatedApp)
        .preferredColorScheme(.dark)
}
