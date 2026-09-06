import SwiftUI
import UIKit

/// A camera capture view for the label scanner that does NOT dismiss itself.
///
/// Unlike `CameraView`, the delegate here does not call `picker.dismiss(...)`.
/// Dismissal is driven solely by the SwiftUI presentation binding via `onFinish`,
/// which prevents a double-dismiss (UIKit + SwiftUI) from tearing down the
/// parent wizard sheet.
struct LabelScanCameraView: UIViewControllerRepresentable {
    /// Called with the captured image (or nil on cancel). The caller is
    /// responsible for setting the presentation binding to false.
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Do NOT dismiss here — let SwiftUI's binding own dismissal.
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
