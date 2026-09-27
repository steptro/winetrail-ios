import SwiftUI
import PhotosUI

/// Photo selection component for the Log Tasting flow.
///
/// Two prominent action buttons (Take Photo + Choose from Library), a photo count indicator,
/// and a horizontal scroll of selected photo thumbnails with remove buttons.
struct PhotoPickerView: View {
    /// Binding to the view model's selected images array.
    @Binding var selectedImages: [UIImage]

    /// Maximum number of photos allowed.
    let maxPhotos: Int = 5

    /// Number of existing photos already saved on the tasting (used in edit flows).
    var existingPhotoCount: Int = 0

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var showCamera = false

    private var totalPhotoCount: Int {
        existingPhotoCount + selectedImages.count
    }

    private var canAddMore: Bool {
        totalPhotoCount < maxPhotos
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            if canAddMore {
                actionButtons
            }

            // Photo count
            Label(
                "\(totalPhotoCount)/\(maxPhotos) photos",
                systemImage: "photo.on.rectangle"
            )
            .font(Theme.captionFont)
            .foregroundStyle(.secondary)

            if isLoadingPhotos {
                HStack(spacing: Theme.smallSpacing) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading photos...")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }

            if !selectedImages.isEmpty {
                selectedPhotosScroll
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                if let image, totalPhotoCount < maxPhotos {
                    selectedImages.append(image)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: Theme.smallSpacing) {
            // Take Photo button
            Button {
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.wineAccent)

            // Choose from Library button
            PhotosPicker(
                selection: $photoPickerItems,
                maxSelectionCount: maxPhotos - totalPhotoCount,
                matching: .images
            ) {
                Label("Library", systemImage: "photo.on.rectangle")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.wineAccent)
            .onChange(of: photoPickerItems) { _, newItems in
                Task { await loadPhotos(from: newItems) }
            }
        }
    }

    // MARK: - Selected Photos Horizontal Scroll

    @ViewBuilder
    private var selectedPhotosScroll: some View {
        VStack(alignment: .leading, spacing: 2) {
            if selectedImages.count > 1 {
                Text("Drag to reorder")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
            }

            ReorderablePhotoStrip(
                images: selectedImages,
                onMove: { from, to in moveImage(from: from, to: to) },
                onRemove: { index in removeImage(at: index) }
            )
            .frame(height: 84)
        }
    }

    /// Moves a selected image from one position to another.
    private func moveImage(from: Int, to: Int) {
        guard selectedImages.indices.contains(from),
              selectedImages.indices.contains(to),
              from != to else { return }
        let image = selectedImages.remove(at: from)
        selectedImages.insert(image, at: to)
    }

    // MARK: - Photo Loading

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isLoadingPhotos = true

        for item in items {
            guard totalPhotoCount < maxPhotos else { break }

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
