import AVFoundation
import Foundation


struct CameraControl {

    let captureSession = AVCaptureSession()
    private let captureSessionQueue = DispatchQueue(label: "net.stuehrk.lukas.Augmented-Reading.CaptureSessionQueue")
    private let errors: [CameraControl.Error]

    init() {
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) else {
            self.errors = [.fatal("Could not create device")]
            return
        }
        if captureDevice.supportsSessionPreset(.hd4K3840x2160) {
            captureSession.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160
        } else {
            captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        }
        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            self.errors = [.fatal("Could not create input")]
            return
        }
        guard captureSession.canAddInput(deviceInput) else {
            self.errors = [.fatal("Could not add input")]
            return
        }
        captureSession.addInput(deviceInput)

        var errors = [CameraControl.Error]()
        // Set zoom and autofocus to help focus on very small text.
        do {
            try captureDevice.lockForConfiguration()
            captureDevice.videoZoomFactor = 2
            captureDevice.autoFocusRangeRestriction = .near
            captureDevice.unlockForConfiguration()
        } catch let error {
            errors.append(.impairing(error))
        }
        self.errors = errors
    }
}


extension CameraControl {
    enum Error: Swift.Error {
        case fatal(String)
        case impairing(Swift.Error)
    }
}
