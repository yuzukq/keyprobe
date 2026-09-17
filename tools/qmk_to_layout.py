#!/usr/bin/env python3
"""Builds a KeyProbe layout JSON from a pair of QMK source files:

  --keyboard-json  keyboards/<vendor>/<board>/.../keyboard.json
                    (or info.json on older boards) — absolute per-key
                    geometry, no KLE cumulative math needed:
                    layouts.<LAYOUT_NAME>.layout = [{matrix:[r,c],x,y,w,h}, ...]

  --keymap-c       keyboards/<vendor>/<board>/keymaps/<name>/keymap.c
                    — the keymaps[][MATRIX_ROWS][MATRIX_COLS] array. We only
                    read one layer (--layer, default the first): QMK layers
                    only affect internal firmware state, not what macOS
                    keycode a *simple* press produces, so layer 0 (the
                    always-active base layer) is what a key tester should
                    show. The LAYOUT() macro's positional argument order is
                    defined to match keyboard.json's layout array order —
                    that's the whole point of the macro — so we zip the two
                    lists position-for-position.

This is a dev-time tool, not shipped in the extension: run it once per
keyboard you want to add, review the output, commit the resulting JSON to
assets/layouts/. See README.md's "自作キーボードレイアウト" section.
"""

import argparse
import json
import re
import sys

# QMK keycode name (without the KC_ prefix already stripped by the caller
# where convenient, but we key on the full name here) -> (macOS virtual
# keycode, on-screen label). None means "occupies a slot but macOS never
# sees a keyDown/keyUp for this by itself" (layer keys, unbound, or a
# consumer/media code our CGEventTap doesn't capture).
#
# Only entries actually exercised so far are included; extend this as new
# keyboards need keys it doesn't cover yet, verifying against a real board
# where possible (see README's "既知の制約" for what's still best-effort).
QMK_TO_MACOS = {
    "KC_A": (0, "A"), "KC_S": (1, "S"), "KC_D": (2, "D"), "KC_F": (3, "F"),
    "KC_H": (4, "H"), "KC_G": (5, "G"), "KC_Z": (6, "Z"), "KC_X": (7, "X"),
    "KC_C": (8, "C"), "KC_V": (9, "V"), "KC_B": (11, "B"), "KC_Q": (12, "Q"),
    "KC_W": (13, "W"), "KC_E": (14, "E"), "KC_R": (15, "R"), "KC_Y": (16, "Y"),
    "KC_T": (17, "T"), "KC_O": (31, "O"), "KC_U": (32, "U"), "KC_I": (34, "I"),
    "KC_P": (35, "P"), "KC_L": (37, "L"), "KC_J": (38, "J"), "KC_K": (40, "K"),
    "KC_N": (45, "N"), "KC_M": (46, "M"),
    "KC_1": (18, "1"), "KC_2": (19, "2"), "KC_3": (20, "3"), "KC_4": (21, "4"),
    "KC_5": (23, "5"), "KC_6": (22, "6"), "KC_7": (26, "7"), "KC_8": (28, "8"),
    "KC_9": (25, "9"), "KC_0": (29, "0"),
    "KC_MINS": (27, "-"), "KC_EQL": (24, "="), "KC_LBRC": (33, "["),
    "KC_RBRC": (30, "]"), "KC_BSLS": (42, "\\"), "KC_SCLN": (41, ";"),
    "KC_QUOT": (39, "'"), "KC_COMM": (43, ","), "KC_DOT": (47, "."),
    "KC_SLSH": (44, "/"), "KC_GRV": (50, "`"),
    "KC_TAB": (48, "tab"), "KC_SPC": (49, "space"), "KC_ENT": (36, "return"),
    "KC_BSPC": (51, "delete"), "KC_ESC": (53, "escape"),
    "KC_LCTL": (59, "control"), "KC_RCTL": (62, "control"),
    "KC_LSFT": (56, "shift"), "KC_RSFT": (60, "shift"),
    "KC_LALT": (58, "option"), "KC_RALT": (61, "option"),
    "KC_LGUI": (55, "command"), "KC_RGUI": (54, "command"),
    "KC_CAPS": (57, "caps lock"),
    "KC_F1": (122, "F1"), "KC_F2": (120, "F2"), "KC_F3": (99, "F3"),
    "KC_F4": (118, "F4"), "KC_F5": (96, "F5"), "KC_F6": (97, "F6"),
    "KC_F7": (98, "F7"), "KC_F8": (100, "F8"), "KC_F9": (101, "F9"),
    "KC_F10": (109, "F10"), "KC_F11": (103, "F11"), "KC_F12": (111, "F12"),
    "KC_UP": (126, "↑"), "KC_DOWN": (125, "↓"), "KC_LEFT": (123, "←"),
    "KC_RGHT": (124, "→"), "KC_RIGHT": (124, "→"),
    "KC_HOME": (115, "home"), "KC_END": (119, "end"),
    "KC_PGUP": (116, "page up"), "KC_PGDN": (121, "page down"),
    "KC_DEL": (117, "forward delete"), "KC_INS": (114, "help"),
    # JIS-only (confirmed against real hardware log earlier in this project)
    "KC_RO": (94, "_"), "KC_JYEN": (93, "¥"),
    "KC_LNG1": (104, "かな"), "KC_KANA": (104, "かな"),
    "KC_LNG2": (102, "英数"), "KC_EISU": (102, "英数"),
    # No stable macOS virtual keycode / not a real keyDown (consumer control,
    # or JIS keys Apple's own keyboards don't have a case for):
    "KC_STOP": None, "KC_MHEN": None, "KC_HENK": None,
    "XXXXXXX": None, "_______": None, "KC_NO": None, "KC_TRNS": None,
}


