// Captures one window of a HIDDEN app via ScreenCaptureKit, without ever taking focus.
//
// Build: swiftc -parse-as-library -O snapshot-capture.swift -o .build/snapshot-capture
//
// Why this exists: the old approach ran `open -a` in a loop, which activates the app — it
// repeatedly stole focus from whoever was using the machine. That loop was never necessary.
// None of the capture APIs care about frontmost-ness, z-order or occlusion; they read the
// window's backing store. The `open -a` was there to fight Stage Manager, which parks a
// *backgrounded* app's window as a ~100x143 thumbnail — and every API then faithfully
// captures the thumbnail, because at that moment the thumbnail is what the window is.
// Launching HIDDEN (`open -j`) sidesteps that entirely: the window is created and rendered at
// full size but lives on no stage, so Stage Manager has nothing to park.
//
// Two traps worth stating, both of which produced the old "window never surfaced" failures:
//   * A hidden app's window reports `isOnScreen == false`, so `onScreenWindowsOnly: true`
//     filters out the very window you are waiting for.
//   * Match on `bundleIdentifier`, never on the application's display name — that name is
//     "DiveSaveEd" while the process is DaveTheDiverSaveEditor, and LaunchServices caches it.
//
// Known and accepted: the window is never key, so macOS renders it in its INACTIVE state.
// Traffic lights are gray, the toolbar dims, and accent-tinted controls desaturate. That is
// not fakeable — it is how an unfocused window genuinely looks. Use `--active` on the shell
// script for the rare occasion you want live chrome and are willing to lose focus for a minute.
import ScreenCaptureKit
import Foundation
import AppKit

@main
struct SnapshotCapture {

    static func fail(_ code: Int32, _ message: String) -> Never {
        FileHandle.standardError.write(Data("  ! snapshot-capture: \(message)\n".utf8))
        exit(code)
    }

    static func main() async {
        // Without touching NSApplication, CoreGraphics aborts inside ScreenCaptureKit with
        // "Assertion failed: (did_initialize)" — a CLI has no window-server connection yet.
        _ = NSApplication.shared

        var args = Array(CommandLine.arguments.dropFirst())
        let withSheet = args.contains("--sheet")
        args.removeAll { $0 == "--sheet" }
        guard args.count == 4, let wantW = Double(args[2]), let wantH = Double(args[3]) else {
            fail(64, "usage: snapshot-capture <bundle-id> <out.png> <width-pt> <height-pt> [--sheet]")
        }
        let bundleID = args[0], outPath = args[1]

        guard CGPreflightScreenCaptureAccess() else {
            fail(3, "Screen Recording permission is missing. Grant it to the terminal running this, not to the app.")
        }

        // MARK: Find the window, at its full size

        var parent: SCWindow?
        var sheet: SCWindow?
        var lastSeen = "none"

        for _ in 0..<40 {
            let content = try? await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: false)
            let mine = (content?.windows ?? []).filter {
                $0.owningApplication?.bundleIdentifier == bundleID && $0.windowLayer == 0
            }
            if let found = mine.first(where: {
                abs($0.frame.width - wantW) < 1 && abs($0.frame.height - wantH) < 1
            }) {
                parent = found
                sheet = mine.first { $0.windowID != found.windowID && $0.frame.width < wantW }
                if !withSheet || sheet != nil { break }
            }
            if let any = mine.first {
                lastSeen = "\(Int(any.frame.width))x\(Int(any.frame.height))"
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        guard let parent else {
            // Fail by name. A silently-wrong image is the worst outcome here, and a parked
            // window has a recognisable signature.
            let hint = lastSeen.hasPrefix("100x")
                ? "Stage Manager parked the window (\(lastSeen)) — it was not launched hidden. Check that the script uses `open -j -a`."
                : "window never reached \(Int(wantW))x\(Int(wantH)) (last seen: \(lastSeen))"
            fail(2, hint)
        }
        if withSheet && sheet == nil { fail(2, "sheet window never appeared next to the parent") }

        // MARK: Capture

        func shot(_ window: SCWindow) async -> CGImage {
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let cfg = SCStreamConfiguration()
            // These default to 1920x1080 — NOT the content size — so they must be set or the
            // output is silently the wrong size.
            cfg.width  = Int(filter.contentRect.width  * CGFloat(filter.pointPixelScale))
            cfg.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))
            cfg.captureResolution = .best
            cfg.ignoreShadowsSingleWindow = true
            cfg.ignoreGlobalClipSingleWindow = true
            cfg.backgroundColor = .clear        // preserves the rounded-corner alpha
            cfg.showsCursor = false             // true can fail with -3811 on this filter
            do {
                return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
            } catch {
                let ns = error as NSError
                fail(3, ns.code == -3801
                     ? "TCC denied (-3801): grant Screen Recording to the terminal running this, not to the app."
                     : "capture failed: \(error)")
            }
        }

