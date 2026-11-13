import SwiftUI
import SwiftData
import PhotosUI

struct CarEditorView: View {
    let car: Car?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var draft: CarDraft
    @State private var loading = false
    @State private var errorText: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var fetchedTrigger = 0
    @State private var savedTrigger = 0

    private let years = Array((1950...Calendar.current.component(.year, from: .now)).reversed())
    private let acquisitionOptions = ["Nieuw gekocht", "Tweedehands gekocht", "Private lease",
                                      "Auto van de zaak", "Gekregen of geërfd", "Anders"]

    init(car: Car?, draft: CarDraft? = nil) {
        self.car = car
        _draft = State(initialValue: draft ?? car.map(CarDraft.init(car:)) ?? CarDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                plateSection
                carSection
                periodSection
                detailsSection
                photoSection
                Section("Notities") {
                    TextField("Bijvoorbeeld: eerste auto, gekocht van oom Jan", text: $draft.notities, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(car == nil ? "Auto toevoegen" : "Auto bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") { save() }
                        .disabled(!draft.isValid)
                }
            }
            .sensoryFeedback(.success, trigger: fetchedTrigger)
            .sensoryFeedback(.success, trigger: savedTrigger)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        draft.foto = ImageTools.downscaled(data)
                    }
                }
            }
        }
    }

    // MARK: Secties

    private var plateSection: some View {
        Section {
            HStack {
                TextField("Kenteken", text: $draft.kenteken)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .onSubmit { Task { await fetchRDW() } }
                if loading {
                    ProgressView()
                } else {
                    Button("Ophalen") { Task { await fetchRDW() } }
                        .buttonStyle(.bordered)
                        .disabled(!Kenteken.isValid(draft.kenteken))
                }
            }
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if let rdw = draft.rdw, Kenteken.normalize(rdw.kenteken) == Kenteken.normalize(draft.kenteken) {
                Label("Gegevens opgehaald bij de RDW", systemImage: "checkmark.seal.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        } header: {
            Text("Kenteken")
        } footer: {
            Text("Weet je het kenteken niet meer? Laat het leeg en vul hieronder merk, model en bouwjaar in. Via Terugvinden kun je het later zoeken.")
        }
    }

    private var carSection: some View {
        Section("Auto") {
            TextField("Merk", text: $draft.merk)
            TextField("Model", text: $draft.model)
            Picker("Bouwjaar", selection: $draft.bouwjaar) {
                Text("Onbekend").tag(Int?.none)
                ForEach(years, id: \.self) { year in
                    Text(verbatim: String(year)).tag(Int?.some(year))
                }
            }
            TextField("Kleur", text: $draft.kleur)
            TextField("Brandstof", text: $draft.brandstof)
        }
    }

    private var periodSection: some View {
        Section {
            Toggle("Heb ik nu nog", isOn: $draft.huidigeAuto)
            Toggle("Alleen jaartallen", isOn: $draft.alleenJaren)

            Toggle("Begin bekend", isOn: $draft.heeftVanaf)
            if draft.heeftVanaf {
                datePicker("In bezit vanaf", date: $draft.vanaf)
            }
            if !draft.huidigeAuto {
                Toggle("Einde bekend", isOn: $draft.heeftTot)
                if draft.heeftTot {
                    datePicker("In bezit tot", date: $draft.tot)
                }
            }
        } header: {
            Text("Periode")
        } footer: {
            Text("Weet je de precieze datum niet meer? Zet \"Alleen jaartallen\" aan.")
        }
    }

    @ViewBuilder
    private func datePicker(_ title: LocalizedStringKey, date: Binding<Date>) -> some View {
        if draft.alleenJaren {
            Picker(title, selection: yearBinding(date)) {
                ForEach(years, id: \.self) { Text(verbatim: String($0)).tag($0) }
            }
        } else {
            DatePicker(title, selection: date, in: ...Date.now, displayedComponents: .date)
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            Picker("Hoe gekregen", selection: $draft.hoeGekregen) {
                Text("Onbekend").tag("")
                ForEach(acquisitionOptions, id: \.self) { Text($0).tag($0) }
            }
            TextField("Aankoopprijs (€)", value: $draft.aankoopprijs, format: .number.precision(.fractionLength(0)))
                .keyboardType(.numberPad)
            if !draft.huidigeAuto {
                TextField("Verkoopprijs (€)", value: $draft.verkoopprijs, format: .number.precision(.fractionLength(0)))
                    .keyboardType(.numberPad)
            }
            TextField("Kilometerstand bij aankoop", value: $draft.kmInkoop, format: .number)
                .keyboardType(.numberPad)
            if !draft.huidigeAuto {
                TextField("Kilometerstand bij verkoop", value: $draft.kmVerkoop, format: .number)
                    .keyboardType(.numberPad)
            }
        }
    }

    private var photoSection: some View {
        Section("Foto") {
            if let data = draft.foto, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                Button("Foto verwijderen", role: .destructive) {
                    draft.foto = nil
                    photoItem = nil
                }
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(draft.foto == nil ? "Foto kiezen" : "Andere foto kiezen", systemImage: "photo")
            }
        }
    }

    // MARK: Acties

    private func yearBinding(_ date: Binding<Date>) -> Binding<Int> {
        Binding(
            get: { Calendar.current.component(.year, from: date.wrappedValue) },
            set: { year in
                date.wrappedValue = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))
                    ?? date.wrappedValue
            }
        )
    }

    private func fetchRDW() async {
        guard Kenteken.isValid(draft.kenteken) else { return }
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            let vehicle = try await RDWClient.shared.vehicle(kenteken: draft.kenteken)
            draft.apply(vehicle)
            fetchedTrigger += 1
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func save() {
        if let car {
            draft.write(to: car)
        } else {
            let newCar = Car()
            draft.write(to: newCar)
            context.insert(newCar)
        }
        try? context.save()
        savedTrigger += 1
        dismiss()
    }
}
