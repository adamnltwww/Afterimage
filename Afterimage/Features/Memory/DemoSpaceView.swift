import SwiftUI
import SwiftData

/// The presentation item owns the ready-to-use database for the entire session.
struct DemoSession: Identifiable {
    let id = UUID()
    let container: ModelContainer

    init() throws { container = try MemoryStore.makeDemoContainer() }
}

struct DemoSpaceView: View {
    let session: DemoSession
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("独立演示空间").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("退出演示", systemImage: "xmark", action: close)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("demo.close")
            }
            .padding(.horizontal, 20)
            Divider()
            MemoryLibraryView(isDemo: true)
                .modelContainer(session.container)
        }
        .background(AfterimageStyle.background)
        .preferredColorScheme(.dark)
        .tint(AfterimageStyle.amber)
    }
}
