import SwiftUI

/// Smooth line through evenly spaced samples, scaled to the rect.
struct SparklineShape: Shape {
    var values: [Double]
    /// Upper bound of the y axis; defaults to the max sample.
    var ceiling: Double?
    /// Close the path to the bottom edge for an area fill.
    var closed = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let top = max(ceiling ?? values.max() ?? 1, 1)
        let stepX = rect.width / CGFloat(values.count - 1)
        let points = values.enumerated().map { index, value in
            CGPoint(
                x: rect.minX + CGFloat(index) * stepX,
                y: rect.maxY - CGFloat(min(value / top, 1)) * rect.height * 0.92
            )
        }
        path.move(to: points[0])
        for index in 1 ..< points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midX = (previous.x + current.x) / 2
            path.addCurve(
                to: current,
                control1: CGPoint(x: midX, y: previous.y),
                control2: CGPoint(x: midX, y: current.y)
            )
        }
        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// A line with an optional soft area fill underneath.
struct Sparkline: View {
    var values: [Double]
    var color: Color
    var ceiling: Double?
    var lineWidth: CGFloat = 2
    var fill = true

    var body: some View {
        ZStack {
            if fill {
                SparklineShape(values: values, ceiling: ceiling, closed: true)
                    .fill(
                        LinearGradient(colors: [color.opacity(0.22), color.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                    )
            }
            SparklineShape(values: values, ceiling: ceiling)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .animation(.easeOut(duration: 0.35), value: values)
        .accessibilityHidden(true)
    }
}

/// Download (filled) and upload (line) on one shared scale.
struct DualTrafficChart: View {
    var download: [Double]
    var upload: [Double]
    var downloadColor: Color
    var uploadColor: Color
    var gridColor: Color = .secondary.opacity(0.12)
    var showsGrid = true

    var body: some View {
        let ceiling = max(download.max() ?? 1, upload.max() ?? 1, 1) * 1.1
        ZStack {
            if showsGrid {
                GeometryReader { proxy in
                    Path { path in
                        for fraction in [0.25, 0.5, 0.75] {
                            let y = proxy.size.height * fraction
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                        }
                    }
                    .stroke(gridColor, lineWidth: 1)
                }
            }
            Sparkline(values: download, color: downloadColor, ceiling: ceiling, lineWidth: 2.2)
            Sparkline(values: upload, color: uploadColor, ceiling: ceiling, lineWidth: 1.8, fill: false)
        }
        .accessibilityElement()
        .accessibilityLabel(Text(skin: "Traffic chart"))
    }
}

/// Column bars, newest on the right. Used by Bento and Radio.
struct BarHistogram: View {
    var values: [Double]
    var color: Color
    var highlight: Color
    var spacing: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let top = max(values.max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index == values.count - 1 ? highlight : color)
                        .frame(height: max(3, proxy.size.height * CGFloat(value / top)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .animation(.easeOut(duration: 0.3), value: values)
        .accessibilityHidden(true)
    }
}
