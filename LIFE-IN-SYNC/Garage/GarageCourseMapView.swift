import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct GarageCourseMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var model: GarageCourseMappingModel
    @State private var tacticalEntryPresentation: GarageTacticalEntryPresentation?
    @State private var calibrationPresentation: GarageCourseCalibrationPresentation?
    @State private var blockerAlert: GarageCourseMapAlert?

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
        .sheet(item: $calibrationPresentation) { presentation in
            GarageCourseCalibrationSheet(
                hole: presentation.hole,
                onComplete: {
                    tacticalEntryPresentation = GarageTacticalEntryPresentation(
                        session: presentation.session,
                        hole: presentation.hole
                    )
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert(item: $blockerAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
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
            handleLogShotTap()
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

    private func handleLogShotTap() {
        garageTriggerImpact(.medium)

        do {
            let session = try GarageCourseMappingPersistence.resolveActiveSession(
                for: model.metadata,
                in: modelContext
            )
            let hole = try GarageCourseMappingPersistence.resolveHole(
                for: model.metadata,
                session: session,
                in: modelContext
            )

            if hole.isCalibrated == false {
                calibrationPresentation = GarageCourseCalibrationPresentation(
                    session: session,
                    hole: hole
                )
                return
            }

            try hole.validateForShotLogging()
            tacticalEntryPresentation = GarageTacticalEntryPresentation(
                session: session,
                hole: hole
            )
        } catch {
            modelContext.rollback()
            blockerAlert = GarageCourseMapAlert(error: error)
        }
    }
}

private struct GarageTacticalEntryPresentation: Identifiable {
    let id = UUID()
    let session: GarageRoundSession
    let hole: GarageHoleMap
}

private struct GarageCourseCalibrationPresentation: Identifiable {
    let id = UUID()
    let session: GarageRoundSession
    let hole: GarageHoleMap
}

private struct GarageCourseMapAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(error: Error) {
        title = "Shot Entry Locked"

        if let localizedError = error as? LocalizedError,
           let errorDescription = localizedError.errorDescription {
            if let recoverySuggestion = localizedError.recoverySuggestion {
                message = "\(errorDescription) \(recoverySuggestion)"
            } else {
                message = errorDescription
            }
        } else {
            message = (error as NSError).localizedDescription
        }
    }
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
