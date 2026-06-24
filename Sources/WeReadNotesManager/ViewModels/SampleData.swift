import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

enum SampleData {
    static func createSampleBooks() -> [Book] {
        let book1 = Book(title: "长安的荔枝", author: "马伯庸")
        let book2 = Book(title: "百年孤独", author: "加西亚·马尔克斯")
        let book3 = Book(title: "老人与海", author: "海明威")

        let note1 = ReadingNote(
            book: book1,
            chapter: "第一章",
            highlight: "一骑红尘妃子笑，无人知是荔枝来。",
            userNote: "这里把个人命运和帝国运输系统连接起来，一个小小的荔枝背后是整个帝国的运转。",
            location: "第 32 页",
            createdAt: Date(timeIntervalSinceNow: -86400 * 30),
            isFavorite: true,
            reviewCount: 3,
            lastReviewedAt: Date(timeIntervalSinceNow: -86400 * 10),
            sourceHash: "sample-hash1"
        )
        let note2 = ReadingNote(
            book: book1,
            chapter: "第二章",
            highlight: "天下熙熙，皆为利来；天下攘攘，皆为利往。",
            userNote: "利益驱动是历史运转的底层逻辑。",
            location: "第 67 页",
            createdAt: Date(timeIntervalSinceNow: -86400 * 25),
            reviewCount: 1,
            lastReviewedAt: Date(timeIntervalSinceNow: -86400 * 20),
            sourceHash: "sample-hash2"
        )
        let note3 = ReadingNote(
            book: book1,
            chapter: "第三章",
            highlight: "流程是用来解决效率问题的，不是用来推卸责任的。",
            location: "第 112 页",
            createdAt: Date(timeIntervalSinceNow: -86400 * 20),
            isFavorite: true,
            sourceHash: "sample-hash3"
        )
        let note4 = ReadingNote(
            book: book2,
            chapter: "第一章",
            highlight: "多年以后，面对行刑队，奥雷里亚诺·布恩迪亚上校将会回想起父亲带他去见识冰块的那个遥远的下午。",
            userNote: "经典的开头，一句话跨越了三个时间维度：未来、现在、过去。",
            location: "第 1 页",
            createdAt: Date(timeIntervalSinceNow: -86400 * 60),
            isFavorite: true,
            reviewCount: 5,
            lastReviewedAt: Date(timeIntervalSinceNow: -86400 * 3),
            sourceHash: "sample-hash4"
        )
        let note5 = ReadingNote(
            book: book2,
            chapter: "第二章",
            highlight: "过去都是假的，回忆是一条没有归途的路。",
            createdAt: Date(timeIntervalSinceNow: -86400 * 50),
            sourceHash: "sample-hash5"
        )
        let note6 = ReadingNote(
            book: book3,
            chapter: "第一章",
            highlight: "一个人可以被毁灭，但不能被打败。",
            userNote: "这是整本书的精神内核。",
            location: "第 45 页",
            createdAt: Date(timeIntervalSinceNow: -86400 * 15),
            isFavorite: true,
            reviewCount: 2,
            lastReviewedAt: Date(timeIntervalSinceNow: -86400 * 7),
            sourceHash: "sample-hash6"
        )
        let note7 = ReadingNote(
            book: book3,
            chapter: "第二章",
            highlight: "现在不是去想缺少什么的时候，想一想凭现有的东西能做什么。",
            location: "第 78 页",
            createdAt: Date(timeIntervalSinceNow: -86400 * 10),
            sourceHash: "sample-hash7"
        )

        book1.notes = [note1, note2, note3]
        book2.notes = [note4, note5]
        book3.notes = [note6, note7]

        return [book1, book2, book3]
    }

    static func allNotes(from books: [Book]) -> [ReadingNote] {
        books.flatMap { $0.notes }
    }
}
