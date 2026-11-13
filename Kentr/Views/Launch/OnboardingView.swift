import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let symbol: String
        let title: LocalizedStringKey
        let text: LocalizedStringKey
    }

    private let pages: [Page] = [
        Page(symbol: "car.2.fill",
             title: "Al je auto's op één plek",
             text: "Houd elke auto bij die je ooit hebt gehad: van je eerste barrel tot je huidige auto. Met kenteken, of alleen merk en type."),
        Page(symbol: "questionmark.square.dashed",
             title: "Vergeten kenteken? Terugvinden!",
             text: "Zoek in de gegevens van de RDW op merk, model, kleur en bouwjaar en herken je oude kenteken."),
        Page(symbol: "eurosign.circle.fill",
             title: "Fiscale waarde en meer",
             text: "Catalogusprijs, bruto BPM, APK en een indicatie van de bijtelling. Beveiligd met Face ID en gesynchroniseerd via iCloud."),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x102C68), Theme.navyDeep], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button("Overslaan", action: onFinish)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                    }
                }
                .frame(height: 56)

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        let p = pages[index]
                        VStack(spacing: 28) {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Theme.plateYellow)
                                    .frame(width: 150, height: 150)
                                Image(systemName: p.symbol)
                                    .font(.system(size: 64, weight: .semibold))
                                    .foregroundStyle(Theme.navy)
                            }
                            .accessibilityHidden(true)
                            Text(p.title)
                                .font(.title.weight(.bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            Text(p.text)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Volgende" : "Aan de slag")
                        .font(.headline)
                        .foregroundStyle(Theme.navy)
                        .frame(maxWidth: 420)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.plateYellow, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .sensoryFeedback(.selection, trigger: page)
            }
        }
    }
}

#Preview { OnboardingView { } }
