import SwiftUI
import AppKit
import ImageIO

final class ImageMemoryCache: @unchecked Sendable {
    static let shared = ImageMemoryCache()
    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 80
        cache.totalCostLimit = 30 * 1024 * 1024
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
    private let phaseContent: ((CachedImagePhase) -> Content)?
    private let imageContent: ((Image) -> Content)?
    private let placeholderContent: (() -> Placeholder)?

    @State private var phase: CachedImagePhase = .empty

    public init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.imageContent = content
        self.placeholderContent = placeholder
        self.phaseContent = nil
        if let url, let cached = ImageMemoryCache.shared.image(for: url) {
            _phase = State(initialValue: .success(Image(nsImage: cached)))
        }
    }

    public init(
        url: URL?,
        @ViewBuilder content: @escaping (CachedImagePhase) -> Content
    ) where Placeholder == EmptyView {
        self.url = url
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
            guard let (data, resp) = try? await NetworkSession.shared.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let img = Self.downsampleImage(data: data, maxDimension: 512) else {
                phase = .failure(URLError(.badServerResponse))
                return
            }
            ImageMemoryCache.shared.insert(img, for: url, cost: data.count)
            phase = .success(Image(nsImage: img))
        }
    }

    private static nonisolated func downsampleImage(data: Data, maxDimension: CGFloat = 512) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return NSImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
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
