import Foundation
import Vision

// FIXME: no forced try.
let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)


extension Array where Element == VNRecognizedText {
    func extractUrl() -> (url: URL, regions: [CGRect])? {
        var url: URL?
        var regions = [CGRect]()
        var allStrings = ""
        for candidate in self {
            let offset = allStrings.utf16.count
            allStrings += candidate.string
            guard let match = detector.firstMatch(in: allStrings, options: [], range: NSRange(location: 0, length: allStrings.utf16.count)) else {
                if url != nil {
                    break
                } else {
                    allStrings = ""
                    continue
                }
            }
            var actualRange = NSRange(location: match.range.location - offset, length: match.range.length)
            if actualRange.location < 0 {
                let offset2 = actualRange.location * -1
                actualRange = NSRange(location: 0, length: match.range.length - offset2)
            }
            guard let range = Range<String.Index>(actualRange, in: candidate.string) else { 
                assertionFailure()
                continue
            }
            if let boundingBox = try? candidate.boundingBox(for: range)?.boundingBox {
                regions.append(boundingBox)
            }
            url = match.url

            if range.upperBound < candidate.string.endIndex {
                break
            }
        }

        guard let unwrappedUrl = url else {
            return nil
        }
        return (url: unwrappedUrl, regions: regions)
    }
}
