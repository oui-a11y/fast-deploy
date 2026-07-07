import AppKit
import Foundation

struct IconSpec {
    let name: String
    let size: Int
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    fputs("Usage: make-app-icon.swift <source.png> <iconset-dir> <output.icns>\n", stderr)
    exit(64)
}

let sourceURL = URL(fileURLWithPath: arguments[1])
let iconsetURL = URL(fileURLWithPath: arguments[2], isDirectory: true)
let outputURL = URL(fileURLWithPath: arguments[3])

guard let source = NSImage(contentsOf: sourceURL) else {
    fputs("Could not read source image: \(sourceURL.path)\n", stderr)
    exit(66)
}

let specs = [
    IconSpec(name: "icon_16x16.png", size: 16),
    IconSpec(name: "icon_16x16@2x.png", size: 32),
    IconSpec(name: "icon_32x32.png", size: 32),
    IconSpec(name: "icon_32x32@2x.png", size: 64),
    IconSpec(name: "icon_128x128.png", size: 128),
    IconSpec(name: "icon_128x128@2x.png", size: 256),
    IconSpec(name: "icon_256x256.png", size: 256),
    IconSpec(name: "icon_256x256@2x.png", size: 512),
    IconSpec(name: "icon_512x512.png", size: 512),
    IconSpec(name: "icon_512x512@2x.png", size: 1024)
]

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for spec in specs {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: spec.size,
        pixelsHigh: spec.size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fputs("Could not allocate bitmap for \(spec.name)\n", stderr)
        exit(70)
    }

    rep.size = NSSize(width: spec.size, height: spec.size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: spec.size, height: spec.size).fill()
    source.draw(in: NSRect(x: 0, y: 0, width: spec.size, height: spec.size))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("Could not encode \(spec.name)\n", stderr)
        exit(70)
    }
    try data.write(to: iconsetURL.appendingPathComponent(spec.name), options: [.atomic])
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    exit(process.terminationStatus)
}
