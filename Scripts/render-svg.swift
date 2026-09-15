// Renders an SVG to a transparent PNG.
//
// The brand assets are authored as SVG in `Packaging/Logo/`. macOS cannot load SVG into `NSImage`
// outside an asset catalog, so this tool rasterises them through WebKit — the same engine
// the legacy Electron app rendered them with, so the result is pixel-identical to 0.9.7.
//
//   swift Scripts/render-svg.swift <input.svg> <output.png> <width> <height>
//
// Re-run it when a logo changes; the PNGs it writes live in Sources/Brewwery/Resources.

import AppKit
import WebKit

let arguments = CommandLine.arguments
guard arguments.count == 5,
      let width = Double(arguments[3]),
      let height = Double(arguments[4])
else {
    FileHandle.standardError.write(Data("usage: render-svg <input.svg> <output.png> <width> <height>\n".utf8))
    exit(2)
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let svg = try String(contentsOf: inputURL, encoding: .utf8)

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)

final class Renderer: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let outputURL: URL
    let size: NSSize

    init(outputURL: URL, size: NSSize) {
        self.outputURL = outputURL
        self.size = size
        webView = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: WKWebViewConfiguration())
        super.init()
        // Keep the page background clear so the PNG carries a real alpha channel.
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
    }

    func load(_ svg: String) {
        let html = """
        <!doctype html>
        <html><head><meta charset="utf-8"><style>
          html, body { margin: 0; padding: 0; background: transparent; }
          svg { display: block; width: 100vw; height: 100vh; }
        </style></head><body>\(svg)</body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // One run-loop turn so the SVG is laid out before the snapshot is taken.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.snapshot() }
    }

    private func snapshot() {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = NSRect(origin: .zero, size: size)
        configuration.snapshotWidth = NSNumber(value: Double(size.width))
        configuration.afterScreenUpdates = true

        webView.takeSnapshot(with: configuration) { image, error in
            guard let image, error == nil else {
                FileHandle.standardError.write(Data("snapshot failed: \(error.map(String.init(describing:)) ?? "unknown")\n".utf8))
                exit(1)
            }
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:])
            else {
                FileHandle.standardError.write(Data("encoding failed\n".utf8))
                exit(1)
            }
            do {
                try png.write(to: self.outputURL)
                print("wrote \(self.outputURL.lastPathComponent) (\(bitmap.pixelsWide)x\(bitmap.pixelsHigh))")
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
                exit(1)
            }
        }
    }
}

let renderer = Renderer(outputURL: outputURL, size: NSSize(width: width, height: height))
let window = NSWindow(
    contentRect: NSRect(origin: .zero, size: NSSize(width: width, height: height)),
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
window.contentView = renderer.webView
window.backgroundColor = .clear
window.isOpaque = false
window.orderFrontRegardless()

renderer.load(svg)
application.run()
