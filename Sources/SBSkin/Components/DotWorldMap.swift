import SwiftUI

/// Offline dot-matrix world map drawn with Canvas from ``WorldMask``.
struct DotWorldMap: View {
    struct Pin: Identifiable, Hashable {
        let id: String
        let latitude: Double
        let longitude: Double
        let label: String
        let selected: Bool
    }

    /// Longitude / latitude at the center of the view.
    var center: (latitude: Double, longitude: Double) = (25, 60)
    /// Degrees of longitude visible across the width.
    var span: Double = 360
    var pins: [Pin] = []
    var dotColor: Color
    var pinColor: Color
    var highlightColor: Color
    var labelColor: Color
    var labelBackground: Color
    var dotScale: CGFloat = 0.36

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let degreesPerPoint = span / Double(max(size.width, 1))
            let cell = CGFloat(WorldMask.step / degreesPerPoint)
            ZStack(alignment: .topLeading) {
                Canvas { context, canvasSize in
                    let radius = max(cell * dotScale, 0.6)
                    var path = Path()
                    for (column, row) in WorldMask.landCells {
                        let longitude = WorldMask.originLongitude + Double(column) * WorldMask.step
                        let latitude = WorldMask.originLatitude - Double(row) * WorldMask.step
                        let point = project(latitude: latitude, longitude: longitude, in: canvasSize, degreesPerPoint: degreesPerPoint)
                        guard point.x > -cell, point.x < canvasSize.width + cell, point.y > -cell, point.y < canvasSize.height + cell else { continue }
                        path.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
                    }
                    context.fill(path, with: .color(dotColor))
                }
                ForEach(pins.filter { !$0.selected }) { pin in
                    let point = project(latitude: pin.latitude, longitude: pin.longitude, in: size, degreesPerPoint: degreesPerPoint)
                    ZStack(alignment: .leading) {
                        Circle()
                            .fill(pinColor)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .frame(width: 11, height: 11)
                        Text(pin.label)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(labelColor)
                            .fixedSize()
                            .offset(x: 13)
                    }
                    .position(x: point.x + 5, y: point.y)
                    .offset(x: 0)
                }
                ForEach(pins.filter(\.selected)) { pin in
                    let point = project(latitude: pin.latitude, longitude: pin.longitude, in: size, degreesPerPoint: degreesPerPoint)
                    SelectedPin(label: pin.label, color: highlightColor, labelColor: labelBackground)
                        .position(x: point.x, y: point.y)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private func project(latitude: Double, longitude: Double, in size: CGSize, degreesPerPoint: Double) -> CGPoint {
        var deltaLongitude = longitude - center.longitude
        if deltaLongitude > 180 { deltaLongitude -= 360 }
        if deltaLongitude < -180 { deltaLongitude += 360 }
        return CGPoint(
            x: size.width / 2 + CGFloat(deltaLongitude / degreesPerPoint),
            y: size.height / 2 - CGFloat((latitude - center.latitude) / degreesPerPoint)
        )
    }
}

private struct SelectedPin: View {
    let label: String
    let color: Color
    let labelColor: Color
    @Environment(\.skinThumbnailMode) private var thumbnail
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 88, height: 88)
                .scaleEffect(pulse ? 1.15 : 0.9)
                .opacity(pulse ? 0.6 : 1)
            Circle()
                .fill(color)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .frame(width: 22, height: 22)
                .shadow(color: color.opacity(0.5), radius: 6, y: 3)
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(labelColor, in: Capsule())
                .fixedSize()
                .offset(y: 30)
        }
        .onAppear {
            guard !thumbnail else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
