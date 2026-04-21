import Foundation

enum GarageHoleSourceType: String, Codable, CaseIterable, Identifiable {
    case uploadedImage
    case uploadedPDFRender
    case assistedWebImport

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uploadedImage:
            "Image Upload"
        case .uploadedPDFRender:
            "PDF Upload"
        case .assistedWebImport:
            "Web Import"
        }
    }
}

enum GarageMapAnchorKind: String, Codable, CaseIterable, Identifiable {
    case tee
    case fairwayCheckpoint
    case greenCenter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tee:
            "Tee"
        case .fairwayCheckpoint:
            "Checkpoint"
        case .greenCenter:
            "Green"
        }
    }
}

struct GarageMapAnchor: Codable, Hashable, Identifiable {
    let kind: GarageMapAnchorKind
    var normalizedX: Double
    var normalizedY: Double

    var id: GarageMapAnchorKind { kind }

    init(kind: GarageMapAnchorKind, normalizedX: Double, normalizedY: Double) {
        self.kind = kind
        self.normalizedX = min(max(normalizedX, 0), 1)
        self.normalizedY = min(max(normalizedY, 0), 1)
    }
}

struct GarageShotPlacement: Codable, Hashable {
    var normalizedX: Double
    var normalizedY: Double

    init(normalizedX: Double, normalizedY: Double) {
        self.normalizedX = min(max(normalizedX, 0), 1)
        self.normalizedY = min(max(normalizedY, 0), 1)
    }
}

enum GarageTacticalClub: String, Codable, CaseIterable, Identifiable {
    case driver
    case threeWood
    case fiveWood
    case hybrid
    case fourIron
    case fiveIron
    case sixIron
    case sevenIron
    case eightIron
    case nineIron
    case pitchingWedge
    case gapWedge
    case sandWedge
    case lobWedge
    case putter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .driver:
            "Driver"
        case .threeWood:
            "3 Wood"
        case .fiveWood:
            "5 Wood"
        case .hybrid:
            "Hybrid"
        case .fourIron:
            "4 Iron"
        case .fiveIron:
            "5 Iron"
        case .sixIron:
            "6 Iron"
        case .sevenIron:
            "7 Iron"
        case .eightIron:
            "8 Iron"
        case .nineIron:
            "9 Iron"
        case .pitchingWedge:
            "PW"
        case .gapWedge:
            "GW"
        case .sandWedge:
            "SW"
        case .lobWedge:
            "LW"
        case .putter:
            "Putter"
        }
    }

    var symbolName: String {
        switch self {
        case .putter:
            "flag.pattern.checkered"
        case .driver, .threeWood, .fiveWood, .hybrid:
            "figure.golf"
        default:
            "smallcircle.filled.circle"
        }
    }
}

enum GarageTacticalShotType: String, Codable, CaseIterable, Identifiable {
    case teeShot
    case approach
    case layup
    case recovery
    case chip
    case putt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teeShot:
            "Tee Shot"
        case .approach:
            "Approach"
        case .layup:
            "Layup"
        case .recovery:
            "Recovery"
        case .chip:
            "Chip"
        case .putt:
            "Putt"
        }
    }

    var symbolName: String {
        switch self {
        case .teeShot:
            "flag.pattern.checkered.2.crossed"
        case .approach:
            "scope"
        case .layup:
            "arrow.turn.down.right"
        case .recovery:
            "arrow.uturn.backward.circle"
        case .chip:
            "dot.scope"
        case .putt:
            "figure.golf"
        }
    }
}

enum GarageTacticalLie: String, Codable, CaseIterable, Identifiable {
    case tee
    case fairway
    case firstCut
    case rough
    case bunker
    case trees
    case fringe
    case green

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tee:
            "Tee"
        case .fairway:
            "Fairway"
        case .firstCut:
            "First Cut"
        case .rough:
            "Rough"
        case .bunker:
            "Bunker"
        case .trees:
            "Trees"
        case .fringe:
            "Fringe"
        case .green:
            "Green"
        }
    }

    var symbolName: String {
        switch self {
        case .tee:
            "flag.pattern.checkered.2.crossed"
        case .fairway:
            "rectangle.lefthalf.inset.filled"
        case .firstCut:
            "leaf"
        case .rough:
            "leaf.fill"
        case .bunker:
            "aqi.medium"
        case .trees:
            "tree.fill"
        case .fringe:
            "circle.dashed"
        case .green:
            "flag.fill"
        }
    }
}

enum GarageTacticalResult: String, Codable, CaseIterable, Identifiable {
    case onTarget
    case short
    case long
    case leftMiss
    case rightMiss
    case hazard
    case recoveryRequired
    case holed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onTarget:
            "On Target"
        case .short:
            "Short"
        case .long:
            "Long"
        case .leftMiss:
            "Left Miss"
        case .rightMiss:
            "Right Miss"
        case .hazard:
            "Hazard"
        case .recoveryRequired:
            "Recovery"
        case .holed:
            "Holed"
        }
    }

    var symbolName: String {
        switch self {
        case .onTarget:
            "checkmark.circle.fill"
        case .short:
            "arrow.down.circle"
        case .long:
            "arrow.up.circle"
        case .leftMiss:
            "arrow.left.circle"
        case .rightMiss:
            "arrow.right.circle"
        case .hazard:
            "exclamationmark.triangle.fill"
        case .recoveryRequired:
            "arrow.uturn.backward.circle.fill"
        case .holed:
            "flag.checkered.circle.fill"
        }
    }
}
