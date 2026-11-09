import SwiftUI

struct TimelineDateFilter: Equatable {
    enum Mode: String, CaseIterable { case all = "全部时间", year = "按年份", month = "按月份", custom = "自定义" }
    var mode: Mode = .all
    var anchor = Date()
    var start = Date()
    var end = Date()

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        switch mode {
        case .all: return true
        case .year, .month:
            guard let interval = calendar.dateInterval(of: mode == .year ? .year : .month, for: anchor) else { return false }
            return date >= interval.start && date < interval.end
        case .custom:
            let first = calendar.startOfDay(for: min(start, end))
            let last = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(start, end)))!
            return date >= first && date < last
        }
    }
    var label: String {
        switch mode {
        case .all: return "全部时间"
        case .year: return anchor.formatted(.dateTime.year())
        case .month: return anchor.formatted(.dateTime.year().month())
        case .custom: return min(start, end).formatted(date: .abbreviated, time: .omitted) + " — " + max(start, end).formatted(date: .abbreviated, time: .omitted)
        }
    }
}

struct TimelineDateFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: TimelineDateFilter
    @State private var draft: TimelineDateFilter
    init(selection: Binding<TimelineDateFilter>) {
        _selection = selection
        _draft = State(initialValue: selection.wrappedValue)
    }
    var body: some View {
        NavigationStack {
            Form {
                Picker("时间范围", selection: $draft.mode) {
                    ForEach(TimelineDateFilter.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                if draft.mode == .year || draft.mode == .month {
                    DatePicker("选择所在日期", selection: $draft.anchor, displayedComponents: .date)
                    Text("将显示 \(draft.label) 的记录").font(.footnote).foregroundStyle(.secondary)
                } else if draft.mode == .custom {
                    DatePicker("开始", selection: $draft.start, displayedComponents: .date)
                    DatePicker("结束", selection: $draft.end, in: draft.start..., displayedComponents: .date)
                        .onChange(of: draft.start) { _, value in if draft.end < value { draft.end = value } }
                }
            }
            .afterimageSheetSurface().navigationTitle("时间范围").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("应用") { selection = draft; dismiss() } }
            }
        }
    }
}
