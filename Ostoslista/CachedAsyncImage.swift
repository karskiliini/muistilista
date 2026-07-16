import SwiftUI

/// AsyncImage flickers back to its placeholder every time a row is
/// recycled, because it re-fetches and re-decodes on each view identity.
/// This caches decoded images in a process-wide NSCache so thumbnails stay
/// resident while scrolling and across the row/results/detail screens.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                content(image)
            } else {
                placeholder().task(id: url) { await load() }
            }
        }
    }

    private func load() async {
        guard let url else { return }
        if let cached = ImageCache.shared.image(for: url) {
            image = cached
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else { return }
        ImageCache.shared.insert(uiImage, for: url)
        image = Image(uiImage: uiImage)
    }
}

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> Image? {
        cache.object(forKey: url as NSURL).map(Image.init(uiImage:))
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}
