import AppKit

/// Swallows all key input so an unhandled keyDown never triggers NSBeep
/// (implementation review #4). The event tap sees every keystroke
/// independently of the responder chain, so nothing needs to reach here
/// for the visualization to work — this view's only job is to stay silent.
private final class SwallowingContentView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {}
    override func keyUp(with event: NSEvent) {}
    override func flagsChanged(with event: NSEvent) {}
}

/// Handles ⌘W (close) / ⌘Q (quit) directly. Needed because `.accessory`
/// activation policy ships no menu bar, so there's no default menu item to
/// wire these to (implementation review #3).
private final class KeyProbeWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "w":
                close()
                return true
            case "q":
                NSApp.terminate(nil)
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Bare vertical-slice window: translucent panel, no key layout yet.
/// Closing it quits the whole helper (settled: Q8 — no background
/// persistence once the window goes away).
final class KeyProbeWindowController: NSObject, NSWindowDelegate {
    static let shared = KeyProbeWindowController()

    private var window: KeyProbeWindow?

    func show() {
        let contentRect = NSRect(x: 0, y: 0, width: 900, height: 320)
        let window = KeyProbeWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.delegate = self

        let visualEffect = NSVisualEffectView(frame: contentRect)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]

        let contentView = SwallowingContentView(frame: contentRect)
        contentView.addSubview(visualEffect)
        window.contentView = contentView

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func bringToFront() {
        guard let window = window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}
