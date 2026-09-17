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
        case "iso":
            file = "iso.json"
        case "7skb":
            file = "7skb.json"
        default:
            file = detectHardwareLayoutFile()
        }
        return (layoutDir as NSString).appendingPathComponent(file)
    }

    private static func detectHardwareLayoutFile() -> String {
        let kbdType = LMGetKbdType()
        let layoutType = Int(KBGetLayoutType(Int16(kbdType)))
        switch layoutType {
        case Int(kKeyboardJIS): return "jis.json"
        case Int(kKeyboardISO): return "iso.json"
        default: return "ansi.json"
        }
    }
}
