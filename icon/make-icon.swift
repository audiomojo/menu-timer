// Draws the 1024×1024 app icon: an alarm clock with a countdown wedge on a warm rounded square.
// Usage: swift icon/make-icon.swift <output.png>   (icon/make-icon.sh builds the .icns from it)
import AppKit

let size = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Point at `radius` from `center`, `degrees` clockwise from 12 o'clock.
func point(_ center: CGPoint, _ radius: CGFloat, _ degrees: CGFloat) -> CGPoint {
    let radians = degrees * .pi / 180
    return CGPoint(x: center.x + radius * sin(radians), y: center.y + radius * cos(radians))
}

func circle(_ ctx: CGContext, _ center: CGPoint, _ radius: CGFloat, _ fill: CGColor) {
    ctx.setFillColor(fill)
    ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

func line(_ ctx: CGContext, from a: CGPoint, to b: CGPoint, width: CGFloat, _ stroke: CGColor) {
    ctx.setStrokeColor(stroke)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.move(to: a)
    ctx.addLine(to: b)
    ctx.strokePath()
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext

// Rounded-square base, inset like Apple's macOS icon grid, with a soft drop shadow.
let base = CGRect(x: 100, y: 100, width: 824, height: 824)
let basePath = CGPath(roundedRect: base, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, 0.3))
ctx.addPath(basePath)
ctx.setFillColor(color(0xF2452E))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(basePath)
ctx.clip()
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: [color(0xFFA040), color(0xF2452E)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: base.maxY), end: CGPoint(x: 512, y: base.minY), options: [])
ctx.restoreGState()

let center = CGPoint(x: 512, y: 488)
let ink = color(0x3B2620)
let white = color(0xFFFFFF)

// Legs and bells sit behind the clock body.
for side: CGFloat in [-1, 1] {
    line(ctx, from: point(center, 230, side * 145), to: point(center, 320, side * 145), width: 34, white)
    circle(ctx, point(center, 268, side * 42), 92, white)
    line(ctx, from: point(center, 268, side * 42), to: point(center, 380, side * 42), width: 26, white)
}

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: color(0x7A1E0E, 0.35))
circle(ctx, center, 262, white)
ctx.restoreGState()
circle(ctx, center, 222, color(0xFFF6EE))

// Countdown wedge: from 12 o'clock clockwise to 4 o'clock.
let wedgeEnd: CGFloat = 120
ctx.move(to: center)
ctx.addArc(center: center, radius: 196, startAngle: .pi / 2, endAngle: .pi / 2 - wedgeEnd * .pi / 180, clockwise: true)
ctx.closePath()
ctx.setFillColor(color(0xF9703A, 0.9))
ctx.fillPath()

// Hour ticks, heavier at 12, 3, 6 and 9.
for hour in 0..<12 {
    let major = hour % 3 == 0
    let angle = CGFloat(hour) * 30
    if angle == wedgeEnd { continue }  // the hand sits here
    line(ctx, from: point(center, major ? 168 : 182, angle), to: point(center, 202, angle),
         width: major ? 18 : 10, ink)
}

// One hand on the wedge's edge, like a timer counting down, and the center cap.
line(ctx, from: center, to: point(center, 176, wedgeEnd), width: 22, ink)
line(ctx, from: center, to: point(center, 110, 0), width: 22, ink)
circle(ctx, center, 26, ink)
circle(ctx, center, 9, color(0xF9703A))

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
