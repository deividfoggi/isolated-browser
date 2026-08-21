import Cocoa

// Gera um PNG 1024x1024 do ícone (fundo gradiente arredondado + globo estilizado + cadeado).
// Uso: mkicon <saida.png>

let size: CGFloat = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let bg = NSBezierPath(roundedRect: rect, xRadius: 180, yRadius: 180)
bg.addClip()

let colors = [
    NSColor(calibratedRed: 0.13, green: 0.20, blue: 0.36, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.13, alpha: 1).cgColor,
] as CFArray
if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
}

// Globo estilizado
let cx = size / 2, cy = size * 0.56, r: CGFloat = size * 0.30
let stroke = NSColor.white
stroke.setStroke()

let circle = NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
circle.lineWidth = 26
circle.stroke()

// Equador + meridiano (elipses)
let eq = NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r * 0.42, width: 2 * r, height: r * 0.84))
eq.lineWidth = 18
eq.stroke()
let mer = NSBezierPath(ovalIn: NSRect(x: cx - r * 0.42, y: cy - r, width: r * 0.84, height: 2 * r))
mer.lineWidth = 18
mer.stroke()

// linha vertical e horizontal
let vline = NSBezierPath()
vline.move(to: NSPoint(x: cx, y: cy - r)); vline.line(to: NSPoint(x: cx, y: cy + r))
vline.lineWidth = 18; vline.stroke()
let hline = NSBezierPath()
hline.move(to: NSPoint(x: cx - r, y: cy)); hline.line(to: NSPoint(x: cx + r, y: cy))
hline.lineWidth = 18; hline.stroke()

// Cadeado (isolamento)
let lw: CGFloat = size * 0.20, lh: CGFloat = size * 0.16
let lx = cx - lw / 2, ly = size * 0.13
NSColor(calibratedRed: 0.30, green: 0.85, blue: 0.55, alpha: 1).setFill()
let body = NSBezierPath(roundedRect: NSRect(x: lx, y: ly, width: lw, height: lh), xRadius: 24, yRadius: 24)
body.fill()
stroke.setStroke()
let shackle = NSBezierPath(ovalIn: NSRect(x: cx - lw * 0.28, y: ly + lh * 0.55, width: lw * 0.56, height: lw * 0.56))
shackle.lineWidth = 26
shackle.stroke()

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try? png.write(to: URL(fileURLWithPath: outPath))
