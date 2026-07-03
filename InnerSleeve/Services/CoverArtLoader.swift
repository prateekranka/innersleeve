import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

final class CoverArtLoader {
    private let session: URLSession
    private let maxPixelSide: CGFloat

    init(session: URLSession = .shared, maxPixelSide: CGFloat = 2048) {
        self.session = session
        self.maxPixelSide = maxPixelSide
    }

    func loadData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("InnerSleeve/1.0 (https://innersleeve.app/contact)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ReleaseLookupError.notFound
        }
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let scale = min(1, maxPixelSide / max(size.width, size.height))
        guard scale < 1 else { return image.jpegData(compressionQuality: 0.86) ?? data }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.9) ?? data
        #else
        return data
        #endif
    }

    #if canImport(UIKit)
    static func maxPixelDimension(of data: Data) -> CGFloat? {
        UIImage(data: data).map { max($0.size.width, $0.size.height) }
    }
    #endif
}

protocol CoverArtDataLoading {
    func loadData(from url: URL) async throws -> Data
}

extension CoverArtLoader: CoverArtDataLoading {}

enum CoverArtRefreshPolicy {
    static let minimumAcceptablePixelSide: CGFloat = 1000

    static func shouldRefresh(existingMaxPixelDimension: CGFloat?, hasImageData: Bool, force: Bool = false) -> Bool {
        if force { return true }
        guard hasImageData else { return true }
        guard let existingMaxPixelDimension else { return false }
        return existingMaxPixelDimension < minimumAcceptablePixelSide
    }
}
