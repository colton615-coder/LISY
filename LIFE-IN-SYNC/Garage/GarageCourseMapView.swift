import Combine
import CoreLocation
import MapKit
import Network
import SwiftData
import SwiftUI

private let garageCourseMapSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
private let garageLISYSystemBlue = Color(uiColor: .systemBlue)
private let garageMetersPerYard = 0.9144
private let garageGPSHoleToleranceMeters = 100 * garageMetersPerYard

struct GarageCourseMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var primaryModel: GarageCourseMappingModel
    @StateObject private var locationController = GarageCourseLocationController()
    @StateObject private var networkMonitor = GarageCourseNetworkMonitor()

    @State private var cameraPosition: MapCameraPosition
    @State private var reticleCoordinate: CLLocationCoordinate2D
    @State private var selectedHoleNumber: Int
    @State private var activeSession: GarageRoundSession?
    @State private var activeHole: GarageHoleMap?
    @State private var isShotDrawerPresented = false
    @State private var selectedClub: GarageTacticalClub? = .driver
    @State private var selectedLie: GarageTacticalLie? = .tee
    @State private var selectedResult: GarageTacticalResult? = .onTarget
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isUsingTeeFallbackOrigin = false

    private let siblingHoleModels: [GarageCourseMappingModel]
    private let bottomInset: CGFloat
    private let onExit: (() -> Void)?

    @MainActor
    init(
        bottomInset: CGFloat = 84,
        onExit: (() -> Void)? = nil
    ) {
        let previewModel = GarageCourseMappingModel.preview
        let region = previewModel.metadata.region.mkRegion
        _primaryModel = StateObject(wrappedValue: previewModel)
        _cameraPosition = State(initialValue: .camera(Self.topDownCamera(center: previewModel.previewTeeCoordinate, region: region)))
        _reticleCoordinate = State(initialValue: previewModel.previewTeeCoordinate)
        _selectedHoleNumber = State(initialValue: previewModel.metadata.safeHoleNumber)
        self.siblingHoleModels = []
        self.bottomInset = bottomInset
        self.onExit = onExit
    }

    @MainActor
    init(
        model: GarageCourseMappingModel,
        siblingHoleModels: [GarageCourseMappingModel] = [],
        bottomInset: CGFloat = 84,
        onExit: (() -> Void)? = nil
    ) {
        let region = model.metadata.region.mkRegion
        _primaryModel = StateObject(wrappedValue: model)
        _cameraPosition = State(initialValue: .camera(Self.topDownCamera(center: model.previewTeeCoordinate, region: region)))
        _reticleCoordinate = State(initialValue: model.previewTeeCoordinate)
        _selectedHoleNumber = State(initialValue: model.metadata.safeHoleNumber)
        self.siblingHoleModels = siblingHoleModels
        self.bottomInset = bottomInset
        self.onExit = onExit
    }

    private var availableModels: [GarageCourseMappingModel] {
        var keyedModels: [Int: GarageCourseMappingModel] = [:]
        for model in [primaryModel] + siblingHoleModels {
            keyedModels[model.metadata.safeHoleNumber] = model
        }
        return keyedModels.keys.sorted().compactMap { keyedModels[$0] }
    }

    private var activeModel: GarageCourseMappingModel {
        availableModels.first(where: { $0.metadata.safeHoleNumber == selectedHoleNumber }) ?? primaryModel
    }

    private var activeRegion: MKCoordinateRegion {
        activeModel.metadata.region.mkRegion
    }

    private var cameraBounds: MapCameraBounds {
        let maxSpan = max(activeRegion.latitudinalMeters, activeRegion.longitudinalMeters)
        return MapCameraBounds(
            centerCoordinateBounds: activeRegion,
            minimumDistance: 55,
            maximumDistance: max(maxSpan * 1.35, 260)
        )
    }

    private var originCoordinate: CLLocationCoordinate2D {
        guard
            let userCoordinate = locationController.userCoordinate,
            isCoordinateWithinActiveHoleTolerance(userCoordinate)
        else {
            return teeCoordinate
        }

        return userCoordinate
    }

    private var teeCoordinate: CLLocationCoordinate2D {
        activeModel.activeRoute?.nodes.first(where: { $0.kind == .tee })?.coordinate.clCoordinate
            ?? activeModel.activeRoute?.coordinates.first?.clCoordinate
            ?? activeRegion.center
    }

    private var greenCoordinate: CLLocationCoordinate2D {
        activeModel.activeRoute?.nodes.first(where: { $0.kind == .target })?.coordinate.clCoordinate
            ?? activeModel.activeRoute?.coordinates.last?.clCoordinate
            ?? activeRegion.center
    }

    private var midpointCoordinate: CLLocationCoordinate2D {
        activeModel.activeRoute?.nodes.first(where: { $0.kind == .landingZone })?.coordinate.clCoordinate
            ?? activeModel.activeRoute?.nodes.first(where: { $0.kind == .checkpoint })?.coordinate.clCoordinate
            ?? activeRegion.center
    }

    private var pathCoordinates: [CLLocationCoordinate2D] {
        [originCoordinate, reticleCoordinate, greenCoordinate]
    }

    private var centerGreenDistanceYards: Int {
        yardage(from: originCoordinate, to: greenCoordinate)
    }

    private var originToTargetYards: Int {
        yardage(from: originCoordinate, to: reticleCoordinate)
    }

    private var targetToGreenYards: Int {
        yardage(from: reticleCoordinate, to: greenCoordinate)
    }

    private var activeHoleNumber: Int {
        activeModel.metadata.safeHoleNumber
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                courseMap
                    .ignoresSafeArea()

                reticle
                    .allowsHitTesting(false)

                overlays(proxy: proxy)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .coordinateSpace(name: GarageSpatialCoordinateSpace.mapSpace)
        }
        .background(garageReviewBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            locationController.start()
            networkMonitor.start()
            refreshActivePersistence()
        }
        .onDisappear {
            locationController.stop()
            networkMonitor.stop()
        }
        .onChange(of: selectedHoleNumber) { _, _ in
            handleHoleSelectionChanged()
        }
        .onChange(of: locationController.locationUpdateID) { _, _ in
            handleUserCoordinateChanged(locationController.userCoordinate)
        }
        .animation(garageCourseMapSpring, value: selectedHoleNumber)
        .animation(garageCourseMapSpring, value: isShotDrawerPresented)
        .animation(garageCourseMapSpring, value: networkMonitor.isOnline)
        .animation(garageCourseMapSpring, value: statusMessage)
        .animation(garageCourseMapSpring, value: errorMessage)
    }

    private var courseMap: some View {
        Map(
            position: $cameraPosition,
            bounds: cameraBounds,
            interactionModes: [.pan, .zoom]
        ) {
            if let headingConeCoordinates {
                MapPolygon(coordinates: headingConeCoordinates)
                    .foregroundStyle(garageLISYSystemBlue.opacity(0.18))
                    .stroke(garageLISYSystemBlue.opacity(0.42), lineWidth: 1)
            }

            MapPolyline(coordinates: pathCoordinates)
                .stroke(.black.opacity(0.42), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [7, 6]))

            MapPolyline(coordinates: pathCoordinates)
                .stroke(.white.opacity(0.92), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [7, 6]))

            ForEach(distanceAnnotations) { annotation in
                Annotation(annotation.title, coordinate: annotation.coordinate, anchor: .center) {
                    GarageCourseMapDistanceTag(title: annotation.title)
                }
            }

            Annotation("Center of Green", coordinate: greenCoordinate, anchor: .center) {
                GarageCourseMapGreenMarker()
            }

            UserAnnotation()
        }
        .mapStyle(.imagery(elevation: .flat))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            reticleCoordinate = context.camera.centerCoordinate
            guard context.camera.pitch > 1 || abs(context.camera.heading) > 0.5 else { return }
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: context.camera.centerCoordinate,
                    distance: context.camera.distance,
                    heading: 0,
                    pitch: 0
                )
            )
        }
    }

    private func overlays(proxy: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            topHUD(proxy: proxy)

            Spacer(minLength: 0)

            bottomControls(proxy: proxy)
        }
        .padding(.horizontal, 14)
        .padding(.top, proxy.safeAreaInsets.top + 8)
        .padding(.bottom, proxy.safeAreaInsets.bottom + max(bottomInset - 26, 12))
        .colorScheme(.dark)
    }

    private func topHUD(proxy: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    garageTriggerImpact(.light)
                    if let onExit {
                        onExit()
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(garageReviewReadableText)
                        .frame(width: 44, height: 44)
                        .background(
                            GarageCourseGlassBackground(shape: Circle(), stroke: Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close course map")

                VStack(alignment: .leading, spacing: 5) {
                    Text(activeModel.metadata.courseName)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(garageReviewMutedText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    HStack(spacing: 10) {
                        metricText("Hole \(activeHoleNumber)")
                        metricText("Par \(activeHole?.par ?? activeModel.metadata.par)")
                        metricText("HCP --")
                        metricText("\(centerGreenDistanceYards) yd COG")
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(garageReviewReadableText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)
            }
            .padding(.trailing, 14)
            .background(
                GarageCourseGlassBackground(shape: Capsule(), stroke: Color.white.opacity(0.1))
            )
            .frame(maxWidth: min(proxy.size.width - 28, 520))

            if networkMonitor.isOnline == false {
                GarageCourseMapNotice(
                    systemImage: "wifi.slash",
                    message: "Satellite imagery requires network; cached Apple tiles may still appear."
                )
                .frame(maxWidth: min(proxy.size.width - 28, 520))
            } else if locationController.userCoordinate == nil {
                GarageCourseMapNotice(
                    systemImage: "location",
                    message: locationController.locationStatusMessage
                )
                .frame(maxWidth: min(proxy.size.width - 28, 520))
            } else if isUsingTeeFallbackOrigin {
                GarageCourseMapNotice(
                    systemImage: "scope",
                    message: "GPS is outside this hole. Garage is using the tee box as origin."
                )
                .frame(maxWidth: min(proxy.size.width - 28, 520))
            }

            if let errorMessage {
                GarageCourseMapNotice(systemImage: "exclamationmark.triangle.fill", message: errorMessage, isError: true)
                    .frame(maxWidth: min(proxy.size.width - 28, 520))
            } else if let statusMessage {
                GarageCourseMapNotice(systemImage: "checkmark.circle.fill", message: statusMessage)
                    .frame(maxWidth: min(proxy.size.width - 28, 520))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func metricText(_ text: String) -> some View {
        Text(text)
    }

    private func bottomControls(proxy: GeometryProxy) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                if isShotDrawerPresented {
                    GarageGPSShotDrawer(
                        selectedClub: $selectedClub,
                        selectedLie: $selectedLie,
                        selectedResult: $selectedResult,
                        canSave: selectedClub != nil && selectedLie != nil && selectedResult != nil,
                        onCancel: {
                            garageTriggerImpact(.light)
                            isShotDrawerPresented = false
                        },
                        onConfirm: persistShotAtReticle
                    )
                    .frame(maxWidth: min(proxy.size.width - 92, 430))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 0)

                shotFAB
            }

            holeCarousel
        }
    }

    private var shotFAB: some View {
        Button {
            garageTriggerImpact(.medium)
            errorMessage = nil
            statusMessage = nil
            isShotDrawerPresented.toggle()
        } label: {
            Image(systemName: isShotDrawerPresented ? "xmark" : "plus")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(garageLISYSystemBlue)
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.7))
                        .shadow(color: garageLISYSystemBlue.opacity(0.34), radius: 18, x: 0, y: 10)
                        .shadow(color: .black.opacity(0.36), radius: 10, x: 0, y: 7)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isShotDrawerPresented ? "Close stroke registration" : "Register stroke")
    }

    private var holeCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(1 ... 18, id: \.self) { holeNumber in
                    let isAvailable = availableModels.contains { $0.metadata.safeHoleNumber == holeNumber }
                    let isSelected = holeNumber == activeHoleNumber

                    Button {
                        guard isAvailable else { return }
                        garageTriggerImpact(.light)
                        selectedHoleNumber = holeNumber
                    } label: {
                        Text("\(holeNumber)")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(isSelected ? garageReviewCanvasFill : garageReviewReadableText.opacity(isAvailable ? 0.92 : 0.32))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(isSelected ? garageLISYSystemBlue : garageReviewSurfaceDark.opacity(isAvailable ? 0.9 : 0.58))
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                isSelected ? garageLISYSystemBlue.opacity(0.72) : Color.white.opacity(isAvailable ? 0.1 : 0.04),
                                                lineWidth: 0.7
                                            )
                                    )
                                    .shadow(color: isSelected ? garageLISYSystemBlue.opacity(0.24) : .black.opacity(0.24), radius: isSelected ? 12 : 6, x: 0, y: 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isAvailable == false)
                    .accessibilityLabel(isAvailable ? "Open hole \(holeNumber)" : "Hole \(holeNumber) unavailable")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(
            GarageCourseGlassBackground(shape: Capsule(), stroke: Color.white.opacity(0.08))
        )
        .colorScheme(.dark)
    }

    private var reticle: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.78), lineWidth: 1.2)
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.72), radius: 4, x: 0, y: 2)

            Rectangle()
                .fill(.white.opacity(0.9))
                .frame(width: 24, height: 1.4)
                .shadow(color: .black.opacity(0.72), radius: 3, x: 0, y: 1)

            Rectangle()
                .fill(.white.opacity(0.9))
                .frame(width: 1.4, height: 24)
                .shadow(color: .black.opacity(0.72), radius: 3, x: 0, y: 1)
        }
        .accessibilityHidden(true)
    }

    private var distanceAnnotations: [GarageCourseDistanceAnnotation] {
        [
            GarageCourseDistanceAnnotation(
                title: "\(originToTargetYards) yd",
                coordinate: midpoint(from: originCoordinate, to: reticleCoordinate)
            ),
            GarageCourseDistanceAnnotation(
                title: "\(targetToGreenYards) yd",
                coordinate: midpoint(from: reticleCoordinate, to: greenCoordinate)
            )
        ]
    }

    private var headingConeCoordinates: [CLLocationCoordinate2D]? {
        guard
            let coordinate = locationController.userCoordinate,
            let heading = locationController.headingDegrees
        else {
            return nil
        }

        let distance = max(min(activeRegion.latitudinalMeters * 0.12, 65), 28)
        return [
            coordinate,
            destinationCoordinate(from: coordinate, bearingDegrees: heading - 18, distanceMeters: distance),
            destinationCoordinate(from: coordinate, bearingDegrees: heading, distanceMeters: distance * 1.2),
            destinationCoordinate(from: coordinate, bearingDegrees: heading + 18, distanceMeters: distance),
            coordinate
        ]
    }

    @MainActor
    private func handleHoleSelectionChanged() {
        let centerCoordinate = resolvedInitialCenterCoordinate(for: locationController.userCoordinate)
        reticleCoordinate = centerCoordinate
        cameraPosition = .camera(Self.topDownCamera(center: centerCoordinate, region: activeRegion))
        errorMessage = nil
        statusMessage = nil
        isShotDrawerPresented = false
        refreshActivePersistence()
    }

    @MainActor
    private func handleUserCoordinateChanged(_ coordinate: CLLocationCoordinate2D?) {
        let centerCoordinate = resolvedInitialCenterCoordinate(for: coordinate)
        cameraPosition = .camera(Self.topDownCamera(center: centerCoordinate, region: activeRegion))
    }

    @MainActor
    private func refreshActivePersistence() {
        do {
            let session = try GarageCourseMappingPersistence.resolveActiveSession(
                for: activeModel.metadata,
                in: modelContext
            )
            let hole = try GarageCourseMappingPersistence.resolveHole(
                for: activeModel.metadata,
                session: session,
                in: modelContext
            )

            activeSession = session
            activeHole = hole
        } catch {
            modelContext.rollback()
            errorMessage = GarageCourseMapErrorFormatter.message(for: error)
        }
    }

    @MainActor
    private func persistShotAtReticle() {
        garageTriggerImpact(.medium)
        errorMessage = nil
        statusMessage = nil

        guard
            let club = selectedClub,
            let lie = selectedLie,
            let result = selectedResult
        else {
            errorMessage = "Select club, lie, and result before saving this shot."
            return
        }

        do {
            let session = try activeSession ?? GarageCourseMappingPersistence.resolveActiveSession(
                for: activeModel.metadata,
                in: modelContext
            )
            let hole = try activeHole ?? GarageCourseMappingPersistence.resolveHole(
                for: activeModel.metadata,
                session: session,
                in: modelContext
            )
            try ensureGPSCompatibilityAnchors(for: hole)

            let placement = try normalizedPlacement(for: reticleCoordinate, in: activeRegion)
            let savedShot = try GarageCourseMappingPersistence.upsertShot(
                editingShotID: nil,
                draft: GarageCourseShotSaveDraft(
                    placement: placement,
                    club: club,
                    lieBeforeShot: lie,
                    actualResult: result
                ),
                session: session,
                hole: hole,
                in: modelContext
            )

            activeSession = session
            activeHole = hole
            isShotDrawerPresented = false
            statusMessage = "Stroke \(savedShot.sequenceIndex) saved at \(originToTargetYards) yd."
        } catch {
            modelContext.rollback()
            errorMessage = GarageCourseMapErrorFormatter.message(for: error)
        }
    }

    @MainActor
    private func ensureGPSCompatibilityAnchors(for hole: GarageHoleMap) throws {
        guard hole.isCalibrated == false else { return }

        let teeAnchor = try normalizedAnchor(kind: .tee, coordinate: teeCoordinate)
        let midAnchor = try normalizedAnchor(kind: .fairwayCheckpoint, coordinate: midpointCoordinate)
        let greenAnchor = try normalizedAnchor(kind: .greenCenter, coordinate: greenCoordinate)

        _ = try GarageCourseMappingPersistence.saveCalibrationAnchors(
            teeAnchor: teeAnchor,
            fairwayCheckpointAnchor: midAnchor,
            greenCenterAnchor: greenAnchor,
            for: hole,
            in: modelContext
        )
    }

    private func normalizedAnchor(
        kind: GarageMapAnchorKind,
        coordinate: CLLocationCoordinate2D
    ) throws -> GarageMapAnchor {
        let placement = try normalizedPlacement(for: coordinate, in: activeRegion)
        return GarageMapAnchor(
            kind: kind,
            normalizedX: placement.normalizedX,
            normalizedY: placement.normalizedY
        )
    }

    private func normalizedPlacement(
        for coordinate: CLLocationCoordinate2D,
        in region: MKCoordinateRegion
    ) throws -> GarageShotPlacement {
        let latitudeDelta = max(region.span.latitudeDelta, 0.000_001)
        let longitudeDelta = max(region.span.longitudeDelta, 0.000_001)
        let maxLatitude = region.center.latitude + latitudeDelta / 2
        let minLongitude = region.center.longitude - longitudeDelta / 2

        let normalizedX = (coordinate.longitude - minLongitude) / longitudeDelta
        let normalizedY = (maxLatitude - coordinate.latitude) / latitudeDelta
        let placement = GarageShotPlacement(normalizedX: normalizedX, normalizedY: normalizedY)
        try placement.validate(fieldName: "GPS shot placement")
        return placement
    }

    private func resolvedInitialCenterCoordinate(
        for userCoordinate: CLLocationCoordinate2D?
    ) -> CLLocationCoordinate2D {
        guard let userCoordinate else {
            isUsingTeeFallbackOrigin = true
            return teeCoordinate
        }

        let isValid = isCoordinateWithinActiveHoleTolerance(userCoordinate)
        isUsingTeeFallbackOrigin = isValid == false
        return isValid ? userCoordinate : teeCoordinate
    }

    private func isCoordinateWithinActiveHoleTolerance(_ coordinate: CLLocationCoordinate2D) -> Bool {
        distanceFromRegionBounds(coordinate, region: activeRegion) <= garageGPSHoleToleranceMeters
    }

    private func distanceFromRegionBounds(
        _ coordinate: CLLocationCoordinate2D,
        region: MKCoordinateRegion
    ) -> CLLocationDistance {
        let regionMapRect = MKMapRect(region)
        let point = MKMapPoint(coordinate)

        if regionMapRect.contains(point) {
            return 0
        }

        let nearestX = min(max(point.x, regionMapRect.minX), regionMapRect.maxX)
        let nearestY = min(max(point.y, regionMapRect.minY), regionMapRect.maxY)
        return point.distance(to: MKMapPoint(x: nearestX, y: nearestY))
    }

    private static func topDownCamera(
        center: CLLocationCoordinate2D,
        region: MKCoordinateRegion
    ) -> MapCamera {
        MapCamera(
            centerCoordinate: center,
            distance: max(min(max(region.latitudinalMeters, region.longitudinalMeters) * 0.72, 720), 160),
            heading: 0,
            pitch: 0
        )
    }

    private func yardage(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> Int {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return Int((startLocation.distance(from: endLocation) / garageMetersPerYard).rounded())
    }

    private func midpoint(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (start.latitude + end.latitude) / 2,
            longitude: (start.longitude + end.longitude) / 2
        )
    }

    private func destinationCoordinate(
        from start: CLLocationCoordinate2D,
        bearingDegrees: CLLocationDegrees,
        distanceMeters: CLLocationDistance
    ) -> CLLocationCoordinate2D {
        let radius = 6_371_000.0
        let bearing = bearingDegrees * .pi / 180
        let startLatitude = start.latitude * .pi / 180
        let startLongitude = start.longitude * .pi / 180
        let angularDistance = distanceMeters / radius

        let latitude = asin(
            sin(startLatitude) * cos(angularDistance)
                + cos(startLatitude) * sin(angularDistance) * cos(bearing)
        )
        let longitude = startLongitude + atan2(
            sin(bearing) * sin(angularDistance) * cos(startLatitude),
            cos(angularDistance) - sin(startLatitude) * sin(latitude)
        )

        return CLLocationCoordinate2D(
            latitude: latitude * 180 / .pi,
            longitude: longitude * 180 / .pi
        )
    }
}

