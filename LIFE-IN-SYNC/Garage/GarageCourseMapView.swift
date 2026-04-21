import CoreLocation
import MapKit
import SwiftUI

struct GarageCourseMapView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model: GarageCourseMappingModel
    @State private var tacticalEntryPresentation: GarageTacticalEntryPresentation?

    private let bottomInset: CGFloat
    private let onExit: (() -> Void)?

    @MainActor
    init(
        bottomInset: CGFloat = 84,
        onExit: (() -> Void)? = nil
    ) {
        _model = StateObject(wrappedValue: .preview)
        self.bottomInset = bottomInset
        self.onExit = onExit
    }

    init(
        model: GarageCourseMappingModel,
        bottomInset: CGFloat = 84,
        onExit: (() -> Void)? = nil
    ) {
        _model = StateObject(wrappedValue: model)
        self.bottomInset = bottomInset
        self.onExit = onExit
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer

            LinearGradient(
                colors: [
                    Color.black.opacity(0.34),
                    Color.black.opacity(0.08),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack {
                    exitButton
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer(minLength: 0)

                tacticalEntryButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, bottomInset)
            }
        }
        .background(ModuleTheme.garageBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $tacticalEntryPresentation) { presentation in
            GarageTacticalEntryFlow(
                session: presentation.session,
                hole: presentation.hole
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var mapLayer: some View {
        Map(
            position: Binding(
                get: { model.cameraPosition },
                set: { model.cameraPosition = $0 }
            ),
            bounds: cameraBounds,
            interactionModes: [.pan, .zoom]
        )
        .mapStyle(.imagery(elevation: .realistic))
        .mapControlVisibility(.hidden)
        .ignoresSafeArea()
    }

    private var cameraBounds: MapCameraBounds {
        MapCameraBounds(
            centerCoordinateBounds: model.metadata.region.mapRect,
            minimumDistance: model.metadata.region.minimumCameraDistance,
            maximumDistance: model.metadata.region.maximumCameraDistance
        )
    }

    private var exitButton: some View {
        Button {
            garageTriggerImpact(.light)
            if let onExit {
                onExit()
            } else {
                dismiss()
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(garageReviewReadableText)
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.10), lineWidth: 0.75)
                        )
                )
                .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var tacticalEntryButton: some View {
        Button {
            garageTriggerImpact(.medium)
            tacticalEntryPresentation = makeTacticalEntryPresentation()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .bold))

                Text("Log Shot")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(garageReviewReadableText)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .fill(Color.vibeElectricCyan.opacity(0.16))
                    }
                    .overlay {
                        Capsule()
                            .stroke(Color.vibeElectricCyan.opacity(0.34), lineWidth: 0.75)
                    }
            )
        }
        .buttonStyle(.plain)
        .shadow(color: Color.vibeElectricCyan.opacity(0.18), radius: 16, x: 0, y: 10)
    }

    private func makeTacticalEntryPresentation() -> GarageTacticalEntryPresentation {
        let holeNumber = Int(model.metadata.holeLabel.filter(\.isNumber)) ?? 1
        let yardage = model.activeRoute?.stats.totalYardage ?? 0

        let session = GarageRoundSession(
            sessionTitle: "Tactical Debrief",
            courseName: model.metadata.courseName
        )

        let hole = GarageHoleMap(
            holeNumber: holeNumber,
            holeName: model.metadata.holeName,
            par: model.metadata.par,
            yardageLabel: yardage > 0 ? "\(yardage)" : "",
            sourceType: .assistedWebImport,
            sourceReference: model.metadata.courseName,
            teeAnchor: GarageMapAnchor(kind: .tee, normalizedX: 0.5, normalizedY: 0.88),
            fairwayCheckpointAnchor: GarageMapAnchor(kind: .fairwayCheckpoint, normalizedX: 0.5, normalizedY: 0.5),
            greenCenterAnchor: GarageMapAnchor(kind: .greenCenter, normalizedX: 0.5, normalizedY: 0.14),
            session: session
        )

        return GarageTacticalEntryPresentation(session: session, hole: hole)
    }
}

private struct GarageTacticalEntryPresentation: Identifiable {
    let id = UUID()
    let session: GarageRoundSession
    let hole: GarageHoleMap
}

private extension GarageCourseRegion {
    var mapRect: MKMapRect {
        let centerPoint = MKMapPoint(center.clCoordinate)
        let pointsPerMeter = MKMapPointsPerMeterAtLatitude(center.latitude)
        let width = max(longitudinalMeters * pointsPerMeter, 1)
        let height = max(latitudinalMeters * pointsPerMeter, 1)

        return MKMapRect(
            x: centerPoint.x - (width / 2),
            y: centerPoint.y - (height / 2),
            width: width,
            height: height
        )
    }

    var minimumCameraDistance: CLLocationDistance {
        max(min(latitudinalMeters, longitudinalMeters) * 0.55, 120)
    }

    var maximumCameraDistance: CLLocationDistance {
        max(max(latitudinalMeters, longitudinalMeters) * 1.15, minimumCameraDistance + 120)
    }
}

#Preview {
    PreviewScreenContainer {
        GarageCourseMapView()
    }
}
