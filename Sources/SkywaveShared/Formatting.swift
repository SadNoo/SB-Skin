import Foundation

/// Compact, locale-stable number formatting shared by every skin and widget.
public enum SkinFormat {
    private static let units = ["B", "KB", "MB", "GB", "TB", "PB"]

    /// Splits a byte count into a short value and its unit, e.g. `(“18.6”, “MB”)`.
    public static func bytesParts(_ bytes: Int64) -> (value: String, unit: String) {
        var value = Double(max(bytes, 0))
        var index = 0
        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }
        let text: String
        if index == 0 {
            text = String(Int(value))
        } else if value >= 100 {
            text = String(format: "%.0f", value)
        } else {
            text = String(format: "%.1f", value)
        }
        return (text, units[index])
    }

    /// `4.8 GB`
    public static func bytes(_ bytes: Int64) -> String {
        let parts = bytesParts(bytes)
        return "\(parts.value) \(parts.unit)"
    }

    /// `(“18.6”, “MB/s”)`
    public static func rateParts(_ bytesPerSecond: Int64) -> (value: String, unit: String) {
        let parts = bytesParts(bytesPerSecond)
        return (parts.value, parts.unit + "/s")
    }

    /// `18.6 MB/s`
    public static func rate(_ bytesPerSecond: Int64) -> String {
        let parts = rateParts(bytesPerSecond)
        return "\(parts.value) \(parts.unit)"
    }

    /// `1:42:17` or `4:12`.
    public static func duration(_ interval: TimeInterval) -> String {
        let total = max(Int(interval), 0)
        let hours = total / 3600
        let minutes = total / 60 % 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Human duration like `1 h 42 min` for sentences.
    public static func spokenDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .short
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(interval, 0)) ?? duration(interval)
    }
}
