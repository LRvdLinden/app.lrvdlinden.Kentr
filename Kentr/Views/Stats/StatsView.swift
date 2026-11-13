import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var cars: [Car]

    private var sorted: [Car] { cars.sorted { $0.sorteerDatum < $1.sorteerDatum } }

    private var totalOwnership: (start: Date, einde: Date)? {
        let intervals = cars.compactMap(\.bezitsduur)
        guard !intervals.isEmpty else { return nil }
        let seconds = intervals.reduce(0.0) { $0 + $1.einde.timeIntervalSince($1.start) }
        let start = Date(timeIntervalSinceReferenceDate: 0)
        return (start, start.addingTimeInterval(seconds))
    }

    private var averageOwnership: (start: Date, einde: Date)? {
        let intervals = cars.compactMap(\.bezitsduur)
        guard !intervals.isEmpty else { return nil }
        let seconds = intervals.reduce(0.0) { $0 + $1.einde.timeIntervalSince($1.start) } / Double(intervals.count)
        let start = Date(timeIntervalSinceReferenceDate: 0)
        return (start, start.addingTimeInterval(seconds))
    }

    private var longest: Car? {
        cars.filter { $0.bezitsduur != nil }.max {
            let a = $0.bezitsduur!, b = $1.bezitsduur!
            return a.einde.timeIntervalSince(a.start) < b.einde.timeIntervalSince(b.start)
        }
    }

    private func counts(_ key: (Car) -> String) -> [(String, Int)] {
        Dictionary(grouping: cars.map(key).filter { !$0.isEmpty }, by: { $0 })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
    }

    private var decades: [(String, Int)] {
        Dictionary(grouping: cars.compactMap { car -> Int? in
            if let v = car.vanaf { return Calendar.current.component(.year, from: v) / 10 * 10 }
            return car.bouwjaar.map { $0 / 10 * 10 }
        }, by: { $0 })
        .map { ("Jaren \(String($0.key))", $0.value.count) }
        .sorted { $0.0 < $1.0 }
    }

    private var totalKm: Int { cars.compactMap(\.gereden).reduce(0, +) }

    var body: some View {
        NavigationStack {
            Group {
                if cars.isEmpty {
                    ContentUnavailableView("Nog geen overzicht",
                                           systemImage: "chart.bar.xaxis",
                                           description: Text("Voeg je auto's toe om hier je autohistorie te zien."))
                } else {
                    List {
                        Section {
                            HStack(spacing: 12) {
                                StatTile(value: String(cars.count), label: "Auto's")
                                StatTile(value: String(Set(cars.map { $0.merk.uppercased() }.filter { !$0.isEmpty }).count), label: "Merken")
                                StatTile(value: String(cars.filter(\.huidigeAuto).count), label: "Nu in bezit")
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }

                        Section("Bezit") {
                            if let total = totalOwnership {
                                LabeledContent("Totaal") { Text(verbatim: Fmt.duration(from: total.start, to: total.einde)) }
                            }
                            if let avg = averageOwnership {
                                LabeledContent("Gemiddeld per auto") { Text(verbatim: Fmt.duration(from: avg.start, to: avg.einde)) }
                            }
                            if let car = longest, let d = car.bezitsduur {
                                LabeledContent("Langst gehouden") {
                                    VStack(alignment: .trailing) {
                                        Text(verbatim: car.titel)
                                        Text(verbatim: Fmt.duration(from: d.start, to: d.einde))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            if let first = sorted.first {
                                LabeledContent("Eerste auto") { Text(verbatim: first.titel) }
                            }
                            if totalKm > 0 {
                                LabeledContent("Zelf gereden") { Text(verbatim: "\(Fmt.number(totalKm)) km") }
                            }
                            let unknown = cars.filter { !$0.heeftKenteken }.count
                            if unknown > 0 {
                                LabeledContent("Zonder kenteken") { Text(verbatim: String(unknown)) }
                            }
                        }

                        countSection("Merken", counts { $0.merk.capitalizedBrand })
                        countSection("Brandstof", counts { $0.brandstof })
                        countSection("Per decennium", decades)
                    }
                }
            }
            .navigationTitle("Overzicht")
        }
    }

    @ViewBuilder
    private func countSection(_ title: LocalizedStringKey, _ items: [(String, Int)]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items, id: \.0) { item in
                    LabeledContent { Text(verbatim: String(item.1)) } label: { Text(verbatim: item.0) }
                }
            }
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 4) {
            Text(verbatim: value)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
