import SwiftUI
import Vision
import VisionKit
import AppKit
import SwiftData

// MARK: - OCR 拍书页识别
//
// 用户从剪贴板/文件上传一张书页图片，
// 用 Vision 识别文字 + 用 NLP 启发式切分"原文/划线/想法"段落，
// 让用户挑出要保留的文本，导入到笔记库。
//
// 注意：macOS 没有 AVCaptureSession，需要从文件/剪贴板读图。
// iOS 版本可以用 VNDocumentCameraViewController。

// MARK: - 识别结果

struct OCRSegment: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var isHighlight: Bool
    var isUserNote: Bool
    var confidence: Double
}

// MARK: - OCR 服务

enum OCRService {
    /// 识别图片里的文字，返回按段落切分的 OCRSegment 列表。
    static func recognize(image: NSImage) async -> [OCRSegment] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let segments = parseObservations(observations)
                continuation.resume(returning: segments)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }

    /// 把识别结果切成"原文（划线）/ 想法"段
    static func parseObservations(_ observations: [VNRecognizedTextObservation]) -> [OCRSegment] {
        // 1. 按从上到下排
        let sorted = observations.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }

        // 2. 取每条 observation 的 top candidate
        let lines = sorted.compactMap { obs -> (text: String, conf: Double)? in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            return (candidate.string, Double(candidate.confidence))
        }

        // 3. 启发式切分：
        //    - 短行 (< 30 字) → 可能是想法标签
        //    - 引号包裹 → 原文
        //    - 其它 → 原文
        var segments: [OCRSegment] = []
        for line in lines {
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let isQuoted = trimmed.contains("「") || trimmed.contains("『") ||
                            trimmed.contains("\"") || trimmed.contains("\"") ||
                            trimmed.contains("'") || trimmed.contains("'")
            let isShort = trimmed.count < 30
            let startsWithVerb = trimmed.hasPrefix("我") || trimmed.hasPrefix("觉得") ||
                                  trimmed.hasPrefix("其实") || trimmed.hasPrefix("可能")

            let isHighlight = isQuoted && !startsWithVerb
            let isUserNote = isShort && !isQuoted

            segments.append(OCRSegment(
                text: trimmed,
                isHighlight: isHighlight,
                isUserNote: isUserNote,
                confidence: line.conf
            ))
        }

        return segments
    }
}

// MARK: - OCR 视图

struct OCRCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppViewModel.self) private var appVM

    @State private var image: NSImage?
    @State private var segments: [OCRSegment] = []
    @State private var selectedIDs: Set<UUID> = []
    @State private var isProcessing = false
    @State private var bookID: UUID?
    @State private var chapter: String = ""
    @State private var statusMessage: String?

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if image == nil {
                importPrompt
            } else {
                HSplitView {
                    previewPane
                        .frame(minWidth: 280)
                    editPane
                        .frame(minWidth: 360)
                }
            }
        }
        .frame(width: 760, height: 560)
    }

    // MARK: - 头部

    private var header: some View {
        HStack {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.accent)
            Text("OCR 识别书页")
                .font(.headline)
            Spacer()
            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    // MARK: - 导入提示

    private var importPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(palette.textTertiary)
            Text("选择或粘贴一张书页图片")
                .font(.title3)
                .foregroundStyle(palette.textPrimary)
            Text("系统会用 Vision 识别文字，启发式切分划线和想法")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            HStack(spacing: 10) {
                Button {
                    pickFromFile()
                } label: {
                    Label("选择文件", systemImage: "photo.on.rectangle.angled")
                }
                .flatActionButton(.accent, height: 32)

                Button {
                    pasteFromClipboard()
                } label: {
                    Label("粘贴图片", systemImage: "doc.on.clipboard")
                }
                .flatActionButton(height: 32)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(palette.error)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 预览

    private var previewPane: some View {
        VStack(spacing: 10) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if isProcessing {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("识别中...")
                        .font(.caption)
                }
            }
        }
        .padding(14)
    }

    // MARK: - 编辑

    private var editPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("识别结果")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("选中要保留的段落")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            if segments.isEmpty && !isProcessing {
                ContentUnavailableView("识别失败", systemImage: "exclamationmark.triangle")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(segments) { segment in
                            OCRSegmentRow(
                                segment: segment,
                                selected: selectedIDs.contains(segment.id),
                                toggle: { toggleSelect(segment) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 240)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("目标书籍")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                Picker("书", selection: $bookID) {
                    Text("选择...").tag(UUID?.none)
                    ForEach(appVM.books) { book in
                        Text(book.title).tag(Optional(book.id))
                    }
                }
                .pickerStyle(.menu)

                TextField("章节（可选）", text: $chapter)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                importSelected()
            } label: {
                HStack {
                    Image(systemName: "tray.and.arrow.down.fill")
                    Text("导入选中 (\(selectedIDs.count)) 条")
                }
                .frame(maxWidth: .infinity)
            }
            .flatActionButton(.accent, height: 32)
            .disabled(selectedIDs.isEmpty || bookID == nil)
        }
        .padding(14)
    }

    // MARK: - 动作

    private func pickFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .pdf]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            loadImage(from: url)
        }
    }

    private func pasteFromClipboard() {
        let pb = NSPasteboard.general
        if let img = pb.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
            self.image = img
            runOCR()
        } else if let url = pb.string(forType: .fileURL).flatMap(URL.init(string:)) {
            loadImage(from: url)
        } else {
            statusMessage = "剪贴板没有图片"
        }
    }

    private func loadImage(from url: URL) {
        if let img = NSImage(contentsOf: url) {
            self.image = img
            runOCR()
        } else {
            statusMessage = "无法读取图片"
        }
    }

    private func runOCR() {
        guard let image else { return }
        isProcessing = true
        statusMessage = nil
        Task {
            let result = await OCRService.recognize(image: image)
            await MainActor.run {
                self.segments = result
                self.selectedIDs = Set(result.filter(\.isHighlight).map(\.id))
                self.isProcessing = false
            }
        }
    }

    private func toggleSelect(_ segment: OCRSegment) {
        if selectedIDs.contains(segment.id) {
            selectedIDs.remove(segment.id)
        } else {
            selectedIDs.insert(segment.id)
        }
    }

    private func importSelected() {
        guard let bookID, let book = appVM.books.first(where: { $0.id == bookID }) else { return }
        let selected = segments.filter { selectedIDs.contains($0.id) }
        for segment in selected {
            let note = ReadingNote(
                book: book,
                chapter: chapter.isEmpty ? nil : chapter,
                highlight: segment.text,
                userNote: segment.isUserNote ? segment.text : nil,
                source: "ocr",
                noteKind: segment.isUserNote ? "thought" : "highlight"
            )
            modelContext.insert(note)
        }
        do {
            try modelContext.save()
            statusMessage = "已导入 \(selected.count) 条笔记"
            dismiss()
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 段落行

struct OCRSegmentRow: View {
    let segment: OCRSegment
    let selected: Bool
    let toggle: () -> Void

    @Environment(\.themePalette) private var palette

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14))
                    .foregroundStyle(selected ? palette.accent : palette.textTertiary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(segment.text)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        if segment.isHighlight {
                            tag(text: "划线", color: palette.accent)
                        }
                        if segment.isUserNote {
                            tag(text: "想法", color: palette.warning)
                        }
                        tag(text: String(format: "%.0f%%", segment.confidence * 100), color: palette.textTertiary)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? palette.accent.opacity(0.10) : palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selected ? palette.accent : palette.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func tag(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(color.opacity(0.18))
            )
            .foregroundStyle(color)
    }
}