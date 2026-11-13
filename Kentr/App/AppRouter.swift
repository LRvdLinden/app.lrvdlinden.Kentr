import SwiftUI

/// Houdt de geselecteerde tab bij en verwerkt deep links (kentr://kenteken/XX99XX).
@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Hashable { case cars, lookup, find, stats, settings }

    @Published var tab: Tab = .cars
    /// Kenteken dat het Opzoeken-scherm direct moet tonen.
    @Published var pendingLookup: String?

    func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "kentr" else { return }
        switch url.host?.lowercased() {
        case "kenteken":
            if let plate = url.pathComponents.dropFirst().first, !plate.isEmpty {
                pendingLookup = Kenteken.normalize(plate)
                tab = .lookup
            }
        case "terugvinden":
            tab = .find
        case "overzicht":
            tab = .stats
        default:
            tab = .cars
        }
    }
}
