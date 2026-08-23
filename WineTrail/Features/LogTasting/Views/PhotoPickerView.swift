import SwiftUI
import PhotosUI

/// Photo selection component for the Log Tasting flow.
///
/// Supports selecting from the photo library OR taking a new photo with the camera.
/// Displays selected photos in a horizontal scroll view, enforces a maximum of 5 photos,
/// and provides add/remove functionality.
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
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            headerView

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

    // MARK: - Header with Add Buttons

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Label(
                "\(totalPhotoCount)/\(maxPhotos) photos",
                systemImage: "photo.on.rectangle"
            )
            .font(Theme.captionFont)
            .foregroundStyle(.secondary)

            Spacer()

            if canAddMore {
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .font(Theme.captionFont)
                        .foregroundStyle(.wineAccent)
                }

                PhotosPicker(
                    selection: $photoPickerItems,
                    maxSelectionCount: maxPhotos - totalPhotoCount,
                    matching: .images
                ) {
                    Label("Library", systemImage: "photo")
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
