import Testing
import Foundation
import SwiftData
@testable import InnerSleeve

@Suite(.serialized)
struct InnerSleeveSerializedTests {}

// MARK: - Carousel geometry

extension InnerSleeveSerializedTests {
    @Suite(.serialized)
    struct CarouselGeometryTests {

    @Test func heroRecordSitsAtCenterFullSize() {
        let geometry = CarouselGeometry()
        let placement = geometry.placement(forOffset: 0)
        #expect(abs(placement.x) < 0.001)
        #expect(abs(placement.scale - 1.0) < 0.001)
        #expect(abs(placement.rotationDegrees) < 0.001)
        #expect(abs(placement.opacity - 1.0) < 0.001)
        #expect(placement.blur == 0)
    }

    @Test func xPositionIsStrictlyIncreasingAcrossOffsets() {
        let geometry = CarouselGeometry()
        var previousX = -Double.infinity
        for step in stride(from: -6.0, through: 6.0, by: 0.5) {
            let x = geometry.placement(forOffset: step).x
            #expect(x > previousX, "x must increase monotonically so records never cross")
            previousX = x
        }
    }

    @Test func neighborsRecedeInScaleAndOpacity() {
        let geometry = CarouselGeometry()
        let hero = geometry.placement(forOffset: 0)
        let near = geometry.placement(forOffset: 1)
        let far = geometry.placement(forOffset: 4)
        #expect(hero.scale > near.scale)
        #expect(near.scale > far.scale)
        #expect(hero.opacity > near.opacity)
        #expect(near.opacity > far.opacity)
        #expect(far.blur > near.blur)
    }

    @Test func neighborScaleMakesHeroDominant() {
        let geometry = CarouselGeometry()
        let hero = geometry.placement(forOffset: 0)
        let neighbor = geometry.placement(forOffset: 1)
        #expect(abs(neighbor.scale - 0.40) < 0.001)
        #expect(hero.scale / neighbor.scale >= 2.2)
    }

    @Test func edgeClusterClearsLargeHeroDisc() {
        let geometry = CarouselGeometry()
        let hero = geometry.placement(forOffset: 0)
        let neighbor = geometry.placement(forOffset: 1)
        let heroEdge = 340.0 / 2.0 * hero.scale
        #expect(neighbor.x - heroEdge > 0)
    }

    @Test func heroStaysOnTopByDistanceFromCenter() {
        let geometry = CarouselGeometry()
        var previousZ = Double.infinity
        for step in stride(from: 0.0, through: 6.0, by: 0.5) {
            let z = geometry.placement(forOffset: step).zIndex
            #expect(z < previousZ || step == 0)
            previousZ = z
        }
    }

    @Test func rotationIsClampedToSeventyTwoDegrees() {
        let geometry = CarouselGeometry()
        for step in stride(from: -8.0, through: 8.0, by: 0.5) {
            let rotation = geometry.placement(forOffset: step).rotationDegrees
            #expect(rotation >= -72.0 && rotation <= 72.0)
        }
    }

    @Test func placementIsSymmetric() {
        let geometry = CarouselGeometry()
        let left = geometry.placement(forOffset: -2)
        let right = geometry.placement(forOffset: 2)
        #expect(abs(left.x + right.x) < 0.001)
        #expect(abs(left.scale - right.scale) < 0.001)
        #expect(abs(left.rotationDegrees + right.rotationDegrees) < 0.001)
    }

    @Test func snapTargetRoundsToNearestRecord() {
        #expect(CarouselGeometry.snapTarget(position: 2.3, velocity: 0, count: 10) == 2)
        #expect(CarouselGeometry.snapTarget(position: 2.6, velocity: 0, count: 10) == 3)
    }

    @Test func snapTargetProjectsFlickVelocity() {
        let flicked = CarouselGeometry.snapTarget(position: 2.0, velocity: 12, count: 10)
        #expect(flicked > 2)
    }

    @Test func snapTargetClampsToCollectionBounds() {
        #expect(CarouselGeometry.snapTarget(position: -3, velocity: -50, count: 10) == 0)
        #expect(CarouselGeometry.snapTarget(position: 14, velocity: 50, count: 10) == 9)
        #expect(CarouselGeometry.snapTarget(position: 0, velocity: 0, count: 0) == 0)
    }

    @Test func rubberBandSoftensOutOfRangeDrags() {
        let past = CarouselGeometry.rubberBand(-2, count: 10)
        #expect(past > -2 && past < 0)
        let beyond = CarouselGeometry.rubberBand(11, count: 10)
        #expect(beyond < 11 && beyond > 9)
        let inside = CarouselGeometry.rubberBand(4.5, count: 10)
        #expect(inside == 4.5)
    }
    }
}

// MARK: - Sleeve pull math

extension InnerSleeveSerializedTests {
    @Suite(.serialized)
    struct SleevePullMathTests {

        @Test func progressClampsTranslation() {
            #expect(SleevePullMath.progress(for: -40) == 0)
            #expect(SleevePullMath.progress(for: 190) == 1)
            #expect(SleevePullMath.progress(for: 380) == 1)
        }

        @Test func thresholdCrossingFiresOnlyWhenEnteringRevealZone() {
            #expect(SleevePullMath.crossedThreshold(previous: 0.4, current: 0.62))
            #expect(!SleevePullMath.crossedThreshold(previous: 0.7, current: 0.8))
            #expect(!SleevePullMath.crossedThreshold(previous: 0.2, current: 0.5))
        }

