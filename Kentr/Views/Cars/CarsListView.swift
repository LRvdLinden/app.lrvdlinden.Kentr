import SwiftUI
import SwiftData

struct CarsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Car.aangemaakt, order: .reverse) private var cars: [Car]
    @State private var search = ""
    @State private var showAdd = false
    @State private var deleteTrigger = 0

    private var filtered: [Car] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let plateQuery = Kenteken.normalize(search)
        return cars
            .filter { car in
                guard !q.isEmpty else { return true }
                return car.titel.lowercased().contains(q)
                    || car.kleur.lowercased().contains(q)
                    || (!plateQuery.isEmpty && car.kenteken.contains(plateQuery))
                    || (car.bouwjaar.map { String($0).contains(q) } ?? false)
            }
            .sorted { $0.sorteerDatum > $1.sorteerDatum }
    }

    private var current: [Car] { filtered.filter(\.huidigeAuto) }
    private var earlier: [Car] { filtered.filter { !$0.huidigeAuto } }

    var body: some View {
        NavigationStack {
            Group {
                if cars.isEmpty {
                    ContentUnavailableView {
                        Label("Nog geen auto's", systemImage: "car.2")
                    } description: {
                        Text("Voeg de auto's toe die je hebt gehad, met of zonder kenteken. Een vergeten kenteken kun je later terugvinden.")
                    } actions: {
                        Button("Auto toevoegen") { showAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    List {
                        if !current.isEmpty {
                            Section("Nu in bezit") {
                                ForEach(current) { car in
                                    NavigationLink(value: car) { CarRow(car: car) }
                                }
                                .onDelete { delete(current, at: $0) }
                            }
                        }
                        if !earlier.isEmpty {
                            Section(current.isEmpty ? "Mijn auto's" : "Eerder") {
                                ForEach(earlier) { car in
                                    NavigationLink(value: car) { CarRow(car: car) }
                                }
                                .onDelete { delete(earlier, at: $0) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mijn auto's")
            .navigationDestination(for: Car.self) { CarDetailView(car: $0) }
            .searchable(text: $search, prompt: "Merk, model, kenteken of jaar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: {
                        Label("Auto toevoegen", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) { CarEditorView(car: nil) }
            .sensoryFeedback(.warning, trigger: deleteTrigger)
        }
    }

    private func delete(_ list: [Car], at offsets: IndexSet) {
        for index in offsets { context.delete(list[index]) }
        try? context.save()
        deleteTrigger += 1
    }
}

struct CarRow: View {
    let car: Car

    var body: some View {
        HStack(spacing: 14) {
            CarThumbnail(car: car, size: 56)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: car.titel)
                    .font(.headline)
                    .lineLimit(1)
                if car.heeftKenteken {
                    KentekenPlateView(kenteken: car.kenteken, height: 22)
                } else {
                    UnknownPlateBadge(height: 22)
                }
                Text(verbatim: car.periodeTekst)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct CarThumbnail: View {
    let car: Car
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let data = car.foto, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Theme.navy, Theme.navyDeep], startPoint: .top, endPoint: .bottom)
                    Image(systemName: car.brandstof.lowercased().contains("elektr") ? "bolt.car.fill" : "car.side.fill")
                        .font(.system(size: size * 0.42))
                        .foregroundStyle(Theme.plateYellow)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}
