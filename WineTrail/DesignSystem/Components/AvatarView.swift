import SwiftUI

/// A circular user avatar that loads a presigned `avatarUrl` (with caching) and
/// falls back to a person placeholder when the user has no avatar or the URL is nil.
///
/// Used everywhere a user is shown — own profile, other users' profiles, feed post
/// authors, comment authors, friend lists, likes, and user search — so avatars render
/// consistently from one component.
struct AvatarView: View {
    /// The presigned avatar URL string, or nil when the user has no avatar.
    let urlString: String?

    /// Diameter of the circular avatar.
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(.wineAccent)
    }
}

#Preview {
    HStack(spacing: 12) {
        AvatarView(urlString: nil, size: 88)
        AvatarView(urlString: nil, size: 40)
    }
    .padding()
}
