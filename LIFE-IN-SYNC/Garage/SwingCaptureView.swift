import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
struct SwingCaptureView: View {
    let onFinished: (URL) -> Void
    let onCancel: () -> Void

    @StateObject private var coordinator = SwingCaptureCoordinator()

    var body: some View {
        ZStack {
            SwingCaptureCameraView(coordinator: coordinator)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.42),
                    Color.clear,
                    Color.black.opacity(0.58)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                topBar

                Spacer()

                bottomControls
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 24)

            if let message = coordinator.statusMessage {
                SwingCaptureStatusOverlay(message: message)
                    .padding(.horizontal, 24)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            coordinator.configure(onFinished: onFinished, onCancel: onCancel)
            coordinator.prepareCapture()
        }
        .onDisappear {
            coordinator.stopSession()
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: coordinator.cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.44))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close swing capture")

            Spacer()

            if coordinator.isRecording {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)

                    Text("REC")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.48))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                )
                .accessibilityLabel("Recording")
            }
        }
    }

    private var bottomControls: some View {
        Button(action: coordinator.toggleRecording) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 82, height: 82)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.72), lineWidth: 3)
                    )

                if coordinator.isRecording {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.red)
                        .frame(width: 34, height: 34)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 58, height: 58)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(coordinator.canRecord == false)
        .opacity(coordinator.canRecord ? 1 : 0.42)
        .accessibilityLabel(coordinator.isRecording ? "Stop swing recording" : "Start swing recording")
    }
}

@MainActor
private final class SwingCaptureCoordinator: ObservableObject {
    @Published var isRecording = false
    @Published var canRecord = false
    @Published var statusMessage: String?

    weak var controller: SwingCaptureController?

    private var onFinished: ((URL) -> Void)?
    private var onCancel: (() -> Void)?

    func configure(onFinished: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.onFinished = onFinished
        self.onCancel = onCancel
    }

    func prepareCapture() {
        statusMessage = "Preparing camera"
        requestPermissions { [weak self] granted in
            guard let self else { return }

            if granted {
                statusMessage = nil
                controller?.configureSession()
            } else {
                canRecord = false
                statusMessage = "Camera and microphone access are required to record a swing."
            }
        }
    }

    func toggleRecording() {
        guard canRecord else { return }

        if isRecording {
            controller?.stopRecording()
        } else {
            controller?.startRecording()
        }
    }

    func cancel() {
        if isRecording {
            controller?.stopRecording(shouldFinish: false)
        }

        stopSession()
        onCancel?()
    }

    func stopSession() {
        controller?.stopSession()
    }

    func markSessionReady() {
        canRecord = true
        statusMessage = nil
    }

    func markUnavailable(_ message: String) {
        canRecord = false
        statusMessage = message
    }

    func markRecording(_ recording: Bool) {
        isRecording = recording
    }

    func finishRecording(url: URL) {
        isRecording = false
        onFinished?(url)
    }

    private func requestPermissions(completion: @escaping (Bool) -> Void) {
        requestAccess(for: .video) { videoGranted in
            guard videoGranted else {
                completion(false)
                return
            }

            self.requestAccess(for: .audio) { audioGranted in
                completion(audioGranted)
            }
        }
    }

    private func requestAccess(for mediaType: AVMediaType, completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                Task { @MainActor in
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}

private struct SwingCaptureCameraView: UIViewControllerRepresentable {
    @ObservedObject var coordinator: SwingCaptureCoordinator

    func makeUIViewController(context: Context) -> SwingCaptureController {
        let controller = SwingCaptureController(coordinator: coordinator)
        coordinator.controller = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: SwingCaptureController, context: Context) {}
}

@MainActor
private final class SwingCaptureController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    private let captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "life-in-sync.garage.swing-capture.session")
    private weak var coordinator: SwingCaptureCoordinator?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var shouldFinishCurrentRecording = true

    init(coordinator: SwingCaptureCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            captureSession.beginConfiguration()
            captureSession.automaticallyConfiguresApplicationAudioSession = false
            captureSession.sessionPreset = .high

            guard configureVideoInput(), configureAudioInput(), configureMovieOutput() else {
                captureSession.commitConfiguration()
                Task { @MainActor in
                    self.coordinator?.markUnavailable("Camera is unavailable on this device.")
                }
                return
            }

            captureSession.commitConfiguration()

            Task { @MainActor in
                self.installPreviewLayerIfNeeded()
                self.coordinator?.markSessionReady()
            }

            if captureSession.isRunning == false {
                captureSession.startRunning()
            }
        }
    }

    func startRecording() {
        guard movieOutput.isRecording == false else { return }

        shouldFinishCurrentRecording = true
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("garage-swing-\(UUID().uuidString)")
            .appendingPathExtension("mov")
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
    }

    func stopRecording(shouldFinish: Bool = true) {
        shouldFinishCurrentRecording = shouldFinish

        guard movieOutput.isRecording else {
            coordinator?.markRecording(false)
            return
        }

        movieOutput.stopRecording()
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, captureSession.isRunning else { return }
            captureSession.stopRunning()
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        coordinator?.markRecording(true)
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        coordinator?.markRecording(false)

        guard shouldFinishCurrentRecording, error == nil, FileManager.default.fileExists(atPath: outputFileURL.path) else {
            return
        }

        coordinator?.finishRecording(url: outputFileURL)
    }

    private func installPreviewLayerIfNeeded() {
        guard previewLayer == nil else { return }

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    private func configureVideoInput() -> Bool {
        guard captureSession.inputs.contains(where: { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true }) == false else {
            return true
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
            return false
        }

        captureSession.addInput(input)
        return true
    }

    private func configureAudioInput() -> Bool {
        guard captureSession.inputs.contains(where: { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.audio) == true }) == false else {
            return true
        }

        guard let microphone = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: microphone),
              captureSession.canAddInput(input) else {
            return false
        }

        captureSession.addInput(input)
        return true
    }

    private func configureMovieOutput() -> Bool {
        guard captureSession.outputs.contains(movieOutput) == false else {
            return true
        }

        guard captureSession.canAddOutput(movieOutput) else {
            return false
        }

        captureSession.addOutput(movieOutput)
        return true
    }
}

private struct SwingCaptureStatusOverlay: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.62))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
            )
    }
}

#Preview("Swing Capture") {
    SwingCaptureView(
        onFinished: { _ in },
        onCancel: {}
    )
}
