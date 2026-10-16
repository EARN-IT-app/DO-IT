// The sink photo that stops the morning alarm. It has to be taken with the
// camera right now (not picked from the photo library), and a sink has to be in it.
import SwiftUI
import UIKit
import Vision

struct AlarmView: View {
    var stopped: () -> Void
    @State private var camera = false
    @State private var checking = false
    @State private var message: String?
    @State private var breathe = false

    var body: some View {
        ZStack {
            // The video fills the whole screen, with the words and button on top.
            if camera { Color.black.ignoresSafeArea() } else { AlarmVideo().ignoresSafeArea() }
            LinearGradient(colors: [.black.opacity(0.8), .clear, .clear, .black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 16) {
                Spacer()
                // The words sit in the middle, breathe and flip forward all the way around.
                VStack(spacing: 16) {
                    Image(systemName: "alarm.fill").font(.system(size: 96)).foregroundColor(doitGreen)
                    Text("GOOD MORNING.").font(.system(size: 80, weight: .black)).multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                    Text("Get up and take a picture of the sink. The alarm keeps going off until you do.")
                        .font(.system(size: 34, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                    if !Goal.today.isEmpty {
                        Text("Today's goal: \(Goal.today)")
                            .font(.system(size: 28, weight: .bold)).foregroundColor(doitGreen)
                            .multilineTextAlignment(.center).minimumScaleFactor(0.5)
                    }
                }
                .scaleEffect(breathe ? 1.06 : 1)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: breathe)
                .rotation3DEffect(.degrees(breathe ? -360 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: false), value: breathe)
                .onAppear { breathe = true }
                if let message { Text(message).bold().foregroundColor(.red).multilineTextAlignment(.center) }
                Spacer()
                Button { camera = true } label: {
                    Text(checking ? "Checking..." : "Open camera").bold().frame(maxWidth: .infinity, minHeight: 60)
                }
                .buttonStyle(.borderedProminent)
                .foregroundColor(.black)
                .disabled(checking)
            }
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.8), radius: 8)
            .padding(28)
        }
        .fullScreenCover(isPresented: $camera) {
            Camera { image in
                camera = false
                guard let image else { return }
                checking = true
                hasSink(image) { found in
                    checking = false
                    if found {
                        Task { await MorningAlarm.photoTaken(); stopped() }
                    } else {
                        message = "I couldn't see a sink in that picture. Get the whole sink in, with the light on, and try again."
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    /// Uses the iPhone's built-in picture labels to look for a sink.
    private func hasSink(_ image: UIImage, done: @escaping (Bool) -> Void) {
        guard let cg = image.cgImage else { return done(false) }
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .init(image.imageOrientation))
            try? handler.perform([request])
            let found = (request.results ?? []).contains { $0.identifier.contains("sink") && $0.confidence > 0.1 }
            DispatchQueue.main.async { done(found) }
        }
    }
}

/// Homework lock screen: the apps stay locked until a picture of finished
/// homework is taken. The check reads the writing in the picture.
struct HomeworkView: View {
    var finished: () -> Void
    @State private var camera = false
    @State private var checking = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "book.fill").font(.system(size: 56)).foregroundColor(doitGreen)
            Text("HOMEWORK TIME.").font(.system(size: 40, weight: .black)).multilineTextAlignment(.center)
            Text("Your apps stay locked until it's done. When you're finished, take a picture of your work. It needs to show your writing clearly.")
                .multilineTextAlignment(.center).foregroundColor(.secondary)
            if let message { Text(message).bold().foregroundColor(.red).multilineTextAlignment(.center) }
            Spacer()
            Button { camera = true } label: {
                Text(checking ? "Reading your work..." : "I'm done, open camera").bold().frame(maxWidth: .infinity, minHeight: 60)
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
                hasWriting(image) { found in
                    checking = false
                    if found { Homework.finish(); finished() }
                    else { message = "I couldn't read any work in that picture. Get the whole page in, with good light, and try again." }
                }
            }
            .ignoresSafeArea()
        }
    }

    /// Uses the iPhone's built-in text reader to look for real writing.
    private func hasWriting(_ image: UIImage, done: @escaping (Bool) -> Void) {
        guard let cg = image.cgImage else { return done(false) }
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .init(image.imageOrientation))
            try? handler.perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined()
            let found = text.filter { $0.isLetter || $0.isNumber }.count >= 25
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
