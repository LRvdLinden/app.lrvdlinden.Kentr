import Foundation
import SwiftData

/// Een auto die je hebt (gehad). Alle velden hebben een standaardwaarde of zijn optioneel (eis van CloudKit).
@Model
final class Car {
    var id: UUID = UUID()
    var kenteken: String = ""
    var merk: String = ""
    var model: String = ""
    var bouwjaar: Int?
    var kleur: String = ""
    var brandstof: String = ""

    var vanaf: Date?
    var tot: Date?
    /// Alleen het jaartal tonen (datum niet precies bekend).
    var alleenJaren: Bool = false
    var huidigeAuto: Bool = false

    var hoeGekregen: String = ""
    var aankoopprijs: Double?
    var verkoopprijs: Double?
    var kmInkoop: Int?
    var kmVerkoop: Int?
    var notities: String = ""

    @Attribute(.externalStorage) var foto: Data?

    /// Laatst opgehaalde RDW-gegevens (JSON van RDWVehicle).
    var rdwData: Data?
    var rdwOpgehaald: Date?

    var aangemaakt: Date = Date()

    init() {}
}

extension Car {
    var heeftKenteken: Bool { Kenteken.isValid(kenteken) }

    var titel: String {
        let name = [merk, model].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "Onbekende auto" : name
    }

    var rdw: RDWVehicle? {
        guard let rdwData else { return nil }
        return try? JSONDecoder().decode(RDWVehicle.self, from: rdwData)
    }

    func setRDW(_ vehicle: RDWVehicle) {
        rdwData = try? JSONEncoder().encode(vehicle)
        rdwOpgehaald = .now
    }

    /// Voor sorteren op tijdlijn: begin van het bezit, anders het bouwjaar.
    var sorteerDatum: Date {
        if let vanaf { return vanaf }
        if let bouwjaar, let d = Calendar.current.date(from: DateComponents(year: bouwjaar, month: 1, day: 1)) {
            return d
        }
        return aangemaakt
    }

    var periodeTekst: String {
        func f(_ d: Date) -> String { alleenJaren ? Fmt.year(d) : Fmt.monthYear(d) }
        switch (vanaf, tot) {
        case let (a?, _) where huidigeAuto: return "Sinds \(f(a))"
        case let (a?, b?): return Fmt.year(a) == Fmt.year(b) && alleenJaren ? f(a) : "\(f(a)) – \(f(b))"
        case let (a?, nil): return "Vanaf \(f(a))"
        case let (nil, b?): return "Tot \(f(b))"
        default: return huidigeAuto ? "Nu in bezit" : "Periode onbekend"
        }
    }

    /// Hoe lang in bezit, als het begin bekend is.
    var bezitsduur: (start: Date, einde: Date)? {
        guard let vanaf else { return nil }
        let einde = huidigeAuto ? Date.now : (tot ?? Date.now)
        guard einde >= vanaf else { return nil }
        return (vanaf, einde)
    }

    var gereden: Int? {
        guard let a = kmInkoop, let b = kmVerkoop, b >= a else { return nil }
        return b - a
    }

    var deelTekst: String {
        var lines = ["🚗 \(titel)"]
        if heeftKenteken { lines.append("Kenteken: \(Kenteken.format(kenteken))") }
        if let bouwjaar { lines.append("Bouwjaar: \(bouwjaar)") }
        lines.append("Periode: \(periodeTekst)")
        if !kleur.isEmpty { lines.append("Kleur: \(kleur)") }
        lines.append("— via Kentr")
        return lines.joined(separator: "\n")
    }
}

/// Bewerkbare kopie van een auto, zodat "Annuleer" niets verandert.
struct CarDraft {
    var kenteken = ""
    var merk = ""
    var model = ""
    var bouwjaar: Int?
    var kleur = ""
    var brandstof = ""
    var heeftVanaf = false
    var vanaf = Date()
    var heeftTot = false
    var tot = Date()
    var alleenJaren = false
    var huidigeAuto = false
    var hoeGekregen = ""
    var aankoopprijs: Double?
    var verkoopprijs: Double?
    var kmInkoop: Int?
    var kmVerkoop: Int?
    var notities = ""
    var foto: Data?
    var rdw: RDWVehicle?

    init() {}

    init(car: Car) {
        kenteken = car.kenteken.isEmpty ? "" : Kenteken.format(car.kenteken)
        merk = car.merk
        model = car.model
        bouwjaar = car.bouwjaar
        kleur = car.kleur
        brandstof = car.brandstof
        heeftVanaf = car.vanaf != nil
        vanaf = car.vanaf ?? Date()
        heeftTot = car.tot != nil
        tot = car.tot ?? Date()
        alleenJaren = car.alleenJaren
        huidigeAuto = car.huidigeAuto
        hoeGekregen = car.hoeGekregen
        aankoopprijs = car.aankoopprijs
        verkoopprijs = car.verkoopprijs
        kmInkoop = car.kmInkoop
        kmVerkoop = car.kmVerkoop
        notities = car.notities
        foto = car.foto
        rdw = car.rdw
    }

    init(vehicle: RDWVehicle) {
        self.init()
        apply(vehicle)
    }

    var isValid: Bool {
        !merk.trimmingCharacters(in: .whitespaces).isEmpty || Kenteken.isValid(kenteken)
    }

    /// Neemt de RDW-gegevens over (alleen lege velden, behalve het kenteken).
    mutating func apply(_ v: RDWVehicle) {
        rdw = v
        kenteken = Kenteken.format(v.kenteken)
        merk = v.merk.isEmpty ? merk : v.merk
        model = v.handelsbenaming.isEmpty ? model : v.handelsbenaming
        if let jaar = v.bouwjaar { bouwjaar = jaar }
        if let k = v.kleur { kleur = k }
        if let b = v.brandstofTekst { brandstof = b }
    }

    func write(to car: Car) {
        car.kenteken = Kenteken.normalize(kenteken)
        car.merk = merk.trimmingCharacters(in: .whitespaces)
        car.model = model.trimmingCharacters(in: .whitespaces)
        car.bouwjaar = bouwjaar
        car.kleur = kleur.trimmingCharacters(in: .whitespaces)
        car.brandstof = brandstof.trimmingCharacters(in: .whitespaces)
        car.vanaf = heeftVanaf ? vanaf : nil
        car.tot = (heeftTot && !huidigeAuto) ? tot : nil
        car.alleenJaren = alleenJaren
        car.huidigeAuto = huidigeAuto
        car.hoeGekregen = hoeGekregen
        car.aankoopprijs = aankoopprijs
        car.verkoopprijs = verkoopprijs
        car.kmInkoop = kmInkoop
        car.kmVerkoop = kmVerkoop
        car.notities = notities
        car.foto = foto
        if let rdw, Kenteken.normalize(rdw.kenteken) == Kenteken.normalize(kenteken) {
            car.setRDW(rdw)
        } else if !Kenteken.isValid(kenteken) {
            car.rdwData = nil
            car.rdwOpgehaald = nil
        }
    }
}
