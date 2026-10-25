// Draws Murmur's app icon and writes Resources/AppIcon.icns.
// Run from the repo root: swift scripts/make-icon.swift
//
// Follows Apple's macOS grid: a 1024 canvas with an 824 continuous-corner squircle,
// so macOS shows it as-is instead of shrinking it onto a grey tile.
import AppKit
import SwiftUI

let blue = Color(red: 0.25, green: 0.38, blue: 1.0)
let rim = Color(red: 0.66, green: 0.74, blue: 1.0)

/// Same silhouette as the prompter: concave shoulders, rounded bottom.
struct NotchShape: Shape {
    var shoulder: CGFloat
    var bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let s = shoulder, r = bottomRadius
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addArc(tangent1End: CGPoint(x: rect.minX + s, y: rect.minY), tangent2End: CGPoint(x: rect.minX + s, y: rect.maxY), radius: s)
        p.addArc(tangent1End: CGPoint(x: rect.minX + s, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: r)
        p.addArc(tangent1End: CGPoint(x: rect.maxX - s, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - s, y: rect.minY), radius: r)
        p.addArc(tangent1End: CGPoint(x: rect.maxX - s, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: s)
        p.closeSubpath()
        return p
    }
}

struct Beam: View {
    let width: CGFloat

    var body: some View {
        ZStack {
            Ellipse().fill(RadialGradient(colors: [blue.opacity(0.85), blue.opacity(0.3), blue.opacity(0)],
                                          center: .center, startRadius: 0, endRadius: width * 0.55))
            Ellipse().stroke(blue, lineWidth: width * 0.07).blur(radius: width * 0.05)
            Ellipse().stroke(rim, lineWidth: width * 0.018).blur(radius: width * 0.008)
        }
        .frame(width: width, height: width * 0.5)
    }
}

struct Panel: View {
    static let size = CGSize(width: 560, height: 480)

    var body: some View {
        let w = Self.size.width, h = Self.size.height
        ZStack {
            Color.black
            // Camera
            Circle()
                .fill(Color(red: 0.09, green: 0.10, blue: 0.16))
                .overlay(Circle().fill(Color(red: 0.17, green: 0.25, blue: 0.50)).padding(9))
                .overlay(Circle().fill(Color.white.opacity(0.5)).frame(width: 5, height: 5).offset(x: -4, y: -4))
                .frame(width: 34, height: 34)
                .position(x: w / 2, y: 62)
            // Script lines, the last one fading out like the prompter does
            ForEach(Array([(0.0, 340.0, 1.0), (58.0, 400.0, 1.0), (116.0, 290.0, 0.4)].enumerated()), id: \.offset) { _, line in
                Capsule()
                    .fill(Color.white.opacity(line.2))
                    .frame(width: line.1, height: 28)
                    .position(x: w / 2, y: 168 + line.0)
            }
            Beam(width: 400)
                .position(x: w / 2, y: h + 34)
        }
        .frame(width: w, height: h)
        .clipShape(NotchShape(shoulder: 46, bottomRadius: 132))
    }
}

struct IconArt: View {
    var body: some View {
        let squircle = RoundedRectangle(cornerRadius: 185, style: .continuous)
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.95, green: 0.96, blue: 1.0), Color(red: 0.74, green: 0.79, blue: 0.93)],
                           startPoint: .top, endPoint: .bottom)
            // Blue light spilling down from the notch, soft on every edge
            Circle()
                .fill(RadialGradient(colors: [blue.opacity(0.5), blue.opacity(0.18), blue.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 360))
                .frame(width: 720, height: 720)
                .scaleEffect(x: 1, y: 0.55)
                .blur(radius: 24)
                .offset(y: Panel.size.height - 360 + 20)
            Panel()
        }
        .frame(width: 824, height: 824)
        .clipShape(squircle)
        .overlay(squircle.strokeBorder(Color.black.opacity(0.08), lineWidth: 2))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 8)
        .frame(width: 1024, height: 1024)
    }
}

func resized(_ image: CGImage, to size: Int) -> Data {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: IconArt())
    renderer.scale = 1
    guard let master = renderer.cgImage else { fatalError("Icon render failed") }

    let fm = FileManager.default
    let iconset = URL(fileURLWithPath: "build/AppIcon.iconset")
    try? fm.removeItem(at: iconset)
    try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

    for points in [16, 32, 128, 256, 512] {
        try! resized(master, to: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
        try! resized(master, to: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
    }
    try! resized(master, to: 1024).write(to: URL(fileURLWithPath: "build/icon-preview.png"))

    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
    try! iconutil.run()
    iconutil.waitUntilExit()
    print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
}
