import SwiftUI

/// Een Nederlandse kentekenplaat: geel met de blauwe EU-strook.
struct KentekenPlateView: View {
    let kenteken: String
    var height: CGFloat = 36

    var body: some View {
        let text = kenteken.isEmpty ? "??-??-??" : Kenteken.format(kenteken)
        HStack(spacing: 0) {
            ZStack {
                Theme.plateBlue
                VStack(spacing: height * 0.04) {
                    Image(systemName: "staroflife.fill")
                        .font(.system(size: height * 0.22))
                        .foregroundStyle(Theme.plateYellow)
                    Text(verbatim: "NL")
                        .font(.system(size: height * 0.28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: height * 0.62)

            Text(verbatim: text)
                .font(.system(size: height * 0.58, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, height * 0.3)
                .frame(maxHeight: .infinity)
                .background(Theme.plateYellow)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height * 0.14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: height * 0.14, style: .continuous)
            .strokeBorder(Theme.ink.opacity(0.85), lineWidth: max(1, height * 0.045)))
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kenteken.isEmpty ? Text("Kenteken onbekend") : Text("Kenteken \(text)"))
    }
}

/// Grijze badge voor een auto zonder (bekend) kenteken.
struct UnknownPlateBadge: View {
    var height: CGFloat = 36

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "questionmark.square.dashed")
            Text("Kenteken onbekend")
        }
        .font(.system(size: height * 0.36, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, height * 0.3)
        .frame(height: height)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: height * 0.14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: height * 0.14, style: .continuous)
            .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

#Preview {
    VStack(spacing: 16) {
        KentekenPlateView(kenteken: "PK015L", height: 44)
        KentekenPlateView(kenteken: "12ABC3")
        UnknownPlateBadge()
    }
    .padding()
}
