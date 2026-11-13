import Foundation

enum RDWError: LocalizedError {
    case invalidPlate
    case notFound
    case server(Int)
    case network
    case tooBroad

    var errorDescription: String? {
        switch self {
        case .invalidPlate: return "Vul een geldig kenteken in (6 tekens)."
        case .notFound: return "Dit kenteken staat niet in de open data van de RDW. Gesloopte of geëxporteerde auto's staan er soms niet (meer) in."
        case .server(let code): return "De RDW gaf een fout (\(code)). Probeer het later opnieuw."
        case .network: return "Geen verbinding met de RDW. Controleer je internet en probeer het opnieuw."
        case .tooBroad: return "Kies minstens een merk en een model of een periode van bouwjaren."
        }
    }
}

/// Zoekopdracht om een vergeten kenteken terug te vinden.
struct PlateSearchCriteria: Hashable {
    var merk: String = ""
    var model: String = ""
    var kleur: String = ""
    var vanJaar: Int = 2000
    var totJaar: Int = 2005
    var voertuigsoort: String = "Personenauto"

    var isUsable: Bool {
        !merk.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Client voor RDW Open Data (opendata.rdw.nl, Socrata). Geen API-sleutel nodig.
struct RDWClient {
    static let shared = RDWClient()

    private let base = "https://opendata.rdw.nl/resource/"
    private let vehicles = "m9d7-ebf2.json"
    private let fuel = "8ys7-d773.json"
    static let searchLimit = 200

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.requestCachePolicy = .reloadRevalidatingCacheData
        return URLSession(configuration: config)
    }()

    // MARK: - Kenteken opzoeken

    func vehicle(kenteken: String) async throws -> RDWVehicle {
        let plate = Kenteken.normalize(kenteken)
        guard plate.count == 6 else { throw RDWError.invalidPlate }

        async let mainRows = rows(vehicles, query: [("kenteken", plate)])
        async let fuelRows = rows(fuel, query: [("kenteken", plate)])

        let main = try await mainRows
        guard let first = main.first else { throw RDWError.notFound }
        let fuels = (try? await fuelRows) ?? []
        return RDWVehicle(main: first, fuels: fuels)
    }

    // MARK: - Kenteken terugvinden

    func search(_ c: PlateSearchCriteria) async throws -> [RDWVehicle] {
        guard c.isUsable else { throw RDWError.tooBroad }
        let from = min(c.vanJaar, c.totJaar), to = max(c.vanJaar, c.totJaar)

        var parts: [String] = []
        parts.append("merk = '\(soql(c.merk.uppercased()))'")
        let model = c.model.trimmingCharacters(in: .whitespaces).uppercased()
        if !model.isEmpty { parts.append("upper(handelsbenaming) like '%\(soql(model))%'") }
        if !c.kleur.isEmpty { parts.append("eerste_kleur = '\(soql(c.kleur.uppercased()))'") }
        if !c.voertuigsoort.isEmpty { parts.append("voertuigsoort = '\(soql(c.voertuigsoort))'") }
        let base = parts.joined(separator: " AND ")

        // De datumkolom bestaat als datumveld (_dt) en als getal/tekst (yyyymmdd);
        // probeer de varianten tot er één werkt.
        let dateFilters = [
            ("datum_eerste_toelating_dt between '\(from)-01-01T00:00:00.000' and '\(to)-12-31T23:59:59.999'", "datum_eerste_toelating_dt"),
            ("datum_eerste_toelating between \(from)0101 and \(to)1231", "datum_eerste_toelating"),
            ("datum_eerste_toelating between '\(from)0101' and '\(to)1231'", "datum_eerste_toelating"),
        ]

        var lastError: Error = RDWError.server(400)
        for (filter, orderField) in dateFilters {
            do {
                let result = try await rows(vehicles, query: [
                    ("$where", "\(base) AND \(filter)"),
                    ("$order", orderField),
                    ("$limit", String(Self.searchLimit)),
                ])
                return result.map { RDWVehicle(main: $0) }
            } catch RDWError.server(let code) where code == 400 {
                lastError = RDWError.server(code)
                continue
            }
        }
        throw lastError
    }

    // MARK: - Netwerk

    private func rows(_ dataset: String, query: [(String, String)]) async throws -> [[String: String]] {
        guard let url = makeURL(dataset, query: query) else { throw RDWError.network }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RDWError.network
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RDWError.server(http.statusCode)
        }
        let decoded = try JSONDecoder().decode([[String: FlexibleString]].self, from: data)
        return decoded.map { $0.mapValues(\.value) }
    }

    private func makeURL(_ dataset: String, query: [(String, String)]) -> URL? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = query.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
        return URL(string: base + dataset + "?" + encoded)
    }

    /// Enkele aanhalingstekens verdubbelen voor SoQL.
    private func soql(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "'", with: "''")
    }
}

/// Merken zoals de RDW ze schrijft, voor suggesties.
enum RDWBrands {
    static let all: [String] = [
        "ALFA ROMEO", "AUDI", "BMW", "BYD", "CHEVROLET", "CHRYSLER", "CITROEN", "CUPRA", "DACIA",
        "DAEWOO", "DAIHATSU", "DS", "FIAT", "FORD", "HONDA", "HYUNDAI", "JAGUAR", "JEEP", "KIA",
        "LAND ROVER", "LANCIA", "LEXUS", "LYNK & CO", "MAZDA", "MERCEDES-BENZ", "MG", "MINI",
        "MITSUBISHI", "NISSAN", "OPEL", "PEUGEOT", "POLESTAR", "PORSCHE", "RENAULT", "ROVER",
        "SAAB", "SEAT", "SKODA", "SMART", "SUBARU", "SUZUKI", "TESLA", "TOYOTA", "VOLKSWAGEN", "VOLVO",
    ]

    static let colors: [String] = [
        "ZWART", "GRIJS", "WIT", "BLAUW", "ROOD", "GROEN", "GEEL", "ORANJE",
        "BRUIN", "BEIGE", "CREME", "PAARS", "ROSE", "DIVERSEN",
    ]
}
