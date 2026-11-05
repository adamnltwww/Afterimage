#if DEBUG
import UIKit
import SwiftData

/// Synthetic geometry cards for isolated screenshot checks; never used in the real library.
enum VisualFixture {
    @MainActor static func insertReading(in container: ModelContainer) throws {
        let context = ModelContext(container)
        for (index, title) in ["Lake morning", "Lake return", "A quiet page"].enumerated() {
            try MemoryStore.save(record: nil,
                                 text: index == 0 ? "A quiet morning. The hiddenkeyword belongs only in the full story." : "Some details to read slowly.",
                                 occurredAt: Date(timeIntervalSince1970: Double(index + 1) * 86400),
                                 photoData: index == 0 ? DemoArtwork.data(scene: 1) : nil,
                                 tagText: index == 2 ? "Solo" : "Lake", title: title, in: context)
        }
        let records = try context.fetch(FetchDescriptor<MemoryRecord>(sortBy: [SortDescriptor(\.occurredAt)]))
        try Resonance.setManual(a: records[0].id, b: records[1].id, note: "Same place, another season.", in: context)
    }

    @MainActor static func insert(in container: ModelContainer) throws {
        let context = ModelContext(container)
        for (index, size) in [CGSize(width: 600, height: 360), CGSize(width: 360, height: 600)].enumerated() {
            let image = UIGraphicsImageRenderer(size: size).image { renderer in
                let ctx = renderer.cgContext
                ctx.setFillColor(UIColor(red: 0.08, green: 0.13, blue: 0.17, alpha: 1).cgColor)
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.setFillColor(UIColor(red: 0.83, green: 0.58, blue: 0.31, alpha: 1).cgColor)
                ctx.fillEllipse(in: CGRect(x: size.width * 0.4, y: size.height * 0.18, width: 100, height: 100))
                ctx.setStrokeColor(UIColor.white.cgColor)
                ctx.setLineWidth(8)
                ctx.stroke(CGRect(x: 8, y: 8, width: size.width - 16, height: size.height - 16))
            }
            context.insert(MemoryRecord(text: index == 0 ? "横幅构图测试 · 四边应完整" : "竖幅构图测试 · 四边应完整", occurredAt: Date(timeIntervalSince1970: Double(index + 1) * 86_400), photoData: image.jpegData(compressionQuality: 0.9), tags: [MemoryTag(name: "摄影")]))
        }
        try context.save()
    }
}
#endif
