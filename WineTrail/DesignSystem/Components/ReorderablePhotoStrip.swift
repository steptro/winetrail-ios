import SwiftUI
import UIKit

/// A horizontal, drag-to-reorder strip of photo thumbnails backed by a UIKit
/// `UICollectionView`. The collection view owns the long-press drag gesture natively,
/// so reordering works reliably even inside a SwiftUI `Form`/`ScrollView` — where
/// SwiftUI's own `.draggable`/`.dropDestination` fought the parent scroll and failed.
///
/// Each item shows an 80×80 rounded thumbnail with a remove (✕) button. Callers get
/// `onMove(from:to:)` and `onRemove(index:)` callbacks and own the underlying array.
struct ReorderablePhotoStrip: UIViewRepresentable {
    /// A photo to display: either a pre-loaded image (new, unsaved photos) or a remote
    /// URL loaded via the shared cache (existing, server photos).
    enum Item: Equatable {
        case image(UIImage)
        case remote(String)

        static func == (lhs: Item, rhs: Item) -> Bool {
            switch (lhs, rhs) {
            case let (.image(a), .image(b)): return a === b
            case let (.remote(a), .remote(b)): return a == b
            default: return false
            }
        }
    }

    /// The items to display, in display order.
    let items: [Item]

    /// Called when the user drags an item from one index to another.
    let onMove: (Int, Int) -> Void

    /// Called when the user taps an item's remove button.
    let onRemove: (Int) -> Void

    /// Convenience init for a strip of already-loaded images (new-photo flow).
    init(images: [UIImage], onMove: @escaping (Int, Int) -> Void, onRemove: @escaping (Int) -> Void) {
        self.items = images.map { .image($0) }
        self.onMove = onMove
        self.onRemove = onRemove
    }

    /// Designated init taking mixed items (used for remote existing photos).
    init(items: [Item], onMove: @escaping (Int, Int) -> Void, onRemove: @escaping (Int) -> Void) {
        self.items = items
        self.onMove = onMove
        self.onRemove = onRemove
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onMove: onMove, onRemove: onRemove)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 80, height: 80)
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dragInteractionEnabled = true
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.dragDelegate = context.coordinator
        collectionView.dropDelegate = context.coordinator
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseId)
        collectionView.setContentHuggingPriority(.required, for: .vertical)
        collectionView.setContentCompressionResistancePriority(.required, for: .vertical)

        context.coordinator.collectionView = collectionView
        return collectionView
    }

    func updateUIView(_ uiView: UICollectionView, context: Context) {
        context.coordinator.onMove = onMove
        context.coordinator.onRemove = onRemove
        // Reload only when the item set actually changed, to avoid interrupting a drag.
        if context.coordinator.items != items {
            context.coordinator.items = items
            uiView.reloadData()
        }
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICollectionView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? UIView.noIntrinsicMetric, height: 80)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate,
                             UICollectionViewDragDelegate, UICollectionViewDropDelegate {
        var items: [Item] = []
        var onMove: (Int, Int) -> Void
        var onRemove: (Int) -> Void
        weak var collectionView: UICollectionView?

        init(onMove: @escaping (Int, Int) -> Void, onRemove: @escaping (Int) -> Void) {
            self.onMove = onMove
            self.onRemove = onRemove
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            items.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoCell.reuseId, for: indexPath) as! PhotoCell
            cell.configure(item: items[indexPath.item]) { [weak self] in
                guard let self, let cv = self.collectionView,
                      let ip = cv.indexPath(for: cell) else { return }
                self.onRemove(ip.item)
            }
            return cell
        }

        // Drag

        func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
            let provider = NSItemProvider(object: "\(indexPath.item)" as NSString)
            let item = UIDragItem(itemProvider: provider)
            item.localObject = indexPath.item
            return [item]
        }

        func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
            UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }

        func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
            guard let dropItem = coordinator.items.first,
                  let sourceIndexPath = dropItem.sourceIndexPath else { return }

            let destinationIndexPath = coordinator.destinationIndexPath
                ?? IndexPath(item: max(items.count - 1, 0), section: 0)

            let from = sourceIndexPath.item
            let to = destinationIndexPath.item
            guard from != to else { return }

            let moved = items.remove(at: from)
            items.insert(moved, at: to)
            collectionView.performBatchUpdates {
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [destinationIndexPath])
            }
            coordinator.drop(dropItem.dragItem, toItemAt: destinationIndexPath)
            onMove(from, to)
        }
    }

    // MARK: - Cell

    final class PhotoCell: UICollectionViewCell {
        static let reuseId = "PhotoCell"

        private let imageView = UIImageView()
        private let removeButton = UIButton(type: .system)
        private var onRemove: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)

            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 8
            imageView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(imageView)

            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            removeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
            removeButton.tintColor = .white
            removeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            removeButton.layer.cornerRadius = 11
            removeButton.clipsToBounds = true
            removeButton.translatesAutoresizingMaskIntoConstraints = false
            removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
            contentView.addSubview(removeButton)

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
                imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
                imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

                removeButton.topAnchor.constraint(equalTo: contentView.topAnchor),
                removeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                removeButton.widthAnchor.constraint(equalToConstant: 22),
                removeButton.heightAnchor.constraint(equalToConstant: 22),
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func configure(item: Item, onRemove: @escaping () -> Void) {
            self.onRemove = onRemove
            currentRemoteURL = nil

            switch item {
            case let .image(image):
                imageView.image = image
            case let .remote(urlString):
                imageView.image = nil
                guard let url = URL(string: urlString) else { return }
                currentRemoteURL = url
                if let cached = ImageCache.shared.get(for: url) {
                    imageView.image = cached
                } else {
                    Task { [weak self] in
                        var loaded = await ImageCache.shared.getFromDisk(for: url)
                        if loaded == nil {
                            loaded = try? await Self.download(url)
                        }
                        let image = loaded
                        await MainActor.run { [weak self] in
                            guard let self, self.currentRemoteURL == url else { return }
                            self.imageView.image = image
                        }
                    }
                }
            }
        }

        private var currentRemoteURL: URL?

        private static func download(_ url: URL) async throws -> UIImage? {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            ImageCache.shared.set(image, for: url)
            await ImageCache.shared.saveToDisk(data, for: url)
            return image
        }

        @objc private func removeTapped() {
            onRemove?()
        }
    }
}
