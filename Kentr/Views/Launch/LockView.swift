import SwiftUI

/// Vergrendelscherm; vraagt automatisch om Face ID bij tonen en na terugkeer uit de achtergrond.
struct LockView: View {
    @EnvironmentObject private var lock: AppLock
    @Environment(\.scenePhase) private var scenePhase
    @State private var wasInBackground = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x102C68), Theme.navyDeep], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                if let icon = AppInfoFooter.appIcon {
                    icon.resizable().scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 96 * 0.2237, style: .continuous))
                        .accessibilityHidden(true)
                }
                Text("Kentr is vergrendeld")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Ontgrendel met \(lock.biometryName)", systemImage: lock.biometrySymbol)
                        .font(.headline)
                        .foregroundStyle(Theme.navy)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(Theme.plateYellow, in: Capsule())
                }
                .disabled(lock.isAuthenticating)
            }
        }
        .task { await lock.unlock() }
        .onChange(of: scenePhase) { _, phase in
            // Alleen opnieuw vragen na echt terugkeren uit de achtergrond (niet na annuleren).
            if phase == .background { wasInBackground = true }
            if phase == .active, wasInBackground {
                wasInBackground = false
                Task { await lock.unlock() }
            }
        }
    }
}
