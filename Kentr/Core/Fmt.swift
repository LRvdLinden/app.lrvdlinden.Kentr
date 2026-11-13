import Foundation

/// Nederlandse opmaak van bedragen, getallen en datums.
enum Fmt {
    static let locale = Locale(identifier: "nl_NL")

    private static let euroFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.maximumFractionDigits = 0
        return f
    }()

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f
    }()

    private static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return f
    }()

    private static let rdwDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    static func euro(_ value: Double) -> String {
        euroFormatter.string(from: NSNumber(value: value)) ?? "€ \(Int(value))"
    }

    static func number(_ value: Double) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func number(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func date(_ date: Date) -> String { longDate.string(from: date) }
    static func monthYear(_ date: Date) -> String { monthYearFormatter.string(from: date) }
    static func year(_ date: Date) -> String { String(Calendar.current.component(.year, from: date)) }

    /// RDW-datum "yyyyMMdd" (of ISO "yyyy-MM-ddT…") naar Date.
    static func rdwDate(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        if text.count >= 8, let d = rdwDateFormatter.date(from: String(text.prefix(8))) { return d }
        if text.count >= 10 {
            let iso = String(text.prefix(10)).replacingOccurrences(of: "-", with: "")
            return rdwDateFormatter.date(from: iso)
        }
        return nil
    }

    /// Jaren en maanden, bv. "3 jaar en 4 maanden".
    static func duration(from start: Date, to end: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: start, to: end)
        let y = max(0, c.year ?? 0), m = max(0, c.month ?? 0)
        switch (y, m) {
        case (0, 0): return "minder dan een maand"
        case (0, _): return m == 1 ? "1 maand" : "\(m) maanden"
        case (_, 0): return "\(y) jaar"
        default: return "\(y) jaar en " + (m == 1 ? "1 maand" : "\(m) maanden")
        }
    }
}
