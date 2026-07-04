import SwiftUI
import SwiftData

/// Root shell: the three physical modes with a floating Liquid Glass switcher.
/// Glass is used only for controls — the records and hardware stay custom-rendered.
struct RootView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case shelf = "Shelf"
        case deck = "Deck"
        case wanted = "Wanted"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .shelf: return "circle.grid.cross"
            case .deck: return "dial.medium"
            case .wanted: return "sparkle.magnifyingglass"
            }
        }
    }

    @State private var mode: Mode = .shelf
    @State private var deckTarget: Record?
    @State private var stageLight = StageLight()
    @Namespace private var glassNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch mode {
                case .shelf:
                    CollectionGalleryView { record in
                        deckTarget = record
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            mode = .deck
                        }
                    }
                case .deck:
                    TurntableModeView(deckTarget: deckTarget)
                case .wanted:
                    WishlistView()
                }
            }
            .ignoresSafeArea(.keyboard)

            modeSwitcher
                .padding(.bottom, 18)
        }
        .environment(stageLight)
        .sensoryFeedback(.selection, trigger: mode)
    }

    private var modeSwitcher: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(Mode.allCases) { candidate in
                    modeButton(for: candidate)
                        .glassEffectID(candidate.id, in: glassNamespace)
                }
            }
        }
    }

    @ViewBuilder
    private func modeButton(for candidate: Mode) -> some View {
        let button = Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                mode = candidate
            }
        } label: {
            Label(candidate.rawValue, systemImage: candidate.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 2)
        }

        if mode == candidate {
            button
                .buttonStyle(.glassProminent)
                .tint(Palette.orangeAccent)
        } else {
            button
                .buttonStyle(.glass)
                .tint(Palette.inkOnStage)
        }
    }
}

#Preview("Full collection") {
    RootView()
        .modelContainer(PreviewContainers.full)
}

#Preview("Empty collection") {
    RootView()
        .modelContainer(PreviewContainers.empty)
}

#Preview("Wishlist-heavy state") {
    RootView()
        .modelContainer(PreviewContainers.wishlistHeavy)
}
