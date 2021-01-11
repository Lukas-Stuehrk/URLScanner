import SwiftUI
import AVFoundation
import Combine

struct UrlScannerView: View {
    private let cameraControl: CameraControl
    private let videoFrameProcessing: VideoFrameProcessing
    private let urlPublisher: Publishers.RemoveDuplicates<Publishers.ReceiveOn<PassthroughSubject<URL?, Never>, DispatchQueue>>
    private let highlightsPublisher: PassthroughSubject<[CGRect], Never>
    private let highlights: Publishers.ReceiveOn<PassthroughSubject<[CGRect], Never>, DispatchQueue>

    // We don't process the full camera image, instead we only process a smaller region of it. This rectangular
    // describes the position of the region of interest in the camera stream in normalized coordinates, where the origin
    // is the upper-left corner.
    private let regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 0.2)

    @State var currentUrl: URL?

    init() {
        let cameraControl = CameraControl()
        self.cameraControl = cameraControl
        let urlPublishSubject = PassthroughSubject<URL?, Never>()
        self.urlPublisher = urlPublishSubject.receive(on: DispatchQueue.main).removeDuplicates()
        let highlightPublishSubject = PassthroughSubject<[CGRect], Never>()
        self.highlightsPublisher = highlightPublishSubject
        self.highlights = highlightPublishSubject.receive(on: DispatchQueue.main)
        var dropped = 0
        self.videoFrameProcessing = VideoFrameProcessing(captureSession: cameraControl.captureSession, regionOfInterest: regionOfInterest) { frameResult in
            switch frameResult {
            case .noMatch:
                dropped += 1
                // TODO: 8 frames is an arbitrary value. Try different values or even go with a more sophisticated
                //       approach.
                if dropped > 8 {
                    urlPublishSubject.send(nil)
                }
                highlightPublishSubject.send([])
            case .urlExtracted(let urlString, count: let count, regions: let regions):
                dropped = 0
                // TODO: 8 frames is an arbitrary value. Try different values or even go with a more sophisticated
                //       approach.
                if count > 8, let url = URL(string: urlString) {
                    urlPublishSubject.send(url)
                }
                highlightPublishSubject.send(regions)
            }
        }
    }
    
    func start() {
        videoFrameProcessing.start()
        highlightsPublisher.send([])
    }

    func stop() {
        videoFrameProcessing.stop()
    }

    var body: some View {

        CameraLiveView(
            captureSession: cameraControl.captureSession,
            regionOfInterest: regionOfInterest,
            highlights: highlights
        )
            .overlay(
                GeometryReader { geometry in
                    VStack {
                        if let url = currentUrl {
                            UrlPreview(url: url)
                                .frame(height: geometry.size.height * 0.8)
                                .offset(y: geometry.size.height * 0.2)
                                .overlay(
                                    Button(action: start) {
                                        HStack {
                                            Image(systemName: "doc.text.viewfinder")
                                            Text("Scan again")
                                        }
                                        .padding()
                                    }
                                    .background(Color(UIColor.secondarySystemBackground).cornerRadius(4))
                                    .padding()
                                    .offset(y: geometry.size.height * 0.2),
                                    alignment: .bottomTrailing
                                )
                        }
                    }
                }
            )
            .onReceive(urlPublisher) {
                self.currentUrl = $0
                if $0 != nil {
                    self.stop()
                }
            }

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        UrlScannerView()
    }
}
