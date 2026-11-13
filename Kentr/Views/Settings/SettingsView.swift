import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var lock: AppLock
    @AppStorage("ui.appearance") private var appearance: AppearanceSetting = .system
    @AppStorage("onboarding.done") private var onboardingDone = true
    @State private var showWhatsNew = false

    var body: some View {
        NavigationStack {
            Form {
                // 1. App-specifieke instellingen
                Section {
                    Toggle(isOn: Binding(
                        get: { lock.isEnabled },
                        set: { value in Task { await lock.setEnabled(value) } }
                    )) {
                        Label("Vergrendel met \(lock.biometryName)", systemImage: lock.biometrySymbol)
                    }
                    .disabled(!lock.canUseAuthentication)
                    if let error = lock.lastError {
                        Text(verbatim: error).font(.footnote).foregroundStyle(.orange)
                    }
                } header: {
                    Text("Beveiliging")
                } footer: {
                    Text("Bij openen en na terugkeer naar de app wordt om \(lock.biometryName) gevraagd.")
                }

                Section {
                    Label("Synchroniseert via iCloud", systemImage: "icloud")
                } footer: {
                    Text("Je auto's staan in je eigen iCloud en zijn zo ook op je iPad beschikbaar. Kentr heeft geen eigen server.")
                }

                // 2. Weergave
                Section("Weergave") {
                    Picker("Weergave", selection: $appearance) {
                        ForEach(AppearanceSetting.allCases) { Text($0.label).tag($0) }
                    }
                }

                // 3. Links
                Section {
                    Link(destination: AppConfig.privacyURL) {
                        Label("Privacyverklaring", systemImage: "hand.raised")
                    }
                    Link(destination: AppConfig.supportURL) {
                        Label("Support en contact", systemImage: "questionmark.circle")
                    }
                    Button {
                        showWhatsNew = true
                    } label: {
                        Label("Wat is nieuw", systemImage: "sparkles")
                    }
                    Button {
                        onboardingDone = false
                    } label: {
                        Label("Toon het welkomstscherm", systemImage: "hand.wave")
                    }
                    Link(destination: AppConfig.rdwOpenDataURL) {
                        Label("Bron: RDW Open Data", systemImage: "building.columns")
                    }
                }

                // 4. Ontdekken
                Section {
                    MoreAppsCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text(verbatim: MoreAppsText.current.section)
                }

                // 5. App-info
                Section {
                    AppInfoFooter()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Instellingen")
            .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
        }
    }
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    private let items: [(String, LocalizedStringKey, LocalizedStringKey)] = [
        ("car.2.fill", "Al je auto's op één plek", "Houd elke auto bij die je hebt gehad, met of zonder kenteken."),
        ("magnifyingglass", "Kenteken opzoeken", "Techniek, APK, catalogusprijs en bruto BPM rechtstreeks van de RDW."),
        ("eurosign.circle", "Bijtelling-indicatie", "Zie wat een auto als auto van de zaak ongeveer aan bijtelling kost."),
        ("questionmark.square.dashed", "Kenteken terugvinden", "Zoek op merk, model, kleur en bouwjaar en herken je oude kenteken."),
        ("faceid", "Face ID en iCloud", "Beveilig de app en houd je iPhone en iPad automatisch gelijk."),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items, id: \.0) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: item.0)
                                .font(.title2)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.1).font(.headline)
                                Text(item.2).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Versie 1.0.0")
                }
            }
            .navigationTitle("Wat is nieuw")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
    }
}
