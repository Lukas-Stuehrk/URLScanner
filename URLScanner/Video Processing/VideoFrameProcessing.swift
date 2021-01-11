import AVFoundation
import Vision


class VideoFrameProcessing: NSObject {
    typealias Callback = (FrameResult) -> Void

    private let captureSession: AVCaptureSession

    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "net.stuehrk.lukas.URLScanner.VideoDataOutputQueue")

    private var request: VNRecognizeTextRequest!

    private var statistics = StringStatistics(bufferSize: 30)

    private let callback: Callback

    /// - Parameters:
    ///   - captureSession:    The capture session which is used to access the camera.
    ///   - regionOfInterest:  The region in the camera image which is used for processing text. The rectangular uses
    ///                        normalized coordinates where the origin is the upper-left corner.
    ///   - callback:          A callback which is called for every processed frame with the result of the processing.
    init(captureSession: AVCaptureSession, regionOfInterest: CGRect, callback: @escaping Callback) {
        self.captureSession = captureSession
        self.callback = callback
        super.init()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            // TODO: I did not check yet if video stabilization gives better results.
            videoDataOutput.connection(with: .video)?.preferredVideoStabilizationMode = .off
        } else {
            print("Could not add output")
        }

        videoDataOutput.connection(with: .video)?.videoOrientation = .landscapeRight

        self.request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler(request:error:))
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        // We need to use the region of interest, otherwise the OCR would take much longer than one frame to process.
        // Also: AVFoundation and UIKit always use the upper-left corner as origin (0,0). Vision takes the lower-left
        // corner, that's why we need to translate between.
        request.regionOfInterest = CGRect(
            x: regionOfInterest.origin.x,
            y: 1 - regionOfInterest.origin.y - regionOfInterest.height,
            width: regionOfInterest.width,
            height: regionOfInterest.height
        )
    }

    func start() {
        statistics = StringStatistics(bufferSize: statistics.bufferSize)
        captureSession.startRunning()
    }

    func stop() {
        captureSession.stopRunning()
    }
}


extension VideoFrameProcessing: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            // TODO: maybe assertion failure
            return
        }
        // We don't support different device orientations for now and explicitly set the video orientation, so we can
        // hardcode the orientation to "up" because our video stream always has the correct orientation. If we support
        // device rotation, we might need to pass a different value for the orientation.
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try requestHandler.perform([request])
        } catch {
            print(error)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("frame drop")
    }
}


extension VideoFrameProcessing {
    func recognizeTextHandler(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNRecognizedTextObservation] else {
            assertionFailure()
            return
        }
        var candidates = [VNRecognizedText]()
        for result in results {
            guard let candidate = result.topCandidates(1).first else { continue }
            candidates.append(candidate)
        }

        if let (url, regions) = candidates.extractUrl() {
            statistics.processFrame(strings: [url.absoluteString])
            callback(.urlExtracted(statistics.mostSeen.string, count: statistics.mostSeen.count, regions: regions))
        } else {
            callback(.noMatch)
        }
    }

    enum FrameResult {
        case urlExtracted(String, count: Int, regions: [CGRect])
        case noMatch
    }
}
