import AVFoundation
import SwiftUI
import Combine


struct CameraLiveView: View, UIViewRepresentable {
    typealias UIViewType = _CameraLiveView

    let captureSession: AVCaptureSession
    let regionOfInterest: CGRect
    let highlights: AnyPublisher<[CGRect], Never>
    
    init<P: Publisher>(
        captureSession: AVCaptureSession,
        regionOfInterest: CGRect,
        highlights: P
    ) where P.Output == [CGRect], P.Failure == Never {
        self.captureSession = captureSession
        self.regionOfInterest = regionOfInterest
        self.highlights = highlights.eraseToAnyPublisher()
    }

    func makeUIView(context: Context) -> _CameraLiveView {
        let view = _CameraLiveView(regionOfInterest: regionOfInterest, highlights: highlights)
        view.captureSession = captureSession
        captureSession.startRunning() // FIXME: This does not feel right.
        return view
    }

    func updateUIView(_ uiView: _CameraLiveView, context: Context) {
        uiView.captureSession = captureSession
    }
}


class _CameraLiveView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private let regionOfInterest: CGRect
    private let maskLayer = CAShapeLayer()
    private let frameLayer = CAShapeLayer()

    private var subscriptions = Set<AnyCancellable>()

    private var currentHighlights = [CAShapeLayer]()

    override var bounds: CGRect {
        didSet {
            updateMask()
        }
    }

    override var frame: CGRect {
        didSet {
            updateMask()
        }
    }

    init(regionOfInterest: CGRect, highlights: AnyPublisher<[CGRect], Never>) {
        self.regionOfInterest = regionOfInterest
        super.init(frame: .zero)
        highlights.sink(receiveValue: { [weak self] rects in
            self?.updateHighlights(newCoordinates: rects)
        }).store(in: &subscriptions)
        maskLayer.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
        layer.insertSublayer(maskLayer, at: 1)
        layer.insertSublayer(frameLayer, at: 1)
        frameLayer.borderWidth = 4
        frameLayer.borderColor = UIColor.green.cgColor
        frameLayer.isHidden = true
        layer.backgroundColor = UIColor.black.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented. You cannot build this view from storyboards.")
    }

    var captureSession: AVCaptureSession? {
        get {
            videoLayer?.session
        }
        set {
            videoLayer?.session = newValue
            videoLayer?.connection?.videoOrientation = .landscapeRight
            // TODO: We want to find out when the frame of the camera layer changed. This only works when we have a
            //       running session. There needs to be a better way to achieve this.
            newValue?.publisher(for: \.isRunning).receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.updateMask()
            }.store(in: &subscriptions)
        }
    }

    private var videoLayer: AVCaptureVideoPreviewLayer? {
        guard let videoLayer = layer as? AVCaptureVideoPreviewLayer else {
            assertionFailure()
            return nil
        }
        return videoLayer
    }

    private func updateHighlights(newCoordinates: [CGRect]) {
        guard let videoLayer = videoLayer else {
            assertionFailure()
            return
        }
        for highlight in currentHighlights {
            highlight.removeFromSuperlayer()
        }
        currentHighlights.removeAll()

        for coordinates in newCoordinates {
            let highlight = CAShapeLayer()
            highlight.backgroundColor = UIColor.green.withAlphaComponent(0.2).cgColor
            highlight.cornerRadius = 2
            highlight.frame = videoLayer.layerRectConverted(fromMetadataOutputRect:
                // The Metadata coordinates start with (0,0) from the upper left. Vision coordinates start with (0,0)
                // from the lower left. That's why we need to translate the different origin of the y axis.
                CGRect(
                    x: coordinates.origin.x,
                    y: 1 - coordinates.origin.y - coordinates.height,
                    width: coordinates.width,
                    height: coordinates.height
                )
                // And the normalized coordinates from the vision result take only the region of interest as full size,
                // so we need to scale by the size of the region of interest.
                .applying(CGAffineTransform(scaleX: regionOfInterest.width, y: regionOfInterest.height))
                // And the region of interest does not need to start from the very top or very left, so we also need to
                // offset for its origin.
                .applying(CGAffineTransform(translationX: regionOfInterest.origin.x, y: regionOfInterest.origin.y))
            )
            videoLayer.insertSublayer(highlight, at: 1)
            currentHighlights.append(highlight)
        }
    }

    func updateMask() {
        maskLayer.frame = frame
        guard let videoLayer = videoLayer else {
            assertionFailure()
            return
        }
        let layer = CAShapeLayer()
        layer.fillRule = .evenOdd
        layer.backgroundColor = UIColor.clear.cgColor
        let cutoutFrame = videoLayer.layerRectConverted(fromMetadataOutputRect: regionOfInterest)
        let path = UIBezierPath(rect: videoLayer.layerRectConverted(fromMetadataOutputRect: .normalizedFullArea))
        path.append(UIBezierPath(rect: cutoutFrame))
        layer.path = path.cgPath
        maskLayer.mask = layer

        frameLayer.frame = cutoutFrame
        frameLayer.isHidden = false
    }
}


private extension CGRect {
    static var normalizedFullArea: CGRect {
        CGRect(x: 0, y: 0, width: 1, height: 1)
    }
}
