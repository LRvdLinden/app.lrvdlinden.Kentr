import SwiftUI

/// Geanimeerd splashscreen (± 4 seconden). Begint gelijk aan het launch screen:
/// donkerblauw met de KENTR-plaat in het midden.
struct SplashView: View {
    static let duration: Double = 4.2

    @State private var backPlates = false
    @State private var shine = false
    @State private var tagline = false
    @State private var lift = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x102C68), Theme.navyDeep], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 36) {
                ZStack {
                    SplashPlate(text: "", opacity: 0.45)
                        .rotationEffect(.degrees(backPlates ? -8 : 0))
                        .offset(x: backPlates ? -14 : 0, y: backPlates ? -70 : 0)
                        .opacity(backPlates ? 1 : 0)
                    SplashPlate(text: "", opacity: 0.75)
                        .rotationEffect(.degrees(backPlates ? -3.5 : 0))
                        .offset(y: backPlates ? -34 : 0)
                        .opacity(backPlates ? 1 : 0)
                    SplashPlate(text: "KENTR", opacity: 1)
                        .overlay {
                            // Lichtschittering over de voorste plaat
                            GeometryReader { geo in
                                LinearGradient(colors: [.clear, .white.opacity(0.55), .clear],
                                               startPoint: .leading, endPoint: .trailing)
                                    .frame(width: geo.size.width * 0.35)
                                    .rotationEffect(.degrees(18))
                                    .offset(x: shine ? geo.size.width * 1.2 : -geo.size.width * 0.5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .allowsHitTesting(false)
                        }
                }
                .offset(y: lift ? -20 : 0)

                VStack(spacing: 6) {
                    Text("Al je auto's. Altijd bij de hand.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Met gegevens van de RDW")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(tagline ? 1 : 0)
                .offset(y: tagline ? 0 : 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kentr")
        .task {
            // Tijdlijn: platen waaieren uit, schittering, tagline, rustig optillen.
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { backPlates = true }
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeInOut(duration: 0.9)) { shine = true }
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeOut(duration: 0.6)) { tagline = true }
            withAnimation(.easeInOut(duration: 1.6)) { lift = true }
        }
    }
}

/// Plaat zoals in het app-icoon, vaste breedte (gelijk aan het launch-logo).
private struct SplashPlate: View {
    let text: String
    let opacity: Double
    private let width: CGFloat = 280
    private var height: CGFloat { width * 240 / 784 }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Theme.plateBlue
                VStack(spacing: 4) {
                    Image(systemName: "staroflife.fill")
                        .font(.system(size: height * 0.2))
                        .foregroundStyle(Theme.plateYellow)
                    Text(verbatim: "NL")
                        .font(.system(size: height * 0.2, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: height * 0.42)
            Text(verbatim: text)
                .font(.system(size: height * 0.62, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.plateYellow)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.ink, lineWidth: 3))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
        .opacity(opacity)
    }
}

#Preview { SplashView() }
