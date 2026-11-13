import SwiftUI
import SwiftData

struct CarDetailView: View {
    let car: Car

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var loading = false
    @State private var errorText: String?
    @State private var refreshedTrigger = 0

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    if let data = car.foto, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    VehicleHeader(kenteken: car.kenteken, title: car.titel, subtitle: car.periodeTekst)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            mySection

            if !car.notities.isEmpty {
                Section("Notities") { Text(verbatim: car.notities) }
            }

            if !car.heeftKenteken {
                Section {
                    NavigationLink {
                        FindPlateForm(criteria: criteriaFromCar, linkTo: car)
                    } label: {
                        Label("Kenteken terugvinden", systemImage: "magnifyingglass")
                    }
                } footer: {
                    Text("Zoek in de RDW-gegevens op merk, model, kleur en bouwjaar en herken je oude kenteken.")
                }
            }

            if let vehicle = car.rdw {
                RDWVehicleSections(vehicle: vehicle)
                if let date = car.rdwOpgehaald {
                    Section {
                        Button {
                            Task { await refresh() }
                        } label: {
                            Label("RDW-gegevens vernieuwen", systemImage: "arrow.clockwise")
                        }
                        .disabled(loading)
                    } footer: {
                        Text("Opgehaald op \(Fmt.date(date)). Bron: RDW Open Data.")
                    }
                }
            } else if car.heeftKenteken {
                Section {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if loading { ProgressView() } else {
                            Label("RDW-gegevens ophalen", systemImage: "arrow.down.circle")
                        }
                    }
                    if let errorText {
                        Text(verbatim: errorText).font(.footnote).foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle(car.titel)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { if car.heeftKenteken { await refresh() } }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShareLink(item: car.deelTekst) {
                    Label("Deel", systemImage: "square.and.arrow.up")
                }
                Menu {
                    Button { showEdit = true } label: { Label("Bewerk", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Verwijder", systemImage: "trash")
                    }
                } label: {
                    Label("Meer", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) { CarEditorView(car: car) }
        .confirmationDialog("Deze auto verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Verwijder", role: .destructive) {
                context.delete(car)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("De auto verdwijnt van al je apparaten.")
        }
        .sensoryFeedback(.success, trigger: refreshedTrigger)
    }

    @ViewBuilder
    private var mySection: some View {
        Section("Mijn gegevens") {
            LabeledContent("Periode") { Text(verbatim: car.periodeTekst) }
            if let duur = car.bezitsduur {
                LabeledContent("In bezit") { Text(verbatim: Fmt.duration(from: duur.start, to: duur.einde)) }
            }
            if let jaar = car.bouwjaar { LabeledContent("Bouwjaar") { Text(verbatim: String(jaar)) } }
            if !car.kleur.isEmpty { LabeledContent("Kleur") { Text(verbatim: car.kleur) } }
            if !car.brandstof.isEmpty { LabeledContent("Brandstof") { Text(verbatim: car.brandstof) } }
            if !car.hoeGekregen.isEmpty { LabeledContent("Hoe gekregen") { Text(verbatim: car.hoeGekregen) } }
            if let p = car.aankoopprijs { LabeledContent("Aankoopprijs") { Text(verbatim: Fmt.euro(p)) } }
            if let p = car.verkoopprijs { LabeledContent("Verkoopprijs") { Text(verbatim: Fmt.euro(p)) } }
            if let km = car.kmInkoop { LabeledContent("Km bij aankoop") { Text(verbatim: Fmt.number(km)) } }
            if let km = car.kmVerkoop { LabeledContent("Km bij verkoop") { Text(verbatim: Fmt.number(km)) } }
            if let km = car.gereden { LabeledContent("Zelf gereden") { Text(verbatim: "\(Fmt.number(km)) km") } }
        }
    }

    private var criteriaFromCar: PlateSearchCriteria {
        var c = PlateSearchCriteria()
        c.merk = car.merk.uppercased()
        c.model = car.model
        if let jaar = car.bouwjaar {
            c.vanJaar = jaar
            c.totJaar = jaar
        } else if let vanaf = car.vanaf {
            let jaar = Calendar.current.component(.year, from: vanaf)
            c.vanJaar = jaar - 10
            c.totJaar = jaar
        }
        let kleur = car.kleur.uppercased()
        if RDWBrands.colors.contains(kleur) { c.kleur = kleur }
        return c
    }

    private func refresh() async {
        guard car.heeftKenteken else { return }
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            let vehicle = try await RDWClient.shared.vehicle(kenteken: car.kenteken)
            car.setRDW(vehicle)
            try? context.save()
            refreshedTrigger += 1
        } catch {
            errorText = error.localizedDescription
        }
    }
}
