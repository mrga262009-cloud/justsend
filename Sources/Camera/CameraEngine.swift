import AVFoundation
import CoreImage
import Photos
import SwiftUI
import UIKit

@MainActor
final class CameraEngine: NSObject, ObservableObject {
    enum Status: String { case idle, configuring, ready, denied, failed }

    @Published private(set) var status: Status = .idle
    @Published private(set) var isRecording = false
    @Published private(set) var recordingProgress: Double = 0   // 0...1 of max duration
    @Published private(set) var lastError: String?
    @Published var selectedFilter: FilterDescriptor?
    @Published var intensity: Double = 0.75
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var cameraPosition: AVCaptureDevice.Position = .front
    @Published var gridEnabled = false
    @Published var mirrorFront = true

    /// Locket Gold-style 60-second capture; free tier is 15 seconds.
    var maxDuration: TimeInterval { isPlus ? 60 : 15 }
    var isPlus: Bool = false

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.justsend.camera.session", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var recordingStart: Date?
    private var progressTimer: Timer?
    private var currentDevice: AVCaptureDevice?
    private var videoDelegate: VideoDelegate?

    // MARK: - Setup

    func configure() async {
        status = .configuring
        let granted = await requestAccess()
        guard granted else {
            status = .denied
            lastError = "Camera or microphone access denied. Enable it in Settings."
            return
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            self.buildInputs()
            if self.session.canAddOutput(self.photoOutput) { self.session.addOutput(self.photoOutput) }
            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
                let conn = self.movieOutput.connection(with: .video)
                conn?.videoRotationAngle = 90
            }
            self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:
                                                kCVPixelFormatType_32BGRA]
            self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
            if self.session.canAddOutput(self.videoOutput) { self.session.addOutput(self.videoOutput) }
            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async { self.status = .ready }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func requestAccess() async -> Bool {
        let cam = await withCheckedContinuation { c in
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: c.resume(returning: true)
            case .notDetermined: AVCaptureDevice.requestAccess(for: .video) { c.resume(returning: $0) }
            default: c.resume(returning: false)
            }
        }
        let mic = await withCheckedContinuation { c in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: c.resume(returning: true)
            case .notDetermined: AVCaptureDevice.requestAccess(for: .audio) { c.resume(returning: $0) }
            default: c.resume(returning: false)
            }
        }
        return cam && mic
    }

    private func buildInputs() {
        for input in session.inputs { session.removeInput(input) }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition)
                ?? AVCaptureDevice.default(for: .video) else { return }
        currentDevice = device
        try? device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        device.unlockForConfiguration()
        try? session.addInput(AVCaptureDeviceInput(device: device))
        if let audio = AVCaptureDevice.default(for: .audio), let ai = try? AVCaptureDeviceInput(device: audio) {
            if session.canAddInput(ai) { session.addInput(ai) }
        }
    }

    func flipCamera() {
        cameraPosition = cameraPosition == .front ? .back : .front
        sessionQueue.async { [weak self] in
            self?.session.beginConfiguration()
            self?.buildInputs()
            self?.session.commitConfiguration()
        }
    }

    func bindPreview(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        layer.session = session
        layer.videoGravity = .resizeAspectFill
    }

    // MARK: - Capture

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { [weak self] continuation in
            guard let self else { continuation.resume(returning: nil); return }
            let settings = AVCapturePhotoSettings()
            settings.flashMode = flashMode
            let delegate = PhotoDelegate { [weak self] image in
                guard let self, let image else { continuation.resume(returning: nil); return }
                let ci = CIImage(image: image) ?? CIImage()
                let filtered = FilterRenderer.apply(self.selectedFilter, to: ci, intensity: self.intensity)
                continuation.resume(returning: UIImage(ciImage: filtered))
            }
            photoOutput.capturePhoto(with: settings, delegate: delegate)
            _ = delegate // retained by capturePhoto
        }
    }

    func startRecording() {
        guard !isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("js-\(UUID().uuidString).mov")
        movieOutput.startRecording(to: url, recordingDelegate: videoDelegate ?? VideoDelegate())
        isRecording = true
        recordingStart = Date()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] t in
            guard let self, let start = self.recordingStart else { t.invalidate(); return }
            let elapsed = Date().timeIntervalSince(start)
            let remaining = self.maxDuration - elapsed
            Task { @MainActor in
                self.recordingProgress = min(1, elapsed / self.maxDuration)
                if remaining <= 0 { self.stopRecording(); t.invalidate() }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        movieOutput.stopRecording()
        isRecording = false
        recordingProgress = 0
        progressTimer?.invalidate()
        progressTimer = nil
    }

    /// Photobooth: four 1-second frames composed into a 2x2 strip.
    func capturePhotobooth() async -> UIImage? {
        var frames: [UIImage] = []
        for _ in 0..<4 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let img = await capturePhoto() else { return nil }
            frames.append(img)
        }
        return composeGrid(frames)
    }

    private func composeGrid(_ images: [UIImage]) -> UIImage? {
        guard images.count == 4 else { return nil }
        let size = images[0].size
        let output = UIGraphicsImageRenderer(size: CGSize(width: size.width * 2, height: size.height * 2))
        return output.image { ctx in
            for (i, img) in images.enumerated() {
                let x = CGFloat(i % 2) * size.width
                let y = CGFloat(i / 2) * size.height
                img.draw(in: CGRect(x: x, y: y, width: size.width, height: size.height))
            }
        }
    }

    // MARK: - Export

    func saveToPhotos(_ image: UIImage) async {
        let status = await withCheckedContinuation { c in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { c.resume(returning: $0) }
        }
        guard status == .authorized || status == .limited else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}

// MARK: - Delegates

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    init(_ completion: @escaping (UIImage?) -> Void) { self.completion = completion }
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { completion(nil); return }
        completion(image)
    }
}

private final class VideoDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) { }
}
