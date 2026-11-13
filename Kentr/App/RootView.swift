import SwiftUI

struct RootView: View {
    @AppStorage("onboarding.done") private var onboardingDone = false
    @EnvironmentObject private var lock: AppLock
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    private var showOnboarding: Bool { !showSplash && !onboardingDone }
    private var showLock: Bool { !showSplash && onboardingDone && lock.isLocked }

    var body: some View {
        ZStack {
            MainTabView()

            if showOnboarding {
                OnboardingView { withAnimation(.easeInOut) { onboardingDone = true } }
                    .transition(.opacity)
                    .zIndex(1)
            }

            if showLock {
                LockView()
                    .transition(.opacity)
                    .zIndex(2)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(3)
            }
        }
        .reviewPrompt(isCalm: !showSplash && onboardingDone && !lock.isLocked)
        .task {
            // Geanimeerd splashscreen: minstens 4 seconden.
            try? await Task.sleep(for: .seconds(SplashView.duration))
            withAnimation(.easeOut(duration: 0.45)) { showSplash = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lock.lockIfNeeded() }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.tab) {
            CarsListView()
                .tabItem { Label("Mijn auto's", systemImage: "car.2.fill") }
                .tag(AppRouter.Tab.cars)
            LookupView()
                .tabItem { Label("Opzoeken", systemImage: "magnifyingglass") }
                .tag(AppRouter.Tab.lookup)
            FindPlateView()
                .tabItem { Label("Terugvinden", systemImage: "questionmark.square.dashed") }
                .tag(AppRouter.Tab.find)
            StatsView()
                .tabItem { Label("Overzicht", systemImage: "chart.bar.xaxis") }
                .tag(AppRouter.Tab.stats)
            SettingsView()
                .tabItem { Label("Instellingen", systemImage: "gearshape") }
                .tag(AppRouter.Tab.settings)
        }
        .sensoryFeedback(.selection, trigger: router.tab)
    }
}
