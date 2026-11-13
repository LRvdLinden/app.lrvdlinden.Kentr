import Foundation
import SwiftUI

/// Voorbeeldfoto van een automodel van Wikipedia / Wikimedia Commons (vrije licentie, met bronvermelding).
struct CarPhoto: Hashable {
    let imageURL: URL
    let pageTitle: String
    let artist: String?
    let license: String?

    /// Tekst voor de bronvermelding, bv. "Wikimedia Commons · M. Jansen · CC BY-SA 4.0".
    var credit: String {
        ["Wikimedia Commons", artist, license].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

enum CarPhotoService {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = ["User-Agent": "Kentr/1.0 (https://kent.lrvdlinden.app)"]
        return URLSession(configuration: config)
    }()

    /// Zoekt een passende foto: eerst met bouwjaar (generatie), dan alleen merk + model.
    static func find(merk: String, model: String, bouwjaar: Int?) async -> CarPhoto? {
        let brand = merk.trimmingCharacters(in: .whitespaces)
        let name = model.trimmingCharacters(in: .whitespaces)
        guard !brand.isEmpty else { return nil }

        var queries: [String] = []
        if !name.isEmpty, let jaar = bouwjaar { queries.append("\(brand) \(name) \(jaar)") }
        if !name.isEmpty { queries.append("\(brand) \(name)") }
        queries.append("\(brand) auto")

        for host in ["en.wikipedia.org", "nl.wikipedia.org"] {
            for query in queries {
                if let photo = await search(host: host, query: query, brand: brand, model: name) {
                    return photo
                }
            }
        }
        return nil
    }

    /// Downloadt de foto en verkleint hem voor opslag.
    static func download(_ photo: CarPhoto) async -> Data? {
        guard let (data, response) = try? await session.data(from: photo.imageURL),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return ImageTools.downscaled(data)
    }

    // MARK: - Wikipedia API

    private struct SearchResponse: Decodable {
        struct Query: Decodable { let pages: [Page]? }
        struct Page: Decodable { let title: String; let index: Int?; let pageimage: String? }
        let query: Query?
    }

    private struct ImageInfoResponse: Decodable {
        struct Query: Decodable { let pages: [Page]? }
        struct Page: Decodable { let imageinfo: [Info]? }
        struct Info: Decodable {
            let thumburl: String?
            let url: String?
            let extmetadata: [String: Meta]?
        }
        struct Meta: Decodable { let value: FlexibleString? }
        let query: Query?
    }

    private static func search(host: String, query: String, brand: String, model: String) async -> CarPhoto? {
        guard let url = apiURL(host: host, params: [
            ("action", "query"), ("format", "json"), ("formatversion", "2"),
            ("generator", "search"), ("gsrsearch", query), ("gsrlimit", "6"), ("gsrnamespace", "0"),
            ("prop", "pageimages"), ("piprop", "name"),
        ]),
        let (data, _) = try? await session.data(from: url),
        let response = try? JSONDecoder().decode(SearchResponse.self, from: data),
        let pages = response.query?.pages else { return nil }

        let brandKey = brand.lowercased().split(separator: " ").first.map(String.init) ?? brand.lowercased()
        let modelKey = model.lowercased().split(separator: " ").first.map(String.init)

        let candidates = pages
            .sorted { ($0.index ?? 99) < ($1.index ?? 99) }
            .filter { page in
                let title = page.title.lowercased()
                guard title.contains(brandKey) else { return false }
                if let modelKey, !modelKey.isEmpty, !title.contains(modelKey) { return false }
                guard let image = page.pageimage?.lowercased() else { return false }
                // Geen logo's, emblemen of tekeningen.
                return !image.hasSuffix(".svg") && !image.contains("logo") && !image.contains("emblem")
            }

        for page in candidates {
            if let file = page.pageimage, let photo = await imageInfo(host: host, file: file, title: page.title) {
                return photo
            }
        }
        return nil
    }

    private static func imageInfo(host: String, file: String, title: String) async -> CarPhoto? {
        guard let url = apiURL(host: host, params: [
            ("action", "query"), ("format", "json"), ("formatversion", "2"),
            ("titles", "File:\(file)"), ("prop", "imageinfo"),
            ("iiprop", "url|extmetadata"), ("iiurlwidth", "1280"),
        ]),
        let (data, _) = try? await session.data(from: url),
        let response = try? JSONDecoder().decode(ImageInfoResponse.self, from: data),
        let info = response.query?.pages?.first?.imageinfo?.first,
        let link = info.thumburl ?? info.url,
        let imageURL = URL(string: link) else { return nil }

        let artist = info.extmetadata?["Artist"]?.value?.value.strippingHTML
        let license = info.extmetadata?["LicenseShortName"]?.value?.value.strippingHTML
        return CarPhoto(imageURL: imageURL, pageTitle: title, artist: artist, license: license)
    }

    private static func apiURL(host: String, params: [(String, String)]) -> URL? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let query = params.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
        }.joined(separator: "&")
        return URL(string: "https://\(host)/w/api.php?\(query)")
    }
}

private extension String {
    /// Verwijdert HTML-tags en overbodige witruimte uit Wikimedia-metadata.
    var strippingHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }
}

/// Toont een voorbeeldfoto bij een RDW-voertuig (Opzoeken / Terugvinden), met bronvermelding.

struct VehiclePhotoView: View {
    let merk: String
    let model: String
    let bouwjaar: Int?

    @AppStorage("photo.autoSearch") private var autoSearch = true
    @State private var image: UIImage?
    @State private var credit: String?
    @State private var loaded = false

    var body: some View {
        Group {
            if let image {
                VStack(alignment: .leading, spacing: 6) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 190)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityLabel("Voorbeeldfoto van een \(merk) \(model)")
                    if let credit {
                        Text("Voorbeeldfoto, niet jouw auto · \(credit)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            } else if !loaded && autoSearch {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 190)
                    .overlay { ProgressView() }
            }
        }
        .task(id: "\(merk)|\(model)|\(bouwjaar ?? 0)") {
            guard autoSearch else { loaded = true; return }
            image = nil
            credit = nil
            if let photo = await CarPhotoService.find(merk: merk, model: model, bouwjaar: bouwjaar),
               let data = await CarPhotoService.download(photo),
               let ui = UIImage(data: data) {
                image = ui
                credit = photo.credit
            }
            loaded = true
        }
    }
}
