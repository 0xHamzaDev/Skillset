import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let inset: CGFloat = 96
let plate = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
NSBezierPath(roundedRect: plate, xRadius: 192, yRadius: 192).setClip()
NSGradient(
    starting: NSColor(srgbRed: 0.137, green: 0.129, blue: 0.118, alpha: 1),
    ending: NSColor(srgbRed: 0.063, green: 0.059, blue: 0.055, alpha: 1)
)!.draw(in: plate, angle: -90)

let orange = NSColor(srgbRed: 1, green: 0.42, blue: 0.19, alpha: 1)

for (index, angle) in [-14.0, 0.0, 14.0].enumerated() {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: 512 + CGFloat(index - 1) * 112, yBy: 512)
    transform.rotate(byDegrees: CGFloat(angle))
    transform.concat()
    let card = NSBezierPath(roundedRect: NSRect(x: -200, y: -250, width: 400, height: 500), xRadius: 86, yRadius: 86)
    orange.blended(withFraction: [0.58, 0.3, 0][index], of: NSColor(srgbRed: 0.25, green: 0.2, blue: 0.17, alpha: 1))!.setFill()
    card.fill()
    NSColor.white.withAlphaComponent(0.16).setStroke()
    card.lineWidth = 3
    card.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

image.unlockFocus()
let tiff = image.tiffRepresentation!
let png = NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
