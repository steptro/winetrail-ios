import SwiftUI

/// A UIScrollView-backed zoom container: pinch-to-zoom and pan handled natively by UIScrollView,
/// which owns the pinch gesture and therefore works reliably even inside a paging `TabView` (a
/// pure-SwiftUI `MagnificationGesture` gets intercepted by the TabView's own recognizers). Double
/// tap toggles between fit and 2.5x. On zoom-out it returns to fit.
///
/// Wrap the image with `ZoomableScrollView { image }`. The content is laid out at the container's
/// size; zooming happens within the container's bounds (the paging TabView clips its pages, so the
/// zoom fills the photo area rather than overflowing the whole screen).
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private let content: Content
    /// When false, the internal double-tap-to-zoom is not installed (so a host's own double-tap
    /// gesture — e.g. the feed's double-tap-to-like — wins). Defaults to true.
    private let doubleTapToZoom: Bool

    init(doubleTapToZoom: Bool = true, @ViewBuilder content: () -> Content) {
        self.doubleTapToZoom = doubleTapToZoom
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5
        scrollView.minimumZoomScale = 1
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        // Let the zoomed image draw beyond the scroll view's bounds so it overflows its frame
        // rather than being cut off at the photo area edges.
        scrollView.clipsToBounds = false
        scrollView.backgroundColor = .clear

        let hosting = context.coordinator.hostingController
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear
        scrollView.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            hosting.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        // Double tap to toggle zoom (optional so a host double-tap gesture can take precedence).
        if doubleTapToZoom {
            let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            scrollView.addGestureRecognizer(doubleTap)
        }
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hostingController: UIHostingController(rootView: content))
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>
        weak var scrollView: UIScrollView?

        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController.view
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: hostingController.view)
                let size = scrollView.bounds.size
                let zoom: CGFloat = 2.5
                let w = size.width / zoom
                let h = size.height / zoom
                let rect = CGRect(x: point.x - w / 2, y: point.y - h / 2, width: w, height: h)
                scrollView.zoom(to: rect, animated: true)
            }
        }
    }
}