        @Test func releaseResolutionUsesThreshold() {
            #expect(!SleevePullMath.resolvesRevealed(progress: 0.61))
            #expect(SleevePullMath.resolvesRevealed(progress: 0.62))
            #expect(SleevePullMath.recordOffset(progress: 1) == 194)
        }

        @Test func coverArtCropMathClampsUserAdjustments() {
            #expect(CoverArtCropMath.clampedScale(0.2) == 1.0)
            #expect(CoverArtCropMath.clampedScale(5.0) == 3.5)
            #expect(CoverArtCropMath.clampedOffset(-0.9) == -0.42)
            #expect(CoverArtCropMath.clampedOffset(0.9) == 0.42)
        }
    }
}

// MARK: - Release lookup and add flow

extension InnerSleeveSerializedTests {
    @Suite(.serialized)
    struct ReleaseLookupTests {

        @Test func sideParserReadsCatalogPositions() {
            #expect(ReleaseSideParser.side(from: "A1") == .a)
            #expect(ReleaseSideParser.side(from: "b03") == .b)
            #expect(ReleaseSideParser.side(from: "1") == nil)
            #expect(ReleaseSideParser.number(from: "B12", fallback: 4) == 12)
            #expect(ReleaseSideParser.number(from: nil, fallback: 4) == 4)
        }

        @Test func sideParserSplitsUnmarkedTracksAcrossSides() {
            let tracks = [
                TrackCandidate(side: nil, number: 1, title: "One"),
                TrackCandidate(side: nil, number: 2, title: "Two"),
                TrackCandidate(side: nil, number: 3, title: "Three"),
                TrackCandidate(side: nil, number: 4, title: "Four"),
                TrackCandidate(side: nil, number: 5, title: "Five"),
            ]

            let assigned = ReleaseSideParser.assignSidesIfMissing(tracks)

            #expect(assigned.map(\.side) == [.a, .a, .a, .b, .b])
            #expect(assigned.map(\.number) == [1, 2, 3, 1, 2])
        }

        @Test func musicBrainzTextQueryUsesArtistReleaseSplits() {
            let query = ReleaseSearchTuning.musicBrainzQuery(for: "kind of blue miles davis")

            #expect(query.contains("release:(kind AND of AND blue)"))
            #expect(query.contains("artist:(miles AND davis)"))
        }

        @Test func musicBrainzTextQuerySplitsLongClassicAlbumQueries() {
            let query = ReleaseSearchTuning.musicBrainzQuery(for: "pink floyd dark side of the moon")

            #expect(query.contains("artist:(pink AND floyd)"))
            #expect(query.contains("release:(dark AND side AND of AND the AND moon)"))
        }

        @Test func searchRankingPrefersExactTitleArtistMatchOverReversedMatch() {
            let reversed = ReleaseCandidate(
                id: "reversed",
                artist: "Abbey Road",
                title: "Enjoy The Beatles!",
                year: nil,
                label: nil,
                catalogNumber: nil,
                format: nil,
                country: nil,
                barcode: nil,
                coverArtURL: nil,
                tracks: []
            )
            let expected = ReleaseCandidate(
                id: "expected",
                artist: "The Beatles",
                title: "Abbey Road",
                year: 1969,
                label: nil,
                catalogNumber: nil,
                format: nil,
                country: nil,
                barcode: nil,
                coverArtURL: nil,
                tracks: []
            )

            let ranked = ReleaseSearchTuning.ranked([reversed, expected], for: "abbey road beatles")

            #expect(ranked.first?.id == "expected")
        }

        @Test func albumDeduplicationKeepsFirstRankedCandidate() {
            let first = ReleaseCandidate(
                id: "first",
                artist: "Pink Floyd",
                title: "The Dark Side of the Moon",
                year: 1973,
                label: "Harvest",
                catalogNumber: nil,
                format: nil,
                country: nil,
                barcode: nil,
                coverArtURL: nil,
                tracks: []
            )
            let duplicate = ReleaseCandidate(
                id: "duplicate",
                artist: "pink floyd",
                title: "The Dark Side of the Moon",
                year: 2016,
                label: "Pink Floyd Records",
                catalogNumber: nil,
                format: nil,
                country: nil,
                barcode: nil,
                coverArtURL: nil,
                tracks: []
            )
            let other = ReleaseCandidate(
                id: "other",
                artist: "Pink Floyd",
                title: "Wish You Were Here",
                year: 1975,
                label: "Harvest",
                catalogNumber: nil,
                format: nil,
                country: nil,
                barcode: nil,
                coverArtURL: nil,
                tracks: []
            )

            let deduped = ReleaseSearchTuning.deduplicatedByAlbum([first, duplicate, other])

            #expect(deduped.map(\.id) == ["first", "other"])
        }