def strip_c_comments(text):
    text = re.sub(r"//.*", "", text)
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return text


def extract_layer_block(keymap_c_source, layer_index):
    """Finds the Nth `LAYOUT(...)` call's argument list (balanced parens)."""
    calls = [m.start() for m in re.finditer(r"\bLAYOUT\w*\s*\(", keymap_c_source)]
    if layer_index >= len(calls):
        raise SystemExit(f"Only found {len(calls)} LAYOUT(...) calls, wanted index {layer_index}")
    start = keymap_c_source.index("(", calls[layer_index])
    depth = 0
    for i in range(start, len(keymap_c_source)):
        if keymap_c_source[i] == "(":
            depth += 1
        elif keymap_c_source[i] == ")":
            depth -= 1
            if depth == 0:
                return keymap_c_source[start + 1:i]
    raise SystemExit("Unbalanced parens in LAYOUT(...) call")


def split_top_level_commas(arg_text):
    tokens, depth, current = [], 0, []
    for ch in arg_text:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            tokens.append("".join(current).strip())
            current = []
        else:
            current.append(ch)
    last = "".join(current).strip()
    if last:
        tokens.append(last)
    return [t for t in tokens if t]


def resolve_keycode(token):
    """Returns (macos_keycode_or_None, label). Unwraps MT()/LT() to their
    tap keycode; anything else unrecognized is left labeled but untestable
    so it's visible in the output for manual review rather than silently
    dropped."""
    inner_call = re.match(r"^(MT|LT)\([^,]+,\s*(\w+)\)$", token)
    if inner_call:
        token = inner_call.group(2)

    if token in QMK_TO_MACOS:
        entry = QMK_TO_MACOS[token]
        if entry is None:
            return None, token
        keycode, label = entry
        return keycode, label

    # Layer-switch functions (MO/TG/TO/OSL/DF over a layer name) — no OS
    # keycode, but "Fn" reads better than the raw "MO(_FN)" token.
    layer_call = re.match(r"^(?:MO|TG|TO|OSL|DF)\(_?(\w+)\)$", token)
    if layer_call:
        return None, layer_call.group(1).replace("_", " ").title()

    return None, token


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--keyboard-json", required=True)
    parser.add_argument("--keymap-c", required=True)
    parser.add_argument("--layout-name", default="LAYOUT", help="key under layouts.* in keyboard.json")
    parser.add_argument("--layer", type=int, default=0, help="which LAYOUT(...) call to read (0 = first/base)")
    parser.add_argument("--name", required=True, help="name field for the output layout JSON")
    parser.add_argument("--unit", type=float, default=46.0)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    kb = json.load(open(args.keyboard_json))
    geometry = kb["layouts"][args.layout_name]["layout"]

    keymap_source = strip_c_comments(open(args.keymap_c).read())
    arg_text = extract_layer_block(keymap_source, args.layer)
    tokens = split_top_level_commas(arg_text)

    if len(tokens) != len(geometry):
        raise SystemExit(
            f"Mismatch: keyboard.json has {len(geometry)} positions, "
            f"layer {args.layer} of keymap.c has {len(tokens)} tokens. "
            "Wrong --layout-name/--layer, or this board's LAYOUT macro "
            "doesn't 1:1 match keyboard.json (check by hand)."
        )

    keys = []
    unresolved = []
    for geo, token in zip(geometry, tokens):
        keycode, label = resolve_keycode(token)
        if keycode is None and token not in ("XXXXXXX", "_______", "KC_NO", "KC_TRNS"):
            unresolved.append(token)
        keys.append({
            "keycode": keycode,
            "x": geo["x"],
            "y": geo["y"],
            "w": geo.get("w", 1.0),
            "h": geo.get("h", 1.0),
            "label": label,
        })

    # Unlike the ANSI/JIS/ISO boards, a custom keyboard can legitimately bind
    # more than one physical key to the same keycode (e.g. a split board's
    # symmetric thumb clusters both sending KC_SPC) — the OS genuinely can't
    # tell them apart, so KeyboardView highlights every slot sharing a
    # keycode together rather than assuming one-slot-per-keycode.
    seen = {}
    for k in keys:
        if k["keycode"] is None:
            continue
        if k["keycode"] in seen:
            print(f"NOTE: keycode {k['keycode']} bound to multiple keys ({seen[k['keycode']]!r} and {k['label']!r}) — will highlight together", file=sys.stderr)
        seen[k["keycode"]] = k["label"]

    max_x = max(k["x"] + k["w"] for k in keys)
    max_y = max(k["y"] + k["h"] for k in keys)

    layout = {
        "name": args.name,
        "unit": args.unit,
        "width": round(max_x, 2),
        "height": round(max_y, 2),
        "keys": keys,
    }
    with open(args.out, "w") as f:
        json.dump(layout, f, ensure_ascii=False, indent=2)

    print(f"Wrote {args.out}: {len(keys)} keys, bounds {max_x}x{max_y}")
    if unresolved:
        print(f"WARNING: {len(unresolved)} token(s) had no known macOS keycode and are non-testable placeholders: {sorted(set(unresolved))}", file=sys.stderr)


if __name__ == "__main__":
    main()
