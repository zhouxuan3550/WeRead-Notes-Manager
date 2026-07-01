import Foundation
import AppKit
import SwiftUI

// MARK: - 图片附件服务
//
// 把粘贴的截图保存到 Application Support 目录，
// 在 SwiftData 之外用 JSON 索引管理关联。
//
// 路径：~/Library/Application Support/书摘温故/Attachments/<uuid>.png

enum ImageAttachmentService {
    static let directoryName = "Attachments"

    static var attachmentsDirectory: URL {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        let dir = support
            .appendingPathComponent("书摘温故", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 保存图片，返回相对路径（用于索引）。
    static func save(_ image: NSImage, noteID: UUID) -> String? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let filename = "\(noteID.uuidString).png"
        let url = attachmentsDirectory.appendingPathComponent(filename)
        do {
            try png.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    /// 加载图片（按相对路径）。
    static func load(filename: String) -> NSImage? {
        let url = attachmentsDirectory.appendingPathComponent(filename)
        return NSImage(contentsOf: url)
    }

    /// 删除附件。
    static func delete(filename: String) {
        let url = attachmentsDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    /// 总占用大小。
    static func totalSize() -> Int64 {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: attachmentsDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return urls.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + Int64(size)
        }
    }
}

// MARK: - 附件 JSON 索引

/// 轻量 JSON 索引：noteID -> [attachment]
struct AttachmentIndex: Codable {
    var entries: [String: [Entry]] = [:]

    struct Entry: Codable {
        let filename: String
        let createdAt: Date
        let kind: String  // png / jpg / pdf
    }

    static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return support
            .appendingPathComponent("书摘温故", isDirectory: true)
            .appendingPathComponent("attachment-index.json")
    }

    static func load() -> AttachmentIndex {
        guard let data = try? Data(contentsOf: fileURL),
              let idx = try? JSONDecoder().decode(AttachmentIndex.self, from: data) else {
            return AttachmentIndex()
        }
        return idx
    }

    static func save(_ index: AttachmentIndex) {
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    mutating func add(noteID: UUID, filename: String, kind: String) {
        let key = noteID.uuidString
        var list = entries[key] ?? []
        list.append(Entry(filename: filename, createdAt: .now, kind: kind))
        entries[key] = list
        AttachmentIndex.save(self)
    }

    mutating func remove(noteID: UUID, filename: String) {
        let key = noteID.uuidString
        var list = entries[key] ?? []
        list.removeAll { $0.filename == filename }
        if list.isEmpty {
            entries.removeValue(forKey: key)
        } else {
            entries[key] = list
        }
        AttachmentIndex.save(self)
    }

    mutating func removeAll(noteID: UUID) {
        entries.removeValue(forKey: noteID.uuidString)
        AttachmentIndex.save(self)
    }

    func attachments(for noteID: UUID) -> [Entry] {
        entries[noteID.uuidString] ?? []
    }
}

// MARK: - 粘贴处理（笔记详情）

@MainActor
enum NoteImagePasteHandler {
    /// 处理粘贴：如果是图片，保存并加入附件索引；返回 true 表示已处理。
    static func handlePaste(in note: ReadingNote) -> Bool {
        let pb = NSPasteboard.general
        guard let imgData = pb.data(forType: .tiff),
              let img = NSImage(data: imgData) else {
            return false
        }

        // 先确保笔记已存在
        var index = AttachmentIndex.load()
        let savedName = ImageAttachmentService.save(img, noteID: note.id)
        if let name = savedName {
            let kind = imgData.count > 1_000_000 ? "png" : "png"
            index.add(noteID: note.id, filename: name, kind: kind)
        }
        return savedName != nil
    }
}