import SwiftUI
import UIKit

enum LongImageExport {
    static let scale: CGFloat = 3
    static let tileHeight: CGFloat = 3000
    enum Failure: LocalizedError {
        case rendering
        var errorDescription: String? { "未能生成图片，请稍后重试。" }
    }
    @MainActor static func height(_ records: [MemoryRecord]) -> CGFloat {
        UIHostingController(rootView: MemorySharePage(records: records, page: 1, total: 1))
            .sizeThatFits(in: CGSize(width: 390, height: CGFloat.greatestFiniteMagnitude)).height
    }
    @MainActor static func pdf(records: [MemoryRecord]) async throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AFTERIMAGE-PDF-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("AFTERIMAGE.pdf")
        do {
            var groups: [[MemoryRecord]] = [], group: [MemoryRecord] = []
            for record in records {
                if !group.isEmpty && height(group + [record]) > tileHeight { groups.append(group); group = [] }
                group.append(record)
                await Task.yield()
            }
            if !group.isEmpty { groups.append(group) }
            guard !groups.isEmpty else { throw Failure.rendering }
            let writer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 390, height: tileHeight))
            var failure: Error?
            try writer.writePDF(to: url) { pdf in
                for (index, records) in groups.enumerated() {
                    let renderer = ImageRenderer(content: MemorySharePage(records: records, page: index + 1, total: groups.count)
                        .environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, .large))
                    renderer.render(rasterizationScale: scale) { size, draw in
                        guard size.width.isFinite, size.height.isFinite, size.height > 0 else { failure = Failure.rendering; return }
                        // Normal groups remain whole. Extremely long single records get tall PDF pages.
                        var top: CGFloat = 0
                        while top < size.height {
                            let length = min(12000, size.height - top)
                            pdf.beginPage(withBounds: CGRect(x: 0, y: 0, width: size.width, height: length), pageInfo: [:])
                            let context = pdf.cgContext
                            context.saveGState()
                            context.translateBy(x: 0, y: length)
                            context.scaleBy(x: 1, y: -1)
                            context.translateBy(x: 0, y: -(size.height - top - length))
                            draw(context)
                            context.restoreGState()
                            if top + length >= size.height { break }
                            top += length - 48
                        }
                    }
                }
            }
            if let failure { throw failure }
            return url
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }
    @MainActor static func render(records: [MemoryRecord]) async throws -> [URL] {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AFTERIMAGE-LongImages-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            var groups: [[MemoryRecord]] = [], group: [MemoryRecord] = []
            for record in records {
                if !group.isEmpty && height(group + [record]) > tileHeight { groups.append(group); group = [] }
                group.append(record)
                await Task.yield()
            }
            if !group.isEmpty { groups.append(group) }
            var files: [URL] = []
            for (index, records) in groups.enumerated() {
                try Task.checkCancellation()
                let renderer = ImageRenderer(content: MemorySharePage(records: records, page: index + 1, total: groups.count)
                    .environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, .large))
                var failure: Error?
                renderer.render(rasterizationScale: scale) { size, draw in
                    guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
                        failure = Failure.rendering; return
                    }
                    var top: CGFloat = 0
                    while top < size.height {
                        let length = min(tileHeight, size.height - top)
                        do {
                            let url = folder.appendingPathComponent(String(format: "AFTERIMAGE-%04d.png", files.count + 1))
                            try autoreleasepool {
                                guard let context = CGContext(data: nil, width: Int(ceil(size.width * scale)), height: Int(ceil(length * scale)), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.rendering }
                                context.scaleBy(x: scale, y: scale)
                                context.translateBy(x: 0, y: -(size.height - top - length))
                                draw(context)
                                guard let image = context.makeImage(), let png = UIImage(cgImage: image).pngData() else { throw Failure.rendering }
                                try png.write(to: url, options: .atomic)
                            }
                            files.append(url)
                        } catch { failure = error; break }
                        if top + length >= size.height { break }
                        top += length - 48
                    }
                }
                if let failure { throw failure }
                await Task.yield()
            }
            guard !files.isEmpty else { throw Failure.rendering }
            return files
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }
}

struct LongImagePreview: View {
    let url: URL
    @State private var data: Data?
    var body: some View {
        Group {
            if let data { PhotoViewerEntry(data: data) }
            else { ProgressView().frame(height: 120) }
        }
        .task { data = try? Data(contentsOf: url) }
        .onDisappear { data = nil }
    }
}
