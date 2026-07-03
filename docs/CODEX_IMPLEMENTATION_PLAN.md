# Inner Sleeve — Phase 2 Implementation Plan (for Codex)

Target: the existing `InnerSleeve.xcodeproj` (iOS 26+, SwiftUI, SwiftData, no backend, **no AI APIs**).
Read `README.md` and the reference teardown first. Do not regress the design language:
records and hardware are custom-rendered; Liquid Glass is for controls only; palette stays
stage grey / charcoal / vinyl black / off-white / warm yellow-orange.

Work the phases in order. Each phase ends with: build passes, tests pass, previews render.

---

## Phase 1 — Shelf: hero-dominant carousel (match the Video A screenshot)

**Goal.** The selected record dominates the screen (~2.2× neighbor size). Neighbors form
tight overlapping clusters at the left/right edges with a clear horizontal gap between the
hero and each cluster. Today's geometry spreads records too evenly.

**Files.** `Views/DepthCarouselView.swift` (geometry only), `Views/CollectionGalleryView.swift`,
`Views/WishlistView.swift`, `InnerSleeveTests/InnerSleeveTests.swift`.

**Changes to `CarouselGeometry`.** Replace the single orbital curve with a piecewise
placement (keep the type and its tests — extend, don't rename):

- Add parameters: `heroClearance: Double = 178` (x where `|offset| == 1` lands),
  `clusterStep: Double = 30` (x per index beyond 1), `neighborScale: Double = 0.40`,
  `clusterScaleDecay: Double = 0.025`, `minClusterScale: Double = 0.30`.
- `placement(forOffset:)`:
  - `|offset| < 1` (the transition zone during drags): ease the disc out with
    `t = easeInOut(|offset|)`; `x = sign(offset) * heroClearance * t`;
    `scale = 1.0 - (1.0 - neighborScale) * t`; `rotationDegrees = -sign(offset) * 58 * t`.
  - `|offset| >= 1` (the edge clusters): `x = sign(offset) * (heroClearance + (|offset| - 1) * clusterStep)`;
    `scale = max(neighborScale - (|offset| - 1) * clusterScaleDecay, minClusterScale)`;
    `rotationDegrees = -sign(offset) * (58 + min((|offset| - 1) * 4, 12))`.
  - Opacity: 1.0 at hero → 0.9 at `|offset| == 1` → linear fade to 0.30 at `maxVisible`.
    Blur: 0 for `|offset| <= 1`, then up to 2.5 at `maxVisible`.
  - zIndex: hero on top; within a cluster, closer-to-center on top
    (`zIndex = 10 - |offset|` works; keep it monotonic in `|offset|`).
- Hero disc diameter: raise `discDiameter` to **340** in `CollectionGalleryView`
  (320 in `WishlistView`). Center the carousel vertically; metadata stays small below.
- Drag feel unchanged: same spring (`response 0.55, damping 0.82`), rubber-band, flick
  projection, haptic on snap. Crossfade metadata after the snap begins (already done).

**Tests.** Update/extend `CarouselGeometryTests`:
- x remains strictly monotonic across offsets −6…6 (existing test must still pass).
- `placement(forOffset: 1).scale ≈ 0.40` and hero/neighbor scale ratio ≥ 2.2.
- Gap assertion: `placement(1).x − heroEdge ≥ 20` where
  `heroEdge = 340/2 * placement(0).scale` — i.e. neighbor clusters clear the hero.
- Symmetry and rotation-clamp tests still pass.

**Acceptance.** Portrait iPhone screenshot reads like the reference: one big record,
two receding stacks at the edges, small centered metadata beneath.

---

## Phase 2 — Deck: right-size the records on the turntable

**Goal.** The record should sit on the platter like a real LP — slightly overhanging the
platter mat, clearly inside the deck body — instead of dwarfing the hardware.

**Files.** `Views/TurntableModeView.swift`, `Views/TurntableDeckView.swift`.

**Numbers.** Deck body is 344×236; platter mat is 158 ⌀ centered at deck offset (−52, 0).

- `discDiameter`: **296 → 204** (overhangs the 158pt mat by ~23pt per side — correct look).
- On-deck record offset: keep easing `x = −52 * factor` so it lands centered on the platter;
  add `y = 0` (unchanged).
- `recordSpacing`: **252 → 190** so queue records peek above/below the deck without
  dominating; queue (off-deck) scale: **0.78 → 0.68**.
- Tonearm: shorten so the headshell tip lands on the record's outer third —
  in `TonearmView.ArmShape`, move `tip` to `(midX − 24, midY + 40)` and the headshell
  offset to `(x: −22, y: 44)`. Verify visually in the deck preview.
- Spin, lift/drop, snap-settle springs, display readouts: unchanged.

**Acceptance.** In the preview, the vinyl reads as *on* the platter; tonearm crosses its
outer edge; queue records are visibly "waiting" above and below the deck.

---

## Phase 3 — Record Detail: sleeve-pull-to-reveal inserts

**Goal.** On `RecordDetailView`, the hero becomes interactive: drag the record out of the
jacket. Pull far enough and the package inserts fan out beneath, like tipping the sleeve's
contents onto a table. This is the signature interaction of the detail page.

**New file.** `Views/SleevePullView.swift`. Replace `RecordDetailView.heroObject` with it.

**Structure (z-order back to front):**
1. Inner-sleeve paper edge (off-white rect, peeks 8pt out of the jacket at rest).
2. The record disc (`RecordDiscView`), starting 74pt out (current resting look).
3. The jacket (cover art), which **clips** layers 1–2 via a `mask` so they emerge from
   its right edge — use a rect mask extending from the jacket's right edge outward.
4. Insert previews (up to 4 `AttachmentObjectView`s at ~0.45 scale), hidden at rest.

**Interaction model.**
- State: `pullProgress: CGFloat` (0…1), `revealed: Bool`.
- Horizontal `DragGesture` on the hero: `pullProgress = clamp(translation.width / 190, 0, 1)`;
  record x-offset = `74 + pullProgress * 120`; add 1–2° of z-rotation proportional to
  progress for physicality.
- Threshold at `0.62`: crossing it fires `.sensoryFeedback(.impact(weight: .medium))`.
- On release: `progress ≥ 0.62` → `revealed = true` — record settles fully out
  (spring `response 0.5, damping 0.75`), inserts fan out **staggered** (30ms delays,
  spring with slight overshoot) into a loose arc below the hero, each with seeded
  rotation jitter (reuse `placementSeed`). `progress < 0.62` → spring everything back.
- Tap any fanned insert → the existing inspection overlay (reuse from
  `PackageArchiveView` — extract `AttachmentInspectionOverlay` into its own file so both
  screens share it). A small glass chip "View all · N" pushes `PackageArchiveView`.
- Tapping the jacket while revealed slides the record back in and collapses the fan.
- Records with zero attachments: pull still works (the record comes out; nothing fans
  out; show a tiny caption "nothing else in the package"). Never block the gesture.
- Discovery affordance: at rest, a subtle 4pt idle "breathe" of the record peeking
  further out once, 1.2s after the view appears (one-shot animation, respects
  `accessibilityReduceMotion`).

**Tests.** Pure helper `SleevePullMath` (progress→offset mapping, threshold logic) with
unit tests: clamping, threshold crossing, release resolution.

**Acceptance.** Dense-archive preview (Quiet Machines): pull reveals OBI/poster/insert/
receipt fanned below; empty-archive record still pulls cleanly.

---

## Phase 4 — Add / Edit flows (scanner + catalog autocomplete + manual entry)

**Goal.** Users can add records by scanning a barcode, searching a catalog with
autocomplete, or typing everything manually; and can edit or delete any record.
This introduces the app's first network calls (metadata only — still no backend of ours,
still no AI).

