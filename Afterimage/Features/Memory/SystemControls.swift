import SwiftUI

/// Use the platform material and press feedback; content cards stay visually quiet.
private struct SystemControlStyle: ViewModifier {
    var prominent = false
    var icon = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            if prominent {
                content.buttonStyle(.glassProminent).buttonBorderShape(.capsule)
            } else if icon {
                content.buttonStyle(.glass).buttonBorderShape(.circle).frame(width: 44, height: 44)
            } else {
                content.buttonStyle(.glass).buttonBorderShape(.capsule)
            }
        } else {
            if prominent {
                content.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
            } else if icon {
                content.buttonStyle(.bordered).buttonBorderShape(.circle).frame(width: 44, height: 44)
            } else {
                content.buttonStyle(.bordered).buttonBorderShape(.capsule)
            }
        }
    }
}

extension View {
    func afterimageSheetSurface() -> some View {
        background(AfterimageStyle.background)
            .presentationBackground(AfterimageStyle.background)
            .modifier(SoftNavigationEdge())
    }
    func afterimageControlGroup() -> some View { modifier(SystemControlGroup()) }
    func afterimageControl(prominent: Bool = false, icon: Bool = false) -> some View {
        modifier(SystemControlStyle(prominent: prominent, icon: icon))
    }
}

private struct SoftNavigationEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
                .toolbarBackground(.automatic, for: .navigationBar)
        } else {
            content.toolbarBackground(.automatic, for: .navigationBar)
        }
    }
}

private struct SystemControlGroup: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.padding(.horizontal, 12).frame(height: 48).fixedSize(horizontal: true, vertical: false)
                .glassEffect(.regular, in: .capsule)
        } else {
            content.padding(.horizontal, 12).frame(height: 48).fixedSize(horizontal: true, vertical: false)
                .background(.regularMaterial, in: Capsule())
        }
    }
}
