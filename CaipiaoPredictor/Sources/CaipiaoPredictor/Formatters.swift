import Foundation

enum DisplayFormat {
    static func number(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    static func digit(_ value: Int) -> String {
        "\(value)"
    }

    static func numbers(_ values: [Int]) -> String {
        values.map(number).joined(separator: " ")
    }

    static func money(_ value: Double?) -> String {
        guard let value else {
            return "-"
        }
        if value >= 100_000_000 {
            return String(format: "%.2f 亿", value / 100_000_000)
        }
        if value >= 10_000 {
            return String(format: "%.2f 万", value / 10_000)
        }
        return String(format: "%.0f", value)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.2f%%", value * 100)
    }

    static func time(_ date: Date?) -> String {
        guard let date else {
            return "-"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
