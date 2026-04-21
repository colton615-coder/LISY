import MapKit
import SwiftUI

struct GarageCourseMapView: View {
    @StateObject private var model: GarageCourseMappingModel

    private let bottomInset: CGFloat

    @MainActor
    init(bottomInset: CGFloat = 84) {
        _model = StateObject(wrappedValue: .preview)
        self.bottomInset = bottomInset
    }

    init(
        model: GarageCourseMappingModel,
        bottomInset: CGFloat = 84
    ) {
        _model = StateObject(wrappedValue: model)
        self.bottomInset = bottomInset
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer

            LinearGradient(
                colors: [
                    Color.black.opacity(0.45),
                    Color.black.opacity(0.08),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 16) {
                topChrome

                Spacer(minLength: 0)

                courseStatsSheet
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, bottomInset)
        }
        .background(ModuleTheme.garageBackground.ignoresSafeArea())
    }

    private var mapLayer: some View {
        Map(
            position: Binding(
                get: { model.cameraPosition },
                set: { model.cameraPosition = $0 }
            ),
            interactionModes: .all
        ) {
            ForEach(model.routes) { route in
                if route.coordinates.count > 1 {
                    MapPolyline(coordinates: route.coordinates.map(\.clCoordinate))
                        .stroke(
                            route.id == model.activeRouteID
                            ? LinearGradient(
                                colors: [
                                    garageReviewAccent.opacity(0.98),
                                    Color(hex: "#6FF7FF")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.26),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(
                                lineWidth: route.id == model.activeRouteID ? 5.5 : 2.5,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }

                ForEach(route.nodes) { node in
                    Annotation(node.title, coordinate: node.coordinate.clCoordinate) {
                        GarageCourseNodeMarker(
                            node: node,
                            isActiveRoute: route.id == model.activeRouteID,
                            isSelected: node.id == model.selectedNodeID
                        ) {
                            garageTriggerImpact(route.id == model.activeRouteID ? .light : .medium)
                            model.selectRoute(route.id)
                            model.selectNode(node.id)
                        }
                    }
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControlVisibility(.hidden)
        .ignoresSafeArea()
    }

    private var topChrome: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TACTICAL SURVEY")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(garageReviewAccent.opacity(0.92))

                Text(model.metadata.courseName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)

                Text("\(model.metadata.holeLabel) • \(model.metadata.holeName)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(garageReviewMutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)

            Button {
                garageTriggerImpact(.light)
                model.focusActiveRoute()
            } label: {
                Label("Recenter", systemImage: "location.north.line.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        GarageCourseGlassBackground(
                            cornerRadius: 16,
                            fillOpacity: 0.22
                        )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var courseStatsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Course Map")
                        .font(.caption.weight(.bold))
                        .tracking(1.3)
                        .foregroundStyle(garageReviewMutedText)

                    Text(model.headline)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)

                    Text(model.activeSummary)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(garageReviewMutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if let activeRoute = model.activeRoute {
                    VStack(alignment: .trailing, spacing: 8) {
                        GarageCourseBadge(
                            title: activeRoute.isPrimary ? "PRIMARY" : "ALT LINE",
                            tint: activeRoute.isPrimary ? garageReviewAccent : Color.white.opacity(0.74)
                        )
                        GarageCourseBadge(
                            title: activeRoute.stats.expectedClub.uppercased(),
                            tint: garageReviewReadableText.opacity(0.92)
                        )
                    }
                }
            }

            routeSelector
            statGrid

            if let selectedNode = model.selectedNode {
                selectedNodeCard(selectedNode)
            }

            Text(model.metadata.contextNote)
                .font(.caption.weight(.medium))
                .foregroundStyle(garageReviewMutedText.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            GarageCourseGlassBackground(
                cornerRadius: 26,
                fillOpacity: 0.26
            )
        )
    }

    private var routeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(model.routes) { route in
                    Button {
                        garageTriggerImpact(.light)
                        model.selectRoute(route.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(route.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(route.id == model.activeRouteID ? garageReviewReadableText : garageReviewMutedText)

                            Text(route.subtitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(route.id == model.activeRouteID ? garageReviewReadableText.opacity(0.88) : garageReviewMutedText.opacity(0.82))
                                .lineLimit(1)
                        }
                        .frame(width: 188, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background {
                            if route.id == model.activeRouteID {
                                GarageRaisedPanelBackground(
                                    shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                    fill: garageReviewSurfaceRaised.opacity(0.94),
                                    stroke: garageReviewAccent.opacity(0.34),
                                    glow: garageReviewAccent.opacity(0.4)
                                )
                            } else {
                                GarageInsetPanelBackground(
                                    shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                    fill: garageReviewInsetSurface.opacity(0.92),
                                    stroke: garageReviewStroke.opacity(0.9)
                                )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var statGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return LazyVGrid(columns: columns, spacing: 10) {
            if let activeRoute = model.activeRoute {
                GarageCourseStatTile(
                    title: "Route",
                    value: "\(activeRoute.stats.totalYardage) yd",
                    accent: garageReviewAccent
                )
                GarageCourseStatTile(
                    title: "Carry",
                    value: "\(activeRoute.stats.carryYardage) yd",
                    accent: Color(hex: "#36D7FF")
                )
                GarageCourseStatTile(
                    title: "Hazards",
                    value: "\(activeRoute.stats.hazardCount)",
                    accent: garageReviewFlagged.opacity(0.88)
                )
                GarageCourseStatTile(
                    title: "Nodes",
                    value: "\(activeRoute.stats.nodeCount)",
                    accent: garageReviewReadableText.opacity(0.84)
                )
            }
        }
    }

    private func selectedNodeCard(_ node: GarageCourseNode) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(garageReviewAccent.opacity(0.18))
                    .frame(width: 38, height: 38)

                Image(systemName: node.kind.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(node.kind == .hazard ? garageReviewFlagged : garageReviewAccent)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(node.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)

                    if let distanceLabel = node.distanceLabel {
                        Text(distanceLabel.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(1.0)
                            .foregroundStyle(garageReviewAccent.opacity(0.92))
                    }
                }

                Text(node.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(garageReviewMutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            GarageInsetPanelBackground(
                shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                fill: garageReviewInsetSurface.opacity(0.94),
                stroke: garageReviewStroke.opacity(0.92)
            )
        )
    }
}

private struct GarageCourseNodeMarker: View {
    let node: GarageCourseNode
    let isActiveRoute: Bool
    let isSelected: Bool
    let action: () -> Void

    private var markerTint: Color {
        if node.kind == .hazard {
            return garageReviewFlagged
        }

        if isActiveRoute {
            return garageReviewAccent
        }

        return Color.white.opacity(0.72)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(isSelected ? 0.7 : 0.58))
                        .frame(width: isSelected ? 34 : 30, height: isSelected ? 34 : 30)

                    Circle()
                        .stroke(markerTint.opacity(isSelected ? 0.96 : 0.68), lineWidth: isSelected ? 2.6 : 1.4)
                        .frame(width: isSelected ? 34 : 30, height: isSelected ? 34 : 30)

                    Image(systemName: node.kind.systemImage)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(markerTint)
                }
                .shadow(color: markerTint.opacity(isActiveRoute ? 0.28 : 0.08), radius: 10, x: 0, y: 4)

                Text(node.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(isSelected ? 0.96 : 0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                            )
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct GarageCourseBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.28), lineWidth: 0.6)
                    )
            )
    }
}

private struct GarageCourseStatTile: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(garageReviewMutedText)

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(garageReviewReadableText)

            Capsule()
                .fill(accent)
                .frame(width: 28, height: 3)
                .shadow(color: accent.opacity(0.3), radius: 8, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            GarageInsetPanelBackground(
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                fill: garageReviewInsetSurface.opacity(0.94),
                stroke: garageReviewStroke.opacity(0.92)
            )
        )
    }
}

private struct GarageCourseGlassBackground: View {
    let cornerRadius: CGFloat
    let fillOpacity: Double

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.vibeSurface.opacity(fillOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.75)
            }
            .shadow(color: Color.black.opacity(0.34), radius: 18, x: 0, y: 12)
    }
}

#Preview {
    PreviewScreenContainer {
        GarageCourseMapView()
    }
}
