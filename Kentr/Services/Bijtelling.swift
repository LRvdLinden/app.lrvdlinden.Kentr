import Foundation

/// Indicatie van de bijtelling (auto van de zaak, privégebruik > 500 km per jaar).
/// Geen fiscaal advies: tarieven staan in de app en moeten jaarlijks worden bijgewerkt.
enum Bijtelling {
    /// Laatste jaar waarvoor de tarieven in deze versie kloppen.
    static let tarievenTotEnMet = 2027
    static let standaard = 0.22
    static let youngtimerPercentage = 0.35
    static let youngtimerLeeftijd = 15

    /// Tarief voor auto's zonder CO2-uitstoot, per jaar waarin de periode van 60 maanden begint.
    /// (percentage, cap: maximum cataloguswaarde waarover het lage percentage geldt)
    static let nulEmissie: [Int: (pct: Double, cap: Double?)] = [
        2014: (0.04, nil), 2015: (0.04, nil), 2016: (0.04, nil), 2017: (0.04, nil), 2018: (0.04, nil),
        2019: (0.04, 50_000), 2020: (0.08, 45_000), 2021: (0.12, 40_000), 2022: (0.16, 35_000),
        2023: (0.16, 30_000), 2024: (0.16, 30_000), 2025: (0.17, 30_000), 2026: (0.18, 30_000),
        2027: (0.20, 30_000),
    ]

    struct Resultaat {
        enum Soort { case normaal, youngtimer }
        let soort: Soort
        /// Effectief percentage over de hele cataloguswaarde.
        let effectiefPercentage: Double
        let laagPercentage: Double?
        let cap: Double?
        let perJaar: Double
        var perMaand: Double { perJaar / 12 }
        let periodeStart: Date
        let periodeEinde: Date
        let toelichting: String
    }

    /// Rekent de bijtelling uit voor vandaag.
    /// - Parameter dagwaarde: alleen nodig voor youngtimers (ouder dan 15 jaar).
    static func bereken(catalogusprijs: Double,
                        eersteToelating: Date,
                        elektrisch: Bool,
                        dagwaarde: Double? = nil,
                        op datum: Date = .now) -> Resultaat {
        let cal = Calendar.current

        // Youngtimer: ouder dan 15 jaar → 35% van de dagwaarde.
        if let leeftijd = cal.dateComponents([.year], from: eersteToelating, to: datum).year,
           leeftijd >= youngtimerLeeftijd {
            let waarde = dagwaarde ?? 0
            return Resultaat(soort: .youngtimer,
                             effectiefPercentage: youngtimerPercentage,
                             laagPercentage: nil, cap: nil,
                             perJaar: waarde * youngtimerPercentage,
                             periodeStart: eersteToelating, periodeEinde: datum,
                             toelichting: "Deze auto is ouder dan 15 jaar (youngtimer). De bijtelling is dan 35% van de dagwaarde in plaats van de catalogusprijs.")
        }

        // De periode van 60 maanden begint op de 1e van de maand na de eerste toelating.
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: eersteToelating)) ?? eersteToelating
        let eersteStart = cal.date(byAdding: .month, value: 1, to: startOfMonth) ?? eersteToelating
        let maanden = max(0, cal.dateComponents([.month], from: eersteStart, to: datum).month ?? 0)
        let periodes = maanden / 60
        let start = cal.date(byAdding: .month, value: periodes * 60, to: eersteStart) ?? eersteStart
        let einde = cal.date(byAdding: .day, value: -1,
                             to: cal.date(byAdding: .month, value: 60, to: start) ?? start) ?? start
        let startJaar = cal.component(.year, from: start)

        if elektrisch, let tarief = nulEmissie[startJaar] {
            let laag: Double
            if let cap = tarief.cap, catalogusprijs > cap {
                laag = cap * tarief.pct + (catalogusprijs - cap) * standaard
            } else {
                laag = catalogusprijs * tarief.pct
            }
            let capTekst = tarief.cap.map { " over de eerste \(Fmt.euro($0)) en 22% daarboven" } ?? ""
            return Resultaat(soort: .normaal,
                             effectiefPercentage: catalogusprijs > 0 ? laag / catalogusprijs : tarief.pct,
                             laagPercentage: tarief.pct, cap: tarief.cap,
                             perJaar: laag,
                             periodeStart: start, periodeEinde: einde,
                             toelichting: "Volledig elektrisch, periode gestart in \(startJaar): \(Int((tarief.pct * 100).rounded()))%\(capTekst).")
        }

        let toelichting = elektrisch
            ? "Volledig elektrisch, maar voor \(startJaar) staat geen verlaagd tarief in de app; gerekend met 22%."
            : "Standaardtarief van 22% van de catalogusprijs."
        return Resultaat(soort: .normaal,
                         effectiefPercentage: standaard,
                         laagPercentage: nil, cap: nil,
                         perJaar: catalogusprijs * standaard,
                         periodeStart: start, periodeEinde: einde,
                         toelichting: toelichting)
    }
}
