import AppKit

/// Three states settled in the design review (Q3): a key starts untested,
/// turns "pressed" for as long as it's held, and once released becomes
/// "tested" until the board is reset.
enum KeyState {
    case untested
    case pressed
    case tested
}

final class KeyView: NSView {
    let keycode: Int
    private let label: NSTextField
    private(set) var state: KeyState = .untested

    init(definition: KeyDefinition, frame: NSRect) {
        self.keycode = definition.keycode
        self.label = NSTextField(labelWithString: definition.label)
        super.init(frame: frame)

        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        label.font = NSFont.systemFont(ofSize: min(12, frame.height * 0.32), weight: .medium)
        label.alignment = .center
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -4),
        ])

        apply(.untested)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(_ newState: KeyState) {
        // pressed -> tested is the only forward transition once released;
        // tested keys ignore further "untested" (that only happens on reset).
        guard newState != state else { return }
        if state == .tested && newState == .untested { return }
        state = newState
        apply(newState)
    }

    func resetToUntested() {
        state = .untested
        apply(.untested)
    }

    private func apply(_ state: KeyState) {
        switch state {
        case .untested:
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
            layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        case .pressed:
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.9).cgColor
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        case .tested:
            // Low-alpha systemMint reads as a tint on the HUD material rather
            // than a flat colored patch, and sits next to controlAccentColor
            // (usually blue) without the hue clash a saturated systemGreen has.
            layer?.backgroundColor = NSColor.systemMint.withAlphaComponent(0.16).cgColor
            layer?.borderColor = NSColor.systemMint.withAlphaComponent(0.45).cgColor
        }
    }
}
