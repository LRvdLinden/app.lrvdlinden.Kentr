import Foundation

/// Hulpfuncties voor Nederlandse kentekens.
enum Kenteken {
    /// Hoofdletters, alleen A–Z en 0–9 (streepjes en spaties eruit).
    static func normalize(_ text: String) -> String {
        String(text.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
    }

    /// Een Nederlands kenteken heeft 6 tekens.
    static func isValid(_ text: String) -> Bool {
        normalize(text).count == 6
    }

    /// Opmaak met streepjes volgens de sidecode, bv. "XX-99-99", "9-XXX-99", "XX-999-X".
    static func format(_ text: String) -> String {
        let plate = normalize(text)
        guard plate.count == 6 else { return plate }

        var groups: [String] = []
        var current = ""
        var currentIsDigit: Bool?
        for ch in plate {
            let isDigit = ch.isNumber
            if let last = currentIsDigit, last != isDigit {
                groups.append(current)
                current = ""
            }
            current.append(ch)
            currentIsDigit = isDigit
        }
        if !current.isEmpty { groups.append(current) }

        switch groups.count {
        case 1:
            let a = Array(plate)
            return "\(String(a[0...1]))-\(String(a[2...3]))-\(String(a[4...5]))"
        case 2:
            // Een groep van 4 wordt 2 + 2 (bv. XX-99-99 of 99-XX-XX).
            var result: [String] = []
            for g in groups {
                if g.count == 4 {
                    let a = Array(g)
                    result.append(String(a[0...1]))
                    result.append(String(a[2...3]))
                } else {
                    result.append(g)
                }
            }
            return result.joined(separator: "-")
        default:
            return groups.joined(separator: "-")
        }
    }
}
