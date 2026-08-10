import SwiftUI
import PhotosUI

/// Photo selection component for the Log Tasting flow.
///
/// Wraps `PhotosUI.PhotosPicker` for selecting images, displays selected photos
/// in a horizontal scroll view, enforces a maximum of 5 photos, and provides
/// add/remove functionality. Photos are compressed before upload via PhotoService.
struct PhotoPickerView: View {
    /// Binding to the view model's selected images array.
    @Binding var selectedImages: [UIImage]

    /// Maximum number of photos allowed.
    let maxPhotos: Int = 5

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false

    private var canAddMore: Bool {
        selectedImages.count < maxPhotos
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            headerView

            if !selectedImages.isEmpty {
                selectedPhotosScroll
            }
        }
    }

    // MARK: - Header with Add Button

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Label(
                "\(selectedImages.count)/\(maxPhotos) photos",
                systemImage: "photo.on.rectangle"
            )
            .font(Theme.captionFont)
            .foregroundStyle(.secondary)

            Spacer()

            if canAddMore {
                PhotosPicker(
                    selection: $photoPickerItems,
                    maxSelectionCount: maxPhotos - selectedImages.count,
                    matching: .images
                ) {
                    Label("Add", systemImage: "plus")
                        .font(Theme.captionFont)
                        .foregroundStyle(.wineAccent)
                }
                .onChange(of: photoPickerItems) { _, newItems in
                    Task { await loadPhotos(from: newItems) }
                }
            }
        }

        if isLoadingPhotos {
            HStack(spacing: Theme.smallSpacing) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading photos...")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Selected Photos Horizontal Scroll

    @ViewBuilder
    private var selectedPhotosScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.smallSpacing) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                    photoThumbnail(image: image, index: index)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func photoThumbnail(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))

            Button {
                removeImage(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .offset(x: 4, y: -4)
            .accessibilityLabel("Remove photo \(index + 1)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Photo \(index + 1) of \(selectedImages.count)")
    }

    // MARK: - Photo Loading

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isLoadingPhotos = true

        for item in items {
            guard selectedImages.count < maxPhotos else { break }

            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImages.append(image)
            }
        }

        // Clear picker items so user can pick again
        photoPickerItems = []
        isLoadingPhotos = false
    }

    // MARK: - Removal

    private func removeImage(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages.remove(at: index)
    }
}

#Preview {
    @Previewable @State var images: [UIImage] = []
    Form {
        Section("Photos") {
            PhotoPickerView(selectedImages: $images)
        }
    }
}
