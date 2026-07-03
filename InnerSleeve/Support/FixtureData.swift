import Foundation
import SwiftData

/// Fictional fixture collection. Every artist, album, label, and shop is invented.
enum FixtureData {

    // MARK: Seeding entry points

    /// Seeds the persistent store and upgrades the old fictional demo catalog
    /// to the real albums used for device playback testing.
    static func seedIfNeeded(into context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<Record>())
        let wishlist = try context.fetch(FetchDescriptor<WishlistItem>())

        var changed = removeLegacyFixtureContent(
            records: records,
            wishlist: wishlist,
            from: context
        )

        if records.isEmpty && wishlist.isEmpty {
            seedProductionCollection(into: context)
            changed = true
        } else if changed {
            let remainingRecords = records.filter { !legacyFixtureRecordKeys.contains(AlbumKey($0)) }
            seedMissingProductionRecords(into: context, existingRecords: remainingRecords)
        }

        if changed {
            try context.save()
        }
    }

    /// The full showcase collection.
    static func seedFull(into context: ModelContext) {
        for record in makeRecords() {
            context.insert(record)
        }
        for item in makeWishlist() {
            context.insert(item)
        }
    }

    /// Production first-run collection, intentionally small so Apple Music
    /// playback testing starts from recognizable real albums.
    static func seedProductionCollection(into context: ModelContext) {
        for record in makeProductionRecords() {
            context.insert(record)
        }
    }

    static func makeProductionRecords() -> [Record] {
        [makeDarkSideOfTheMoon(), makeMidnights()]
    }

    /// Wishlist-heavy state: a couple of records, a big want list.
    static func seedWishlistHeavy(into context: ModelContext) {
        let records = makeRecords()
        for record in records.prefix(2) {
            context.insert(record)
        }
        for item in makeWishlist() {
            context.insert(item)
        }
        for item in makeExtraWishlist() {
            context.insert(item)
        }
    }

    // MARK: Records

    private static func makeMidnights() -> Record {
        let record = Record(
            artist: "Taylor Swift",
            title: "Midnights",
            releaseYear: 2022,
            label: "Republic Records",
            pressingDescription: "2022 Moonstone Blue Edition, 13-track LP",
            catalogNumber: "2445790098",
            coverArtSourceURL: "https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/3d/01/f2/3d01f2e5-5a08-835f-3d30-d031720b2b80/22UM1IM07364.rgb.jpg/1200x1200bb.jpg",
            artSeed: 401,
            artStyleRaw: CoverArtStyle.quadrants.rawValue,
            conditionMedia: .nearMint,
            conditionSleeve: .nearMint,
            storageLocation: "Deck Test · Slot 01",
            notes: "Seeded playback test record. Apple Music album ID is prelinked.",
            appleMusicAlbumID: "1649434004"
        )
        record.tracks = sideTracks(
            a: [
                ("Lavender Haze", 202),
                ("Maroon", 218),
                ("Anti-Hero", 201),
                ("Snow On The Beach", 256),
                ("You're On Your Own, Kid", 194),
                ("Midnight Rain", 175),
            ],
            b: [
                ("Question...?", 210),
                ("Vigilante Shit", 164),
                ("Bejeweled", 194),
                ("Labyrinth", 248),
                ("Karma", 204),
                ("Sweet Nothing", 188),
                ("Mastermind", 191),
            ]
        )
        return record
    }

    private static func makeDarkSideOfTheMoon() -> Record {
        let record = Record(
            artist: "Pink Floyd",
            title: "The Dark Side of the Moon",
            releaseYear: 1973,
            label: "Harvest Records",
            pressingDescription: "1973 album, Apple Music catalog playback test",
            catalogNumber: "SHVL 804",
            coverArtSourceURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/3e/76/b0/3e76b0e3-762b-2286-a019-8afb19cee541/886445635829.jpg/1200x1200bb.jpg",
            artSeed: 402,
            artStyleRaw: CoverArtStyle.beam.rawValue,
            conditionMedia: .vgPlus,
            conditionSleeve: .vgPlus,
            storageLocation: "Deck Test · Slot 02",
            notes: "Seeded playback test record. Apple Music album ID is prelinked.",
            appleMusicAlbumID: "1065973699"
        )
        record.tracks = sideTracks(
            a: [
                ("Speak to Me", 90),
                ("Breathe (In the Air)", 163),
                ("On the Run", 216),
                ("Time", 413),
                ("The Great Gig in the Sky", 276),
            ],
            b: [
                ("Money", 383),
                ("Us and Them", 469),
                ("Any Colour You Like", 206),
                ("Brain Damage", 226),
                ("Eclipse", 123),
            ]
        )
        return record
    }

    static func makeRecords() -> [Record] {
        var records: [Record] = []
        let calendar = Calendar.current

        func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
        }

        // 1 — the flagship
        let nightBureau = Record(
            artist: "Glass Meridian",
            title: "Night Bureau",
            releaseYear: 2019,
            label: "Meridian Sound Works",
            pressingDescription: "2019 first pressing, gatefold, 180 g",
            artSeed: 101, artStyleRaw: CoverArtStyle.rings.rawValue,
            conditionMedia: .nearMint, conditionSleeve: .nearMint,
            storageLocation: "Crate A · Slot 03",
            purchaseDate: day(2023, 11, 4), purchasePrice: 34, estimatedValue: 55,
            lastPlayedAt: day(2026, 6, 28), playCount: 23,
            notes: "The record that started the shelf. Dead quiet pressing."
        )
        nightBureau.tracks = sideTracks(
            a: [("Night Bureau", 254), ("Copper Wire", 231), ("Standing Signal", 305), ("Meridian Line", 218), ("Office of Clouds", 267)],
            b: [("Second Shift", 243), ("Analog Daughter", 288), ("Slow Elevator", 214), ("Closing Time at the Bureau", 356)]
        )
        nightBureau.attachments = [
            PackageAttachment(kind: .lyricInsert, title: "Printed lyric sheet", condition: .nearMint, placementSeed: 11),
            PackageAttachment(kind: .hypeSticker, title: "\"180 g audiophile\" sticker on shrink", condition: .vgPlus, placementSeed: 12),
        ]
        nightBureau.playLog = [
            PlayLogEntry(playedAt: day(2026, 6, 28), note: "Sunday morning, side B twice."),
            PlayLogEntry(playedAt: day(2026, 5, 30)),
            PlayLogEntry(playedAt: day(2026, 4, 12), note: "New stylus sounds incredible on this."),
        ]
        records.append(nightBureau)

        // 2
        let signalFires = Record(
            artist: "Copper Veldt",
            title: "Signal Fires",
            releaseYear: 1974,
            label: "Halcyon Records",
            pressingDescription: "1974 original, textured sleeve",
            artSeed: 102, artStyleRaw: CoverArtStyle.beam.rawValue,
            conditionMedia: .vgPlus, conditionSleeve: .vg,
            storageLocation: "Crate A · Slot 07",
            purchaseDate: day(2024, 3, 16), purchasePrice: 62, estimatedValue: 90,
            lastPlayedAt: day(2026, 6, 14), playCount: 11,
            notes: "Light crackle on the intro of A1, otherwise clean."
        )
        signalFires.tracks = sideTracks(
            a: [("Kindling", 198), ("Signal Fires", 276), ("Veldt Song", 243), ("Dry Season", 312)],
            b: [("Ember Council", 254), ("Smoke Reader", 221), ("The Long Grass", 289), ("Ash Map", 197)]
        )
        signalFires.attachments = [
            PackageAttachment(kind: .innerSleeve, title: "Original printed inner sleeve", condition: .vg, placementSeed: 21),
        ]
        signalFires.playLog = [PlayLogEntry(playedAt: day(2026, 6, 14))]
        records.append(signalFires)

        // 3
        let meridianLine = Record(
            artist: "The Paper Suns",
            title: "Meridian Line",
            releaseYear: 1968,
            label: "Golden Hour Recording Co.",
            pressingDescription: "1971 second pressing, mono",
            artSeed: 103, artStyleRaw: CoverArtStyle.quadrants.rawValue,
            conditionMedia: .vg, conditionSleeve: .good,
            storageLocation: "Crate A · Slot 12",
            purchaseDate: day(2022, 8, 2), purchasePrice: 18, estimatedValue: 40,
            lastPlayedAt: day(2026, 3, 8), playCount: 7,
            notes: "Mono mix is punchier than the reissue. Sleeve has ring wear."
        )
        meridianLine.tracks = sideTracks(
            a: [("Sunrise Census", 182), ("Paper Crown", 205), ("Meridian Line", 244), ("Tea and Telegrams", 173), ("Kite Weather", 191)],
            b: [("Afternoon People", 213), ("The Orchard Wall", 258), ("Half-Moon Terrace", 226), ("Goodnight, Observatory", 302)]
        )
        records.append(meridianLine)

        // 4
        let concreteGarden = Record(
            artist: "Vela Nova",
            title: "Concrete Garden",
            releaseYear: 1981,
            label: "Standard Frequency",
            pressingDescription: "1981 original, die-cut sleeve",
            vinylAppearance: .smoke,
            artSeed: 104, artStyleRaw: CoverArtStyle.wave.rawValue,
            conditionMedia: .nearMint, conditionSleeve: .vgPlus,
            storageLocation: "Crate B · Slot 01",
            purchaseDate: day(2024, 10, 19), purchasePrice: 48, estimatedValue: 70,
            lastPlayedAt: day(2026, 6, 30), playCount: 15,
            notes: "Smoke-grey vinyl. Die-cut window shows the inner sleeve pattern."
        )
        concreteGarden.tracks = sideTracks(
            a: [("Poured Foundations", 234), ("Concrete Garden", 267), ("Rebar Roses", 219), ("Municipal Light", 305)],
            b: [("Drainage Song", 244), ("Grey Belt", 231), ("Planting Season", 276), ("Demolition Lullaby", 328)]
        )
        concreteGarden.attachments = [
            PackageAttachment(kind: .innerSleeve, title: "Patterned die-cut inner", condition: .nearMint, placementSeed: 41),
            PackageAttachment(kind: .lyricInsert, title: "Folded lyric broadsheet", condition: .vgPlus, placementSeed: 42),
        ]
        concreteGarden.playLog = [
            PlayLogEntry(playedAt: day(2026, 6, 30), note: "Last night's closer."),
            PlayLogEntry(playedAt: day(2026, 6, 21)),
        ]
        records.append(concreteGarden)

        // 5
        let lowTide = Record(
            artist: "Harbor Lights Assembly",
            title: "Low Tide Frequencies",
            releaseYear: 2003,
            label: "Quiet Harbor",
            format: "2×12\" LP, 45 RPM",
            pressingDescription: "2020 remaster, double LP, 45 RPM",
            artSeed: 105, artStyleRaw: CoverArtStyle.dots.rawValue,
            conditionMedia: .mint, conditionSleeve: .nearMint,
            storageLocation: "Crate B · Slot 05",
            purchaseDate: day(2025, 1, 22), purchasePrice: 52, estimatedValue: 52,
            lastPlayedAt: day(2026, 5, 17), playCount: 6,
            notes: "45 RPM cut. Bass on B1 goes very deep."
        )
        lowTide.tracks = sideTracks(
            a: [("Harbor Master", 342), ("Low Tide Frequencies", 398), ("Mooring Lines", 287)],
            b: [("Fog Bell", 356), ("Salt Static", 312), ("Last Ferry Out", 421)]
        )
        records.append(lowTide)

        // 6 — splatter vinyl
        let staticBloom = Record(
            artist: "Ferric",
            title: "Static Bloom",
            releaseYear: 1994,
            label: "Oxide & Sons",
            pressingDescription: "2021 reissue, orange splatter, /500",
            vinylAppearance: .splatter,
            artSeed: 106, artStyleRaw: CoverArtStyle.rings.rawValue,
            conditionMedia: .nearMint, conditionSleeve: .nearMint,
            storageLocation: "Crate B · Slot 09",
            purchaseDate: day(2024, 6, 8), purchasePrice: 45, estimatedValue: 85,
            lastPlayedAt: day(2026, 2, 2), playCount: 4,
            notes: "Numbered 137/500. Splatter pattern is heavier on side B."
        )
        staticBloom.tracks = sideTracks(
            a: [("Bloom", 187), ("Rust Chorus", 164), ("Magnet School", 209), ("Static Bloom", 243), ("Iron Lung Serenade", 178)],
            b: [("Feedback Garden", 198), ("Oxidize Me", 172), ("Antenna Farm", 231), ("Decay Constant", 265)]
        )
        staticBloom.attachments = [
            PackageAttachment(kind: .hypeSticker, title: "Numbered edition sticker", condition: .mint, placementSeed: 61),
        ]
        records.append(staticBloom)

        // 7 — deliberately long title
        let cartographers = Record(
            artist: "Ondine Marrow",
            title: "The Cartographer's Waltz and Other Songs from the Northern Survey Expedition",
            releaseYear: 1972,
            label: "Compass Point Phonograph",
            pressingDescription: "1972 original, tip-on gatefold with fold-out map",
            artSeed: 107, artStyleRaw: CoverArtStyle.wave.rawValue,
            conditionMedia: .vgPlus, conditionSleeve: .vgPlus,
            storageLocation: "Crate A · Slot 15",
            purchaseDate: day(2023, 4, 29), purchasePrice: 120, estimatedValue: 210,
            lastPlayedAt: day(2026, 4, 5), playCount: 9,
            notes: "The fold-out survey map is intact, which is rare. Handle carefully."
        )
        cartographers.tracks = sideTracks(
            a: [("The Cartographer's Waltz", 312), ("Sixty Degrees North", 244), ("Snowline", 198), ("The Surveyor's Daughter", 276)],
            b: [("Baseline Measurements", 233), ("Aurora Field Notes", 305), ("Triangulation", 187), ("The Long Way Home from the Northern Survey", 384)]
        )
        cartographers.attachments = [
            PackageAttachment(kind: .poster, title: "Fold-out survey map poster", condition: .vgPlus, placementSeed: 71),
            PackageAttachment(kind: .booklet, title: "Expedition field notes booklet", condition: .vg, placementSeed: 72),
        ]
        records.append(cartographers)

        // 8
        let palomino = Record(
            artist: "June Reverie",
            title: "Palomino",
            releaseYear: 1988,
            label: "Dust Road Records",
            pressingDescription: "1988 original, club edition",
            artSeed: 108, artStyleRaw: CoverArtStyle.quadrants.rawValue,
            conditionMedia: .good, conditionSleeve: .fair,
            storageLocation: "Crate C · Slot 02",
            purchaseDate: day(2021, 7, 11), purchasePrice: 6, estimatedValue: 15,
            lastPlayedAt: day(2025, 12, 24), playCount: 19,
            notes: "Dollar-bin rescue. Plays better than it looks."
        )
        palomino.tracks = sideTracks(
            a: [("Palomino", 221), ("Country Dark", 254), ("Two-Lane Heart", 199), ("Radio Static Love", 243)],
            b: [("Neon Stables", 232), ("Dust Road", 265), ("Slow Rider", 288), ("Last Light on the Ridge", 312)]
        )
        records.append(palomino)

        // 9 — missing cover art fixture
        let ashline = Record(
            artist: "Motor Temple",
            title: "Ashline",
            releaseYear: 2011,
            label: "Ninth Gear",
            pressingDescription: "2011 first pressing, plain white sleeve",
            artSeed: 109, artStyleRaw: CoverArtStyle.missing.rawValue,
            hasCoverArt: false,
            conditionMedia: .vgPlus, conditionSleeve: .good,
            storageLocation: "Crate C · Slot 06",
            purchaseDate: day(2025, 9, 3), purchasePrice: 28, estimatedValue: 30,
            playCount: 0,
            notes: "Came in a generic white sleeve — original art missing. Still hunting for a proper jacket."
        )
        ashline.tracks = sideTracks(
            a: [("Ashline", 276), ("Idle High", 234), ("Carburetor Hymn", 298)],
            b: [("Downshift", 254), ("Temple Run", 312), ("Exhaust Prayer", 343)]
        )
        records.append(ashline)

        // 10
        let goldenHour = Record(
            artist: "The Analog Society",
            title: "Golden Hour Transmission",
            releaseYear: 2015,
            label: "Warm Signal",
            pressingDescription: "2015 first pressing, half-speed master",
            vinylAppearance: .amber,
            artSeed: 110, artStyleRaw: CoverArtStyle.beam.rawValue,
            conditionMedia: .nearMint, conditionSleeve: .nearMint,
            storageLocation: "Crate B · Slot 11",
            purchaseDate: day(2024, 12, 25), purchasePrice: 40, estimatedValue: 60,
            lastPlayedAt: day(2026, 6, 20), playCount: 13,
            notes: "Translucent amber vinyl. A gift — the record that converted two friends."
        )
        goldenHour.tracks = sideTracks(
            a: [("Test Card", 187), ("Golden Hour Transmission", 265), ("Warm Signal", 243), ("Vertical Hold", 221)],
            b: [("Broadcast Days", 254), ("Static Between Stations", 232), ("Sign-Off Anthem", 298)]
        )
        goldenHour.playLog = [
            PlayLogEntry(playedAt: day(2026, 6, 20), note: "Golden hour, obviously."),
        ]
        records.append(goldenHour)

        // 11
        let coldSprings = Record(
            artist: "Wren & The Wire",
            title: "Cold Springs",
            releaseYear: 1979,
            label: "Blue Larch",
            pressingDescription: "1979 original, promo stamp on back",
            artSeed: 111, artStyleRaw: CoverArtStyle.dots.rawValue,
            conditionMedia: .vg, conditionSleeve: .vg,
            storageLocation: "Crate A · Slot 19",
            purchaseDate: day(2023, 2, 14), purchasePrice: 22, estimatedValue: 35,
            lastPlayedAt: day(2026, 1, 18), playCount: 8,
            notes: "White-label promo. The stamp says \"NOT FOR SALE\" — sold anyway, forty-seven years later."
        )
        coldSprings.tracks = sideTracks(
            a: [("Cold Springs", 234), ("Wire Song", 198), ("Feather and Fence", 221), ("Northern Porch", 254)],
            b: [("Migration Patterns", 243), ("The Thaw", 276), ("Riverbed Choir", 232), ("Winter Wren", 287)]
        )
        records.append(coldSprings)

        // 12
        let neonOrchard = Record(
            artist: "Kilowatt Choir",
            title: "Neon Orchard",
            releaseYear: 1986,
            label: "Voltage Lane",
            pressingDescription: "1986 original, embossed sleeve",
            artSeed: 112, artStyleRaw: CoverArtStyle.rings.rawValue,
            conditionMedia: .vgPlus, conditionSleeve: .nearMint,
            storageLocation: "Crate C · Slot 10",
            purchaseDate: day(2025, 5, 31), purchasePrice: 33, estimatedValue: 45,
            lastPlayedAt: day(2026, 5, 2), playCount: 5,
            notes: "Embossed fruit pattern on the jacket catches the light."
        )
        neonOrchard.tracks = sideTracks(
            a: [("Orchard Gate", 212), ("Neon Fruit", 243), ("Harvest Voltage", 265), ("Glow Season", 231)],
            b: [("Circuit Cider", 254), ("Midnight Picking", 276), ("The Long Row", 243), ("Lights Out in the Orchard", 312)]
        )
        records.append(neonOrchard)

        // 13 — dense package archive fixture
        let quietMachines = Record(
            artist: "Assembly Line Ballet",
            title: "Quiet Machines",
            releaseYear: 2021,
            label: "Factory Floor Editions",
            pressingDescription: "2021 deluxe Japanese edition, OBI, 180 g",
            artSeed: 113, artStyleRaw: CoverArtStyle.quadrants.rawValue,
            conditionMedia: .mint, conditionSleeve: .mint,
            storageLocation: "Display Shelf · Front",
            purchaseDate: day(2025, 11, 8), purchasePrice: 95, estimatedValue: 140,
            lastPlayedAt: day(2026, 6, 25), playCount: 3,
            notes: "The complete-package grail. Everything the deluxe edition shipped with, all accounted for."
        )
        quietMachines.tracks = sideTracks(
            a: [("Power On", 198), ("Quiet Machines", 276), ("Conveyor Waltz", 243), ("Pneumatic Heart", 232)],
            b: [("Assembly Line Ballet", 305), ("Lubrication Hymn", 221), ("Shift Change", 254), ("Power Down", 342)]
        )
        quietMachines.attachments = [
            PackageAttachment(kind: .obiStrip, title: "Japanese OBI strip", condition: .mint, notes: "Text intact, no fading.", placementSeed: 131),
            PackageAttachment(kind: .poster, title: "Factory blueprint poster", condition: .mint, notes: "Never unfolded past the first crease.", placementSeed: 132),
            PackageAttachment(kind: .lyricInsert, title: "Bilingual lyric insert", condition: .mint, placementSeed: 133),
            PackageAttachment(kind: .receipt, title: "Tower of Wax receipt", condition: .nearMint, notes: "Original purchase receipt from Osaka.", placementSeed: 134),
            PackageAttachment(kind: .hypeSticker, title: "Deluxe edition hype sticker", condition: .mint, placementSeed: 135),
            PackageAttachment(kind: .booklet, title: "24-page production booklet", condition: .mint, placementSeed: 136),
            PackageAttachment(kind: .signedItem, title: "Signed setlist card", condition: .nearMint, notes: "Both members, silver pen.", placementSeed: 137),
            PackageAttachment(kind: .innerSleeve, title: "Anti-static audiophile inner", condition: .mint, placementSeed: 138),
        ]
        quietMachines.playLog = [
            PlayLogEntry(playedAt: day(2026, 6, 25), note: "Careful ceremony. White gloves optional but used."),
        ]
        records.append(quietMachines)

        // 14
        let driftworks = Record(
            artist: "Sea of Wires",
            title: "Driftworks Vol. II",
            releaseYear: 1998,
            label: "Undertow Audio",
            format: "2×12\" LP, 33 RPM",
            pressingDescription: "1998 original, double LP",
            artSeed: 114, artStyleRaw: CoverArtStyle.wave.rawValue,
            conditionMedia: .vgPlus, conditionSleeve: .vgPlus,
            storageLocation: "Crate B · Slot 14",
            purchaseDate: day(2022, 10, 30), purchasePrice: 38, estimatedValue: 65,
            lastPlayedAt: day(2026, 6, 10), playCount: 17,
            notes: "Volume I still missing from the collection — see wishlist."
        )
        driftworks.tracks = sideTracks(
            a: [("Drift 07", 421), ("Cable Bay", 356), ("Undertow", 398)],
            b: [("Drift 09", 387), ("Salt on the Circuit", 334), ("Drift 11 (Coda)", 456)]
        )
        records.append(driftworks)

        return records
    }

    // MARK: Wishlist

    static func makeWishlist() -> [WishlistItem] {
        [
            WishlistItem(
                artist: "Polar Freight",
                title: "Aurora Substation",
                releaseYear: 1977,
                targetPressing: "1977 UK first pressing, textured jacket",
                maxPrice: 180,
                priority: 1,
                shopLinks: ["https://example.com/waxhound/aurora-substation", "https://example.com/crate-atlas/polar-freight"],
                notes: "The one. Only original pressings have the extended B3.",
                artSeed: 201, artStyleRaw: CoverArtStyle.rings.rawValue
            ),
            WishlistItem(
                artist: "Sea of Wires",
                title: "Driftworks Vol. I",
                releaseYear: 1996,
                targetPressing: "1996 original, double LP",
                maxPrice: 90,
                priority: 1,
                shopLinks: ["https://example.com/waxhound/driftworks-1"],
                notes: "Completes the pair with Vol. II on the shelf.",
                artSeed: 202, artStyleRaw: CoverArtStyle.wave.rawValue
            ),
            WishlistItem(
                artist: "The Paper Suns",
                title: "Evening Census",
                releaseYear: 1969,
                targetPressing: "1969 original mono, any condition above VG",
                maxPrice: 75,
                priority: 2,
                shopLinks: [],
                notes: "Follow-up to Meridian Line. Mono only.",
                artSeed: 203, artStyleRaw: CoverArtStyle.quadrants.rawValue
            ),
            WishlistItem(
                artist: "Ferric",
                title: "Oxide Hymnal",
                releaseYear: 1992,
                targetPressing: "Original 1992, clear vinyl variant preferred",
                maxPrice: 60,
                priority: 2,
                shopLinks: ["https://example.com/crate-atlas/ferric-oxide-hymnal"],
                notes: "Reissue is fine if clear variant never surfaces.",
                artSeed: 204, artStyleRaw: CoverArtStyle.dots.rawValue
            ),
            WishlistItem(
                artist: "Vela Nova",
                title: "Terrazzo",
                releaseYear: 1983,
                targetPressing: "1983 Japanese pressing with OBI",
                maxPrice: 110,
                priority: 3,
                shopLinks: ["https://example.com/tokyo-spindle/vela-nova-terrazzo"],
                notes: "Japanese press is quieter. OBI must be present.",
                artSeed: 205, artStyleRaw: CoverArtStyle.beam.rawValue
            ),
            WishlistItem(
                artist: "Kilowatt Choir",
                title: "Substation Sessions",
                releaseYear: 1989,
                targetPressing: "Any pressing, sleeve condition matters more",
                maxPrice: 25,
                priority: 3,
                shopLinks: [],
                notes: "Casual want. Shows up in dollar bins occasionally.",
                artSeed: 206, artStyleRaw: CoverArtStyle.rings.rawValue
            ),
        ]
    }

    static func makeExtraWishlist() -> [WishlistItem] {
        [
            WishlistItem(
                artist: "Ondine Marrow",
                title: "Southern Survey",
                releaseYear: 1974,
                targetPressing: "1974 original with intact map",
                maxPrice: 200,
                priority: 1,
                shopLinks: ["https://example.com/waxhound/southern-survey"],
                notes: "Companion to the Northern Survey record.",
                artSeed: 207, artStyleRaw: CoverArtStyle.wave.rawValue
            ),
            WishlistItem(
                artist: "Harbor Lights Assembly",
                title: "High Tide Frequencies",
                releaseYear: 2006,
                targetPressing: "2006 original, 45 RPM cut",
                maxPrice: 85,
                priority: 2,
                shopLinks: [],
                notes: "",
                artSeed: 208, artStyleRaw: CoverArtStyle.dots.rawValue
            ),
            WishlistItem(
                artist: "Motor Temple",
                title: "Ashline (jacket only)",
                releaseYear: 2011,
                targetPressing: "Original jacket to reunite with orphaned disc",
                maxPrice: 20,
                priority: 2,
                shopLinks: [],
                notes: "The disc on the shelf deserves better than a white sleeve.",
                artSeed: 209, artStyleRaw: CoverArtStyle.beam.rawValue
            ),
            WishlistItem(
                artist: "Glass Meridian",
                title: "Day Bureau (Remixes)",
                releaseYear: 2020,
                targetPressing: "Limited 12\", 500 copies",
                maxPrice: 55,
                priority: 3,
                shopLinks: ["https://example.com/crate-atlas/day-bureau"],
                notes: "",
                artSeed: 210, artStyleRaw: CoverArtStyle.rings.rawValue
            ),
        ]
    }

    // MARK: Helpers

    private static func sideTracks(
        a: [(String, Int)],
        b: [(String, Int)]
    ) -> [Track] {
        let sideA = a.enumerated().map { index, item in
            Track(side: .a, trackNumber: index + 1, title: item.0, duration: item.1)
        }
        let sideB = b.enumerated().map { index, item in
            Track(side: .b, trackNumber: index + 1, title: item.0, duration: item.1)
        }
        return sideA + sideB
    }

    private static func seedMissingProductionRecords(into context: ModelContext, existingRecords: [Record]) {
        let existingKeys = Set(existingRecords.map(AlbumKey.init))
        for record in makeProductionRecords() where !existingKeys.contains(AlbumKey(record)) {
            context.insert(record)
        }
    }

    @discardableResult
    private static func removeLegacyFixtureContent(
        records: [Record],
        wishlist: [WishlistItem],
        from context: ModelContext
    ) -> Bool {
        var changed = false

        for record in records where legacyFixtureRecordKeys.contains(AlbumKey(record)) {
            context.delete(record)
            changed = true
        }

        for item in wishlist where legacyFixtureWishlistKeys.contains(AlbumKey(item)) {
            context.delete(item)
            changed = true
        }

        return changed
    }

    private struct AlbumKey: Hashable {
        var artist: String
        var title: String

        init(artist: String, title: String) {
            self.artist = artist.seedKeyNormalized
            self.title = title.seedKeyNormalized
        }

        init(_ record: Record) {
            self.init(artist: record.artist, title: record.title)
        }

        init(_ item: WishlistItem) {
            self.init(artist: item.artist, title: item.title)
        }
    }

    private static let legacyFixtureRecordKeys: Set<AlbumKey> = [
        AlbumKey(artist: "Glass Meridian", title: "Night Bureau"),
        AlbumKey(artist: "Copper Veldt", title: "Signal Fires"),
        AlbumKey(artist: "The Paper Suns", title: "Meridian Line"),
        AlbumKey(artist: "Vela Nova", title: "Concrete Garden"),
        AlbumKey(artist: "Harbor Lights Assembly", title: "Low Tide Frequencies"),
        AlbumKey(artist: "Ferric", title: "Static Bloom"),
        AlbumKey(artist: "Ondine Marrow", title: "The Cartographer's Waltz and Other Songs from the Northern Survey Expedition"),
        AlbumKey(artist: "June Reverie", title: "Palomino"),
        AlbumKey(artist: "Motor Temple", title: "Ashline"),
        AlbumKey(artist: "The Analog Society", title: "Golden Hour Transmission"),
        AlbumKey(artist: "Wren & The Wire", title: "Cold Springs"),
        AlbumKey(artist: "Kilowatt Choir", title: "Neon Orchard"),
        AlbumKey(artist: "Assembly Line Ballet", title: "Quiet Machines"),
        AlbumKey(artist: "Sea of Wires", title: "Driftworks Vol. II"),
    ]

    private static let legacyFixtureWishlistKeys: Set<AlbumKey> = [
        AlbumKey(artist: "Polar Freight", title: "Aurora Substation"),
        AlbumKey(artist: "Sea of Wires", title: "Driftworks Vol. I"),
        AlbumKey(artist: "The Paper Suns", title: "Evening Census"),
        AlbumKey(artist: "Ferric", title: "Oxide Hymnal"),
        AlbumKey(artist: "Vela Nova", title: "Terrazzo"),
        AlbumKey(artist: "Kilowatt Choir", title: "Substation Sessions"),
        AlbumKey(artist: "Ondine Marrow", title: "Southern Survey"),
        AlbumKey(artist: "Harbor Lights Assembly", title: "High Tide Frequencies"),
        AlbumKey(artist: "Motor Temple", title: "Ashline (jacket only)"),
        AlbumKey(artist: "Glass Meridian", title: "Day Bureau (Remixes)"),
    ]
}

private extension String {
    var seedKeyNormalized: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
