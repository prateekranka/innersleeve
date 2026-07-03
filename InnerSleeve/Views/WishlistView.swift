import SwiftUI
import SwiftData

/// Wishlist: the same physical shelf language, but these records are ghosts —
/// wanted, not yet owned.
struct WishlistView: View {
    @Query private var allItems: [WishlistItem]
    @State private var selection: Int = 0

    private var items: [WishlistItem] {
        WishlistItem.huntOrder(allItems)
    }

    private var selectedItem: WishlistItem? {
        guard items.indices.contains(selection) else { return nil }
        return items[selection]
    }

    var body: some View {
        ZStack {
            Palette.stageGrey.ignoresSafeArea()

            if items.isEmpty {
                emptyWishlist
            } else {
                VStack(spacing: 0) {
                    Text("The Want List")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.inkOnStage.opacity(0.8))
                        .padding(.top, 18)

                    DepthCarouselView(
                        items: items,
                        selection: $selection,
                        discDiameter: 320
                    ) { item, isSelected in
                        wantedDisc(item, isSelected: isSelected)
                    }
                    .frame(height: 400)
                    .frame(maxHeight: .infinity, alignment: .center)

                    metadataBlock
                        .padding(.bottom, 96)
                }
            }
        }
    }

    // MARK: Wanted record rendering

    private func wantedDisc(_ item: WishlistItem, isSelected: Bool) -> some View {
        ZStack {
            RecordDiscView(wishlistItem: item, glossStrength: isSelected ? 0.8 : 0.4)
                .opacity(0.82)
            // Dashed "not yet owned" ring.
            Circle()
                .strokeBorder(
                    Palette.orangeAccent.opacity(isSelected ? 0.9 : 0.4),
                    style: StrokeStyle(lineWidth: 1.6, dash: [6, 6])
                )
                .padding(2)
            if isSelected {
                priceTag(item)
                    .offset(x: 86, y: -104)
            }
        }
    }

    private func priceTag(_ item: WishlistItem) -> some View {
        VStack(spacing: 1) {
            Text("MAX")
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .kerning(1.0)
                .foregroundStyle(Color.black.opacity(0.5))
            Text(item.formattedMaxPrice)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.black.opacity(0.85))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Palette.warmYellow)
                .shadow(color: Palette.warmShadow, radius: 5, y: 3)
        )
        .overlay(alignment: .top) {
            // Tag hole and string.
            Circle()
                .fill(Palette.stageGrey)
                .frame(width: 5, height: 5)
                .offset(y: 3)
        }
        .rotationEffect(.degrees(8))
    }

    // MARK: Metadata

    private var metadataBlock: some View {
        VStack(spacing: 5) {
            if let item = selectedItem {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        priorityDots(item.priority)
                        Text(item.priorityLabel.uppercased())
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .kerning(1.2)
                            .foregroundStyle(Palette.orangeAccent)
                    }
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.inkOnStage)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text("\(item.artist) · \(String(item.releaseYear))")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkOnStage.opacity(0.65))
                    Text(item.targetPressing)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.inkOnStage.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)

                    if !item.notes.isEmpty {
                        Text(item.notes)
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.inkOnStage.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.top, 1)
                    }

                    if !item.shopLinks.isEmpty {
                        shopLinkRow(item)
                            .padding(.top, 6)
                    }
                }
                .id(item.persistentModelID)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 36)
        .animation(.easeInOut(duration: 0.22), value: selection)
    }

    private func priorityDots(_ priority: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i < (4 - priority) ? Palette.orangeAccent : Palette.inkOnStage.opacity(0.15))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private func shopLinkRow(_ item: WishlistItem) -> some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(Array(item.shopLinks.enumerated()), id: \.offset) { _, link in
                    if let url = URL(string: link) {
                        Link(destination: url) {
                            Label(shopName(from: link), systemImage: "cart")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.glass)
                        .tint(Palette.inkOnStage)
                    }
                }
            }
        }
    }

    private func shopName(from link: String) -> String {
        guard let url = URL(string: link) else { return "Shop" }
        let path = url.pathComponents.dropFirst()
        return path.first?.replacingOccurrences(of: "-", with: " ").capitalized ?? "Shop"
    }

    private var emptyWishlist: some View {
        VStack(spacing: 18) {
            Circle()
                .strokeBorder(
                    Palette.orangeAccent.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2, dash: [7, 7])
                )
                .frame(width: 200, height: 200)
            Text("No records on the want list")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.inkOnStage.opacity(0.7))
            Text("Grails, hunts, and dollar-bin hopes\nwill line up here.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkOnStage.opacity(0.45))
                .multilineTextAlignment(.center)
        }
    }
}

#Preview("Wishlist") {
    WishlistView()
        .modelContainer(PreviewContainers.full)
}

#Preview("Wishlist-heavy state") {
    WishlistView()
        .modelContainer(PreviewContainers.wishlistHeavy)
}

#Preview("Wishlist · empty") {
    WishlistView()
        .modelContainer(PreviewContainers.empty)
}