@MainActor
private final class GarageCourseLocationController: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userCoordinate: CLLocationCoordinate2D?
    @Published var headingDegrees: CLLocationDirection?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var locationErrorMessage: String?
    @Published var locationUpdateID = UUID()

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
        manager.headingFilter = 4
    }

    var locationStatusMessage: String {
        switch authorizationStatus {
        case .notDetermined:
            "GPS locating. Allow location access for live yardages."
        case .restricted, .denied:
            "Location access is off. Yardages are using the tee as origin."
        case .authorizedAlways, .authorizedWhenInUse, .authorized:
            locationErrorMessage ?? "GPS locating. Yardages are using the tee until a fix arrives."
        @unknown default:
            "GPS status unavailable. Yardages are using the tee as origin."
        }
    }

    func start() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        refreshTracking()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    private func refreshTracking() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationErrorMessage = "Location services are disabled."
            return
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse, .authorized:
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        case .notDetermined, .restricted, .denied:
            manager.stopUpdatingLocation()
            manager.stopUpdatingHeading()
        @unknown default:
            manager.stopUpdatingLocation()
            manager.stopUpdatingHeading()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            refreshTracking()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        let latitude = latest.coordinate.latitude
        let longitude = latest.coordinate.longitude
        Task { @MainActor in
            userCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            locationUpdateID = UUID()
            locationErrorMessage = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        guard heading >= 0 else { return }
        Task { @MainActor in
            headingDegrees = heading
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = (error as NSError).localizedDescription
        Task { @MainActor in
            locationErrorMessage = message
        }
    }
}

