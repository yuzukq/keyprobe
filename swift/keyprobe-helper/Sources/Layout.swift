import Foundation

/// A single key's position on the rendered board, in "u" units (1u = one
/// standard keycap). `keycode` is a macOS virtual keycode (`CGKeyCode`),
/// not a matrix row/column — this is what makes future VIA/QMK import
/// additive rather than a rework (implementation review #2): a future
/// converter just needs to produce this same shape from a keyboard
/// definition + keymap pair.
/// `keycode` is nil for slots that never produce an OS keyDown/keyUp on
/// their own — layer keys (QMK `MO()`/`TG()`), unbound positions
/// (`XXXXXXX`), and similar. Those still occupy board space (so custom
/// keyboard imports look right) but must render as permanently
/// non-testable rather than "untested", or a layer key reads as a dead
/// key on exactly the boards this tool exists to check.
struct KeyDefinition: Codable {
    let keycode: Int?
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    let label: String
}

struct Layout: Codable {
    let name: String
    let unit: Double
    let width: Double
    let height: Double
    let keys: [KeyDefinition]

    static func load(from path: String) -> Layout? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(Layout.self, from: data)
    }
}
