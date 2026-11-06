import SwiftUI
import Observation

/// Tile identity and world origin stay fixed across scrolling and deceleration.
enum SilkTiling {
    static let width = 384.0
    static let bleed = 32.0
    static func indices(offset: Double, viewport: Double) -> ClosedRange<Int> {
        (Int(floor(offset / width)) - 1)...(Int(floor((offset + viewport) / width)) + 1)
    }
}

struct TimelineSilkField: View {
    let offset: Double
    let viewport: Double
    let contentWidth: Double
    let height: Double
    var spans: [ThemeWeave.Span] = []
    var selectedKey: String?
    var progress = 0.0
    var memberPositions: [Double] = []
    var displacements: [Double] = []
    var focus: Double?
    var hasFocus = false
    var ink = ThemePalette.ink(0)
    var sampleTime: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openingPresentation) private var opening
    var body: some View {
        TimelineView(.animation(minimumInterval: opening?.isBlocking == true ? 1.0 / 60 : 1.0 / 30,
                                paused: sampleTime != nil || reduceMotion || scenePhase != .active)) { timeline in
        let time = sampleTime ?? (reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate)
        ZStack(alignment: .topLeading) {
            ForEach(Array(SilkTiling.indices(offset: offset, viewport: viewport)), id: \.self) { index in
                TimelineSilkTile(origin: Double(index) * SilkTiling.width, height: height,
                                 spans: spans, selectedKey: selectedKey, progress: progress,
                                 memberPositions: memberPositions, displacements: displacements,
                                 focus: focus, hasFocus: hasFocus, ink: ink, time: time, synchronous: sampleTime != nil,
                                 themeOpacity: opening?.contentOpacity ?? 1, openingAmount: opening?.silkAmount(at: time) ?? 0,
                                 openingCenter: opening?.isBlocking == true ? offset + viewport / 2 : 0,
                                 openingWidth: viewport)
                    .equatable()
                    .position(x: Double(index) * SilkTiling.width + SilkTiling.width / 2, y: height / 2)
            }
        }.frame(width: contentWidth, height: height, alignment: .topLeading)
            .opacity(opening?.silkOpacity ?? 1)
            .background {
                if let opening, opening.isBlocking, sampleTime == nil {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear { opening.axisFrame = geometry.frame(in: .global) }
                            .onChange(of: geometry.frame(in: .global)) { _, frame in opening.axisFrame = frame }
                    }
                }
            }
            // Continue outside content bounds to cover native rubber-banding at both ends.
            .allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

private struct TimelineSilkTile: View, Equatable {
    let origin: Double
    let height: Double
    let spans: [ThemeWeave.Span]
    let selectedKey: String?
    let progress: Double
    let memberPositions: [Double]
    let displacements: [Double]
    let focus: Double?
    let hasFocus: Bool
    let ink: ThemePalette.Ink
    let time: Double
    let synchronous: Bool
    let themeOpacity: Double
    let openingAmount: Double
    let openingCenter: Double
    let openingWidth: Double
    var body: some View {
        let start = origin - SilkTiling.bleed
        let width = SilkTiling.width + SilkTiling.bleed * 2
        ZStack(alignment: .topLeading) {
            ThemeWeave(spans: spans, origin: start, width: width, front: false,
                       selectedKey: selectedKey, progress: progress, hasFocus: hasFocus, height: height, renderTime: time, synchronous: synchronous)
                .offset(x: -origin)
                .opacity(themeOpacity)
            SilkAxis(origin: start, width: width, tension: progress, threadPositions: memberPositions,
                     threadDisplacements: displacements, threadFocus: focus, height: height, lightSamples: 32, renderTime: time, synchronous: synchronous,
                     openingAmount: openingAmount, openingCenter: openingCenter, openingWidth: openingWidth)
                .offset(x: -origin)
            ThemeWeave(spans: spans, origin: start, width: width, front: true,
                       selectedKey: selectedKey, progress: progress, hasFocus: hasFocus, height: height, renderTime: time, synchronous: synchronous)
                .offset(x: -origin)
                .opacity(themeOpacity)
            ThreadCanvas(width: width, range: memberPositions.first.flatMap { first in memberPositions.last.map { first...$0 } },
                         progress: progress, positions: memberPositions, displacements: displacements, focus: focus,
                         visibleRange: start...(start + width), themeInk: ink, height: height, renderTime: time, synchronous: synchronous)
                .offset(x: -origin)
                .opacity(themeOpacity)
        }.frame(width: SilkTiling.width, height: height, alignment: .topLeading).clipped()
    }
}

@Observable final class TimelineReadProgress { var value = 1.0 }
struct ReadingPositionWordmark: View {
    @Environment(\.openingPresentation) private var opening
    let progress: TimelineReadProgress
    let empty: Bool
    var externalWordmark = false
    var body: some View {
        if externalWordmark, let opening {
            // Reserve the native title slot without creating a second visible wordmark.
            Color.clear.frame(width: 190, height: 32)
                .background {
                    OpeningGeometryProbe(presentation: opening, target: .title,
                                         readingProgress: empty ? 0 : progress.value)
                }
                .accessibilityHidden(true)
        } else {
            AfterimageWordmark(progress: empty ? 0 : progress.value)
        }
    }
}
