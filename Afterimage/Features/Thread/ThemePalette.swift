import SwiftUI
import SwiftData

enum ThemePalette {
    struct Ink: Equatable {
        let name: String
        let red: Double
        let green: Double
        let blue: Double
        var color: Color { Color(red: red, green: green, blue: blue) }
    }
    static let inks: [Ink] = [
        Ink(name: "青玉", red: 0.46, green: 0.85, blue: 0.74),
        Ink(name: "雾蓝", red: 0.47, green: 0.70, blue: 0.94),
        Ink(name: "淡紫", red: 0.72, green: 0.61, blue: 0.92),
        Ink(name: "珊瑚", red: 0.96, green: 0.61, blue: 0.48),
        Ink(name: "玫瑰", red: 0.89, green: 0.56, blue: 0.73),
        Ink(name: "月白", red: 0.79, green: 0.85, blue: 0.94),
        Ink(name: "嫩绿", red: 0.70, green: 0.83, blue: 0.46),
        Ink(name: "琥珀", red: 0.94, green: 0.75, blue: 0.43)
    ]
    static func ink(_ index: Int?) -> Ink { inks[max(0, index ?? 0) % inks.count] }
    static func nextIndex(used: [Int]) -> Int {
        // Exhaust the palette before reusing the least represented hue.
        (0..<inks.count).min { a, b in
            let ca = used.filter { $0 == a }.count, cb = used.filter { $0 == b }.count
            return ca == cb ? a < b : ca < cb
        } ?? 0
    }
    static func phase(for key: String) -> Double {
        Double(key.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) } % 6283) / 1000
    }
}

struct ThemeColorMenu: View {
    let tag: MemoryTag
    @Environment(\.modelContext) private var context
    @State private var errorMessage: String?

    var body: some View {
        Menu {
            ForEach(ThemePalette.inks.indices, id: \.self) { index in
                Button {
                    let previous = tag.colorIndex
                    tag.colorIndex = index
                    do { try context.save() }
                    catch { tag.colorIndex = previous; errorMessage = "颜色未能保存，请重试。" }
                } label: {
                    Label(ThemePalette.inks[index].name, systemImage: tag.colorIndex == index ? "checkmark.circle.fill" : "circle.fill")
                        .tint(ThemePalette.inks[index].color)
                }
                .accessibilityIdentifier("theme.color.\(index)")
            }
        } label: {
            Image(systemName: "circle.lefthalf.filled")
                .foregroundStyle(ThemePalette.ink(tag.colorIndex).color)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("\(tag.name)的颜色，\(ThemePalette.ink(tag.colorIndex).name)")
        .accessibilityIdentifier("theme.colorPicker")
        .alert("未能完成", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}