        @Test func musicBrainzArtworkCandidatesDoNotDedupeSameAlbumReleases() async throws {
            let service = makeMusicBrainzService { request in
                #expect(request.url?.query?.contains("limit=25") == true)
                return (Data(Self.musicBrainzDuplicateAlbumSearchJSON.utf8), 200, [:])
            }

            let results = try await service.artworkCandidates(text: "taylor swift midnights")

            #expect(results.map(\.id) == [
                "mb:missing-artwork-release",
                "mb:found-artwork-release",
            ])
        }

        @MainActor
        @Test func recordDraftSaveCreatesRecordAndTracks() {
            var draft = RecordDraft()
            draft.artist = "Draft Artist"
            draft.title = "Draft Album"
            draft.releaseYear = 2026
            draft.label = "Draft Label"
            draft.catalogNumber = "DR-1"
            draft.barcode = "999"
            draft.sourceReference = "mb:test"
            draft.coverArtURL = URL(string: "https://example.com/cover-1200.jpg")
            draft.coverImageData = Data([1, 2, 3])
            draft.coverArtScale = 1.8
            draft.coverArtOffsetX = -0.12
            draft.coverArtOffsetY = 0.2
            draft.labelArtScale = 2.1
            draft.labelArtOffsetX = 0.18
            draft.labelArtOffsetY = -0.16
            draft.tracks = [
                TrackDraft(side: .a, number: 1, title: "A Song", duration: 90),
                TrackDraft(side: .b, number: 1, title: "B Song", duration: 120),
                TrackDraft(side: .b, number: 2, title: "   ", duration: 180),
            ]

            let record = Record(draft: draft)

            #expect(record.artist == "Draft Artist")
            #expect(record.catalogNumber == "DR-1")
            #expect(record.barcode == "999")
            #expect(record.sourceReference == "mb:test")
            #expect(record.coverArtSourceURL == "https://example.com/cover-1200.jpg")
            #expect(record.coverImageData == Data([1, 2, 3]))
            #expect(record.coverArtScaleValue == 1.8)
            #expect(record.coverArtOffsetXValue == -0.12)
            #expect(record.coverArtOffsetYValue == 0.2)
            #expect(record.labelArtScaleValue == 2.1)
            #expect(record.labelArtOffsetXValue == 0.18)
            #expect(record.labelArtOffsetYValue == -0.16)
            #expect(record.tracks.count == 2)
            #expect(record.tracksSideA.first?.title == "A Song")
            #expect(record.tracksSideB.first?.duration == 120)
        }

        @MainActor
        @Test func musicBrainzCoverArtURLPrefersTwelveHundredPixelImage() {
            let record = Record(
                artist: "Pink Floyd",
                title: "The Dark Side Of The Moon",
                releaseYear: 1973,
                label: "Harvest",
                pressingDescription: "LP",
                sourceReference: "mb:test-release-id",
                coverArtSourceURL: "https://coverartarchive.org/release/test-release-id/front-500",
                artSeed: 42,
                storageLocation: "Shelf"
            )

            #expect(record.highDefinitionCoverArtURL?.absoluteString == "https://coverartarchive.org/release/test-release-id/front-1200")
        }

        @MainActor
        @Test func refetchedArtworkPersistsDataAndSourceURLOnRecord() {
            let record = Record(
                artist: "Taylor Swift",
                title: "Midnights",
                releaseYear: 2022,
                label: "Republic",
                pressingDescription: "LP",
                sourceReference: "mb:test-release-id",
                coverImageData: Data([1]),
                coverArtSourceURL: "https://coverartarchive.org/release/test-release-id/front-500",
                artSeed: 13,
                storageLocation: "Shelf"
            )
            let replacement = Data([9, 8, 7])
            let sourceURL = URL(string: "https://coverartarchive.org/release/test-release-id/front-1200")!

            record.applyRefetchedArtwork(replacement, sourceURL: sourceURL)

            #expect(record.coverImageData == replacement)
            #expect(record.coverArtSourceURL == sourceURL.absoluteString)
        }

        @Test func artworkRefreshPolicyAllowsMissingAndLowResolutionImagesToRefresh() {
            #expect(CoverArtRefreshPolicy.shouldRefresh(existingMaxPixelDimension: nil, hasImageData: false))
            #expect(CoverArtRefreshPolicy.shouldRefresh(existingMaxPixelDimension: 500, hasImageData: true))
            #expect(!CoverArtRefreshPolicy.shouldRefresh(existingMaxPixelDimension: 1200, hasImageData: true))
            #expect(CoverArtRefreshPolicy.shouldRefresh(existingMaxPixelDimension: 1200, hasImageData: true, force: true))
        }

        @Test func artworkRefetcherTriesLaterMusicBrainzCandidatesWhenFirstArtworkIsMissing() async {
            let missing = URL(string: "https://coverartarchive.org/release/missing/front-1200")!
            let found = URL(string: "https://coverartarchive.org/release/found/front-1200")!
            let expected = Data([4, 5, 6])
            let refetcher = CoverArtRefetcher(
                lookupService: StubReleaseLookupService(candidates: [
                    ReleaseCandidate(
                        id: "mb:missing",
                        artist: "Taylor Swift",
                        title: "Midnights",
                        year: 2022,
                        label: nil,
                        catalogNumber: nil,
                        format: nil,
                        country: "AU",
                        barcode: nil,
                        coverArtURL: missing,
                        tracks: []
                    ),
                    ReleaseCandidate(
                        id: "mb:found",
                        artist: "Taylor Swift",
                        title: "Midnights",
                        year: 2022,
                        label: nil,
                        catalogNumber: nil,
                        format: nil,
                        country: "CA",
                        barcode: nil,
                        coverArtURL: found,
                        tracks: []
                    ),
                ]),
                loader: StubCoverArtLoader(responses: [found: expected])
            )

            let result = await refetcher.refetch(
                savedURL: nil,
                artist: "Taylor Swift",
                title: "Midnights",
                forceLookup: true
            )

            #expect(result?.data == expected)
            #expect(result?.sourceURL == found)
        }

        @Test func artworkRefetcherUsesArtworkCandidateLookupWhenAvailable() async {
            let missing = URL(string: "https://coverartarchive.org/release/missing/front-1200")!
            let found = URL(string: "https://coverartarchive.org/release/found/front-1200")!
            let expected = Data([1, 4, 9])
            let refetcher = CoverArtRefetcher(
                lookupService: StubArtworkCandidateLookupService(
                    searchCandidates: [
                        ReleaseCandidate(
                            id: "mb:missing",
                            artist: "Taylor Swift",
                            title: "Midnights",
                            year: 2022,
                            label: nil,
                            catalogNumber: nil,
                            format: nil,
                            country: "AU",
                            barcode: nil,
                            coverArtURL: missing,
                            tracks: []
                        ),
                    ],
                    artworkCandidates: [
                        ReleaseCandidate(
                            id: "mb:missing",
                            artist: "Taylor Swift",
                            title: "Midnights",
                            year: 2022,
                            label: nil,
                            catalogNumber: nil,
                            format: nil,
                            country: "AU",
                            barcode: nil,
                            coverArtURL: missing,
                            tracks: []
                        ),
                        ReleaseCandidate(
                            id: "mb:found",
                            artist: "Taylor Swift",
                            title: "Midnights",
                            year: 2022,
                            label: nil,
                            catalogNumber: nil,
                            format: nil,
                            country: "CA",
                            barcode: nil,
                            coverArtURL: found,
                            tracks: []
                        ),
                    ]
                ),
                loader: StubCoverArtLoader(responses: [found: expected])
            )

            let result = await refetcher.refetch(
                savedURL: nil,
                artist: "Taylor Swift",
                title: "Midnights",
                forceLookup: true
            )

            #expect(result?.data == expected)
            #expect(result?.sourceURL == found)
        }

        @Test func artworkRefetcherFallsBackFromTwelveHundredToFiveHundred() async {
            let hd = URL(string: "https://coverartarchive.org/release/test/front-1200")!
            let fallback = URL(string: "https://coverartarchive.org/release/test/front-500")!
            let expected = Data([7, 8, 9])
            let refetcher = CoverArtRefetcher(
                lookupService: StubReleaseLookupService(candidates: []),
                loader: StubCoverArtLoader(responses: [fallback: expected])
            )

            let result = await refetcher.refetch(
                savedURL: hd,
                artist: "Artist",
                title: "Album",
                forceLookup: false
            )

            #expect(result?.data == expected)
            #expect(result?.sourceURL == fallback)
        }

        @Test func musicBrainzBarcodeHitMapsFixture() async throws {
            let service = makeMusicBrainzService { request in
                #expect(request.value(forHTTPHeaderField: "User-Agent")?.contains("InnerSleeve/1.0") == true)
                #expect(request.url?.query?.contains("barcode:123456789012") == true)
                return (try fixtureData("musicbrainz-search"), 200, [:])
            }

            let results = try await service.search(barcode: "123456789012")

            #expect(results.count == 1)
            #expect(results.first?.artist == "Test Artist")
            #expect(results.first?.title == "Fixture Nights")
            #expect(results.first?.year == 1987)
            #expect(results.first?.label == "Fixture Records")
            #expect(results.first?.catalogNumber == "FIX-001")
            #expect(results.first?.coverArtURL?.absoluteString.contains("coverartarchive.org") == true)
        }

        @Test func musicBrainzDetailsMapsTracksAndLabels() async throws {
            let service = makeMusicBrainzService { _ in
                (try fixtureData("musicbrainz-detail"), 200, [:])
            }
            let candidate = ReleaseCandidate(
                id: "mb:11111111-2222-3333-4444-555555555555",
                artist: "Fallback",
                title: "Fallback",
                year: nil,
                label: nil,
                catalogNumber: nil,
                format: nil,
                country: nil,
                barcode: nil,
                coverArtURL: nil,
                tracks: []
            )

            let detailed = try await service.details(for: candidate)

            #expect(detailed.artist == "Test Artist")
            #expect(detailed.tracks.map(\.side) == [.a, .a, .b])
            #expect(detailed.tracks.map(\.number) == [1, 2, 1])
            #expect(detailed.tracks.first?.seconds == 184)
            #expect(detailed.coverArtURL?.absoluteString == "https://coverartarchive.org/release/11111111-2222-3333-4444-555555555555/front-1200")
        }

        @Test func musicBrainzNoResultsThrowsNotFound() async {
            let service = makeMusicBrainzService { _ in
                (Data(#"{"releases":[]}"#.utf8), 200, [:])
            }

            await expectLookupError(.notFound) {
                _ = try await service.search(text: "missing album")
            }
        }

        @Test func musicBrainzServiceUnavailableThrowsRateLimited() async {
            let service = makeMusicBrainzService { _ in
                (Data(), 503, [:])
            }

            await expectLookupError(.rateLimited) {
                _ = try await service.search(text: "busy")
            }
        }

        @Test func discogsSearchToleratesLooseFieldShapes() async throws {
            let service = makeDiscogsService { request in
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Discogs token=test-token")
                return (Data(Self.discogsLooseSearchJSON.utf8), 200, ["x-discogs-ratelimit-remaining": "58"])
            }

            let results = try await service.search(text: "pink floyd")

            #expect(results.count == 2)
            #expect(results.first?.artist == "Pink Floyd")
            #expect(results.first?.title == "The Dark Side Of The Moon")
            #expect(results.first?.year == 1973)
            #expect(results.first?.label == "Harvest")
            #expect(results.first?.catalogNumber == "11163")
            #expect(results.first?.barcode == "123456")
            #expect(results.last?.coverArtURL?.absoluteString == "https://example.com/cover.jpg")
        }

        @Test func discogsDetailsToleratesLooseFieldShapes() async throws {
            let service = makeDiscogsService { _ in
                (Data(Self.discogsLooseReleaseJSON.utf8), 200, ["x-discogs-ratelimit-remaining": "57"])
            }
            let candidate = ReleaseCandidate(
                id: "dc:12345",
                artist: "Pink Floyd",
                title: "The Dark Side Of The Moon",
                year: nil,
                label: nil,
                catalogNumber: nil,
                format: nil,
                country: nil,
                barcode: nil,
                coverArtURL: nil,
                tracks: []
            )

            let detailed = try await service.details(for: candidate)

            #expect(detailed.artist == "Pink Floyd")
            #expect(detailed.label == "Harvest")
            #expect(detailed.catalogNumber == "11163")
            #expect(detailed.tracks.count == 2)
            #expect(detailed.tracks.map(\.number) == [1, 2])
            #expect(detailed.tracks.first?.seconds == 210)
            #expect(detailed.coverArtURL?.absoluteString == "https://example.com/detail-cover.jpg")
        }

        private func makeMusicBrainzService(
            handler: @escaping (URLRequest) throws -> (Data, Int, [String: String])
        ) -> MusicBrainzService {
            FixtureURLProtocol.handler = handler
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [FixtureURLProtocol.self]
            return MusicBrainzService(
                session: URLSession(configuration: configuration),
                throttle: RequestThrottle(minimumDelay: 0)
            )
        }

        private func makeDiscogsService(
            handler: @escaping (URLRequest) throws -> (Data, Int, [String: String])
        ) -> DiscogsService {
            FixtureURLProtocol.handler = handler
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [FixtureURLProtocol.self]
            return DiscogsService(
                tokenProvider: { "test-token" },
                session: URLSession(configuration: configuration)
            )
        }

        private func fixtureData(_ name: String) throws -> Data {
            let bundle = Bundle(for: FixtureBundleMarker.self)
            let url = bundle.url(forResource: name, withExtension: "json")
                ?? bundle.url(
                forResource: name,
                withExtension: "json",
                subdirectory: "Fixtures"
            )
            guard let url else {
                throw FixtureError.missingFixture(name)
            }
            return try Data(contentsOf: url)
        }

        private func expectLookupError(
            _ expected: ReleaseLookupError,
            operation: () async throws -> Void
        ) async {
            do {
                try await operation()
                Issue.record("Expected \(expected)")
            } catch let error as ReleaseLookupError {
                #expect(error == expected)
            } catch {
                Issue.record("Expected \(expected), got \(error)")
            }
        }

        private static let discogsLooseSearchJSON = """
        {
          "results": [
            {
              "id": "12345",
              "title": "Pink Floyd - The Dark Side Of The Moon",
              "year": "1973",
              "label": "Harvest",
              "catno": 11163,
              "country": 840,
              "barcode": "123456",
              "cover_image": false
            },
            {
              "id": 67890,
              "title": "Pink Floyd - Wish You Were Here",
              "year": 1975,
              "label": ["Columbia"],
              "catno": "PC 33453",
              "barcode": ["654321"],
              "cover_image": "https://example.com/cover.jpg"
            }
          ]
        }
        """

        private static let discogsLooseReleaseJSON = """
        {
          "id": "12345",
          "title": "The Dark Side Of The Moon",
          "year": "1973",
          "country": 840,
          "labels": [
            { "name": "Harvest", "catno": 11163 }
          ],
          "formats": [
            { "name": "Vinyl" }
          ],
          "artists": [
            { "name": "Pink Floyd" }
          ],
          "tracklist": [
            { "position": "A1", "title": "Speak To Me", "duration": 210, "type_": "track" },
            { "position": "A2", "title": "Breathe", "duration": "2:43", "type_": "track" },
            { "position": "", "title": "Side B", "type_": "heading" }
          ],
          "images": [
            { "uri": "https://example.com/back-cover.jpg", "type": "secondary" },
            { "uri": "https://example.com/detail-cover.jpg", "uri150": 12345, "type": "primary" }
          ]
        }
        """

        private static let musicBrainzDuplicateAlbumSearchJSON = """
        {
          "releases": [
            {
              "id": "missing-artwork-release",
              "title": "Midnights",
              "date": "2022-10-21",
              "country": "AU",
              "artist-credit": [{ "name": "Taylor Swift" }]
            },
            {
              "id": "found-artwork-release",
              "title": "Midnights",
              "date": "2022-10-21",
              "country": "CA",
              "artist-credit": [{ "name": "Taylor Swift" }]
            }
          ]
        }
        """
    }
}

