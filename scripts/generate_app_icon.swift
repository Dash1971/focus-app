import AppKit

// AppKit renders at the Mac's 2x backing scale, producing Apple's required 1024 px asset.
let size = NSSize(width: 512, height: 512)
let image = NSImage(size: size)
image.lockFocus()

let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.12, alpha: 1),
    NSColor(calibratedRed: 0.20, green: 0.12, blue: 0.45, alpha: 1)
])!
background.draw(in: NSRect(origin: .zero, size: size), angle: -55)

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 305),
    .paragraphStyle: paragraph
]
let emoji = NSAttributedString(string: "🔒", attributes: attributes)
emoji.draw(in: NSRect(x: 0, y: 85, width: 512, height: 350))
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render app icon")
}
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.png")
try png.write(to: output)
print(output.path)
