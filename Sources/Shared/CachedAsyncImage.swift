import SwiftUI
import AppKit
import ImageIO

final class ImageMemoryCache: @unchecked Sendable {
    static let shared = ImageMemoryCache()
    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 40 * 1024 * 1024
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: NSImage, for url: URL, cost: Int) {
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    func clear() {
        cache.removeAllObjects()
    }

    func findImage(forSong song: Song) -> NSImage? {
        let base = song.thumbnailUrl
        if base.isEmpty { return nil }
        let candidates = [
            base,
            base.thumbnailSized(for: 500),
            base.thumbnailSized(for: 512),
            base.thumbnailSized(for: 600),
            base.thumbnailSized(for: 440),
            base.thumbnailSized(for: 320),
            base.thumbnailSized(for: 200),
            base.thumbnailSized(for: 100),
            base.thumbnailSized(for: 80)
        ]
        for c in candidates {
            if let u = URL(string: c), let img = image(for: u) {
                return img
            }
        }
        return nil
    }

    func jpegData(for image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}

public enum CachedImagePhase {
    case empty
    case success(Image)
    case failure(any Error)

    public var image: Image? {
        if case .success(let img) = self { return img }
        return nil
    }

    public var error: (any Error)? {
        if case .failure(let err) = self { return err }
        return nil
    }
}

public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let targetDimension: CGFloat?
    private let phaseContent: ((CachedImagePhase) -> Content)?
    private let imageContent: ((Image) -> Content)?
    private let placeholderContent: (() -> Placeholder)?

    @State private var phase: CachedImagePhase = .empty

    public init(
        url: URL?,
        targetDimension: CGFloat? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.targetDimension = targetDimension
        self.imageContent = content
        self.placeholderContent = placeholder
        self.phaseContent = nil
        if let url, let cached = ImageMemoryCache.shared.image(for: url) {
            _phase = State(initialValue: .success(Image(nsImage: cached)))
        }
    }

    public init(
        url: URL?,
        targetDimension: CGFloat? = nil,
        @ViewBuilder content: @escaping (CachedImagePhase) -> Content
    ) where Placeholder == EmptyView {
        self.url = url
        self.targetDimension = targetDimension
        self.phaseContent = content
        self.imageContent = nil
        self.placeholderContent = nil
        if let url, let cached = ImageMemoryCache.shared.image(for: url) {
            _phase = State(initialValue: .success(Image(nsImage: cached)))
        }
    }

    @ViewBuilder
    public var body: some View {
        Group {
            if let phaseContent {
                phaseContent(phase)
            } else if let imageContent, let placeholderContent {
                switch phase {
                case .success(let img):
                    imageContent(img)
                default:
                    placeholderContent()
                }
            } else {
                EmptyView()
            }
        }
        .task(id: url) {
            guard let url else {
                phase = .empty
                return
            }
            if let cached = ImageMemoryCache.shared.image(for: url) {
                phase = .success(Image(nsImage: cached))
                return
            }
            let targetDim = targetDimension ?? Self.targetDimension(for: url)
            guard let (data, resp) = try? await NetworkSession.shared.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let img = Self.downsampleImage(data: data, maxDimension: targetDim) else {
                phase = .failure(URLError(.badServerResponse))
                return
            }
            let bitmapBytes: Int
            if let rep = img.representations.first {
                bitmapBytes = rep.pixelsWide * rep.pixelsHigh * 4
            } else {
                bitmapBytes = Int(img.size.width * img.size.height * 4)
            }
            ImageMemoryCache.shared.insert(img, for: url, cost: max(bitmapBytes, data.count))
            phase = .success(Image(nsImage: img))
        }
    }

    private static nonisolated func targetDimension(for url: URL?) -> CGFloat {
        guard let urlStr = url?.absoluteString else { return 300 }
        for prefix in ["=w", "=s"] {
            if let range = urlStr.range(of: prefix) {
                let digits = urlStr[range.upperBound...].prefix(while: \.isNumber)
                if let d = Double(digits) {
                    return d <= 120 ? max(CGFloat(d), 64) : min(CGFloat(d) * 1.5, 768)
                }
            }
        }
        if let match = urlStr.range(of: "(\\d+)x(\\d+)", options: .regularExpression) {
            let parts = urlStr[match].split(separator: "x")
            if let first = parts.first, let d = Double(first) {
                return d <= 120 ? max(CGFloat(d), 64) : min(CGFloat(d) * 1.5, 768)
            }
        }
        return 300
    }

    private static nonisolated func downsampleImage(data: Data, maxDimension: CGFloat = 360) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return NSImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return NSImage(data: data)
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