private final class FixtureBundleMarker {}

private enum FixtureError: Error {
    case missingFixture(String)
}

private struct StubReleaseLookupService: ReleaseLookupService {
    var candidates: [ReleaseCandidate]

    func search(text: String) async throws -> [ReleaseCandidate] {
        candidates
    }

    func search(barcode: String) async throws -> [ReleaseCandidate] {
        candidates
    }

    func details(for candidate: ReleaseCandidate) async throws -> ReleaseCandidate {
        candidate
    }
}

private struct StubArtworkCandidateLookupService: ReleaseLookupService, CoverArtCandidateLookupService {
    var searchCandidates: [ReleaseCandidate]
    var artworkCandidates: [ReleaseCandidate]

    func search(text: String) async throws -> [ReleaseCandidate] {
        searchCandidates
    }

    func search(barcode: String) async throws -> [ReleaseCandidate] {
        searchCandidates
    }

    func details(for candidate: ReleaseCandidate) async throws -> ReleaseCandidate {
        candidate
    }

    func artworkCandidates(text: String) async throws -> [ReleaseCandidate] {
        artworkCandidates
    }
}

private struct StubCoverArtLoader: CoverArtDataLoading {
    var responses: [URL: Data]

    func loadData(from url: URL) async throws -> Data {
        guard let data = responses[url] else {
            throw ReleaseLookupError.notFound
        }
        return data
    }
}

