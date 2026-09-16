import CoreGraphics
import AppKit
import Carbon.HIToolbox

/// Captures global keyboard events via CGEventTap (listen-only — settled: Q5).
///
/// Vertical slice: reports a human-readable description of every keyDown,
/// keyUp and flagsChanged event through `onEvent`. main.swift currently just
/// logs these to a file so they can be checked against a real keyboard
/// before any layout/rendering work starts (blocks #1 and #5 from the
/// implementation review need to be confirmed empirically here).
class EventTap {
    static let shared = EventTap()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var onEvent: ((String) -> Void)?

    private init() {}

    func start(onEvent: @escaping (String) -> Void) -> Bool {
        self.onEvent = onEvent

        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
            return false
        }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let instance = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()

                // System disables the tap under load; re-enable immediately (KeyRaycast pattern).
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = instance.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                instance.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        CGEvent.tapEnable(tap: tap, enable: true)

        // flagsChanged-only taps can succeed without full permission; confirm
        // keyDown specifically is actually granted (KeyRaycast pattern).
        let keyOnlyMask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        if let testTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: keyOnlyMask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) {
            CGEvent.tapEnable(tap: testTap, enable: false)
        } else {
            stop()
            return false
        }

        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        eventTap = nil
        runLoopSource = nil
        onEvent = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        switch type {
        case .keyDown:
            onEvent?("keyDown   keycode=\(keyCode) name=\(Self.keyName(keyCode)) flags=\(Self.describeFlags(flags))")
        case .keyUp:
            onEvent?("keyUp     keycode=\(keyCode) name=\(Self.keyName(keyCode)) flags=\(Self.describeFlags(flags))")
        case .flagsChanged:
            // Modifier keys (Shift/Ctrl/Option/Command/Fn/CapsLock, including
            // left/right pairs) never fire keyDown/keyUp — only this event
            // (implementation review #1). keyCode alone identifies exactly
            // which physical key changed; `flags` gives the resulting mask
            // so direction can be diffed once the UI layer tracks state.
            onEvent?("flagsChanged keycode=\(keyCode) name=\(Self.keyName(keyCode)) flags=\(Self.describeFlags(flags))")
        default:
            break
        }
    }

    private static func describeFlags(_ flags: CGEventFlags) -> String {
        var parts: [String] = []
        if flags.contains(.maskShift) { parts.append("shift") }
        if flags.contains(.maskControl) { parts.append("control") }
        if flags.contains(.maskAlternate) { parts.append("option") }
        if flags.contains(.maskCommand) { parts.append("command") }
        if flags.contains(.maskSecondaryFn) { parts.append("fn") }
        if flags.contains(.maskAlphaShift) { parts.append("capslock") }
        return parts.isEmpty ? "-" : parts.joined(separator: "+")
    }

    /// Named only for the keycodes relevant to the review's open items
    /// (L/R modifier pairs + JIS-specific keys); everything else logs by
    /// number for now. Filled in properly once layout JSON work starts.
    private static func keyName(_ keyCode: Int64) -> String {
        switch Int(keyCode) {
        case kVK_Shift: return "LeftShift"
        case kVK_RightShift: return "RightShift"
        case kVK_Control: return "LeftControl"
        case kVK_RightControl: return "RightControl"
        case kVK_Option: return "LeftOption"
        case kVK_RightOption: return "RightOption"
        case kVK_Command: return "LeftCommand"
        case kVK_RightCommand: return "RightCommand"
        case kVK_Function: return "Fn"
        case kVK_CapsLock: return "CapsLock"
        case kVK_JIS_Yen: return "JIS_Yen"
        case kVK_JIS_Underscore: return "JIS_Underscore"
        case kVK_JIS_KeypadComma: return "JIS_KeypadComma"
        case kVK_JIS_Eisu: return "JIS_Eisu"
        case kVK_JIS_Kana: return "JIS_Kana"
        default: return "?"
        }
    }
}
