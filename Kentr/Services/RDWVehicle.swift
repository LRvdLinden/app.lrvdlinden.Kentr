import Foundation

/// Waarde uit de RDW-API; RDW levert bijna alles als tekst, maar we accepteren ook getallen en booleans.
struct FlexibleString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let i = try? c.decode(Int.self) { value = String(i) }
        else if let d = try? c.decode(Double.self) { value = String(d) }
        else if let b = try? c.decode(Bool.self) { value = b ? "Ja" : "Nee" }
        else { value = "" }
    }
}

/// Voertuiggegevens van de RDW (Open Data), plus de brandstofregels.
struct RDWVehicle: Codable, Hashable, Identifiable {
    /// Velden uit "Gekentekende voertuigen" (m9d7-ebf2).
    var main: [String: String]
    /// Regels uit "Gekentekende voertuigen brandstof" (8ys7-d773); één per brandstof.
    var fuels: [[String: String]]

    var id: String { kenteken }

    init(main: [String: String], fuels: [[String: String]] = []) {
        self.main = main
        self.fuels = fuels
    }

    // MARK: - Hulpfuncties

    func text(_ key: String) -> String? {
        guard let v = main[key]?.trimmingCharacters(in: .whitespaces), !v.isEmpty else { return nil }
        return v
    }

    func number(_ key: String) -> Double? {
        guard let v = text(key) else { return nil }
        return Double(v.replacingOccurrences(of: ",", with: "."))
    }

    private func fuelNumber(_ keys: [String]) -> Double? {
        for row in fuels {
            for key in keys {
                if let v = row[key], let d = Double(v.replacingOccurrences(of: ",", with: ".")) { return d }
            }
        }
        return nil
    }

    // MARK: - Basis

    var kenteken: String { text("kenteken") ?? "" }
    var merk: String { text("merk")?.capitalizedBrand ?? "" }
    var handelsbenaming: String {
        // RDW zet het merk soms voor de typenaam ("VOLKSWAGEN GOLF").
        guard var name = text("handelsbenaming") else { return "" }
        if let brand = text("merk"), name.uppercased().hasPrefix(brand.uppercased() + " ") {
            name = String(name.dropFirst(brand.count + 1))
        }
        return name.capitalizedBrand
    }
    var displayName: String { [merk, handelsbenaming].filter { !$0.isEmpty }.joined(separator: " ") }
    var voertuigsoort: String? { text("voertuigsoort") }
    var inrichting: String? { text("inrichting")?.capitalizedBrand }
    var kleur: String? {
        guard let first = text("eerste_kleur"), first != "N.v.t." else { return nil }
        if let second = text("tweede_kleur"), second != "Niet geregistreerd", second != "N.v.t." {
            return "\(first.capitalizedBrand) / \(second.capitalizedBrand)"
        }
        return first.capitalizedBrand
    }
    var eersteKleurRaw: String? { text("eerste_kleur") }

    // MARK: - Datums

    var datumEersteToelating: Date? { Fmt.rdwDate(text("datum_eerste_toelating") ?? text("datum_eerste_toelating_dt")) }
    var datumEersteToelatingNL: Date? {
        Fmt.rdwDate(text("datum_eerste_tenaamstelling_in_nederland") ?? text("datum_eerste_tenaamstelling_in_nederland_dt"))
    }
    var datumTenaamstelling: Date? { Fmt.rdwDate(text("datum_tenaamstelling") ?? text("datum_tenaamstelling_dt")) }
    var vervaldatumAPK: Date? { Fmt.rdwDate(text("vervaldatum_apk") ?? text("vervaldatum_apk_dt")) }
    var bouwjaar: Int? { datumEersteToelating.map { Calendar.current.component(.year, from: $0) } }

    /// Eerste toelating in het buitenland en later in Nederland (import).
    var isImport: Bool {
        guard let a = datumEersteToelating, let b = datumEersteToelatingNL else { return false }
        return Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0 > 31
    }

    // MARK: - Fiscaal

    var catalogusprijs: Double? { number("catalogusprijs").flatMap { $0 > 0 ? $0 : nil } }
    var brutoBPM: Double? { number("bruto_bpm").flatMap { $0 > 0 ? $0 : nil } }

    var brandstoffen: [String] {
        fuels.compactMap { $0["brandstof_omschrijving"]?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    var brandstofTekst: String? {
        let list = brandstoffen
        return list.isEmpty ? nil : list.joined(separator: " + ")
    }
    /// Volledig elektrisch (geen andere brandstof).
    var isElectric: Bool {
        let list = brandstoffen.map { $0.lowercased() }
        return !list.isEmpty && list.allSatisfy { $0 == "elektriciteit" }
    }
    var co2: Double? {
        fuelNumber(["co2_uitstoot_gecombineerd", "emissie_co2_gecombineerd_wltp", "co2_uitstoot_gewogen"])
    }

    // MARK: - Techniek

    var vermogenKW: Double? { fuelNumber(["nettomaximumvermogen", "netto_max_vermogen_elektrisch"]) }
    var vermogenTekst: String? {
        guard let kw = vermogenKW, kw > 0 else { return nil }
        return "\(Fmt.number(kw)) kW (\(Int((kw * 1.35962).rounded())) pk)"
    }
    var cilinderinhoud: Double? { number("cilinderinhoud").flatMap { $0 > 0 ? $0 : nil } }
    var massaRijklaar: Double? { number("massa_rijklaar").flatMap { $0 > 0 ? $0 : nil } }
    var zitplaatsen: Int? { number("aantal_zitplaatsen").map { Int($0) } }
    var deuren: Int? { number("aantal_deuren").flatMap { $0 > 0 ? Int($0) : nil } }
    var verbruik: Double? { fuelNumber(["brandstofverbruik_gecombineerd"]) }

    // MARK: - Status

    var tellerstandoordeel: String? { text("tellerstandoordeel") }
    var jaarLaatsteTellerstand: String? { text("jaar_laatste_registratie_tellerstand") }
    var wamVerzekerd: String? { text("wam_verzekerd") }
    var terugroepactieOpen: Bool { text("openstaande_terugroepactie_indicator")?.lowercased() == "ja" }
    var terugroepactieTekst: String? { text("openstaande_terugroepactie_indicator") }
    var geexporteerd: Bool { text("export_indicator")?.lowercased() == "ja" }
    var taxi: Bool { text("taxi_indicator")?.lowercased() == "ja" }
}

extension String {
    /// "VOLKSWAGEN" → "Volkswagen", maar korte afkortingen ("BMW", "GTI") blijven hoofdletters.
    var capitalizedBrand: String {
        split(separator: " ").map { word -> String in
            let w = String(word)
            if w.count <= 3, w.allSatisfy({ $0.isLetter }) { return w.uppercased() }
            if w.contains(where: \.isNumber) { return w.uppercased() }
            return w.split(separator: "-", omittingEmptySubsequences: false)
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: "-")
        }.joined(separator: " ")
    }
}