private final class FixtureURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Data, Int, [String: String]))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: ReleaseLookupError.offline)
            return
        }

        do {
            let (data, statusCode, headers) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Model container helper

@MainActor
private struct TestModelStore {
    let container: ModelContainer
    let context: ModelContext
}

@MainActor
private func freshStore() throws -> TestModelStore {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Record.self, Track.self, PackageAttachment.self, WishlistItem.self, PlayLogEntry.self,
        configurations: configuration
    )
    return TestModelStore(container: container, context: container.mainContext)
}

// MARK: - Fixtures

extension InnerSleeveSerializedTests {
    @MainActor
    @Suite(.serialized)
    struct FixtureTests {

    @Test func fixtureCollectionIsSubstantial() {
        let records = FixtureData.makeRecords()
        #expect(records.count >= 12)
        let wishlist = FixtureData.makeWishlist()
        #expect(wishlist.count >= 5)
    }

    @Test func everyRecordHasTracksOnBothSides() {
        for record in FixtureData.makeRecords() {
            #expect(!record.tracksSideA.isEmpty, "\(record.title) is missing Side A tracks")
            #expect(!record.tracksSideB.isEmpty, "\(record.title) is missing Side B tracks")
        }
    }

    @Test func trackNumbersAreSequentialPerSide() {
        for record in FixtureData.makeRecords() {
            for side in [record.tracksSideA, record.tracksSideB] {
                let numbers = side.map(\.trackNumber)
                #expect(numbers == Array(1...side.count), "\(record.title) has non-sequential track numbers")
            }
        }
    }

