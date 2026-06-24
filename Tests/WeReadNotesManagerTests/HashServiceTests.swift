import XCTest
@testable import WeReadNotesManager

final class HashServiceTests: XCTestCase {
    func testGenerateHash_SameContent_ProducesSameHash() {
        let hash1 = HashService.generateHash(
            source: "manual",
            sourceID: nil,
            bookTitle: "长安的荔枝",
            author: "马伯庸",
            chapter: "第一章",
            highlight: "一骑红尘妃子笑",
            userNote: nil,
            location: "第 32 页"
        )
        let hash2 = HashService.generateHash(
            source: "manual",
            sourceID: nil,
            bookTitle: "长安的荔枝",
            author: "马伯庸",
            chapter: "第一章",
            highlight: "一骑红尘妃子笑",
            userNote: nil,
            location: "第 32 页"
        )
        XCTAssertEqual(hash1, hash2)
    }

    func testGenerateHash_DifferentWhitespace_ProducesSameHash() {
        // `normalizedForHash` 做 NFKC + 合并连续空白 + lowercase。
        // 同一个 highlight，前后空白差异应被归一为相同 hash。
        let hash1 = HashService.generateHash(
            source: "manual",
            sourceID: nil,
            bookTitle: "Hello World",
            author: nil,
            chapter: nil,
            highlight: "foo bar baz",
            userNote: nil,
            location: nil
        )
        let hash2 = HashService.generateHash(
            source: "manual",
            sourceID: nil,
            bookTitle: "Hello World",
            author: nil,
            chapter: nil,
            highlight: "foo   bar    baz",
            userNote: nil,
            location: nil
        )
        XCTAssertEqual(hash1, hash2, "连续空白应归一为相同 hash")
    }

    func testGenerateHash_FullAndHalfWidth_ProducesSameHash() {
        let hash1 = HashService.generateHash(
            source: "manual",
            sourceID: nil,
            bookTitle: "Hello World",
            author: nil,
            chapter: nil,
            highlight: "ＡＢＣ",
            userNote: nil,
            location: nil
        )
        let hash2 = HashService.generateHash(
            source: "manual",
            sourceID: nil,
            bookTitle: "Hello World",
            author: nil,
            chapter: nil,
            highlight: "ABC",
            userNote: nil,
            location: nil
        )
        XCTAssertEqual(hash1, hash2, "全角/半角字符应归一为相同 hash")
    }

    func testGenerateHash_WithSourceID_IgnoresOtherFields() {
        let hash1 = HashService.generateHash(
            source: "weread_skill",
            sourceID: "bookmark:123",
            bookTitle: "A",
            author: "X",
            chapter: "C1",
            highlight: "highlight1",
            userNote: "n",
            location: "1-5"
        )
        let hash2 = HashService.generateHash(
            source: "weread_skill",
            sourceID: "bookmark:123",
            bookTitle: "B", // changed
            author: "Y",     // changed
            chapter: "C2",   // changed
            highlight: "highlight2", // changed
            userNote: nil,
            location: nil
        )
        XCTAssertEqual(hash1, hash2, "sourceID 存在时其他字段不影响 hash")
    }

    func testGenerateHash_DifferentContent_ProducesDifferentHash() {
        let hash1 = HashService.generateHash(
            source: "manual",
            sourceID: nil,
            bookTitle: "长安的荔枝",
            author: "马伯庸",
            chapter: "第一章",
            highlight: "划线 A",
            userNote: nil,
            location: nil
        )
        let hash2 = HashService.generateHash(
            source: "manual",
            sourceID: nil,
            bookTitle: "长安的荔枝",
            author: "马伯庸",
            chapter: "第一章",
            highlight: "划线 B",
            userNote: nil,
            location: nil
        )
        XCTAssertNotEqual(hash1, hash2)
    }
}
