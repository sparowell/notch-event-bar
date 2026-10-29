import Foundation

/// One way to write a length of time everywhere it is shown: `45 min`, `1h`,
/// `1h05`, `4h`. Round hours carry no `00`.
enum DurationLabel {
    static func short(minutes: Int, locale: Locale = .current) -> String {
        let minutes = max(minutes, 0)
        let hours = minutes / 60
        let rest = minutes % 60

        guard hours > 0 else {
            return Localized.string("\(rest) min", locale: locale)
        }
        guard rest > 0 else {
            return Localized.string("\(hours)h", locale: locale)
        }
        let paddedMinutes = String(format: "%02d", rest)
        return Localized.string("\(hours)h\(paddedMinutes)", locale: locale)
    }
}

/// Where the faint dividers sit on the panel's progress bar.
enum ProgressTicks {
    static let maximumParts = 4

    /// A part is about 30 minutes, at most four: 45 min has none, 1 h one at
    /// 50 %, 1 h 30 two, 2 h and longer three (25/50/75 %).
    static func fractions(durationSeconds: TimeInterval) -> [Double] {
        let parts = min(max(Int(durationSeconds / 1800), 1), maximumParts)
        guard parts > 1 else { return [] }
        return (1..<parts).map { Double($0) / Double(parts) }
    }
}
