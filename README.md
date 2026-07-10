# Wax Ledger

A SwiftUI iPhone app for tracking a physical vinyl record collection — built as an
interactive music object, not a catalog. iOS 26+, SwiftData, no backend, no AI.

Design source of truth: `~/Documents/Codex/2026-07-02/i/outputs/vinyl-reference-teardown.md`

## Modes

- **Shelf** (first screen) — draggable 3D depth carousel of records. Hero record at
  center; neighbors recede in scale, rotation, opacity, and blur. Tap the hero to open
  Record Detail. Metadata (title, artist, pressing, condition, last played) sits small
  beneath the object. A toggle switches to the **display shelf**: a listening-room wall
  of covers on picture ledges with a tripod floor lamp (tap to light the room) and a
  credenza holding a turntable and crates of records.
- **Deck** — fixed product-rendered turntable. Drag vertically to stream records through
  the platter. The tonearm is the primary control: pick the stylus up and place it on
  any part of the record to play from that portion, or drag it back to the arm rest to
  lift the needle — the platter keeps spinning until the deck's stop button is pressed.
  "Log play" records a listen.
- **Wanted** — the wishlist in the same carousel language: ghost records with dashed
  rings, a price tag on the hero, target pressing, priority, and shop links.

From Record Detail: Side A/B track list, pressing/copy details, play history, notes, and
the **Package Archive** — inserts, posters, obi strips, receipts, stickers, booklets,
signed items, and inner sleeves laid out as physical objects on a charcoal table.

## Build & run

```bash
open InnerSleeve.xcodeproj   # requires Xcode 26 (iOS 26 SDK)
```

- Run the **InnerSleeve** scheme on any iPhone simulator (⌘R).
- Tests: ⌘U, or:

```bash
xcodebuild test -project InnerSleeve.xcodeproj -scheme InnerSleeve \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- Screenshots from the booted simulator:

```bash
xcrun simctl io booted screenshot shelf.png
```

## Architecture

- `Models/` — SwiftData: `Record`, `Track`, `PackageAttachment`, `WishlistItem`,
  `PlayLogEntry`. Enums for condition grades, vinyl appearance, attachment kinds.
- `Support/` — palette from the teardown, seeded RNG, procedural cover/label art
  (`CoverArtView`), fixture collection (14 fictional records, 6+ wishlist items),
  in-memory preview containers.
- `Views/` — `RecordDiscView` (Canvas-rendered vinyl: grooves, gloss, label, splatter),
  `DepthCarouselView` (+ testable `CarouselGeometry`), `CollectionGalleryView`,
  `TurntableDeckView`/`TonearmView`, `TurntableModeView`, `RecordDetailView`,
  `PackageArchiveView`, `WishlistView`, `RootView` (Liquid Glass mode switcher).
- `InnerSleeveTests/` — Swift Testing suite: carousel math, fixtures, play logging,
  sorting, deterministic art.

Liquid Glass (`glassEffect`, `GlassEffectContainer`, `.glass`/`.glassProminent` button
styles) is used only for controls and floating overlays. Records, deck, and archive
objects are custom-rendered.

## Preview variants

`#Preview`s cover: full collection, empty collection, long album titles, missing cover
image, dense package archive, wishlist-heavy state, plus component previews for discs,
cover art styles, and the deck.

## Deliberately mocked (MVP)

- No audio playback — the deck is a browsing/logging instrument.
- Cover art is generated, not photographed; all records are fictional.
- Wishlist shop links point at example.com.
- No add/edit/delete UI yet — the collection is fixture-seeded on first launch.
- No barcode scanning / Discogs import.
