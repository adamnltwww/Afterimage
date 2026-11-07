import SwiftUI
import UIKit

struct TimelineMemoryColumn: View {
    @AppStorage(AppPreferences.summariesKey) private var showSummaries = true
    let memory: MemoryRecord
    let x: Double
    let above: Bool
    let linked: Bool
    let select: (MemoryRecord) -> Void
    var threadMember = false
    var threadSelected = false
    var threadProgress = 0.0
    var memberPositions: [Double] = []
    var threadBounds: ClosedRange<Double>?
    var motion: ThreadMotion?
    var themeColor: Color = .mint
    var canvasHeight = 530.0
    private var verticalScale: Double { canvasHeight / 530 }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var pressed = false
    private var engaged: Bool { pressed || (threadMember && motion?.isDragging == true && abs((motion?.focusX ?? -1000) - x) < 1) }

    private var nodeY: Double { (threadMember ? ThreadGeometry.y(at: x, progress: threadProgress, positions: memberPositions, focus: motion?.focusX, bounds: threadBounds, displacements: motion?.displacements ?? []) : TimelineLayout.y(at: x)) * verticalScale }
    private var cardY: Double {
        let distance = cardHeight / 2 + 28 - 10 * activeProgress - (engaged ? 3 : 0)
        let desired = nodeY + ((!above && activeProgress < 0.2) ? distance : -distance)
        return max(cardHeight / 2 + 6, min(canvasHeight - cardHeight / 2 - 6, desired))
    }
    private var previewOpacity: Double {
        threadMember && !above ? min(1, abs(activeProgress - 0.2) / 0.2) : 1
    }
    private var activeProgress: Double { threadMember ? ThreadGeometry.sample(at: x, positions: memberPositions, values: motion?.displacements ?? [], fallback: threadProgress) : 0 }
    private var compactPhoto: Bool { threadSelected && !threadMember && threadProgress > 0.12 && memory.photoData != nil }
    private var previewWidth: Double { 168 }
    private var textWidth: Double { compactPhoto ? 114 : previewWidth }
    private var previewLines: Int { memory.photoData == nil ? 3 : 2 }
    private var previewStyle: UIFont.TextStyle { memory.photoData == nil ? .subheadline : .caption1 }
    private var previewFont: Font { memory.photoData == nil ? .subheadline : .caption }
    private var dateHeight: Double { ceil(UIFont.preferredFont(forTextStyle: .caption2).lineHeight) }
    private var previewTitle: String { memory.displayTitle.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
    private var previewBody: String? {
        guard showSummaries, memory.photoData == nil, memory.text != memory.displayTitle else { return nil }
        var body = memory.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix(memory.displayTitle) { body = String(body.dropFirst(memory.displayTitle.count)).trimmingCharacters(in: .whitespacesAndNewlines) }
        return body.isEmpty ? nil : String(body.prefix(70)).replacingOccurrences(of: "\n", with: " ")
    }
    private var bodyHeight: Double { previewBody == nil ? 0 : ceil(UIFont.preferredFont(forTextStyle: .caption1).lineHeight) + 8 }
    private var titleHeight: Double {
        let font = UIFont.preferredFont(forTextStyle: previewStyle)
        let height = (previewTitle as NSString).boundingRect(with: CGSize(width: textWidth, height: 1000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil).height
        return min(ceil(height), ceil(font.lineHeight * Double(previewLines)))
    }
    private var photoHeight: Double {
        let below = !above && activeProgress < 0.2
        let room = (below ? canvasHeight - nodeY : nodeY) - 28
        return max(0, min(130 - 90 * activeProgress, room - titleHeight - dateHeight - 16))
    }
    private var cardHeight: Double { if compactPhoto { return max(44, titleHeight + dateHeight + 8) }; return titleHeight + bodyHeight + dateHeight + 8 + (memory.photoData == nil || photoHeight == 0 ? 0 : photoHeight + 8) }
    private var color: Color { threadMember && activeProgress > 0.08 ? themeColor : AfterimageStyle.amber }

    private var previewText: some View {
        VStack(alignment: .leading, spacing: 8) {
                    Text(memory.occurredAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_CN"))))
                        .font(.caption2).foregroundStyle(AfterimageStyle.amber.opacity(0.66))
                    Text(previewTitle).font(previewFont).lineLimit(previewLines)
                        .foregroundStyle(memory.photoData == nil ? Color.primary : Color.secondary)
                        .multilineTextAlignment(.leading)
                    if let previewBody {
                        Text(previewBody).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
        }.frame(width: textWidth, alignment: .leading)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { timeline in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                Canvas(rendersAsynchronously: true) { context, _ in
                let base = TimelineLayout.y(at: x) * verticalScale
                if threadMember {
                    var tether = Path()
                    tether.move(to: CGPoint(x: 130, y: base))
                    tether.addCurve(to: CGPoint(x: 130, y: nodeY),
                                    control1: CGPoint(x: 138, y: base - (base - nodeY) * 0.35),
                                    control2: CGPoint(x: 122, y: nodeY + (base - nodeY) * 0.35))
                    context.stroke(tether, with: .linearGradient(Gradient(colors: [
                        AfterimageStyle.amber.opacity(0.05 * activeProgress), themeColor.opacity(0.14 * activeProgress)
                    ]), startPoint: CGPoint(x: 130, y: base), endPoint: CGPoint(x: 130, y: nodeY)), lineWidth: 0.5)
                    var afterglow = context
                    afterglow.addFilter(.blur(radius: 2))
                    afterglow.fill(Path(ellipseIn: CGRect(x: 124, y: base - 1, width: 12, height: 2)),
                                   with: .color(AfterimageStyle.amber.opacity(0.18 * activeProgress)))
                }
                let edge = cardY + cardHeight / 2 * (cardY < nodeY ? 1 : -1)
                let direction = edge < nodeY ? -1.0 : 1.0
                var filament = Path()
                filament.move(to: CGPoint(x: 130, y: nodeY))
                filament.addCurve(to: CGPoint(x: 130, y: edge),
                                  control1: CGPoint(x: 120, y: nodeY + direction * 8),
                                  control2: CGPoint(x: 134, y: edge - direction * 6))
                context.stroke(filament, with: .linearGradient(Gradient(colors: [
                    color.opacity((engaged ? 0.55 : 0.25) * previewOpacity),
                    color.opacity(0.02 * previewOpacity)
                ]), startPoint: CGPoint(x: 130, y: nodeY), endPoint: CGPoint(x: 130, y: edge)), lineWidth: 0.6)

                // A loose, open turn around the axis; the bundle itself keeps its width.
                for strand in 0..<2 {
                    var turn = Path()
                    for step in 0...48 {
                        let t = Double(step) / 48
                        let worldX = x - 64 + 128 * t
                        let baseline = nodeY + (TimelineLayout.y(at: worldX) - TimelineLayout.y(at: x)) * verticalScale
                        let phase = t * .pi * 1.65 + Double(strand) * 2.1 + x / 173 - time * 0.13
                        let radius = (engaged ? 11.0 : 7.0) + Double(strand) * 3
                        let p = CGPoint(x: 66 + 128 * t,
                                        y: baseline + sin(phase) * radius)
                        if step == 0 { turn.move(to: p) } else { turn.addLine(to: p) }
                    }
                    context.stroke(turn, with: .linearGradient(Gradient(stops: [
                        .init(color: color.opacity(0), location: 0),
                        .init(color: color.opacity(strand == 0 ? 0.34 : 0.15), location: 0.4),
                        .init(color: color.opacity(strand == 0 ? 0.22 : 0.28), location: 0.65),
                        .init(color: color.opacity(0), location: 1)
                    ]), startPoint: CGPoint(x: 66, y: nodeY), endPoint: CGPoint(x: 194, y: nodeY)), lineWidth: 0.45)
                }

                }
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            Button { select(memory) } label: {
                ZStack {
                    Ellipse().fill(color.opacity(engaged ? 0.35 : 0.13))
                        .frame(width: engaged ? 42 : 28, height: engaged ? 9 : 4).blur(radius: 6)
                    Capsule().fill(Color(red: 1, green: 0.92, blue: 0.75))
                        .frame(width: engaged ? 9 : 6, height: 1).blur(radius: 0.7)
                        .shadow(color: color.opacity(0.65), radius: 4)
                    if linked {
                        Ellipse().fill(themeColor.opacity(0.25 + activeProgress * 0.2))
                            .frame(width: 4, height: 2).blur(radius: 1).offset(x: 1.5)
                    }
                }
                .frame(width: 48, height: 48).contentShape(Rectangle())
                .overlay {
                    ThreadNodeTouch(enabled: threadMember, motion: motion, reduceMotion: reduceMotion,
                                    x: x, verticalScale: verticalScale, press: { pressed = $0 }) { select(memory) }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(memory.occurredAt.formatted(date: .abbreviated, time: .shortened))，\(memory.displayTitle)")
            .accessibilityHint(linked ? "存在关联，点击查看详情与关联依据" : "查看详情")
            .accessibilityIdentifier("timeline.node")
            .accessibilityValue(threadMember ? (threadProgress > 0.99 ? "已抽出" : threadProgress < 0.01 ? "已收回" : threadProgress < ThreadMotion.releaseThreshold ? "逐级牵引" : "整线抽出") : "")
            .accessibilityAction(named: "抽出主题线") {
                guard threadMember else { return }
                motion?.settle(expanded: true, immediately: reduceMotion)
            }
            .accessibilityAction(named: "收回主题线") {
                guard threadMember else { return }
                motion?.settle(expanded: false, immediately: reduceMotion)
            }
            .position(x: 130, y: nodeY)

            Button { select(memory) } label: {
                Group {
                    if compactPhoto {
                        HStack(alignment: .top, spacing: 10) {
                            previewText
                            MemoryVisual(id: memory.id, photoData: memory.photoData, preserveAspect: true)
                                .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            if memory.photoData != nil && photoHeight > 0 {
                                MemoryVisual(id: memory.id, photoData: memory.photoData, preserveAspect: true)
                                    .frame(height: photoHeight).clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            previewText
                        }
                    }
                }
                .frame(width: previewWidth, height: cardHeight, alignment: (!above && activeProgress < 0.2) ? .topLeading : .bottomLeading)
                .background { AfterimageStyle.background.opacity(activeProgress * 0.65).blur(radius: 10) }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(memory.occurredAt.formatted(date: .abbreviated, time: .omitted))，\(memory.displayTitle)")
            .accessibilityHint("查看完整内容")
            .opacity(previewOpacity)
            .scaleEffect(engaged ? 1.012 : 1, anchor: cardY < nodeY ? .bottom : .top)
            .position(x: 130, y: cardY)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: pressed)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: compactPhoto)
        .opacity(threadSelected && !threadMember ? 1 - 0.58 * threadProgress : 1)
    }
}