### 4.1 Data source — decision

Use **MusicBrainz** as the default lookup service and **Discogs** as an optional
power-user upgrade:

| | MusicBrainz | Discogs |
|---|---|---|
| Key | None (meaningful `User-Agent` required) | Personal access token required for `/database/search` |
| Rate limit | ~1 req/sec | 60 req/min authenticated |
| Barcode lookup | `GET /ws/2/release/?query=barcode:{code}&fmt=json` | `GET /database/search?barcode={code}&token={t}` |
| Text search | `query=artist:X AND release:Y` | `?q=…&type=release` |
| Cover art | Cover Art Archive: `https://coverartarchive.org/release/{mbid}/front-500` (no key, no rate limit) | Included in results (auth required) |
| Vinyl pressing detail | Basic (format, country, label, catno) | Canonical — pressings are Discogs' core model |

Ship MusicBrainz + Cover Art Archive working out of the box; add a Settings field where
the user can paste a Discogs token to switch the provider (better pressing data).

### 4.2 Service layer

**New folder `Services/`:**

- `ReleaseLookup.swift` — provider-agnostic contract:
  ```swift
  struct ReleaseCandidate: Identifiable, Equatable {
      let id: String            // provider-scoped id, e.g. "mb:<mbid>" / "dc:<release_id>"
      var artist: String
      var title: String
      var year: Int?
      var label: String?
      var catalogNumber: String?
      var format: String?       // "12" LP, 33 RPM" etc.
      var country: String?
      var barcode: String?
      var coverArtURL: URL?
      var tracks: [TrackCandidate]   // may be empty until `details(for:)`
  }
  struct TrackCandidate { var side: RecordSide?; var number: Int; var title: String; var seconds: Int? }

  protocol ReleaseLookupService {
      func search(text: String) async throws -> [ReleaseCandidate]
      func search(barcode: String) async throws -> [ReleaseCandidate]
      func details(for candidate: ReleaseCandidate) async throws -> ReleaseCandidate
  }
  ```
