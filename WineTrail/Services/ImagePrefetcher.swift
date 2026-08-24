import Foundation
import UIKit

/// Prefetches images for upcoming cells in scroll views.
/// Call `prefetch(urls:)` when items are about to appear.
actor ImagePrefetcher {
    static let shared = ImagePrefetcher()

    private var activeTasks: Set<URL> = []

    /// Prefetches images at the given URLs into the shared cache.
    /// Skips URLs that are already cached or being fetched.
    func prefetch(urls: [URL]) {
        for url in urls {
            guard ImageCache.shared.get(for: url) == nil,
                  !activeTasks.contains(url) else { continue }

            activeTasks.insert(url)

            Task {
                defer { activeTasks.remove(url) }

                // Check disk first
                if let diskImage = await ImageCache.shared.getFromDisk(for: url) {
                    ImageCache.shared.set(diskImage, for: url)
                    return
                }

                // Download
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let image = UIImage(data: data) else { return }

                ImageCache.shared.set(image, for: url)
                await ImageCache.shared.saveToDisk(data, for: url)
            }
        }
    }
}