@MainActor
private final class GarageCourseNetworkMonitor: ObservableObject, @unchecked Sendable {
    @Published var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "GarageCourseNetworkMonitor")
    private var hasStarted = false

    func start() {
        guard hasStarted == false else { return }
        hasStarted = true
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            guard let monitor = self else { return }
            Task { @MainActor in
                monitor.isOnline = isOnline
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
        hasStarted = false
    }
}

private struct GarageCourseDistanceAnnotation: Identifiable {
    let id = UUID()
    let title: String
    let coordinate: CLLocationCoordinate2D
}

private struct GarageCourseGlassBackground<S: Shape>: View {
    let shape: S
    var stroke: Color = Color.white.opacity(0.1)
    var shadowRadius: CGFloat = 16
    var shadowYOffset: CGFloat = 10

    var body: some View {
        shape
            .fill(Color.black.opacity(0.4))
            .overlay(shape.fill(.ultraThinMaterial))
            .overlay(shape.stroke(stroke, lineWidth: 0.7))
            .shadow(color: .black.opacity(0.28), radius: shadowRadius, x: 0, y: shadowYOffset)
    }
}

private struct GarageCourseMapDistanceTag: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                GarageCourseGlassBackground(
                    shape: Capsule(),
                    stroke: Color.white.opacity(0.18),
                    shadowRadius: 5,
                    shadowYOffset: 3
                )
            )
            .colorScheme(.dark)
    }
}

