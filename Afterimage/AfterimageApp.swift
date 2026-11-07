import SwiftUI
import SwiftData

@main
struct AfterimageApp: App {
    @State private var opening = OpeningPresentation(animationEnabled: AppPreferences.openingAnimationEnabled)
    private let container: ModelContainer?
    private let storageError: String?

    init() {
        #if DEBUG
        _opening = State(initialValue: OpeningPresentation(active: !ProcessInfo.processInfo.arguments.contains("--ui-testing") || ProcessInfo.processInfo.arguments.contains("--ui-opening"), animationEnabled: AppPreferences.openingAnimationEnabled))
        #endif
        do {
            #if DEBUG
            let created = try MemoryStore.makeContainer(inMemory: ProcessInfo.processInfo.arguments.contains("--ui-testing"))
            if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
               ProcessInfo.processInfo.arguments.contains("--ui-visual-fixture") {
                try VisualFixture.insert(in: created)
            }
            if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
               ProcessInfo.processInfo.arguments.contains("--ui-reading-fixture") {
                try VisualFixture.insertReading(in: created)
                if ProcessInfo.processInfo.arguments.contains("--ui-collection-fixture") {
                    let context = ModelContext(created)
                    let records = try context.fetch(FetchDescriptor<MemoryRecord>(sortBy: [SortDescriptor(\.occurredAt)]))
                    if let first = records.first {
                        first.additionalPhotoData = try JSONEncoder().encode([DemoArtwork.data(scene: 2), DemoArtwork.data(scene: 3)].compactMap { $0 })
                    }
                    let walk = MemoryTag(name: "Walk"); walk.colorIndex = 2
                    context.insert(walk)
                    for record in records where record.id != records.dropFirst().first?.id { record.tags.append(walk) }
                    try context.save()
                }
            }
            if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
               ProcessInfo.processInfo.arguments.contains("--ui-stress") {
                let context = ModelContext(created)
                context.autosaveEnabled = false
                let tag = MemoryTag(name: "摄影")
                for index in 0..<200 {
                    context.insert(MemoryRecord(text: "Stress memory \(index)", occurredAt: Date(timeIntervalSince1970: Double(index) * 86_400), tags: [tag]))
                }
                try context.save()
            }
            if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
               ProcessInfo.processInfo.arguments.contains("--ui-drawer-fixture") {
                let context = ModelContext(created)
                for index in 0..<18 {
                    let tag = MemoryTag(name: String(format: "Scope%02d", index))
                    context.insert(MemoryRecord(text: "Earlier unrelated moment \(index)",
                                                occurredAt: Date(timeIntervalSince1970: Double(index - 40) * 86400), tags: [tag]))
                }
                try context.save()
            }
            container = created
            #else
            container = try MemoryStore.makeContainer()
            #endif
            storageError = nil
        } catch {
            container = nil
            storageError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    MemoryLibraryView(isDemo: false)
                        .modelContainer(container)
                        .allowsHitTesting(!opening.isBlocking)
                        .accessibilityHidden(opening.isBlocking)
                } else {
                    ContentUnavailableView {
                        Label("暂时无法打开本地记录", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("请保留 App 后重试，不要卸载。\n\(storageError ?? "未知存储错误")")
                    }
                }
            }
            .environment(\.openingPresentation, opening)
            .overlay {
                if opening.isBlocking { OpeningView(presentation: opening) }
            }
            .preferredColorScheme(.dark)
            .modifier(AppMotionPreference())
            .tint(AfterimageStyle.amber)
        }
    }
}