    @Test func fixtureTitlesAreUnique() {
        let titles = FixtureData.makeRecords().map(\.title)
        #expect(Set(titles).count == titles.count)
    }

    @Test func fixturesIncludeEdgeCaseRecords() {
        let records = FixtureData.makeRecords()
        #expect(records.contains { !$0.hasCoverArt }, "needs a missing-cover fixture")
        #expect(records.contains { $0.title.count > 40 }, "needs a long-title fixture")
        #expect(records.contains { $0.attachments.count >= 6 }, "needs a dense package archive fixture")
        #expect(records.contains { $0.vinylAppearance == .splatter }, "needs a splatter vinyl fixture")
        #expect(records.contains { $0.playCount == 0 }, "needs a never-played fixture")
    }

    @Test func seedIfNeededSeedsOnceOnly() throws {
        let store = try freshStore()
        let context = store.context
        try FixtureData.seedIfNeeded(into: context)
        let firstCount = try context.fetchCount(FetchDescriptor<Record>())
        #expect(firstCount == 2)
        try FixtureData.seedIfNeeded(into: context)
        let secondCount = try context.fetchCount(FetchDescriptor<Record>())
        #expect(secondCount == firstCount, "seeding twice must not duplicate the collection")
    }

    @Test func productionSeedContainsPlaybackTestAlbums() throws {
        let store = try freshStore()
        let context = store.context
        try FixtureData.seedIfNeeded(into: context)
        let records = Record.shelfOrder(try context.fetch(FetchDescriptor<Record>()))

        #expect(records.map(\.title) == ["The Dark Side of the Moon", "Midnights"])
        #expect(records.allSatisfy { !$0.tracksSideA.isEmpty && !$0.tracksSideB.isEmpty })
        #expect(records.first { $0.title == "Midnights" }?.appleMusicAlbumID == "1649434004")
        #expect(records.first { $0.title == "The Dark Side of the Moon" }?.appleMusicAlbumID == "1065973699")
    }

    @Test func legacyFixtureSeedIsReplacedWithPlaybackTestAlbums() throws {
        let store = try freshStore()
        let context = store.context
        FixtureData.seedFull(into: context)
        try context.save()

        try FixtureData.seedIfNeeded(into: context)

        let records = try context.fetch(FetchDescriptor<Record>())
        let wishlist = try context.fetch(FetchDescriptor<WishlistItem>())
        #expect(records.count == 2)
        #expect(records.contains { $0.artist == "Taylor Swift" && $0.title == "Midnights" })
        #expect(records.contains { $0.artist == "Pink Floyd" && $0.title == "The Dark Side of the Moon" })
        #expect(!records.contains { $0.artist == "Glass Meridian" && $0.title == "Night Bureau" })
        #expect(!wishlist.contains { $0.artist == "Polar Freight" && $0.title == "Aurora Substation" })
    }

