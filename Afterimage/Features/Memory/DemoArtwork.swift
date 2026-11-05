import UIKit

/// Small fictional studies for the isolated demo, visibly labelled as illustrations.
enum DemoArtwork {
    static func data(scene: Int) -> Data? {
        let size = scene.isMultiple(of: 2) ? CGSize(width: 600, height: 380) : CGSize(width: 380, height: 540)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let context = renderer.cgContext
            let w = size.width, h = size.height
            let palettes: [[UIColor]] = [
                [UIColor(red: 0.12, green: 0.20, blue: 0.25, alpha: 1), UIColor(red: 0.76, green: 0.52, blue: 0.34, alpha: 1)],
                [UIColor(red: 0.12, green: 0.24, blue: 0.29, alpha: 1), UIColor(red: 0.76, green: 0.75, blue: 0.58, alpha: 1)],
                [UIColor(red: 0.13, green: 0.19, blue: 0.22, alpha: 1), UIColor(red: 0.62, green: 0.69, blue: 0.60, alpha: 1)],
                [UIColor(red: 0.17, green: 0.16, blue: 0.25, alpha: 1), UIColor(red: 0.72, green: 0.42, blue: 0.31, alpha: 1)]
            ]
            let palette = palettes[scene % palettes.count]
            let colors = palette.map(\.cgColor) as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: w * 0.3, y: h), options: [])
            }
            context.setFillColor(UIColor(red: 0.98, green: 0.83, blue: 0.55, alpha: 0.8).cgColor)
            context.fillEllipse(in: CGRect(x: w * 0.68, y: h * 0.29, width: 30, height: 30))
            if scene == 1 || scene == 2 {
                context.setFillColor(UIColor(red: 0.08, green: 0.17, blue: 0.18, alpha: 0.8).cgColor)
                context.move(to: CGPoint(x: 0, y: h * 0.58))
                context.addCurve(to: CGPoint(x: w, y: h * 0.54), control1: CGPoint(x: w * 0.28, y: h * 0.37), control2: CGPoint(x: w * 0.61, y: h * 0.68))
                context.addLine(to: CGPoint(x: w, y: h)); context.addLine(to: CGPoint(x: 0, y: h)); context.closePath(); context.fillPath()
                for row in 0..<18 {
                    let y = h * 0.66 + CGFloat(row) * h * 0.018
                    context.setStrokeColor(UIColor.white.withAlphaComponent(0.03 + Double(row % 3) * 0.02).cgColor)
                    context.move(to: CGPoint(x: CGFloat(row % 4) * 34, y: y))
                    context.addLine(to: CGPoint(x: w - CGFloat(row % 5) * 29, y: y + 2))
                    context.setLineWidth(1); context.strokePath()
                }
            } else {
                for column in 0..<9 {
                    let x = CGFloat(column) * w / 8 - 12
                    let height = h * (0.18 + CGFloat((column * 7 + scene) % 5) * 0.045)
                    context.setFillColor(UIColor(red: 0.06, green: 0.09, blue: 0.12, alpha: 0.85).cgColor)
                    context.fill(CGRect(x: x, y: h * 0.77 - height, width: w / 9, height: h * 0.23 + height))
                    context.setFillColor(UIColor(red: 0.95, green: 0.75, blue: 0.43, alpha: 0.55).cgColor)
                    for row in 0..<3 { context.fill(CGRect(x: x + 10, y: h * 0.77 - height + 14 + CGFloat(row) * 22, width: 4, height: 7)) }
                }
            }
            let caption = "AFTERIMAGE / 演示插画" as NSString
            caption.draw(at: CGPoint(x: 16, y: h - 27), withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.65)
            ])
        }
        return image.jpegData(compressionQuality: 0.82)
    }
}