- `MusicBrainzService.swift` — URLSession, `User-Agent: InnerSleeve/1.0 (contact URL)`,
  simple serial throttle ≥ 1.1s between requests, decode with `Codable` DTOs kept
  `private`. Release detail: `/ws/2/release/{mbid}?inc=recordings+labels+artist-credits&fmt=json`;
  map `media[].tracks[]` → sides A/B (first medium's first half/second half if side info
  is absent; vinyl media usually carry `position` like "A1" — parse the letter).
- `DiscogsService.swift` — token from settings, `Authorization: Discogs token=…` header,
  respect `x-discogs-ratelimit-remaining`, map `/releases/{id}` tracklist positions
  ("A1", "B2") to sides.
- `CoverArtLoader.swift` — fetch → downscale to ≤ 1024px → store `Data` on the record.
- All errors surface as a small typed enum (`.offline, .notFound, .rateLimited, .decoding`)
  so the UI can show friendly states. **Never block manual entry on network failure.**

### 4.3 Model changes (`Models/Record.swift`)

Additive only (SwiftData lightweight migration):
- `var barcode: String?`
- `var catalogNumber: String?`
- `var sourceReference: String?`   // "mb:<mbid>" or "dc:<id>", provenance
- `var coverImageData: Data?`      // real art; procedural art remains the fallback

`RecordDiscView` / detail hero / sleeve: when `coverImageData` is non-nil, render the
image (clipped to label circle / jacket) instead of `CoverArtView`. Keep procedural art
for every existing fixture.

### 4.4 Barcode scanner

- `Views/AddFlow/BarcodeScannerView.swift` — wrap VisionKit's
  `DataScannerViewController` (`UIViewControllerRepresentable`), restricted to
  `.barcode(symbologies: [.ean13, .ean8, .upce, .code128])`, single-item highlight,
  haptic + auto-dismiss on first stable read.
- Build setting (both app configs): `INFOPLIST_KEY_NSCameraUsageDescription =
  "Inner Sleeve uses the camera to scan record barcodes."`
- Simulator/no-camera fallback: `DataScannerViewController.isSupported == false` →
  show a manual barcode text field instead. (This is also the test path.)

### 4.5 Add flow UI

`Views/AddFlow/AddRecordFlow.swift`, presented as a sheet from a new `+` glass button on
the Shelf (top-right). Three entry points on one small chooser (glass buttons on the
stage, records-not-cards):

1. **Scan barcode** → scanner → `search(barcode:)` → candidate list → confirm form.
2. **Search catalog** → `Views/AddFlow/CatalogSearchView.swift`: search field, 350ms
   debounce (min 3 chars), results as rows [small procedural disc or fetched thumb ·
   title · artist · year · label]. Selecting fetches `details(for:)` and prefills the form.
3. **Manual entry** → straight to the empty form.

