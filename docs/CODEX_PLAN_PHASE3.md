# Inner Sleeve — Phase 3 Implementation Plan (for Codex)

Grounded in the current repo state (github.com/prateekranka/innersleeve): Shelf tab has two
modes (`ShelfMode.carousel` and `.displayShelf` in `CollectionGalleryView.swift`); the deck
plays via `AppleMusicDeckPlayer` (MusicKit) with a stylus-cue drag zone; edit flow is
`RecordFormView` + `RecordDraft`; discs render in `RecordDiscView` with
`VinylAppearance { black, amber, smoke, splatter }`.

Do not regress: custom-rendered records/hardware, glass for controls only, teardown palette,
fictional fixtures. Work phases in order; after each: build, test, previews.

---

## Phase A — Deck hardware refinements

All in `TurntableDeckView.swift` / `TurntableModeView.swift`.

### A1. Smaller record + full-width ticker

- `discDiameter`: **204 → 172** (platter mat is 158 ⌀; a 172 disc overhangs it ~7pt per
  side and clears the `INNER SLEEVE · IS-1` brand mark at (−108, −100), since the disc's
  vertical extent is ±86 around platter center (−52, 0)). Keep `offset(x: -52 * factor)`.
- Queue: `recordSpacing` 190 → **170**; off-deck scale stays 0.68.
- **Verify visually** that IS-1 is fully clear of the disc in the deck preview. If it still
  clips at any point of the landing animation, nudge the brand mark to (−112, −104) — do
  NOT remove it.
