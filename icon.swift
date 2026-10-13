// アプリアイコン生成（白地＋10目盛り。Liquid Glass 風の光沢・厚み）
// 使い方: swiftc -target arm64-apple-macos14.0 icon.swift -o build/icon && build/icon AppIcon.iconset && iconutil -c icns AppIcon.iconset
import AppKit

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func gray(_ w: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(white: w, alpha: a) }
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }

// 影をつけて描く
func withShadow(_ color: NSColor, _ offset: NSSize, _ blur: CGFloat, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow()
    s.shadowColor = color
    s.shadowOffset = offset
    s.shadowBlurRadius = blur
    s.set()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

// パスの内側にだけ影を落とす（へこみ表現）
func innerShadow(_ path: NSBezierPath, _ color: NSColor, _ offset: NSSize, _ blur: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    let outer = NSBezierPath(rect: path.bounds.insetBy(dx: -200, dy: -200))
    outer.append(path.reversed)
    withShadow(color, offset, blur) {
        gray(0).setFill()
        outer.fill()
    }
    NSGraphicsContext.restoreGraphicsState()
}

extension NSBezierPath {
    func strokedOutline(width: CGFloat) -> NSBezierPath {
        let cg = self.cgPath.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
        return NSBezierPath(cgPath: cg)
    }
}

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // ── 本体: Liquid Glass に馴染む、柔らかい白（濃い外周線は使わない） ──
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    withShadow(gray(0, 0.22), NSSize(width: 0, height: -10), 28) {
        gray(0.95).setFill()
        bodyPath.fill()
    }
    NSGradient(colors: [gray(0.995), gray(0.955), gray(0.90)], atLocations: [0, 0.5, 1], colorSpace: .deviceRGB)!
        .draw(in: bodyPath, angle: -90)
    // ガラスの縁に乗る鏡面ハイライト（左上が強く、右下にも淡く回り込む）
    let rim = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    rim.append(NSBezierPath(roundedRect: body.insetBy(dx: 9, dy: 9), xRadius: 176, yRadius: 176))
    rim.windingRule = .evenOdd
    NSGradient(colors: [gray(1, 1.0), gray(1, 0.0), gray(1, 0.0), gray(1, 0.7)],
               atLocations: [0, 0.42, 0.62, 1], colorSpace: .deviceRGB)!.draw(in: rim, angle: -45)
    gray(0, 0.08).setStroke(); bodyPath.lineWidth = 2; bodyPath.stroke()

    // ── 10目盛り（残り6）: 点灯=光沢のある濃いガラス、消灯=本体に浅く彫られた溝 ──
    let segments = 10, lit = 6
    let w: CGFloat = 50, gap: CGFloat = 14, h: CGFloat = 230, radius: CGFloat = 14
    let total = CGFloat(segments) * w + CGFloat(segments - 1) * gap
    let x0 = (1024 - total) / 2, y0 = (1024 - h) / 2
    for i in 0..<segments {
        let r = NSRect(x: x0 + CGFloat(i) * (w + gap), y: y0, width: w, height: h)
        let p = NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
        if i < lit {
            // 下に柔らかい影を落として浮かせる
            withShadow(gray(0, 0.28), NSSize(width: 0, height: -8), 12) { gray(0.1).setFill(); p.fill() }
            NSGradient(colors: [gray(0.30), gray(0.14), gray(0.07)], atLocations: [0, 0.45, 1], colorSpace: .deviceRGB)!
                .draw(in: p, angle: -90)
            // 全体になめらかにかかる光（帯の切れ目を作らない）
            NSGradient(colors: [gray(1, 0.26), gray(1, 0.06), gray(1, 0.0)], atLocations: [0, 0.45, 1], colorSpace: .deviceRGB)!
                .draw(in: p, angle: -90)
            // 縁で光が屈折して見える内側の明るい縁（上が強く下は淡く）
            NSGraphicsContext.saveGraphicsState()
            p.addClip()
            let edge = NSBezierPath(roundedRect: r.insetBy(dx: 1.5, dy: 1.5), xRadius: radius - 1.5, yRadius: radius - 1.5)
            edge.lineWidth = 3
            NSGradient(colors: [gray(1, 0.45), gray(1, 0.05), gray(1, 0.22)], atLocations: [0, 0.6, 1], colorSpace: .deviceRGB)!
                .draw(in: edge.strokedOutline(width: 3), angle: -90)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            NSGradient(starting: gray(0.86), ending: gray(0.91))!.draw(in: p, angle: -90)
            innerShadow(p, gray(0, 0.20), NSSize(width: 0, height: -5), 8)
            // 溝の下側にやわらかく光が回る
            NSGraphicsContext.saveGraphicsState()
            p.addClip()
            NSGradient(colors: [gray(1, 0.0), gray(1, 0.0), gray(1, 0.55)], atLocations: [0, 0.8, 1], colorSpace: .deviceRGB)!
                .draw(in: p, angle: 90)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// iconutil が要求するファイル名とピクセル数
for base in [16, 32, 128, 256, 512] {
    try! draw(base).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base).png"))
    try! draw(base * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base)@2x.png"))
}
