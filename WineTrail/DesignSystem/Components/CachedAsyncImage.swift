import SwiftUI

/// A drop-in replacement for `AsyncImage` with in-memory and disk caching.
/// Avoids reloading photos every time the user scrolls past a cell.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task(id: url) {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url, !isLoading else { return }
        isLoading = true

        // Check memory cache
        if let cached = ImageCache.shared.get(for: url) {
            image = cached
            isLoading = false
            return
        }

        // Check disk cache
        if let diskCached = await ImageCache.shared.getFromDisk(for: url) {
            ImageCache.shared.set(diskCached, for: url)
            image = diskCached
            isLoading = false
            return
        }

        // Download
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let downloaded = UIImage(data: data) else {
                isLoading = false
                return
            }
            ImageCache.shared.set(downloaded, for: url)
            await ImageCache.shared.saveToDisk(data, for: url)
            image = downloaded
        } catch {
            // Silently fail — placeholder stays visible
        }

        isLoading = false
    }
}

// MARK: - Image Cache

/// Thread-safe in-memory + disk image cache.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL

    private init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    func get(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url.absoluteString as NSString)
    }

    func set(_ image: UIImage, for url: URL) {
        let cost = image.pngData()?.count ?? 0
        memoryCache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }

    func getFromDisk(for url: URL) async -> UIImage? {
        let fileURL = diskFileURL(for: url)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func saveToDisk(_ data: Data, for url: URL) async {
        let fileURL = diskFileURL(for: url)
        try? data.write(to: fileURL, options: .atomic)
    }

    private func diskFileURL(for url: URL) -> URL {
        let hash = url.absoluteString.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .prefix(64)
        return diskCacheURL.appendingPathComponent(String(hash))
    }
}
