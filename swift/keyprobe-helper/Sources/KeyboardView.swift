import AppKit

/// Renders a Layout as a grid of KeyViews and routes keycode events to them.
/// Also settled in the design review: keys with no slot on the board
/// (media keys, unrecognized HID codes — Q7) surface as text instead of
/// being silently dropped, since telling "no event" apart from "dead key"
/// is exactly what this tool exists to do (implementation review #10).
final class KeyboardView: NSView {
    // Named boardLayout, not layout: NSView already declares `func layout()`
    // for its own layout pass, and a stored property named `layout` shadows it.
    private let boardLayout: Layout
    private var viewsByKeycode: [Int: KeyView] = [:]
    private let unmappedLabel: NSTextField

    init(layout: Layout, unmappedLabel: NSTextField) {
        self.boardLayout = layout
        self.unmappedLabel = unmappedLabel
        let size = NSSize(width: layout.width * layout.unit, height: layout.height * layout.unit)
        super.init(frame: NSRect(origin: .zero, size: size))

        let gap: CGFloat = 3
        for def in layout.keys {
            let rect = NSRect(
                x: def.x * layout.unit + gap / 2,
                y: size.height - (def.y + def.h) * layout.unit + gap / 2,
                width: def.w * layout.unit - gap,
                height: def.h * layout.unit - gap
            )
            let keyView = KeyView(definition: def, frame: rect)
            addSubview(keyView)
            viewsByKeycode[def.keycode] = keyView
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func handleDown(keycode: Int64) {
        guard let view = viewsByKeycode[Int(keycode)] else {
            unmappedLabel.stringValue = "Unmapped key: keycode \(keycode) (not on this layout)"
            return
        }
        view.set(.pressed)
    }

    func handleUp(keycode: Int64) {
        guard let view = viewsByKeycode[Int(keycode)] else { return }
        view.set(.tested)
    }

    /// Manual reset (Q10) — window-open auto-reset is just "start a fresh helper",
    /// since state lives only in this in-memory view tree.
    func resetAll() {
        for view in viewsByKeycode.values {
            view.resetToUntested()
        }
        unmappedLabel.stringValue = ""
    }
}
