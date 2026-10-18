import AppKit

// Save the icon macOS itself shows for a bundle (IconServices, as used by Finder), so the
// packaged icon can be reviewed without opening Finder. It reads files only; nothing launches.
// Usage: swift scripts/app-icon-snapshot.swift build/VolumeBridge.app build/icon-snapshot.png [pixels]
let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: app-icon-snapshot.swift APP OUTPUT.png [pixels]\n".data(using: .utf8)!)
    exit(2)
}
let pixels = args.count > 3 ? Int(args[3]) ?? 512 : 512
// NSWorkspace needs an absolute path; a relative one silently yields the generic document icon.
let app = URL(fileURLWithPath: args[1]).standardizedFileURL.path
guard FileManager.default.fileExists(atPath: app) else {
    FileHandle.standardError.write("not found: \(app)\n".data(using: .utf8)!)
    exit(1)
}
let icon = NSWorkspace.shared.icon(forFile: app)
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
icon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: args[2]))
print(args[2])