        var image = await shot(parent)
        let scale = Int(SCContentFilter(desktopIndependentWindow: parent).pointPixelScale)

        // MARK: Composite the sheet

        // A SwiftUI `.sheet` is a SEPARATE window. `screencapture -l` on the parent composited
        // it in for free; SCContentFilter(desktopIndependentWindow:) does not, so both windows
        // are captured and combined here — including the parent dimming a real sheet causes.
        if let sheet {
            let sheetImage = await shot(sheet)
            guard let ctx = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                fail(5, "could not allocate the compositing context")
            }
            let full = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            ctx.draw(image, in: full)
            ctx.setFillColor(CGColor(gray: 0, alpha: 0.2))
            ctx.fill(full)
            // The sheet's own frame is NOT usable here. Because the app is launched hidden,
            // macOS never attaches the sheet to its parent — measured, the parent sat at
            // x=510 while the sheet reported x=0, i.e. it was never positioned at all. So the
            // placement is reconstructed: a macOS sheet is horizontally centred on its parent
            // and sits slightly above centre vertically.
            let sheetW = CGFloat(sheetImage.width), sheetH = CGFloat(sheetImage.height)
            let dx = (CGFloat(image.width) - sheetW) / 2
            let dy = (CGFloat(image.height) - sheetH) / 2 + CGFloat(24 * scale)
            ctx.setShadow(offset: .zero, blur: 24, color: CGColor(gray: 0, alpha: 0.35))
            ctx.draw(sheetImage, in: CGRect(x: dx, y: dy,
                                            width: CGFloat(sheetImage.width),
                                            height: CGFloat(sheetImage.height)))
            guard let composited = ctx.makeImage() else { fail(5, "compositing produced no image") }
            image = composited
        }

        // MARK: Assert before writing

        let wantPx = (Int(wantW) * scale, Int(wantH) * scale)
        guard (image.width, image.height) == wantPx else {
            fail(4, "wrong size: got \(image.width)x\(image.height), want \(wantPx.0)x\(wantPx.1)")
        }
        let rep = NSBitmapImageRep(cgImage: image)
        var colors = Set<UInt32>()
        for y in stride(from: 0, to: image.height, by: 37) {
            for x in stride(from: 0, to: image.width, by: 37) {
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                    colors.insert(UInt32(c.redComponent * 255) << 16
                                | UInt32(c.greenComponent * 255) << 8
                                | UInt32(c.blueComponent * 255))
                }
            }
        }
        guard colors.count > 50 else {
            fail(4, "image looks blank (\(colors.count) distinct colours) — the window rendered empty")
        }

        rep.size = NSSize(width: image.width / scale, height: image.height / scale)  // 144 dpi
        let tmp = outPath + ".tmp.png"
        guard let png = rep.representation(using: .png, properties: [:]) else {
            fail(5, "PNG encoding failed")
        }
        do {
            try png.write(to: URL(fileURLWithPath: tmp))
            if FileManager.default.fileExists(atPath: outPath) {
                _ = try FileManager.default.replaceItemAt(URL(fileURLWithPath: outPath),
                                                          withItemAt: URL(fileURLWithPath: tmp))
            } else {
                try FileManager.default.moveItem(atPath: tmp, toPath: outPath)
            }
        } catch {
            fail(5, "write failed: \(error)")
        }
        print("  ✓ \(URL(fileURLWithPath: outPath).lastPathComponent)  \(image.width)x\(image.height)")
        exit(0)
    }
}