    @Test func showcaseSeedStillSupportsDenseArchivePreviews() throws {
        let store = try freshStore()
        let context = store.context
        FixtureData.seedFull(into: context)
        let records = try context.fetch(FetchDescriptor<Record>())
        let dense = records.first { $0.attachments.count >= 6 }
        #expect(dense != nil)
        #expect(dense!.attachments.allSatisfy { $0.record === dense })
    }
    }
}

// MARK: - Record behavior

extension InnerSleeveSerializedTests {
    @MainActor
    @Suite(.serialized)
    struct RecordBehaviorTests {

    @Test func logPlayUpdatesCountDateAndHistory() throws {
        let store = try freshStore()
        let context = store.context
        let record = Record(
            artist: "Test Artist", title: "Test Album", releaseYear: 2020,
            label: "Test Label", pressingDescription: "Test pressing",
            artSeed: 1, storageLocation: "Nowhere"
        )
        context.insert(record)

        let before = record.playCount
        let playDate = Date(timeIntervalSince1970: 1_800_000_000)
        record.logPlay(note: "First spin", at: playDate)

        #expect(record.playCount == before + 1)
        #expect(record.lastPlayedAt == playDate)
        #expect(record.playLog.count == 1)
        #expect(record.playLog.first?.note == "First spin")
    }

    @Test func shelfOrderSortsByArtistThenTitle() {
        let a = Record(artist: "Beta Band", title: "Zebra", releaseYear: 2000, label: "L", pressingDescription: "p", artSeed: 1, storageLocation: "s")
        let b = Record(artist: "Alpha Choir", title: "Middle", releaseYear: 2000, label: "L", pressingDescription: "p", artSeed: 2, storageLocation: "s")
        let c = Record(artist: "Beta Band", title: "Aardvark", releaseYear: 2000, label: "L", pressingDescription: "p", artSeed: 3, storageLocation: "s")

        let sorted = Record.shelfOrder([a, b, c])
        #expect(sorted.map(\.title) == ["Middle", "Aardvark", "Zebra"])
    }

    @Test func recentlyPlayedOrderPutsNeverPlayedLast() {
        let played = Record(artist: "A", title: "Played", releaseYear: 2000, label: "L", pressingDescription: "p", artSeed: 1, storageLocation: "s", lastPlayedAt: .now)
        let never = Record(artist: "B", title: "Never", releaseYear: 2000, label: "L", pressingDescription: "p", artSeed: 2, storageLocation: "s")

        let sorted = Record.recentlyPlayedOrder([never, played])
        #expect(sorted.first?.title == "Played")
        #expect(sorted.last?.title == "Never")
    }

    @Test func trackDurationsFormatAsMinutesSeconds() {
        let track = Track(side: .a, trackNumber: 1, title: "T", duration: 254)
        #expect(track.formattedDuration == "4:14")
        let short = Track(side: .a, trackNumber: 2, title: "S", duration: 59)
        #expect(short.formattedDuration == "0:59")
    }

    @Test func trackPlayLogStoresScrobbleMetadata() {
        let record = Record(
            artist: "Taylor Swift",
            title: "Midnights",
            releaseYear: 2022,
            label: "Republic",
            pressingDescription: "Test",
            artSeed: 1,
            storageLocation: "Test"
        )
        let track = Track(side: .b, trackNumber: 3, title: "Bejeweled", duration: 194)

        record.logTrackPlay(track: track, source: .stylusDrop, cueProgress: 0.72)

        #expect(record.playCount == 1)
        #expect(record.lastPlayedAt != nil)
        #expect(record.playLog.count == 1)
        #expect(record.playLog.first?.trackTitle == "Bejeweled")
        #expect(record.playLog.first?.trackNumber == 3)
        #expect(record.playLog.first?.trackSideRaw == "B")
        #expect(record.playLog.first?.sourceRaw == "stylusDrop")
        #expect(record.playLog.first?.cueProgress == 0.72)
    }

    @Test func conditionGradesCompareFromBestToWorst() {
        #expect(ConditionGrade.mint < ConditionGrade.nearMint)
        #expect(ConditionGrade.nearMint < ConditionGrade.fair)
        #expect(ConditionGrade.mint.shortCode == "M")
        #expect(ConditionGrade.vgPlus.shortCode == "VG+")
    }
    }
}

// MARK: - Wishlist behavior

extension InnerSleeveSerializedTests {
    @Suite(.serialized)
    struct WishlistBehaviorTests {

    @Test func huntOrderPutsGrailsFirstThenPriceDescending() {
        let casual = WishlistItem(artist: "A", title: "Casual", releaseYear: 2000, targetPressing: "any", maxPrice: 500, priority: 3, artSeed: 1)
        let grailCheap = WishlistItem(artist: "B", title: "Grail Cheap", releaseYear: 2000, targetPressing: "any", maxPrice: 40, priority: 1, artSeed: 2)
        let grailDear = WishlistItem(artist: "C", title: "Grail Dear", releaseYear: 2000, targetPressing: "any", maxPrice: 200, priority: 1, artSeed: 3)

        let sorted = WishlistItem.huntOrder([casual, grailCheap, grailDear])
        #expect(sorted.map(\.title) == ["Grail Dear", "Grail Cheap", "Casual"])
    }

