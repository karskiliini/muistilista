import Foundation
import AppKit
import CoreGraphics
import ImageIO

let S = 1024
let cs = CGColorSpaceCreateDeviceRGB()
// noneSkipLast → no alpha channel; app icons must be fully opaque.
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Top-left origin, y down.
ctx.translateBy(x: 0, y: CGFloat(S)); ctx.scaleBy(x: 1, y: -1)

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}
let dark = NSColor(calibratedRed: 0.27, green: 0.26, blue: 0.24, alpha: 1)
let green = NSColor(calibratedRed: 0.20, green: 0.70, blue: 0.30, alpha: 1)

// Background: warm off-white, subtle vertical gradient.
let bg = CGGradient(colorsSpace: cs,
    colors: [rgb(0.945, 0.933, 0.910), rgb(0.882, 0.867, 0.835)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 0),
                       end: CGPoint(x: 0, y: 1024), options: [])

/// Draw an SF Symbol tinted `color`, centered in `rect` (aspect-fit).
func symbol(_ name: String, _ rect: CGRect, _ color: NSColor, weight: NSFont.Weight = .semibold) {
    let cfg = NSImage.SymbolConfiguration(pointSize: rect.height, weight: weight)
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) else {
        FileHandle.standardError.write("missing symbol \(name)\n".data(using: .utf8)!)
        return
    }
    let sz = base.size
    let tinted = NSImage(size: sz)
    tinted.lockFocus()
    base.draw(in: NSRect(origin: .zero, size: sz))
    color.set()
    NSRect(origin: .zero, size: sz).fill(using: .sourceAtop)
    tinted.unlockFocus()
    var pr = CGRect(origin: .zero, size: sz)
    guard let cg = tinted.cgImage(forProposedRect: &pr, context: nil, hints: nil) else { return }
    // Aspect-fit into rect.
    let scale = min(rect.width / sz.width, rect.height / sz.height)
    let w = sz.width * scale, h = sz.height * scale
    let x = rect.midX - w / 2, y = rect.midY - h / 2
    ctx.saveGState()
    ctx.translateBy(x: x, y: y + h)     // flip locally so the image isn't upside-down
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    ctx.restoreGState()
}

func line(y: CGFloat) {
    let r = CGRect(x: 404, y: y - 15, width: 408, height: 30)
    ctx.setFillColor(dark.cgColor)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 15, cornerHeight: 15, transform: nil))
    ctx.fillPath()
}

let rows: [CGFloat] = [388, 566, 744]

// Row 1: checkbox with a green check.
symbol("square", CGRect(x: 196, y: rows[0] - 62, width: 124, height: 124), dark, weight: .bold)
symbol("checkmark", CGRect(x: 212, y: rows[0] - 72, width: 142, height: 142), green, weight: .heavy)
line(y: rows[0])

// Row 2: shopping cart.
symbol("cart", CGRect(x: 186, y: rows[1] - 64, width: 158, height: 128), dark, weight: .semibold)
line(y: rows[1])

// Row 3: price tag with a dollar sign.
symbol("tag", CGRect(x: 190, y: rows[2] - 62, width: 140, height: 124), dark, weight: .semibold)
symbol("dollarsign", CGRect(x: 228, y: rows[2] - 34, width: 46, height: 64), dark, weight: .bold)
line(y: rows[2])

let out = CommandLine.arguments[1]
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL,
                                           "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out)")
