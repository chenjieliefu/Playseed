// Apply the macOS icon safe area and an actual alpha channel when packaging artwork.
import AppKit
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let target = URL(fileURLWithPath: CommandLine.arguments[2])
guard let image = NSImage(contentsOf: source),
      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { fatalError("Cannot load icon") }
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill(using: .copy)
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
NSBezierPath(roundedRect: tile, xRadius: 200, yRadius: 200).addClip()
// The edited artwork has a 7% surround. Crop that surround before placing the tile.
let crop = NSRect(x: image.size.width * 0.069, y: image.size.height * 0.069,
                  width: image.size.width * 0.862, height: image.size.height * 0.862)
image.draw(in: tile, from: crop, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
try png.write(to: target)
// Guard against accidentally shipping another opaque square.
assert(bitmap.colorAt(x: 0, y: 0)!.alphaComponent == 0)
assert(bitmap.colorAt(x: 512, y: 512)!.alphaComponent > 0.99)
