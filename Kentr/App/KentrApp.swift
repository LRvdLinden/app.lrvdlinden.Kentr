import SwiftUI
import SwiftData

@main
struct KentrApp: App {
    @AppStorage("ui.appearance") private var appearance: AppearanceSetting = .system
    @StateObject private var lock = AppLock()
    @StateObject private var router = AppRouter()

    private let container: ModelContainer = {
        let schema = Schema([Car.self])
        let cloud = ModelConfiguration(schema: schema,
                                       cloudKitDatabase: .private(AppConfig.cloudKitContainer))
        if let container = try? ModelContainer(for: schema, configurations: cloud) {
            return container
        }
        // Fallback: lokaal opslaan als iCloud (nog) niet beschikbaar is.
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            fatalError("Kan de database niet openen: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(lock)
                .environmentObject(router)
                .environment(\.locale, Locale(identifier: "nl_NL"))
                .preferredColorScheme(appearance.colorScheme)
                .tint(Theme.accent)
                .onOpenURL { router.handle($0) }
        }
        .modelContainer(container)
    }
}