- Ticker (`DeckTickerDisplay`): becomes a full-width instrument.
  - `displayWidth` 190 → **300**, repositioned to `offset(x: 0, y: 100)` (bottom band of
    the deck, centered). Disc bottom edge sits at y ≈ 86, display top at y ≈ 89 — no overlap.
  - Text: always `"<full album title>  •  <full track title>"` via the existing
    `deckTickerText` (drop the fallback truncation — never `lineLimit` the source string).
  - **Always scrolls** — remove the `characterThreshold` gate. Continuous marquee: duplicate
    the string with a `"     •     "` gap, translate at a constant **30 pt/s**, wrap
    seamlessly (reset when the first copy fully exits — measure text width with a hidden
    `Text` + `onGeometryChange`, don't estimate `count * 6`). Pause when nothing is on deck.

### A2. Skeuomorphic STOP button

The current invisible `tonearmStopControl` (tap on the arm base) goes away as the *primary*
stop. Replace with an explicit hardware button on the deck body:

- New `DeckStopButton` in `TurntableDeckView.swift`: rounded-rect key, **48×24**, placed
  bottom-left of the deck at `offset(x: -128, y: 100)` (clear of platter and ticker).
  - Off-white key cap with the deck's bevel language: top-light/bottom-dark strokeBorder,
    tiny drop shadow.
  - Engraved label `STOP` (6.5pt monospaced semibold, black 0.4 opacity) or a 7×7 filled
    square glyph — match the vents' restraint.
  - Pressed state: translate y +1, swap to inner-shadow look, haptic
    `.impact(weight: .medium)`.
  - A 3pt amber LED dot beside it, lit (with soft glow) while `deckPlayer.isPlaying`.
- Action: `liftStylus()` (stop playback + arm returns to rest). Accessibility: "Stop".
- The deck gains a `onStop: (() -> Void)?` parameter; `TurntableModeView` wires it.

### A3. Draggable stylus: lift, place, and cue smoothly

Replace the invisible `stylusCueDragZone` + tap-zone model with direct tonearm manipulation.
The arm becomes the instrument:

- New state in `TurntableModeView`: `enum ArmState { case resting; case cueing(progress: Double); case playing(progress: Double) }`.
- `TonearmView` gains `angle: Double` (degrees) instead of just `isLifted`, rotating around
  the existing pivot anchor `UnitPoint(x: 0.69, y: 0.09)`:
  - **Rest**: −16° (parked right, off the record) — add a small white arm-rest clip drawn
    on the deck at the resting tip position so the pose reads physically.
  - **Outer groove**: 0°. **Inner groove (label edge)**: +14°.
  - Map cue progress 0…1 linearly to 0°…+14°.
- Drag gesture on the arm itself (contentShape along the arm path, ~44pt wide):
  - While dragging: arm is lifted (existing −7° pitch + shadow), and its angle tracks the
    finger — compute the angle from the drag location relative to the pivot, clamped to
    [−16°, +14°]. Follow with `.interactiveSpring(response: 0.18, dampingFraction: 0.86)` —
    this is the "smoother" feel: the arm never jumps, it eases toward the finger.
  - Amber cue dot (existing `stylusCueIndicator`) tracks the mapped progress while over
    the record zone (angle ≥ 0°).
  - On release **over the record** (angle ≥ 0°): drop the arm (spring
    `response 0.42, damping 0.7`, haptic), convert angle → progress → track via the
    existing `stylusCueTrackIndex(progress:trackDurations:)`, then `play(...)`.
  - On release **off the record** (angle < 0°): arm settles onto the rest, playback stops
    (`deckPlayer.stop()`), state `.resting`. This is the "lift the stylus off to stop"
    interaction.
- Record-change behavior unchanged (pulse lift on snap, auto-play keeps working); the arm
  animates rest → drop when auto-play starts.
- Keep a plain *tap* on the on-deck record opening `RecordDetailView`.
- Pure math (`armAngle(for:)`, `progress(fromAngle:)`, rest threshold) goes in a testable
  `TonearmMath` enum.

### A4. Explicit loading states (fixes "added a record and it didn't play")

Root cause: first play triggers a MusicKit catalog search + album fetch with no UI signal.

- `AppleMusicDeckPlayer`: add `private(set) var isLoading: Bool` — true for the whole
  span of `loadAndPlay`/`play` (set in a `defer`), false after. `statusText` gains a
  loading branch: `"Finding on Apple Music…"` / `"Loading album…"`.
- While `isLoading`:
  - Ticker shows the status text (takes priority over album • track).
  - Tonearm hovers lifted mid-record (not resting, not dropped) — the physical read of
    "about to play".
  - The status control shows a small `ProgressView` in place of the dot.
- On failure (`errorMessage` non-nil): ticker shows the error for 4s (e.g. "ALBUM NOT
  FOUND — TAP TO RETRY"), arm returns to rest, status control becomes the retry button.
- Add flow: after save, the new record's disc shows a thin indeterminate progress ring
  around the label while `CoverArtRefetcher`/cover fetch is in flight. Implement a tiny
  `@Observable ArtFetchStatus` (set of `PersistentIdentifier`) injected via environment;
  `RecordDiscView(record:)` call sites overlay the ring when their id is in the set.
  Never let a background fetch look like a hang.

---

## Phase B — Shelf room view (replaces the row-of-three grid)

**Keep `.carousel` untouched.** Replace `DisplayShelfGridView` (+ its row/button structs)
with a room scene. New file `Views/ShelfRoomView.swift`.

### B1. Scene composition (reference: wall-shelf room photos)

Vertical layout, top to bottom:

1. **Three wall shelves** (equal heights, ~26% of scene height each): records standing on
   ledge strips. Reuse the existing ledge gradient bar (the 10pt rounded rect) under each
   row. Wall = `Palette.stageGrey` with a very subtle vertical luminance gradient.
2. **Console table** (~22% of scene height, pinned to the bottom): wood-toned table top
   (tan/brown linear gradient with 2–3 seeded grain lines, matching the teardown's wood
   recipe), containing:
   - **Lamp** (left corner): small illustrated table lamp — cylindrical shade (off-white),
     thin stem, round base. Tap toggles `lampOn`:
     - ON: warm radial gradient glow behind/under the shade (`Palette.warmYellow` →
       clear, ~140pt radius), shade brightens, and the whole room warms slightly (overlay
       `Palette.warmYellow.opacity(0.05)` on the scene).
     - OFF: glow gone, scene overlay `Palette.charcoal.opacity(0.22)` — the room dims.
     - Spring the transition (0.35s), haptic `.impact(weight: .light)`. Persist `lampOn`
       in `@AppStorage`.
   - **Plant** (right corner): small potted plant — terracotta/off-white pot, 5–7 leaf
     shapes (two greens from the label-ink palette), slight seeded rotation per leaf.
   - **Record stack**: 6–8 thin horizontal slabs (record spines) piled with small x-jitter
     next to the plant, plus one sleeve leaning against the wall. Pure decoration.
3. These props are illustrations in the Figma-construction style — layered simple shapes,
   soft shadows. No emoji, no SF Symbols for the props.

### B2. Records on the shelves

- Render **sleeves, not bare discs** (this view is "album covers on the wall"):
  a `ShelfSleeveView` = rounded-rect jacket (aspect 1:1, ~118pt) with
  `RecordCoverArtworkView`/`CoverArtView` front, thin spine shadow at the bottom edge, and
  a disc peeking 6pt above the jacket top (crop of `RecordDiscView`) so it still reads
  as vinyl. Soft drop shadow onto the wall.
- Distribution: `Record.shelfOrder`, dealt sequentially into rows round-robin
  (`index % 3`) so all three shelves fill evenly from the start.
- **Each shelf row scrolls horizontally, smoothly, snapping per record**:
  - `ScrollView(.horizontal)` + `LazyHStack(spacing: 18)` + `.scrollTargetLayout()`,
    with `.scrollTargetBehavior(.viewAligned)` — native smooth snap, and fast flicks
    travel multiple records before settling (exactly the requested feel).
  - `.contentMargins(.horizontal, 24, for: .scrollContent)` gives the leading/trailing
    **anchor** so the first/last sleeve aligns cleanly and end spacing never collapses.
  - `.scrollIndicators(.hidden)`.
- Interactions per sleeve: tap → `onOpen` (detail); context menu → Edit / Delete /
  Put on deck (reuse the existing closures — `CollectionGalleryView` keeps its sheets and
  confirmation dialog exactly as-is).
- Empty rows (fewer than 3 records): show a faint dashed sleeve outline placeholder.

### B3. Single view-toggle button

In `shelfChrome`, replace the two-button `HStack` with **one** button that always shows
the icon of the view it will switch **to**:

- In carousel mode → icon `"square.split.bottomrightquarter"` (shelves), label
  "Show display shelf".
- In shelf-room mode → icon `"circle.grid.cross"` (the carousel's existing mark), label
  "Show carousel".
- Animate the swap with `.contentTransition(.symbolEffect(.replace))`; keep `.glass`
  style, `Palette.inkOnStage` tint.

---

## Phase C — Vinyl design system + per-record look editor

The reference boards call for real colored-vinyl pressings: solid translucent color,
two-color swirl/marble, tri-color pinwheel, radial burst/tie-dye, color-ring halo,
splatter-on-cream, smoke marble.

### C1. Model (additive, lightweight migration)

On `Record` (and mirrored in `RecordDraft`):

- `var vinylStyleRaw: String?` — new enum `VinylStyle: String, Codable, CaseIterable`
  `{ black, translucent, swirl, marble, pinwheel, burst, halo, splatterMix, smoke }`.
- `var vinylPrimaryHex: String?`, `var vinylSecondaryHex: String?` — user-pickable colors.
- `var vinylSeed: Int?` — pattern variation, shuffle-able.
- Back-compat: computed `resolvedVinylStyle` maps nil → from legacy `VinylAppearance`
  (black→black, amber→translucent(amber), smoke→smoke, splatter→splatterMix). Do not
  remove `vinylAppearance` or touch fixtures.

### C2. Rendering (`RecordDiscView`)

Replace the `vinylBase`/`splatter` switch with a `VinylSurfaceView(style:primary:secondary:seed:size:)`
Canvas layer stack. Recipes (all seeded, all clipped to the disc circle, grooves/gloss/label
layers stay on top unchanged):

- **translucent**: radial gradient of primary (0.92 → darkened 40%), slight edge lightening
  — the golden-record look.
- **swirl**: dark base of primary; 6–9 large soft blobs of secondary (and lightened primary)
  at seeded polar positions, each blurred 8–14pt, plus 2–3 comma-shaped smears (arc-stroked
  paths, thick linewidth, blurred) — the blue/white marble look.
- **marble**: like swirl but low-contrast: primary base, secondary veins as 4–6 thin
  blurred bezier strands crossing the disc — the teal marble look.
- **pinwheel**: 4–6 angular wedge segments (primary, secondary, plus one/two inks from
  `Palette.labelInks`), edges softened with 6pt blur, slight rotational smear — the
  tri-color CBS look.
- **burst**: dark center disc of secondary fading out; 40–70 thin radial streaks of primary
  and lightened variants from ~35% radius outward, seeded lengths/widths, 2pt blur —
  the tie-dye burst look.
- **halo**: primary base; a wide soft ring band of secondary centered at ~55% radius
  (stroke width ~28% of radius, blurred 10pt) — the orange/white haze look.
- **splatterMix**: cream/neutral base (secondary), existing splatter generator using
  primary + one label ink, denser (120 dots) with a few elongated streaks.
- **smoke**: keep current recipe.
- Hex ⇄ Color helpers in `Palette` (`Color(hex:)`, `hexString`), with fallbacks to the
  teardown palette when hex is nil. Rendering must stay deterministic per seed
  (screenshots and previews stable).

### C3. Editor — "Record look" in the edit menu

- New `Views/VinylDesignEditorView.swift`, pushed from a new **"Record look"** row in
  `RecordFormView`'s pressing section (shows a 44pt live mini-disc as its row thumbnail).
  Also add a "Record look" item to both record context menus (carousel + shelf room),
  presenting the editor directly in a sheet.
- Editor layout (stage-grey, object-first):
  - Top: large live `RecordDiscView` preview (~260pt) reflecting every change instantly.
  - Style row: horizontally scrolling chips, each a 56pt mini disc rendered in that style
    (current colors) — selection ring in `Palette.orangeAccent`.
  - Two `ColorPicker`s (Primary / Secondary), hidden for styles that ignore secondary
    (translucent, smoke).
  - "Shuffle pattern" glass button → new random `vinylSeed` (haptic).
  - Save/Cancel: edits write through `RecordDraft` when inside the form; write directly +
    `modelContext.save()` when opened from a context menu.
- Add previews: one per style, plus the editor itself.

### C4. Tests

- Hex round-trip; legacy `VinylAppearance` → `resolvedVinylStyle` mapping; determinism
  (same seed/style/colors → identical placements — expose the blob/streak geometry
  generator as a pure seeded function and assert equality across two runs).

---

## Phase D — Movable light source + iridescent sheen

A draggable "studio lamp" that relights the records — vinyl surfaces catch an iridescent,
groove-diffraction rainbow that tracks the light.

### D1. Light model

- `@Observable final class StageLight` in `Support/`: `var position: CGPoint`
  (normalized −1…1 in both axes, relative to disc center; default (−0.45, −0.6) matching
  today's fixed gloss angle), `var intensity: Double = 1`. Injected via `.environment` at
  `RootView`. Pure helper `StageLightMath.angle(from:)` / `.elevation(from:)` for tests.

### D2. Rendering (in `RecordDiscView`)

- The two gloss crescents' `rotationEffect(-18°)` becomes `StageLightMath.angle(position)`
  so highlights orbit the disc as the light moves; opacity scales with
  `intensity * (1 − distanceFactor)`.
- New **iridescence layer** between grooves and gloss: an `AngularGradient` of
  low-saturation spectral hues (teal→violet→amber→teal, opacities ≤ 0.12), masked to the
  groove band (ring from label edge to rim), rotated to the light angle, with
  `.blendMode(.plusLighter)`. Strength scales with light proximity, and is stronger on
  colored/translucent styles than black. Static per light position — no animation loop,
  so it costs nothing while the light isn't moving.
- Respect `glossStrength` (carousel far discs stay quiet).

### D3. The movable lamp control

- A small draggable light glyph (12pt warm-yellow disc with 4 short rays — illustrated,
  not SF Symbol) available on the two hero surfaces:
  - **Record detail** (`SleevePullView` hero): orbits within the hero area.
  - **Carousel** hero: appears only while a new "relight" mode is active — a small glass
    toggle (sun icon) near the metadata block; off by default so the shelf stays clean.
- Drag updates `StageLight.position` (normalized against the hero frame) through
  `.interactiveSpring` — the sheen sweep must track the finger with zero perceptible lag.
  Haptic `.selection` when crossing the disc's vertical axis (feels like the highlight
  "rolling over" the spindle).
- The shelf-room lamp (Phase B) also nudges `StageLight`: lamp ON sets position toward
  the lamp corner + intensity 1; OFF drops intensity to 0.35 — the two features read as
  one lighting system.

### D4. Tests

`StageLightMath` angle/elevation mapping; intensity clamping; default position matches
the legacy −18° highlight so unedited screenshots don't shift.

---

## Sequencing & guardrails

1. Order: **A (deck) → B (shelf room) → C (vinyl designs) → D (light)**. A4's loading
   states ship with A — they fix an active UX bug.
2. After each phase: `xcodebuild test -project InnerSleeve.xcodeproj -scheme InnerSleeve
   -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`; keep the serialized suite
   green; screenshot deck + both shelf views.
3. New files land under `InnerSleeve/` — synchronized folders, never hand-edit the pbxproj.
4. No new dependencies. MusicKit/SwiftData/VisionKit/URLSession only.
5. Props and hardware are layered-shape illustrations per the teardown's construction
   method — no stock imagery, no SF Symbols for physical objects.
6. If the same build/runtime error occurs twice, research 3–5 fixes before attempt three.
