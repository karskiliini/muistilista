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
let dark = NSColor(calibratedRed: 0.25, green: 0.24, blue: 0.22, alpha: 1)
let green = NSColor(calibratedRed: 0.18, green: 0.66, blue: 0.29, alpha: 1)

// Background: warm off-white, subtle vertical gradient (kept as-is).
let bg = CGGradient(colorsSpace: cs,
    colors: [rgb(0.945, 0.933, 0.910), rgb(0.882, 0.867, 0.835)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 0),
                       end: CGPoint(x: 0, y: 1024), options: [])

/// Draw an SF Symbol tinted `color`, centered in `rect` (aspect-fit).
func symbol(_ name: String, _ rect: CGRect, _ color: NSColor, weight: NSFont.Weight = .semibold) {
    let cfg = NSImage.SymbolConfiguration(pointSize: rect.height, weight: weight)
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) else { return }
    let sz = base.size
    let tinted = NSImage(size: sz)
    tinted.lockFocus()
    base.draw(in: NSRect(origin: .zero, size: sz))
    color.set()
    NSRect(origin: .zero, size: sz).fill(using: .sourceAtop)
    tinted.unlockFocus()
    var pr = CGRect(origin: .zero, size: sz)
    guard let cg = tinted.cgImage(forProposedRect: &pr, context: nil, hints: nil) else { return }
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
    let r = CGRect(x: 402, y: y - 14, width: 358, height: 28)
    ctx.setFillColor(dark.cgColor)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.fillPath()
}

// ---- Post-it note (slightly tilted), with the motif on top ----
let center = CGPoint(x: 512, y: 516)
ctx.saveGState()
ctx.translateBy(x: center.x, y: center.y)
ctx.rotate(by: -3.0 * .pi / 180)          // gentle tilt
ctx.translateBy(x: -center.x, y: -center.y)

// Note paper with a soft drop shadow.
let note = CGRect(x: 168, y: 172, width: 688, height: 688)
let notePath = CGPath(roundedRect: note, cornerWidth: 16, cornerHeight: 16, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 24), blur: 44, color: rgb(0.35, 0.30, 0.10, 0.34))
ctx.setFillColor(rgb(0.99, 0.90, 0.36))
ctx.addPath(notePath); ctx.fillPath()
ctx.restoreGState()
// Subtle paper gradient (lighter top → warmer bottom) for depth.
ctx.saveGState()
ctx.addPath(notePath); ctx.clip()
let paper = CGGradient(colorsSpace: cs,
    colors: [rgb(1.0, 0.95, 0.55), rgb(0.98, 0.86, 0.30)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(paper, start: CGPoint(x: 0, y: 172),
                       end: CGPoint(x: 0, y: 860), options: [])
ctx.restoreGState()

// Motif on the note.
let rows: [CGFloat] = [356, 516, 676]
symbol("square", CGRect(x: 232, y: rows[0] - 54, width: 108, height: 108), dark, weight: .bold)
symbol("checkmark", CGRect(x: 246, y: rows[0] - 62, width: 124, height: 124), green, weight: .heavy)
line(y: rows[0])
symbol("cart", CGRect(x: 224, y: rows[1] - 56, width: 138, height: 112), dark, weight: .semibold)
line(y: rows[1])
symbol("tag", CGRect(x: 226, y: rows[2] - 54, width: 122, height: 108), dark, weight: .semibold)
symbol("dollarsign", CGRect(x: 260, y: rows[2] - 30, width: 40, height: 56), dark, weight: .bold)
line(y: rows[2])

ctx.restoreGState()

let out = CommandLine.arguments[1]
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL,
                                           "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out)")
