import CoreGraphics

enum GarageSpatialCoordinateSpace {
    static let mapSpace = "MapSpace"
    static let hudSpace = "HUDSpace"
}

func garageVisionAspectFitRect(contentSize: CGSize, in container: CGRect) -> CGRect {
    garageAspectFitRectImpl(contentSize: contentSize, in: container)
}

func garageVisionAspectFitRect(container: CGSize, aspectRatio: CGFloat) -> CGRect {
    garageAspectFitRectImpl(container: container, aspectRatio: aspectRatio)
}

func garageVisionMappedPoint(x: Double, y: Double, in rect: CGRect) -> CGPoint {
    garageMappedPointImpl(x: x, y: y, in: rect)
}

func garageVisionMappedPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
    garageVisionMappedPoint(x: point.x, y: point.y, in: rect)
}

func garageVisionNormalizedPoint(from location: CGPoint, in rect: CGRect) -> CGPoint? {
    garageNormalizedPointImpl(from: location, in: rect)
}

func garageClampedVisionNormalizedPoint(_ point: CGPoint) -> CGPoint {
    garageClampedNormalizedPointImpl(point)
}

func garageCourseMapLayerRect(contentSize: CGSize, in container: CGRect) -> CGRect {
    garageAspectFitRectImpl(contentSize: contentSize, in: container)
}

func garageCourseMapLayerRect(container: CGSize, aspectRatio: CGFloat) -> CGRect {
    garageAspectFitRectImpl(container: container, aspectRatio: aspectRatio)
}

func garageCourseMapPoint(x: Double, y: Double, in rect: CGRect) -> CGPoint {
    garageMappedPointImpl(x: x, y: y, in: rect)
}

func garageCourseMapPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
    garageCourseMapPoint(x: point.x, y: point.y, in: rect)
}

func garageCourseMapNormalizedPoint(from location: CGPoint, in rect: CGRect) -> CGPoint? {
    garageNormalizedPointImpl(from: location, in: rect)
}

func garageClampedCourseMapNormalizedPoint(_ point: CGPoint) -> CGPoint {
    garageClampedNormalizedPointImpl(point)
}

private func garageAspectFitRectImpl(contentSize: CGSize, in container: CGRect) -> CGRect {
    guard contentSize.width > 0, contentSize.height > 0, container.width > 0, container.height > 0 else {
        return .zero
    }

    let scale = min(container.width / contentSize.width, container.height / contentSize.height)
    let scaledSize = CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
    let origin = CGPoint(
        x: container.midX - (scaledSize.width / 2),
        y: container.midY - (scaledSize.height / 2)
    )
    return CGRect(origin: origin, size: scaledSize)
}

private func garageAspectFitRectImpl(container: CGSize, aspectRatio: CGFloat) -> CGRect {
    guard container.width > 0, container.height > 0, aspectRatio > 0 else {
        return CGRect(origin: .zero, size: container)
    }

    let contentSize: CGSize
    if aspectRatio >= 1 {
        contentSize = CGSize(width: aspectRatio, height: 1)
    } else {
        contentSize = CGSize(width: 1, height: 1 / aspectRatio)
    }

    return garageAspectFitRectImpl(
        contentSize: contentSize,
        in: CGRect(origin: .zero, size: container)
    )
}

private func garageMappedPointImpl(x: Double, y: Double, in rect: CGRect) -> CGPoint {
    CGPoint(
        x: rect.minX + (rect.width * x),
        y: rect.minY + (rect.height * y)
    )
}

private func garageNormalizedPointImpl(from location: CGPoint, in rect: CGRect) -> CGPoint? {
    guard rect.contains(location), rect.width > 0, rect.height > 0 else {
        return nil
    }

    let normalizedX = (location.x - rect.minX) / rect.width
    let normalizedY = (location.y - rect.minY) / rect.height
    return CGPoint(x: normalizedX, y: normalizedY)
}

private func garageClampedNormalizedPointImpl(_ point: CGPoint) -> CGPoint {
    CGPoint(
        x: min(max(point.x, 0), 1),
        y: min(max(point.y, 0), 1)
    )
}
