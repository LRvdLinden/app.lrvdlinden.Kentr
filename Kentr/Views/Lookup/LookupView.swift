import SwiftUI

struct LookupView: View {
    @EnvironmentObject private var router: AppRouter
    @AppStorage("lookup.recent") private var recentRaw = ""
    @State private var plate = ""
    @State private var vehicle: RDWVehicle?
    @State private var loading = false
    @State private var errorText: String?
    @State private var addDraft: IdentifiedDraft?
    @State private var foundTrigger = 0
    @FocusState private var focused: Bool

    private var recent: [String] { recentRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        TextField("XX-999-X", text: $plate)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.title2, design: .monospaced).weight(.heavy))
                            .focused($focused)
                            .submitLabel(.search)
                            .onSubmit { Task { await lookup() } }
                        if loading {
                            ProgressView()
                        } else {
                            Button {
                                Task { await lookup() }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.headline)
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!Kenteken.isValid(plate))
                            .accessibilityLabel("Opzoeken")
                        }
                    }
                } header: {
                    Text("Kenteken")
                } footer: {
                    Text("Zoek elk Nederlands kenteken op: techniek, catalogusprijs, BPM, bijtelling en APK.")
                }

                if let errorText {
                    Section {
                        ContentUnavailableView {
                            Label("Niet gevonden", systemImage: "car.side.rear.and.collision.and.car.side.front")
                        } description: {
                            Text(verbatim: errorText)
                        } actions: {
                            Button("Opnieuw proberen") { Task { await lookup() } }
                        }
                    }
                }

                if let vehicle {
                    Section {
                        VStack(spacing: 14) {
                            VehiclePhotoView(merk: vehicle.merk, model: vehicle.handelsbenaming, bouwjaar: vehicle.bouwjaar)
                            VehicleHeader(kenteken: vehicle.kenteken, title: vehicle.displayName,
                                          subtitle: vehicle.bouwjaar.map { "Bouwjaar \($0)" })
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    Section {
                        Button {
                            addDraft = IdentifiedDraft(draft: CarDraft(vehicle: vehicle))
                        } label: {
                            Label("Toevoegen aan mijn auto's", systemImage: "plus.circle.fill")
                        }
                        ShareLink(item: URL(string: "kentr://kenteken/\(vehicle.kenteken)")!,
                                  subject: Text(verbatim: vehicle.displayName),
                                  message: Text(verbatim: "\(vehicle.displayName) – \(Kenteken.format(vehicle.kenteken))")) {
                            Label("Deel", systemImage: "square.and.arrow.up")
                        }
                    }
                    RDWVehicleSections(vehicle: vehicle)
                } else if !recent.isEmpty, errorText == nil {
                    Section {
                        ForEach(recent, id: \.self) { item in
                            Button {
                                plate = Kenteken.format(item)
                                Task { await lookup() }
                            } label: {
                                KentekenPlateView(kenteken: item, height: 28)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text("Recent opgezocht")
                            Spacer()
                            Button("Wis") { recentRaw = "" }
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Opzoeken")
            .sheet(item: $addDraft) { item in
                CarEditorView(car: nil, draft: item.draft)
            }
            .sensoryFeedback(.success, trigger: foundTrigger)
            .onAppear(perform: takePending)
            .onChange(of: router.pendingLookup) { _, _ in takePending() }
        }
    }

    private func takePending() {
        guard let pending = router.pendingLookup else { return }
        router.pendingLookup = nil
        plate = Kenteken.format(pending)
        Task { await lookup() }
    }

    private func lookup() async {
        guard Kenteken.isValid(plate) else { return }
        focused = false
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            let result = try await RDWClient.shared.vehicle(kenteken: plate)
            vehicle = result
            plate = Kenteken.format(result.kenteken)
            remember(result.kenteken)
            foundTrigger += 1
        } catch {
            vehicle = nil
            errorText = error.localizedDescription
        }
    }

    private func remember(_ kenteken: String) {
        let n = Kenteken.normalize(kenteken)
        var list = recent.filter { $0 != n }
        list.insert(n, at: 0)
        recentRaw = list.prefix(8).joined(separator: ",")
    }
}

/// Maakt een CarDraft bruikbaar voor .sheet(item:).
struct IdentifiedDraft: Identifiable {
    let id = UUID()
    let draft: CarDraft
}
