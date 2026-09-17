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

/// Owns the window, the keyboard board, and the toolbar (reset button +
/// unmapped-key readout). Closing the window quits the whole helper
/// (settled: Q8 — no background persistence once the window goes away).
final class KeyProbeWindowController: NSObject, NSWindowDelegate {
    static let shared = KeyProbeWindowController()

    private var window: KeyProbeWindow?
    private var keyboardView: KeyboardView?

    func show(layout: Layout) {
        let toolbarHeight: CGFloat = 40
        let padding: CGFloat = 16
        let boardWidth = layout.width * layout.unit
        let boardHeight = layout.height * layout.unit
        let contentSize = NSSize(width: boardWidth + padding * 2, height: boardHeight + toolbarHeight + padding * 2)
        let contentRect = NSRect(origin: .zero, size: contentSize)

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

        let unmappedLabel = NSTextField(labelWithString: "")
        unmappedLabel.font = .systemFont(ofSize: 11)
        unmappedLabel.textColor = .secondaryLabelColor
        unmappedLabel.lineBreakMode = .byTruncatingTail
        unmappedLabel.frame = NSRect(
            x: padding, y: contentSize.height - toolbarHeight - padding / 2,
            width: boardWidth - 200, height: 20
        )
        unmappedLabel.autoresizingMask = [.width]
        contentView.addSubview(unmappedLabel)

        let keyboardView = KeyboardView(layout: layout, unmappedLabel: unmappedLabel)
        keyboardView.frame.origin = NSPoint(x: padding, y: padding)
        contentView.addSubview(keyboardView)
        self.keyboardView = keyboardView

        let resetButton = NSButton(title: "Reset", target: self, action: #selector(resetTapped))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(
            x: contentSize.width - 80 - padding, y: contentSize.height - toolbarHeight - padding / 2,
            width: 80, height: 24
        )
        resetButton.autoresizingMask = [.minXMargin]
        contentView.addSubview(resetButton)

        // Opens the "Select Keyboard Layout" Raycast command via deeplink
        // instead of duplicating its search UI natively. search-layout.tsx
        // restarts this window itself once a new layout is picked there.
        let layoutButton = NSButton(title: "Layout…", target: self, action: #selector(layoutTapped))
        layoutButton.bezelStyle = .rounded
        layoutButton.frame = NSRect(
            x: contentSize.width - 80 - 8 - 100 - padding, y: contentSize.height - toolbarHeight - padding / 2,
            width: 100, height: 24
        )
        layoutButton.autoresizingMask = [.minXMargin]
        contentView.addSubview(layoutButton)

        window.contentView = contentView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    @objc private func resetTapped() {
        keyboardView?.resetAll()
    }

    @objc private func layoutTapped() {
        guard let url = URL(string: "raycast://extensions/yuzu/keyprobe/search-layout") else { return }
        NSWorkspace.shared.open(url)
    }

    func handleDown(keycode: Int64) {
        keyboardView?.handleDown(keycode: keycode)
    }

    func handleUp(keycode: Int64) {
        keyboardView?.handleUp(keycode: keycode)
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