private struct GarageCourseMapGreenMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(garageLISYSystemBlue.opacity(0.18))
                .frame(width: 34, height: 34)

            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 1.5)
                .frame(width: 22, height: 22)

            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
        }
        .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 3)
        .accessibilityLabel("Center of green")
    }
}

private struct GarageCourseMapNotice: View {
    let systemImage: String
    let message: String
    var isError = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(.caption, design: .rounded).weight(.bold))

            Text(message)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(isError ? garageReviewFlagged : garageReviewReadableText)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GarageCourseGlassBackground(
                shape: Capsule(),
                stroke: (isError ? garageReviewFlagged : Color.white).opacity(isError ? 0.22 : 0.08),
                shadowRadius: 10,
                shadowYOffset: 6
            )
        )
        .colorScheme(.dark)
    }
}

private struct GarageGPSShotDrawer: View {
    @Binding var selectedClub: GarageTacticalClub?
    @Binding var selectedLie: GarageTacticalLie?
    @Binding var selectedResult: GarageTacticalResult?

    let canSave: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("STROKE REGISTRATION")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(garageLISYSystemBlue)

                    Text("Save the reticle target to the active hole.")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(garageReviewMutedText)
                }

                Spacer(minLength: 0)
            }

            selectionRail(title: "Club", items: GarageTacticalClub.allCases, selection: $selectedClub)
            selectionRail(title: "Lie", items: GarageTacticalLie.allCases, selection: $selectedLie)
            selectionRail(title: "Result", items: GarageTacticalResult.allCases, selection: $selectedResult)

            HStack(spacing: 10) {
                drawerButton(title: "Cancel", isPrimary: false, isEnabled: true, action: onCancel)
                drawerButton(title: "Save Stroke", isPrimary: true, isEnabled: canSave, action: onConfirm)
            }
        }
        .padding(14)
        .background(
            GarageCourseGlassBackground(
                shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
                stroke: Color.white.opacity(0.1),
                shadowRadius: 18,
                shadowYOffset: 12
            )
        )
        .colorScheme(.dark)
    }

    private func selectionRail<Item: CaseIterable & Identifiable & Hashable & GarageGPSSelectable>(
        title: String,
        items: Item.AllCases,
        selection: Binding<Item?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .tracking(0.8)
                .foregroundStyle(garageReviewMutedText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(items), id: \.id) { item in
                        let isSelected = selection.wrappedValue == item

                        Button {
                            garageTriggerImpact(.light)
                            selection.wrappedValue = item
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: item.symbolName)
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                                Text(item.title)
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(isSelected ? .white : garageReviewReadableText.opacity(0.86))
                            .frame(minHeight: 44)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(isSelected ? garageLISYSystemBlue.opacity(0.88) : garageReviewSurfaceDark.opacity(0.74))
                                    .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 0.6))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func drawerButton(
        title: String,
        isPrimary: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard isEnabled else { return }
            garageTriggerImpact(isPrimary ? .medium : .light)
            action()
        } label: {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(isPrimary ? .white : garageReviewReadableText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    Capsule()
                        .fill(isPrimary ? garageLISYSystemBlue.opacity(isEnabled ? 1 : 0.34) : garageReviewSurfaceDark.opacity(0.82))
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.6))
                )
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
        .opacity(isEnabled ? 1 : 0.55)
    }
}

