import AVFoundation
import SwiftUI
import Combine


struct CameraLiveView: View, UIViewRepresentable {
    typealias UIViewType = _CameraLiveView

    let captureSession: AVCaptureSession
    let highlights: AnyPublisher<[CGRect], Never>
    
    init<P: Publisher>(captureSession: AVCaptureSession, highlights: P) where P.Output == [CGRect], P.Failure == Never {
        self.captureSession = captureSession
        self.highlights = highlights.eraseToAnyPublisher()
    }

    func makeUIView(context: Context) -> _CameraLiveView {
        let view = _CameraLiveView(highlights: highlights)
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

    private var subscriptions = Set<AnyCancellable>()

    private var currentHighlights = [CAShapeLayer]()

    init(highlights: AnyPublisher<[CGRect], Never>) {
        super.init(frame: .zero)
        highlights.sink(receiveValue: { [weak self] rects in
            self?.updateHighlights(newCoordinates: rects)
        }).store(in: &subscriptions)
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
        }
    }

    private var videoLayer: AVCaptureVideoPreviewLayer? {
        guard let videoLayer = layer as? AVCaptureVideoPreviewLayer else {
            assertionFailure()
            return nil
        }
        return videoLayer
    }

    func updateHighlights(newCoordinates: [CGRect]) {
        for highlight in currentHighlights {
            highlight.removeFromSuperlayer()
        }
        currentHighlights.removeAll()
        for coordinate in newCoordinates {
            let highlight = CAShapeLayer()
            highlight.backgroundColor = UIColor.green.withAlphaComponent(0.2).cgColor
            highlight.cornerRadius = 2
            let height = frame.height * coordinate.size.height * 0.2
            // TODO: explain and simpliy.
            highlight.frame = CGRect(
                x: frame.width * coordinate.origin.x,
                y: (frame.height * (1 - coordinate.origin.y) * 0.2) - height,
                width: frame.width * coordinate.size.width,
                height: height
            )
            layer.insertSublayer(highlight, at: 1)
            currentHighlights.append(highlight)
        }
    }
}