`Views/AddFlow/RecordFormView.swift` — the single shared confirm/edit form:
- Sections: identity (artist/title/year/label), pressing (format, pressing description,
  catalog number, barcode, vinyl appearance picker showing live `RecordDiscView`),
  condition (media/sleeve grade pickers), copy (storage location, purchase date/price,
  estimated value, notes), tracks (editable list, side A/B, reorder, add/remove —
  prefilled from candidate tracklist when available).
- Every prefilled field stays editable. Save inserts the `Record` (+`Track`s), fetches
  cover art in the background (non-blocking), dismisses to the Shelf with the new record
  selected (scroll/snap the carousel to it).

### 4.6 Edit & delete

- "Edit" glass button in `RecordDetailView`'s toolbar → same `RecordFormView` bound to
  the existing record.
- Delete: at the bottom of the edit form, destructive confirm; cascade removes tracks/
  attachments/log (already modeled). Also long-press context menu on shelf hero →
  Edit / Delete / Put on deck.
- Wishlist: same pattern later — out of scope for this phase, don't build it.

### 4.7 Settings

Minimal `Views/SettingsView.swift` (gear glass button, Shelf top-left): provider picker
(MusicBrainz default / Discogs), Discogs token field (stored in Keychain, not
UserDefaults), attribution lines. Keep it one screen.

### 4.8 Tests

- DTO→`ReleaseCandidate` mapping tests with bundled JSON fixtures (one MusicBrainz
  release-search response, one release-detail with A1/B1 positions, one Discogs search
  + release; anonymized/fictional contents are fine).
- Stub `URLProtocol` for service tests: barcode hit, no results, 503 → `.rateLimited`.
- Side-parsing tests: "A1"/"B2"/"1" (no side) → `RecordSide` mapping.
- Form logic: saving a candidate creates a Record with sequential per-side track numbers
  (reuse existing fixture invariants).

**Acceptance.** Scan (or type) a barcode on device → confirm form prefilled → record
appears on the Shelf with fetched art on its label. Airplane mode → manual entry still
works end-to-end.

---

## Phase 5 (optional — recommended to SKIP for now) — drag record from Shelf to Deck

**Recommendation: not necessary.** The mode switcher already moves between Shelf and
Deck in one tap, both screens share selection state conceptually, and a long-press
context menu ("Put on deck") delivers the same outcome with zero gesture-conflict risk.
The shelf's horizontal drag and the deck's vertical drag are each already loaded with
meaning; a cross-screen drag would need long-press-to-lift disambiguation and a shared
overlay layer — real complexity for a shortcut few will discover. Ship the context-menu
version first; revisit only if usage shows demand.

**If/when built, the implementation is:**
- `RootView` owns the drag: `@State var liftedRecord: Record?`, a `@Namespace`, and a
  full-screen overlay `ZStack` above both modes where the lifted disc renders
  (`matchedGeometryEffect` from the shelf disc).
- Gesture on the shelf hero: `LongPressGesture(minimumDuration: 0.3)` (lift: scale 1.06,
  stronger shadow, haptic) `.sequenced(before: DragGesture())` — the carousel's own drag
  keeps `minimumDistance` so the two don't fight; while lifted, the carousel ignores drags.
- A drop chip ("Deck") fades in near the bottom via `GlassEffectContainer`; its frame is
  published with a `PreferenceKey`; drop-hit-testing is a frame containment check.
- On drop: switch `mode = .deck`, set the deck's selection to that record, and let the
  overlay disc animate onto the platter (`matchedGeometryEffect` target on the platter
  position), tonearm drop + haptic. On cancel: spring back to the shelf slot.

---

## Sequencing, hygiene, guardrails

1. Phases 1–2 are pure geometry/layout — do them first, update tests, screenshot.
2. Phase 3 next (self-contained view work). Phase 4 last (largest surface).
3. After each phase: `xcodebuild test -project InnerSleeve.xcodeproj -scheme InnerSleeve
   -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
4. Don't hand-edit `project.pbxproj` for new files — targets use synchronized folders;
   files added under `InnerSleeve/` / `InnerSleeveTests/` are picked up automatically.
5. No new dependencies/SPM packages; URLSession + VisionKit + SwiftData only.
6. Keep fictional fixture data intact; real metadata enters only via user-initiated adds.
7. If a build/runtime error repeats twice, stop and research 3–5 candidate fixes before
   the third attempt (per project convention).
