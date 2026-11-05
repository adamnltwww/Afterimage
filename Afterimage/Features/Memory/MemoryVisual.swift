import SwiftUI
import UIKit
import ImageIO

enum AfterimageStyle {
    static let background = Color(red: 0.035, green: 0.043, blue: 0.055)
    static let surface = Color(red: 0.095, green: 0.102, blue: 0.11)
    static let amber = Color(red: 0.88, green: 0.65, blue: 0.40)
}

struct MemoryVisual: View {
    let id: UUID
    let photoData: Data?
    var preserveAspect = false
    @State private var preview: UIImage?

    private var seed: Double {
        Double(id.uuidString.utf8.reduce(0) { ($0 + Int($1)) % 997 }) / 997
    }

    var body: some View {
        GeometryReader { geometry in
            if let image = preview {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: preserveAspect ? .fit : .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else {
                ZStack {
                    Color(hue: seed, saturation: 0.18, brightness: 0.11)
                    Ellipse()
                        .fill(Color(hue: seed, saturation: 0.35, brightness: 0.54).opacity(0.5))
                        .frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.7)
                        .blur(radius: 38)
                        .offset(x: geometry.size.width * (seed - 0.5), y: -20)
                    Ellipse()
                        .fill(AfterimageStyle.amber.opacity(0.27))
                        .frame(width: geometry.size.width * 0.6, height: 45)
                        .blur(radius: 28)
                        .rotationEffect(.degrees(-28))
                        .offset(y: geometry.size.height * 0.3)
                    Canvas { context, size in
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: size.height * 0.7))
                        path.addCurve(to: CGPoint(x: size.width, y: size.height * 0.5),
                                      control1: CGPoint(x: size.width * 0.4, y: size.height * seed),
                                      control2: CGPoint(x: size.width * 0.6, y: size.height))
                        context.stroke(path, with: .color(AfterimageStyle.amber.opacity(0.35)), lineWidth: 0.7)
                    }
                }
                .clipped()
            }
        }
        .accessibilityHidden(true)
        .task(id: photoData) {
            preview = nil
            guard let photoData else { return }
            let image = await Task.detached(priority: .userInitiated) { () -> CGImage? in
                guard let source = CGImageSourceCreateWithData(photoData as CFData, nil) else { return nil }
                return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1000,
                    kCGImageSourceShouldCacheImmediately: true
                ] as CFDictionary)
            }.value
            guard !Task.isCancelled else { return }
            preview = image.map { UIImage(cgImage: $0) }
        }
    }
}
