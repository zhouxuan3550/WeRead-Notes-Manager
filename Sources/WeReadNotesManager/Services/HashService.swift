import Foundation
import CryptoKit

enum HashService {
    static func generateHash(
        source: String,
        sourceID: String?,
        bookTitle: String,
        author: String?,
        chapter: String?,
        highlight: String,
        userNote: String?,
        location: String?
    ) -> String {
        if let sourceID = sourceID, !sourceID.isEmpty {
            return sha256("\(source):\(sourceID)")
        }
        var components = [bookTitle.normalizedForHash()]
        components.append((author ?? "").normalizedForHash())
        components.append((chapter ?? "").normalizedForHash())
        components.append(highlight.normalizedForHash())
        components.append((userNote ?? "").normalizedForHash())
        if let location = location, !location.isEmpty {
            components.append(location.normalizedForHash())
        }
        return sha256(components.joined(separator: "|"))
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
