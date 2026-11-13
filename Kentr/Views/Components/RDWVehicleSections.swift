import SwiftUI

/// Secties met RDW-gegevens: voertuig, fiscaal, bijtelling en status. Voor gebruik in een List/Form.
struct RDWVehicleSections: View {
    let vehicle: RDWVehicle

    var body: some View {
        Group {
            vehicleSection
            fiscalSection
            BijtellingSection(vehicle: vehicle)
            statusSection
        }
    }

    // MARK: Voertuig

    private var vehicleSection: some View {
        Section("Voertuig") {
            row("Merk", vehicle.merk)
            row("Model", vehicle.handelsbenaming)
            row("Voertuigsoort", vehicle.voertuigsoort)
            row("Carrosserie", vehicle.inrichting)
            row("Kleur", vehicle.kleur)
            row("Bouwjaar", vehicle.bouwjaar.map { String($0) })
            row("Brandstof", vehicle.brandstofTekst)
            row("Vermogen", vehicle.vermogenTekst)
            row("Cilinderinhoud", vehicle.cilinderinhoud.map { "\(Fmt.number($0)) cc" })
            row("Massa rijklaar", vehicle.massaRijklaar.map { "\(Fmt.number($0)) kg" })
            row("Zitplaatsen", vehicle.zitplaatsen.map { String($0) })
            row("Deuren", vehicle.deuren.map { String($0) })
            row("Verbruik (gecombineerd)", vehicle.verbruik.map { "\(Fmt.number($0)) l/100 km" })
        }
    }

    // MARK: Fiscaal

    private var fiscalSection: some View {
        Section {
            row("Catalogusprijs", vehicle.catalogusprijs.map(Fmt.euro), fallback: "Niet bekend bij RDW")
            row("Bruto BPM", vehicle.brutoBPM.map(Fmt.euro), fallback: "Niet bekend bij RDW")
            row("Eerste toelating", vehicle.datumEersteToelating.map(Fmt.date))
            row("Eerste toelating in NL", vehicle.datumEersteToelatingNL.map(Fmt.date))
            if vehicle.isImport {
                Label("Geïmporteerd: eerste toelating was in het buitenland", systemImage: "airplane.arrival")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            row("Laatste tenaamstelling", vehicle.datumTenaamstelling.map(Fmt.date))
            row("CO2-uitstoot", vehicle.co2.map { "\(Fmt.number($0)) g/km" })
        } header: {
            Text("Fiscaal")
        } footer: {
            Text("De catalogusprijs is de fiscale waarde: de basis voor de bijtelling. Gegevens van de RDW, geen fiscaal advies.")
        }
    }

    // MARK: Status

    private var statusSection: some View {
        Section("Status") {
            row("APK geldig tot", vehicle.vervaldatumAPK.map(Fmt.date))
            if let oordeel = vehicle.tellerstandoordeel {
                LabeledContent("Kilometerstand") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: oordeel)
                        if let jaar = vehicle.jaarLaatsteTellerstand {
                            Text("Laatst geregistreerd in \(jaar)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            row("WAM-verzekerd", vehicle.wamVerzekerd)
            if vehicle.terugroepactieOpen {
                Label("Er staat een terugroepactie open", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if vehicle.terugroepactieTekst != nil {
                row("Open terugroepactie", "Nee")
            }
            if vehicle.geexporteerd {
                Label("Deze auto is geëxporteerd", systemImage: "arrow.up.forward.square")
                    .foregroundStyle(.secondary)
            }
            if vehicle.taxi { row("Taxi", "Ja") }
        }
    }

    @ViewBuilder
    private func row(_ title: LocalizedStringKey, _ value: String?, fallback: String? = nil) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(title) { Text(verbatim: value) }
        } else if let fallback {
            LabeledContent(title) { Text(verbatim: fallback).foregroundStyle(.secondary) }
        }
    }
}

/// Indicatie van de bijtelling als auto van de zaak.
struct BijtellingSection: View {
    let vehicle: RDWVehicle
    @State private var dagwaarde: Double?

    var body: some View {
        if let prijs = vehicle.catalogusprijs, let det = vehicle.datumEersteToelating {
            let r = Bijtelling.bereken(catalogusprijs: prijs, eersteToelating: det,
                                       elektrisch: vehicle.isElectric, dagwaarde: dagwaarde)
            Section {
                if r.soort == .youngtimer {
                    LabeledContent("Percentage") { Text(verbatim: "35% van de dagwaarde") }
                    TextField("Dagwaarde (€)", value: $dagwaarde, format: .number.precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                    if (dagwaarde ?? 0) > 0 {
                        amounts(r)
                    }
                } else {
                    LabeledContent("Percentage") { Text(verbatim: percent(r.effectiefPercentage)) }
                    amounts(r)
                    LabeledContent("Tarief vast t/m") { Text(verbatim: Fmt.date(r.periodeEinde)) }
                }
                Text(verbatim: r.toelichting)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Bijtelling (indicatie)")
            } footer: {
                Text("Als auto van de zaak met meer dan 500 km privé per jaar. Bruto bedrag dat bij je inkomen wordt opgeteld; wat je netto betaalt hangt af van je belastingschijf. Tarieven t/m \(String(Bijtelling.tarievenTotEnMet)). Geen fiscaal advies.")
            }
        }
    }

    @ViewBuilder
    private func amounts(_ r: Bijtelling.Resultaat) -> some View {
        LabeledContent("Per maand") { Text(verbatim: Fmt.euro(r.perMaand)).fontWeight(.semibold) }
        LabeledContent("Per jaar") { Text(verbatim: Fmt.euro(r.perJaar)) }
    }

    private func percent(_ value: Double) -> String {
        let p = value * 100
        return p.rounded() == p ? "\(Int(p))%" : String(format: "%.1f%%", p).replacingOccurrences(of: ".", with: ",")
    }
}

/// Kopblok met kentekenplaat en naam.
struct VehicleHeader: View {
    let kenteken: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 10) {
            if Kenteken.isValid(kenteken) {
                KentekenPlateView(kenteken: kenteken, height: 46)
            } else {
                UnknownPlateBadge(height: 40)
            }
            Text(verbatim: title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(verbatim: subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