private protocol GarageGPSSelectable {
    var title: String { get }
    var symbolName: String { get }
}

extension GarageTacticalClub: GarageGPSSelectable {}
extension GarageTacticalLie: GarageGPSSelectable {}
extension GarageTacticalResult: GarageGPSSelectable {}

private enum GarageCourseMapErrorFormatter {
    static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let errorDescription = localizedError.errorDescription {
            if let recoverySuggestion = localizedError.recoverySuggestion {
                return "\(errorDescription) \(recoverySuggestion)"
            }
            return errorDescription
        }

        return (error as NSError).localizedDescription
    }
}

private extension GarageCourseMetadata {
    var safeHoleNumber: Int {
        (try? resolvedHoleNumber) ?? Int(holeLabel.filter(\.isNumber)) ?? 1
    }
}

private extension GarageCourseMappingModel {
    var previewTeeCoordinate: CLLocationCoordinate2D {
        activeRoute?.nodes.first(where: { $0.kind == .tee })?.coordinate.clCoordinate
            ?? activeRoute?.coordinates.first?.clCoordinate
            ?? metadata.region.mkRegion.center
    }
}

private extension MKMapRect {
    init(_ region: MKCoordinateRegion) {
        let latitudeDelta = max(region.span.latitudeDelta, 0.000_001)
        let longitudeDelta = max(region.span.longitudeDelta, 0.000_001)
        let northWest = CLLocationCoordinate2D(
            latitude: region.center.latitude + latitudeDelta / 2,
            longitude: region.center.longitude - longitudeDelta / 2
        )
        let southEast = CLLocationCoordinate2D(
            latitude: region.center.latitude - latitudeDelta / 2,
            longitude: region.center.longitude + longitudeDelta / 2
        )
        let origin = MKMapPoint(northWest)
        let opposite = MKMapPoint(southEast)

        self.init(
            x: min(origin.x, opposite.x),
            y: min(origin.y, opposite.y),
            width: abs(origin.x - opposite.x),
            height: abs(origin.y - opposite.y)
        )
    }
}

private extension MKCoordinateRegion {
    var latitudinalMeters: CLLocationDistance {
        MKMapPoint(
            CLLocationCoordinate2D(
                latitude: center.latitude - span.latitudeDelta / 2,
                longitude: center.longitude
            )
        )
        .distance(
            to: MKMapPoint(
                CLLocationCoordinate2D(
                    latitude: center.latitude + span.latitudeDelta / 2,
                    longitude: center.longitude
                )
            )
        )
    }

    var longitudinalMeters: CLLocationDistance {
        MKMapPoint(
            CLLocationCoordinate2D(
                latitude: center.latitude,
                longitude: center.longitude - span.longitudeDelta / 2
            )
        )
        .distance(
            to: MKMapPoint(
                CLLocationCoordinate2D(
                    latitude: center.latitude,
                    longitude: center.longitude + span.longitudeDelta / 2
                )
            )
        )
    }
}

#Preview {
    PreviewScreenContainer {
        GarageCourseMapView()
    }
    .modelContainer(PreviewCatalog.emptyApp)
}
