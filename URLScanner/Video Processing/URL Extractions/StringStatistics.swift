struct StringStatistics {

    let bufferSize: Int

    private(set) var mostSeen: (string: String, count: Int) = (string: "", count: 0)

    private var countByString = [String: Int]()
    private var seenStrings = [String]()

    init(bufferSize: Int) {
        self.bufferSize = bufferSize
    }

    mutating func processFrame(strings: [String]) {
        for string in strings {
            seenStrings.append(string)

            if countByString[string] == nil {
                countByString[string] = -1
            }
            countByString[string]? += 1

            if let currentCount = countByString[string], currentCount >= mostSeen.count {
                mostSeen = (string: string, currentCount)
            }
        }

        let toRemove = seenStrings.count - bufferSize
        guard toRemove > 0 else { return }
        for _ in 0..<toRemove {
            let string = seenStrings.removeFirst()
            countByString[string]? -= 1
            if mostSeen.string == string {
                mostSeen.count -= 1
            }
        }
    }
}
