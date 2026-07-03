import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum CoverArtCropMath {
    static let minimumScale = 1.0
    static let maximumScale = 3.5
    static let maximumOffset = 0.42

    static func clampedScale(_ scale: Double) -> Double {
        min(max(scale, minimumScale), maximumScale)
    }

    static func clampedOffset(_ offset: Double) -> Double {
        min(max(offset, -maximumOffset), maximumOffset)
    }
}

struct CoverArtworkImageView: View {
    var imageData: Data
    var scale: Double = 1
    var offsetX: Double = 0
    var offsetY: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            #if canImport(UIKit)
            if let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
                    .frame(width: side, height: side)
                    .scaleEffect(CoverArtCropMath.clampedScale(scale))
                    .offset(
                        x: side * CoverArtCropMath.clampedOffset(offsetX),
                        y: side * CoverArtCropMath.clampedOffset(offsetY)
                    )
                    .frame(width: side, height: side)
                    .clipped()
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            } else {
                Color.black.opacity(0.08)
            }
            #else
            Color.black.opacity(0.08)
            #endif
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

