// The mirror photo that stops the morning alarm. It has to be taken with the
// camera right now (not picked from the photo library), and a face has to be in it.
import SwiftUI
import UIKit
import Vision

struct AlarmView: View {
    var stopped: () -> Void
    @State private var camera = false
    @State private var checking = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "alarm.fill").font(.system(size: 64)).foregroundColor(doitGreen)
            Text("GOOD MORNING.").font(.system(size: 40, weight: .black)).multilineTextAlignment(.center)
            Text("Get up, go to the mirror, and take a photo of yourself. The alarm keeps going off until you do.")
                .multilineTextAlignment(.center).foregroundColor(.secondary)
            if !camera {
                AlarmVideo()
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            if let message { Text(message).bold().foregroundColor(.red).multilineTextAlignment(.center) }
            Spacer()
            Button { camera = true } label: {
                Text(checking ? "Checking..." : "Open camera").bold().frame(maxWidth: .infinity, minHeight: 60)
            }
            .buttonStyle(.borderedProminent)
            .foregroundColor(.black)
            .disabled(checking)
        }
        .padding(28)
        .fullScreenCover(isPresented: $camera) {
            Camera { image in
                camera = false
                guard let image else { return }
                checking = true
                hasFace(image) { found in
                    checking = false
                    if found {
                        Task { await MorningAlarm.photoTaken(); stopped() }
                    } else {
                        message = "I couldn't see your face. Stand in front of the mirror with good light and try again."
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func hasFace(_ image: UIImage, done: @escaping (Bool) -> Void) {
        guard let cg = image.cgImage else { return done(false) }
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .init(image.imageOrientation))
            try? handler.perform([request])
            let found = !(request.results ?? []).isEmpty
            DispatchQueue.main.async { done(found) }
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// The iPhone camera, camera only.
struct Camera: UIViewControllerRepresentable {
    var done: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraDevice = .rear
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}
