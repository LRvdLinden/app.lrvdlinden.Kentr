import SwiftUI
import SwiftData

/// Tab "Terugvinden".
struct FindPlateView: View {
    var body: some View {
        NavigationStack {
            FindPlateForm(criteria: PlateSearchCriteria(), linkTo: nil)
        }
    }
}

/// Zoekformulier om een vergeten kenteken terug te vinden in de RDW-gegevens.
struct FindPlateForm: View {
    @State var criteria: PlateSearchCriteria
    var linkTo: Car?

    @State private var results: [RDWVehicle] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var searched = false
    @State private var resultTrigger = 0

    private let years = Array((1950...Calendar.current.component(.year, from: .now)).reversed())

    private var brandSuggestions: [String] {
        let q = criteria.merk.trimmingCharacters(in: .whitespaces).uppercased()
        guard !q.isEmpty, !RDWBrands.all.contains(q) else { return [] }
        return Array(RDWBrands.all.filter { $0.hasPrefix(q) || $0.contains(q) }.prefix(5))
    }

    var body: some View {
        Form {
            Section {
                Label {
                    Text("De RDW publiceert geen eigenaren. Kentr toont auto's die passen bij je omschrijving, zodat je je eigen kenteken kunt herkennen. Gesloopte of geëxporteerde auto's staan er soms niet meer in.")
                } icon: {
                    Image(systemName: "info.circle").foregroundStyle(Theme.accent)
                }
                .font(.footnote)
            }

            Section("Auto") {
                TextField("Merk (bv. Volkswagen)", text: $criteria.merk)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                ForEach(brandSuggestions, id: \.self) { brand in
                    Button {
                        criteria.merk = brand
                    } label: {
                        Label(brand.capitalizedBrand, systemImage: "arrow.up.left")
                    }
                }
                TextField("Model (bv. Golf, Clio, 206)", text: $criteria.model)
                    .autocorrectionDisabled()
                Picker("Kleur", selection: $criteria.kleur) {
                    Text("Alle kleuren").tag("")
                    ForEach(RDWBrands.colors, id: \.self) { kleur in
                        Text(verbatim: kleur.capitalizedBrand).tag(kleur)
                    }
                }
            }

            Section {
                Picker("Van", selection: $criteria.vanJaar) {
                    ForEach(years, id: \.self) { Text(verbatim: String($0)).tag($0) }
                }
                Picker("Tot en met", selection: $criteria.totJaar) {
                    ForEach(years, id: \.self) { Text(verbatim: String($0)).tag($0) }
                }
            } header: {
                Text("Bouwjaar (eerste toelating)")
            } footer: {
                Text("Hoe kleiner de periode, hoe korter de lijst.")
            }

            Section {
                Button {
                    Task { await search() }
                } label: {
                    HStack {
                        Spacer()
                        if loading { ProgressView() } else { Label("Zoek kentekens", systemImage: "magnifyingglass") }
                        Spacer()
                    }
                }
                .disabled(!criteria.isUsable || loading)
            }

            if let errorText {
                Section {
                    Label(errorText, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Button("Opnieuw proberen") { Task { await search() } }
                }
            }

            if searched && errorText == nil {
                if results.isEmpty {
                    Section {
                        ContentUnavailableView("Geen auto's gevonden",
                                               systemImage: "car.side",
                                               description: Text("Probeer een ander model, een andere kleur of een ruimere periode."))
                    }
                } else {
                    Section {
                        ForEach(results) { vehicle in
                            NavigationLink {
                                FindResultDetail(vehicle: vehicle, linkTo: linkTo)
                            } label: {
                                ResultRow(vehicle: vehicle)
                            }
                        }
                    } header: {
                        Text(results.count >= RDWClient.searchLimit
                             ? "Eerste \(String(RDWClient.searchLimit)) resultaten"
                             : "\(String(results.count)) resultaten")
                    } footer: {
                        if results.count >= RDWClient.searchLimit {
                            Text("Er zijn meer auto's. Maak de zoekopdracht specifieker met model, kleur of een kortere periode.")
                        }
                    }
                }
            }
        }
        .navigationTitle(linkTo == nil ? "Terugvinden" : "Kenteken zoeken")
        .sensoryFeedback(.success, trigger: resultTrigger)
    }

    private func search() async {
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            results = try await RDWClient.shared.search(criteria)
            searched = true
            resultTrigger += 1
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct ResultRow: View {
    let vehicle: RDWVehicle

    var body: some View {
        HStack(spacing: 12) {
            KentekenPlateView(kenteken: vehicle.kenteken, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: vehicle.handelsbenaming.isEmpty ? vehicle.merk : vehicle.handelsbenaming)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(verbatim: [vehicle.kleur, vehicle.datumEersteToelating.map(Fmt.date)]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// Details van een zoekresultaat, met de knop om hem als eigen auto te koppelen.
struct FindResultDetail: View {
    let vehicle: RDWVehicle
    var linkTo: Car?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var full: RDWVehicle?
    @State private var addDraft: IdentifiedDraft?
    @State private var linked = false
    @State private var linkTrigger = 0

    private var shown: RDWVehicle { full ?? vehicle }

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    VehiclePhotoView(merk: shown.merk, model: shown.handelsbenaming, bouwjaar: shown.bouwjaar)
                    VehicleHeader(kenteken: shown.kenteken, title: shown.displayName,
                                  subtitle: shown.bouwjaar.map { "Bouwjaar \($0)" })
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                if let linkTo {
                    Button {
                        var draft = CarDraft(car: linkTo)
                        draft.apply(shown)
                        draft.write(to: linkTo)
                        try? context.save()
                        linked = true
                        linkTrigger += 1
                    } label: {
                        Label("Dit is mijn auto – koppel dit kenteken", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(linked)
                } else {
                    Button {
                        addDraft = IdentifiedDraft(draft: CarDraft(vehicle: shown))
                    } label: {
                        Label("Dit was mijn auto – toevoegen", systemImage: "plus.circle.fill")
                    }
                }
            }
            RDWVehicleSections(vehicle: shown)
        }
        .navigationTitle(Kenteken.format(shown.kenteken))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if full == nil { full = try? await RDWClient.shared.vehicle(kenteken: vehicle.kenteken) }
        }
        .sheet(item: $addDraft) { item in
            CarEditorView(car: nil, draft: item.draft)
        }
        .alert("Kenteken gekoppeld", isPresented: $linked) {
            Button("Klaar") { dismiss() }
        } message: {
            Text("\(Kenteken.format(shown.kenteken)) staat nu bij je auto, met de gegevens van de RDW.")
        }
        .sensoryFeedback(.success, trigger: linkTrigger)
    }
}
