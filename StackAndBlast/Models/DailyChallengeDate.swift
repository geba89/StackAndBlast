import Foundation

/// The "which day is it?" key for the Daily Challenge, e.g. `"2026-09-24"`.
///
/// It seeds the daily pieces and records which day was completed, so it must come out
/// identical on every device for the same calendar day. That's why it doesn't use a
/// plain `DateFormatter`: those follow the device's calendar and digits, producing
/// "2569-09-24" on a phone set to the Thai (Buddhist) calendar or "٢٠٢٦-٠٩-٢٤" with
/// Arabic digits — a different seed, and therefore a different "daily" puzzle.
enum DailyChallengeDate {

    /// Key for the player's local calendar day (like Wordle, the new puzzle
    /// unlocks at local midnight). Always Gregorian, always ASCII digits.
    static func key(for date: Date = Date(), timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(padded(parts.year, 4))-\(padded(parts.month, 2))-\(padded(parts.day, 2))"
    }

    /// Zero-pad a number, e.g. `padded(9, 2)` → `"09"`. `String(Int)` always uses ASCII digits.
    private static func padded(_ value: Int?, _ width: Int) -> String {
        let digits = String(value ?? 0)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
