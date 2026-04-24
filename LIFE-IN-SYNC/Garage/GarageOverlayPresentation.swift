import SwiftUI

enum GarageOverlayMode: String, CaseIterable, Identifiable, Equatable {
    case clean
    case pro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean:
            "Clean"
        case .pro:
            "Pro"
        }
    }
}



enum GarageOverlayLens: String, CaseIterable, Identifiable, Equatable {
    case posture
    case headStability
    case handPath
    case hipSway

    var id: String { rawValue }

    var title: String {
        switch self {
        case .posture:
            "Posture"
        case .headStability:
            "Head"
        case .handPath:
            "Path"
        case .hipSway:
            "Hip Sway"
        }
    }

    var symbolName: String {
        switch self {
        case .posture:
            "figure.golf"
        case .headStability:
            "face.dashed"
        case .handPath:
            "point.topleft.down.curvedto.point.bottomright.up"
        case .hipSway:
            "arrow.left.and.right"
        }
    }
}
enum GarageOverlayMetricStatus: Equatable {
    case optimal
    case warning
    case critical
    case insufficientData

    var label: String {
        switch self {
        case .optimal:
            "Solid"
        case .warning:
            "Watch"
        case .critical:
            "Needs work"
        case .insufficientData:
            "Limited"
        }
    }

    var tint: Color {
        switch self {
        case .optimal:
            garageReviewReadableText
        case .warning:
            garageReviewPending
        case .critical:
            garageReviewFlagged
        case .insufficientData:
            garageReviewMutedText
        }
    }

    var opacityScale: Double {
        switch self {
        case .optimal:
            1.0
        case .warning:
            0.92
        case .critical:
            0.96
        case .insufficientData:
            0.34
        }
    }
}

enum GarageOverlayConfidenceLevel: Equatable {
    case high
    case moderate
    case low
    case insufficientData

    var opacityScale: Double {
        switch self {
        case .high:
            1.0
        case .moderate:
            0.76
        case .low:
            0.44
        case .insufficientData:
            0.22
        }
    }
}

enum GarageOverlayCueKind: String, Equatable {
    case spine
    case pelvis
    case head

    var title: String {
        switch self {
        case .spine:
            "Posture"
        case .pelvis:
            "Depth"
        case .head:
            "Head stability"
        }
    }
}

struct GarageOverlayLine: Equatable {
    let start: CGPoint
    let end: CGPoint
    let outerWidth: CGFloat
    let coreWidth: CGFloat
    var dash: [CGFloat] = []
}

struct GarageOverlayPolyline: Equatable {
    let points: [CGPoint]
    let outerWidth: CGFloat
    let coreWidth: CGFloat
    var dash: [CGFloat] = []
}

struct GarageOverlayHalo: Equatable {
    let rect: CGRect
    let outerWidth: CGFloat
    let coreWidth: CGFloat
    let dash: [CGFloat]
}

struct GarageOverlayCue: Equatable {
    let kind: GarageOverlayCueKind
    let title: String
    let status: GarageOverlayMetricStatus
    let confidence: GarageOverlayConfidenceLevel
    let opacity: Double
    let line: GarageOverlayLine?
    let polyline: GarageOverlayPolyline?
    let halo: GarageOverlayHalo?
}

struct GarageOverlayJoint: Equatable {
    let name: SwingJointName
    let center: CGPoint
    let radius: CGFloat
    let status: GarageOverlayMetricStatus
    let confidence: GarageOverlayConfidenceLevel
    let opacity: Double
}

struct GarageOverlayMarker: Equatable {
    let center: CGPoint
    let status: GarageOverlayMetricStatus
    let outerRadius: CGFloat
    let innerRadius: CGFloat
    let opacity: Double
}

struct GarageOverlayLabel: Equatable {
    let id: String
    let text: String
    let anchor: CGPoint
    let status: GarageOverlayMetricStatus
    let opacity: Double
}

struct GarageOverlayHUDPresentation: Equatable {
    let title: String
    let detail: String
    let severity: GarageSkeletonHUDSeverity?
    let primaryStatus: GarageOverlayMetricStatus
    let mode: GarageOverlayMode
    let selectedLens: GarageOverlayLens
    let isModeToggleEnabled: Bool
    let opacity: Double

    static let unavailable = GarageOverlayHUDPresentation(
        title: "Pose overlay unavailable",
        detail: "Garage does not have enough frame data to draw a trustworthy body overlay.",
        severity: .warning("Pose data limited"),
        primaryStatus: .insufficientData,
        mode: .clean,
        selectedLens: .posture,
        isModeToggleEnabled: false,
        opacity: 1
    )
}

struct GarageOverlayPresentationState: Equatable {
    let mode: GarageOverlayMode
    let selectedLens: GarageOverlayLens
    let cleanCues: [GarageOverlayCue]
    let proSegments: [GarageOverlayLine]
    let proJoints: [GarageOverlayJoint]
    let proHeadHalo: GarageOverlayHalo?
    let proHeadTrail: GarageOverlayPolyline?
    let proRibbonSegments: [GarageOverlayPolyline]
    let flowPath: GarageOverlayPolyline?
    let pulseMarker: GarageOverlayMarker?
    let issueMarker: GarageOverlayMarker?
    let labels: [GarageOverlayLabel]
    let hud: GarageOverlayHUDPresentation

    static let unavailable = GarageOverlayPresentationState(
        mode: .clean,
        selectedLens: .posture,
        cleanCues: [],
        proSegments: [],
        proJoints: [],
        proHeadHalo: nil,
        proHeadTrail: nil,
        proRibbonSegments: [],
        flowPath: nil,
        pulseMarker: nil,
        issueMarker: nil,
        labels: [],
        hud: .unavailable
    )
}
