import LinkPresentation
import SwiftUI


struct UrlPreview: View {
    let url: URL

    var body: some View {
        ScrollView {
            RichSnippetUrlPreview(url: url)
                .aspectRatio(contentMode: .fit)
                .padding()
        }
        .background(Color(UIColor.systemBackground))
    }
}


private struct RichSnippetUrlPreview: View, UIViewRepresentable {
    typealias UIViewType = LPLinkView

    let url: URL

    func makeUIView(context: Context) -> LPLinkView {
        let metadata = LPLinkMetadata()
        metadata.url = url
        // We want to display the full URL somewhere. LPLinkView only provides the host for some URLs. That's why we set
        // the full URL as title, to display the full URL in the title.
        metadata.title = url.absoluteString
        let linkView = LPLinkView(metadata: metadata)
        let metadataProvider = LPMetadataProvider()
        metadataProvider.startFetchingMetadata(for: url) { maybeMetadata, maybeError in
            if let metadata = maybeMetadata {
                DispatchQueue.main.async {
                    linkView.metadata = metadata
                    linkView.alpha = 1
                }
            }
        }
        return linkView
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {
        
    }
}
