import SwiftData
import SwiftUI

enum GarageAnalysisProgressStep: Equatable {
    case loadingVideo
    case samplingFrames
    case detectingBody
    case mappingCheckpoints
    case savingSwing

    var title: String {
        switch self {
        case .loadingVideo:
            "Local Source"
        case .samplingFrames:
            "Silent Capture"
        case .detectingBody:
            "Passive Tracking"
        case .mappingCheckpoints:
            "Hole Context"
        case .savingSwing:
            "Local Save"
        }
    }

    var detail: String {
        switch self {
        case .loadingVideo:
            "Preparing the local tracker state."
        case .samplingFrames:
            "Listening for passive round signals."
        case .detectingBody:
            "Active swing tracking is disabled."
        case .mappingCheckpoints:
            "Resolving current hole context."
        case .savingSwing:
            "Saving the silent tracker state."
        }
    }

    var telemetryLabel: String {
        switch self {
        case .loadingVideo:
            "LOCAL"
        case .samplingFrames:
            "PASSIVE"
        case .detectingBody:
            "DISABLED"
        case .mappingCheckpoints:
            "HOLE"
        case .savingSwing:
            "SAVE"
        }
    }
}

struct GarageAnalysisProgressUpdate: Equatable {
    let step: GarageAnalysisProgressStep
    let frameCount: Int
    let totalFrames: Int

    init(
        step: GarageAnalysisProgressStep,
        frameCount: Int = 0,
        totalFrames: Int = 0
    ) {
        self.step = step
        self.frameCount = frameCount
        self.totalFrames = totalFrames
    }
}

enum GarageImportPresentationState: Equatable {
    case idle
    case preparing
    case analyzing(step: GarageAnalysisProgressStep, frameCount: Int = 0, totalFrames: Int = 0)
    case failure(String)

    var isPresented: Bool {
        self != .idle
    }
}

struct GaragePreFlightSelection: Equatable {
    var clubType: String = "7 Iron"
    var isLeftHanded: Bool = false
    var cameraAngle: String = "Down the Line"
    var trimStartSeconds: Double = 0
    var trimEndSeconds: Double = 0
    var hasConfirmedTrimWindow = false
}

let garageLongClipTrimThreshold = 8.0
let garageDefaultTrimWindowDuration = 4.0
let garageMinimumTrimWindowDuration = 1.5
let garageMaximumTrimWindowDuration = 6.0

func garageRequiresManualTrim(for duration: Double) -> Bool {
    duration > garageLongClipTrimThreshold
}

func garageDefaultTrimWindow(for duration: Double) -> ClosedRange<Double> {
    let safeDuration = max(duration, 0)
    guard safeDuration > 0 else { return 0...0 }

    let preferredWindow = min(
        max(garageDefaultTrimWindowDuration, garageMinimumTrimWindowDuration),
        min(garageMaximumTrimWindowDuration, safeDuration)
    )
    let midpoint = safeDuration / 2
    let start = max(min(midpoint - (preferredWindow / 2), safeDuration - preferredWindow), 0)
    let end = min(start + preferredWindow, safeDuration)
    return start...end
}

func garageNormalizedTrimWindow(start: Double, end: Double, duration: Double) -> ClosedRange<Double> {
    let safeDuration = max(duration, 0)
    guard safeDuration > 0 else { return 0...0 }

    let minimumWindow = min(garageMinimumTrimWindowDuration, safeDuration)
    let maximumWindow = min(garageMaximumTrimWindowDuration, safeDuration)

    var lowerBound = min(max(start, 0), safeDuration)
    var upperBound = min(max(end, 0), safeDuration)
    if upperBound < lowerBound {
        swap(&lowerBound, &upperBound)
    }

    var windowLength = upperBound - lowerBound
    if windowLength < minimumWindow {
        upperBound = min(lowerBound + minimumWindow, safeDuration)
        lowerBound = max(upperBound - minimumWindow, 0)
        windowLength = upperBound - lowerBound
    }

    if windowLength > maximumWindow {
        upperBound = min(lowerBound + maximumWindow, safeDuration)
        lowerBound = max(upperBound - maximumWindow, 0)
    }

    return lowerBound...upperBound
}

extension GaragePreFlightSelection {
    var trimDuration: Double {
        max(trimEndSeconds - trimStartSeconds, 0)
    }
}

func garageRecordSelectionKey(for record: SwingRecord) -> String {
    String(describing: record.persistentModelID)
}

func garageImportRetryErrorCode(from error: Error) -> Int? {
    let nsError = error as NSError

    if garageIsRetryableImportNSError(nsError) {
        return nsError.code
    }

    if let detailedErrors = nsError.userInfo["NSDetailedErrors"] as? [NSError] {
        for detailedError in detailedErrors {
            if let retryCode = garageImportRetryErrorCode(from: detailedError) {
                return retryCode
            }
        }
    }

    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
        return garageImportRetryErrorCode(from: underlyingError)
    }

    return nil
}

func garageShouldRetryImportAfterFailure(_ error: Error) -> Bool {
    garageImportRetryErrorCode(from: error) != nil
}

func garageImportFailureMessage(from error: Error) -> String {
    let nsError = error as NSError
    var diagnostics: [String] = []
    var currentError: NSError? = nsError

    while let error = currentError {
        var segment = "domain=\(error.domain) code=\(error.code) description=\(error.localizedDescription)"

        if let failureReason = error.localizedFailureReason, failureReason.isEmpty == false {
            segment += " reason=\(failureReason)"
        }

        if let recoverySuggestion = error.localizedRecoverySuggestion, recoverySuggestion.isEmpty == false {
            segment += " suggestion=\(recoverySuggestion)"
        }

        diagnostics.append(segment)
        currentError = error.userInfo[NSUnderlyingErrorKey] as? NSError
    }

    guard diagnostics.isEmpty == false else {
        return "Import failed: \(error.localizedDescription)"
    }

    return "Import failed: \(diagnostics.joined(separator: " | underlying: "))"
}

private func garageIsRetryableImportNSError(_ error: NSError) -> Bool {
    let domain = error.domain.lowercased()

    switch domain {
    case "com.apple.swiftdata":
        return error.code == -54
    case "nscocoaerrordomain":
        return [4097, 4099, 134110].contains(error.code)
    case "nssqliteerrordomain":
        return [5, 6].contains(error.code)
    case "nsposixerrordomain":
        return error.code == 16
    default:
        return false
    }
}

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