    @Test func priorityLabelsReadCorrectly() {
        let item = WishlistItem(artist: "A", title: "T", releaseYear: 2000, targetPressing: "any", maxPrice: 10, priority: 1, artSeed: 1)
        #expect(item.priorityLabel == "Grail")
        item.priority = 2
        #expect(item.priorityLabel == "Hunting")
        item.priority = 3
        #expect(item.priorityLabel == "Watching")
    }
    }
}

// MARK: - Deterministic art

extension InnerSleeveSerializedTests {
    @Suite(.serialized)
    struct GenerativeArtTests {

    @Test func seededRandomIsDeterministic() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        for _ in 0..<20 {
            #expect(a.next() == b.next())
        }
    }

    @Test func differentSeedsDiverge() {
        var a = SeededRandom(seed: 1)
        var b = SeededRandom(seed: 2)
        let aValues = (0..<8).map { _ in a.next() }
        let bValues = (0..<8).map { _ in b.next() }
        #expect(aValues != bValues)
    }

    @Test func artInitialsTakeFirstTwoWords() {
        #expect("Glass Meridian".artInitials == "GM")
        #expect("The Paper Suns".artInitials == "TP")
        #expect("Ferric".artInitials == "F")
    }

    @Test func everyFixtureArtStyleRoundTrips() {
        for record in FixtureData.makeRecords() {
            #expect(CoverArtStyle(rawValue: record.artStyleRaw) != nil, "\(record.title) has an unknown art style")
        }
    }
    }
}

// MARK: - Stylus cue mapping

extension InnerSleeveSerializedTests {
    @Suite(.serialized)
    struct StylusCueMappingTests {

        @Test func edgeProgressMapsToFirstTrack() {
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0, trackCount: 1) == 0)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0, trackCount: 3) == 0)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0, trackCount: 10) == 0)
        }

        @Test func centerProgressMapsToLastTrack() {
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 1, trackCount: 1) == 0)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 1, trackCount: 3) == 2)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 1, trackCount: 10) == 9)
        }

        @Test func midpointMapsToMiddleTrack() {
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0.5, trackCount: 5) == 2)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0.5, trackCount: 10) == 5)
        }

        @Test func durationWeightedProgressMapsToTrackRuntime() {
            let durations = [60, 60, 180]

            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0.0, trackDurations: durations) == 0)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0.35, trackDurations: durations) == 1)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0.45, trackDurations: durations) == 2)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 1.0, trackDurations: durations) == 2)
        }

        @Test func durationWeightedProgressFallsBackForMissingDurations() {
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0.5, trackDurations: [0, 0, 0, 0, 0]) == 2)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 1.5, trackDurations: [60, 0, 120]) == 2)
        }

        @Test func progressIsMonotonicallyIncreasing() {
            let count = 12
            var previous = -1
            for step in stride(from: 0.0, through: 1.0, by: 0.05) {
                let index = AppleMusicDeckPlayer.stylusCueTrackIndex(progress: step, trackCount: count)
                #expect(index >= previous)
                previous = index
            }
        }

        @Test func outOfBoundsProgressClampsToValidRange() {
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: -1, trackCount: 5) == 0)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 2, trackCount: 5) == 4)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: -0.5, trackCount: 3) == 0)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 1.5, trackCount: 3) == 2)
        }

        @Test func zeroTrackCountReturnsZero() {
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0, trackCount: 0) == 0)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0.8, trackCount: 0) == 0)
        }

        @Test func singleTrackAlwaysReturnsZero() {
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0, trackCount: 1) == 0)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 0.5, trackCount: 1) == 0)
            #expect(AppleMusicDeckPlayer.stylusCueTrackIndex(progress: 1, trackCount: 1) == 0)
        }
    }
}

// MARK: - Apple Music search tuning

extension InnerSleeveSerializedTests {
    @Suite(.serialized)
    struct AppleMusicSearchTuningTests {

        @Test func catalogSearchTermsTryArtistTitleTitleArtistAndTitleOnly() {
            let terms = AppleMusicSearchTuning.catalogSearchTerms(
                artist: "Taylor Swift",
                title: "Midnights"
            )

            #expect(terms == [
                "taylor swift midnights",
                "midnights taylor swift",
                "midnights",
            ])
        }

        @Test func normalizedWordsIgnorePunctuationEditionsAndStopWords() {
            let recordWords = AppleMusicSearchTuning.normalizedWords(in: "The Dark Side of the Moon")
            let appleMusicWords = AppleMusicSearchTuning.normalizedWords(in: "Dark Side of the Moon (2011 Remaster)")

            #expect(recordWords == ["dark", "side", "moon"])
            #expect(recordWords.intersection(appleMusicWords).count == 3)
        }

        @Test func oneWordTitlesNeedOneWordOverlap() {
            let words = AppleMusicSearchTuning.normalizedWords(in: "Midnights")
            #expect(AppleMusicSearchTuning.titleOverlapThreshold(for: words) == 1)
        }

        @Test func deckTickerTextCombinesAlbumAndTrack() {
            #expect(
                AppleMusicDeckPlayer.deckTickerText(albumTitle: "Midnights", trackTitle: "Lavender Haze")
                == "Midnights  •  Lavender Haze"
            )
            #expect(AppleMusicDeckPlayer.deckTickerText(albumTitle: "Midnights", trackTitle: nil) == "Midnights")
            #expect(AppleMusicDeckPlayer.deckTickerText(albumTitle: nil, trackTitle: nil) == "No record on deck")
        }
    }
}
