import Carbon.HIToolbox
import Foundation

/// Picks which bundled layout JSON to render.
///
/// "auto" reads the *physically attached keyboard's* hardware type via
/// `LMGetKbdType()`/`KBGetLayoutType()` — not the current input source
/// (System Settings language), which is a separate, unrelated setting.
/// This intentionally does NOT help a case like an ANSI-shaped custom
/// keyboard that sends JIS-mapped keycodes over firmware combos: the
/// hardware reports as ANSI, so auto mode shows the ANSI board and the
/// JIS-only presses (英数/かな/¥/_) land in the "unmapped key" readout
/// instead of lighting up a slot. That's why the Raycast preference can
/// force "jis" regardless of what the hardware reports.
enum LayoutSelector {
    static func resolve(mode: String, layoutDir: String) -> String {
        let file: String
        switch mode {
        case "ansi":
            file = "ansi.json"
        case "jis":
            file = "jis.json"
        default:
            file = detectHardwareLayoutIsJIS() ? "jis.json" : "ansi.json"
        }
        return (layoutDir as NSString).appendingPathComponent(file)
    }

    private static func detectHardwareLayoutIsJIS() -> Bool {
        let kbdType = LMGetKbdType()
        let layoutType = KBGetLayoutType(Int16(kbdType))
        return Int(layoutType) == Int(kKeyboardJIS)
    }
}
