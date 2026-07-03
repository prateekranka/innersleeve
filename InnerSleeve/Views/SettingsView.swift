import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var discogsToken = ""
    @State private var tokenStatus: TokenStatus?
    @State private var isTestingDiscogs = false

    private enum TokenStatus: Equatable {
        case saved
        case accepted(String?)
        case missing
        case rejected
        case rateLimited
        case offline

        var message: String {
            switch self {
            case .saved:
                return "Token saved locally."
            case .accepted(let remaining):
                if let remaining, !remaining.isEmpty {
                    return "Discogs token accepted · \(remaining) requests remaining."
                }
                return "Discogs token accepted."
            case .missing:
                return "Paste a Discogs token before testing."
            case .rejected:
                return "Discogs rejected this token."
            case .rateLimited:
                return "Discogs accepted the request but rate limited it."
            case .offline:
                return "Could not reach Discogs. The token remains saved."
            }
        }
    }

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Catalog provider") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(ReleaseProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                Text("MusicBrainz and Cover Art Archive are used by default.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Discogs") {
                SecureField("Personal access token", text: $discogsToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { saveToken(settings) }
                Button("Save token") {
                    saveToken(settings)
                }
                Button {
                    Task { await testDiscogsToken(settings) }
                } label: {
                    if isTestingDiscogs {
                        ProgressView()
                    } else {
                        Label("Test Discogs token", systemImage: "checkmark.seal")
                    }
                }
                .disabled(isTestingDiscogs)
                if let tokenStatus {
                    Text(tokenStatus.message)
                        .font(.footnote)
                        .foregroundStyle(statusColor(tokenStatus))
                }
            }

            Section("Attribution") {
                Text("Metadata: MusicBrainz / Discogs")
                Text("Artwork: Cover Art Archive / Discogs")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    saveToken(settings)
                    dismiss()
                }
            }
        }
        .onAppear {
            discogsToken = settings.discogsToken
        }
    }

    private func saveToken(_ settings: SettingsStore) {
        settings.discogsToken = discogsToken
        tokenStatus = .saved
    }

    private func testDiscogsToken(_ settings: SettingsStore) async {
        saveToken(settings)
        isTestingDiscogs = true
        let result = await DiscogsService.validate(token: discogsToken)
        switch result {
        case .accepted(let remaining):
            tokenStatus = .accepted(remaining)
        case .missing:
            tokenStatus = .missing
        case .rejected:
            tokenStatus = .rejected
        case .rateLimited:
            tokenStatus = .rateLimited
        case .offline:
            tokenStatus = .offline
        }
        isTestingDiscogs = false
    }

    private func statusColor(_ status: TokenStatus) -> Color {
        switch status {
        case .saved, .accepted:
            return .secondary
        case .missing, .rejected, .rateLimited, .offline:
            return Palette.orangeAccent
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(SettingsStore())
    }
}
