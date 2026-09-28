import UIKit
import Social
import UniformTypeIdentifiers

/// Share Extension entry point: receives an image shared from another app (Photos, Safari, …),
/// stashes it in the shared App Group container, and opens the WineTrail app on the photo-search
/// flow. The extension is a thin relay — it does no networking and holds no logged-in session;
/// the main app owns the search and the account (the WhatsApp share-sheet pattern).
class ShareViewController: UIViewController {

    /// App Group shared with the main app. Must match the app's entitlement.
    private static let appGroupId = "group.dev.stephantromer.winetrail"
    /// File name the shared image is written under, in the App Group container.
    private static let sharedImageFileName = "shared-wine-photo.jpg"
    /// Custom URL scheme the app registers to receive the hand-off.
    private static let openURL = "winetrail://search-photo"

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let image = firstSharedImageProvider() else {
            complete()
            return
        }

        loadImage(from: image) { [weak self] data in
            guard let self else { return }
            if let data { self.saveToAppGroup(data) }
            self.openHostApp()
            self.complete()
        }
    }

    /// Finds the first attachment that carries an image among the shared items.
    private func firstSharedImageProvider() -> NSItemProvider? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }

        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                return provider
            }
        }
        return nil
    }

    /// Loads the shared image as JPEG data, resolving whether the provider yields a URL,
    /// a UIImage, or raw Data.
    private func loadImage(from provider: NSItemProvider, completion: @escaping (Data?) -> Void) {
        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
            var data: Data?

            if let url = item as? URL, let fileData = try? Data(contentsOf: url) {
                data = UIImage(data: fileData)?.jpegData(compressionQuality: 0.85) ?? fileData
            } else if let image = item as? UIImage {
                data = image.jpegData(compressionQuality: 0.85)
            } else if let raw = item as? Data {
                data = UIImage(data: raw)?.jpegData(compressionQuality: 0.85) ?? raw
            }

            completion(data)
        }
    }

    /// Writes the JPEG into the shared App Group container so the main app can read it.
    private func saveToAppGroup(_ data: Data) {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupId) else { return }

        let fileURL = container.appendingPathComponent(Self.sharedImageFileName)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Opens the WineTrail app via its custom URL scheme. Walks the responder chain to reach
    /// `UIApplication.open`, which an extension cannot call directly.
    private func openHostApp() {
        guard let url = URL(string: Self.openURL) else { return }

        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url)
                return
            }
            responder = current.next
        }
    }

    /// Tells the host the share request is finished, dismissing the extension UI.
    private func complete() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
