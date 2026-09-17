#!/usr/bin/env python3
"""One-off batch runner over qmk_to_layout.py for the "famous boards"
shortlist picked from a commit-count ranking (see project README/chat log).
Not shipped, not meant to be re-run generically — just records how this
batch was produced and reports per-board results."""

import importlib.util
import os
import re
import subprocess
import sys

CONVERTER = os.path.join(os.path.dirname(__file__), "qmk_to_layout.py")
_spec = importlib.util.spec_from_file_location("qmk_to_layout", CONVERTER)
_qmk_to_layout = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_qmk_to_layout)
load_jsonc = _qmk_to_layout.load_jsonc

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "layouts")
QMK_ROOT = "/Users/yuzu/qmk_firmware/keyboards"

# Each entry: display name, keyboard.json dir (relative to QMK_ROOT unless
# it starts with "/", for the couple of boards whose geometry actually
# lives in a shared community-layout dir instead of their own
# keyboard.json), keymap dir (relative to QMK_ROOT), output stem, and an
# optional --layout-name override for boards whose default keymap calls a
# macro name (often a per-board alias, e.g. LAYOUT_planck_grid ->
# LAYOUT_ortho_4x12) that doesn't literally match what keyboard.json
# declares. Resolved by hand from the discovery pass (upward keymap
# search + "prefer rev1" heuristic + manual alias verification).
BOARDS = [
    ("Planck", "planck/rev6", "planck/keymaps/default", "planck", "LAYOUT_ortho_4x12"),
    ("Preonic", "preonic/rev3", "preonic/keymaps/default", "preonic", "LAYOUT_ortho_5x12"),
    # crkbd/rev1's own keyboard.json declares no layouts at all — QMK
    # resolves LAYOUT_split_3x6_3 via the shared community layout dir by
    # naming convention. Same geometry, different source file.
    ("Corne (crkbd)", "/Users/yuzu/qmk_firmware/layouts/default/split_3x6_3", "crkbd/keymaps/default", "crkbd", "LAYOUT_split_3x6_3"),
    ("Iris", "keebio/iris/rev8", "keebio/iris/keymaps/default", "iris", None),
    ("Let's Split", "lets_split/rev2", "lets_split/keymaps/default", "lets_split", None),
    ("Helix", "helix/rev3", "helix/rev3/keymaps/default", "helix", None),
    ("KBD67 (rev1)", "kbdfans/kbd67/rev1", "kbdfans/kbd67/rev1/keymaps/default", "kbd67", None),
    ("DZ60", "dz60", "dz60/keymaps/default", "dz60", None),
    ("Lily58", "lily58/rev1", "lily58/keymaps/default", "lily58v1", None),
    ("Kyria", "splitkb/kyria/rev3", "splitkb/kyria/keymaps/default", "kyria", "LAYOUT_split_3x6_5"),
    ("GMMK Pro (ANSI)", "gmmk/pro/rev1/ansi", "gmmk/pro/rev1/ansi/keymaps/default", "gmmk_pro", None),
    ("Atreus (promicro)", "atreus/promicro", "atreus/keymaps/default", "atreus", None),
    ("Orthodox", "orthodox/rev1", "orthodox/keymaps/default", "orthodox", None),
    ("Quefrency (rev1)", "keebio/quefrency/rev1", "keebio/quefrency/keymaps/default", "quefrency", None),
    ("Nyquist (rev1)", "keebio/nyquist/rev1", "keebio/nyquist/keymaps/default", "nyquist", None),
    ("DZ65RGB", "dztech/dz65rgb/v1", "dztech/dz65rgb/keymaps/default", "dz65rgb", None),
    ("GH60 Satan", "gh60/satan", "gh60/satan/keymaps/default", "gh60_satan", None),
    ("Tada68", "tada68", "tada68/keymaps/default", "tada68", None),
    ("Clueboard 66 (rev3)", "clueboard/66/rev3", "clueboard/66/keymaps/default", "clueboard66", "LAYOUT_all"),
    ("Sofle", "sofle/rev1", "sofle/keymaps/default", "sofle", None),
    ("Levinson (rev1)", "keebio/levinson/rev1", "keebio/levinson/keymaps/default", "levinson", None),
    ("KBD6x", "kbdfans/kbd6x", "kbdfans/kbd6x/keymaps/default", "kbd6x", None),
    ("HS60 v2 ANSI", "hs60/v2/ansi", "hs60/v2/ansi/keymaps/default", "hs60_v2", None),
    # Second batch: user-requested specific boards (身内でよく見る/SNSで流行り),
    # after checking which of the named boards actually run QMK (see chat —
    # moNa2/cornix/roBa/Kinesis Advantage360 turned out to be ZMK, a
    # different firmware/config format this tool doesn't parse; Lofree/
    # Realforce aren't practically obtainable — official QMK source withheld
    # or proprietary).
    ("7sPlus (Salicylic)", "salicylic_acid3/7splus", "salicylic_acid3/7splus/keymaps/default", "7splus", None),
    ("Ajisai74 (Salicylic)", "salicylic_acid3/ajisai74", "salicylic_acid3/ajisai74/keymaps/default", "ajisai74", None),
    ("ErgoArrows (Salicylic)", "salicylic_acid3/ergoarrows", "salicylic_acid3/ergoarrows/keymaps/default", "ergoarrows", None),
    ("Getta25 (Salicylic)", "salicylic_acid3/getta25/rev1", "salicylic_acid3/getta25/keymaps/default", "getta25", None),
    ("Guide68 (Salicylic)", "salicylic_acid3/guide68", "salicylic_acid3/guide68/keymaps/default", "guide68", None),
    ("Jisplit89 (Salicylic)", "salicylic_acid3/jisplit89/rev1", "salicylic_acid3/jisplit89/keymaps/default", "jisplit89", None),
    ("Nafuda (Salicylic)", "salicylic_acid3/nafuda", "salicylic_acid3/nafuda/keymaps/default", "nafuda", None),
    ("Naked48 (Salicylic)", "salicylic_acid3/naked48/rev1", "salicylic_acid3/naked48/keymaps/default", "naked48", None),
    ("Naked60 (Salicylic)", "salicylic_acid3/naked60/rev1", "salicylic_acid3/naked60/keymaps/default", "naked60", None),
    ("Naked64 (Salicylic)", "salicylic_acid3/naked64/rev1", "salicylic_acid3/naked64/keymaps/default", "naked64", None),
    ("NKNL7EN (Salicylic)", "salicylic_acid3/nknl7en", "salicylic_acid3/nknl7en/keymaps/default", "nknl7en", None),
    ("NKNL7JP (Salicylic)", "salicylic_acid3/nknl7jp", "salicylic_acid3/nknl7jp/keymaps/default", "nknl7jp", None),
    ("Setta21 (Salicylic)", "salicylic_acid3/setta21/rev1", "salicylic_acid3/setta21/keymaps/default", "setta21", None),
    ("Keychron Q11 (ANSI)", "keychron/q11", "keychron/q11/ansi_encoder/keymaps/default", "keychron_q11", "LAYOUT_91_ansi"),
    ("HHKB ANSI", "hhkb/ansi", "hhkb/ansi/keymaps/default", "hhkb_ansi", "LAYOUT"),
    ("HHKB JP", "hhkb/jp", "hhkb/jp/keymaps/default", "hhkb_jp", None),
    ("Silakka 54", "silakka54", "silakka54/keymaps/default", "silakka54", None),
]
# Dropped from this batch after investigation (not worth chasing further
# right now — can revisit by hand later): Ergodox EZ (LAYOUT_ergodox_pretty
# doesn't match the "ergodox" community layout — different board, 76 vs 78
# keys), DZ60RGB / BDN9 (plain "LAYOUT" macro not declared in keyboard.json
# and no matching community layout by name — likely defined in a legacy
# per-board header we're not parsing), Adelais (default keymap's LAYOUT_all
# isn't declared by the specific variant directory picked; needs a
# different sub-variant).


def find_keymap_file(keymap_dir_abs):
    for name in ("keymap.json", "keymap.c"):
        p = os.path.join(keymap_dir_abs, name)
        if os.path.isfile(p):
            return p
    return None


def guess_layout_name(keymap_c_path, available_layouts):
    """For .c keymaps: find which LAYOUT_xxx macro name is actually invoked,
    and confirm it's one keyboard.json declares."""
    src = open(keymap_c_path, encoding="utf-8", errors="replace").read()
    src = re.sub(r"//.*", "", src)
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.DOTALL)
    names = re.findall(r"\b(LAYOUT\w*)\s*\(", src)
    for n in names:
        if n in available_layouts:
            return n
    return None


def find_keyboard_json(kb_dir):
    for name in ("keyboard.json", "info.json"):
        p = os.path.join(kb_dir, name)
        if os.path.isfile(p):
            return p
    return None


def main():
    results = []
    for display_name, kb_rel, km_rel, stem, layout_override in BOARDS:
        kb_dir = kb_rel if kb_rel.startswith("/") else os.path.join(QMK_ROOT, kb_rel)
        km_dir = os.path.join(QMK_ROOT, km_rel)
        kb_json_path = find_keyboard_json(kb_dir)
        out_path = os.path.abspath(os.path.join(OUT_DIR, f"{stem}.json"))

        if kb_json_path is None:
            results.append((display_name, "SKIP", f"no keyboard.json/info.json at {kb_rel}"))
            continue

        keymap_path = find_keymap_file(km_dir)
        if keymap_path is None:
            results.append((display_name, "SKIP", f"no keymap.json/keymap.c under {km_rel}"))
            continue

        kb_data = load_jsonc(kb_json_path)
        available_layouts = list(kb_data.get("layouts", {}).keys())

        layout_name = layout_override
        if layout_name is None and keymap_path.endswith(".c"):
            layout_name = guess_layout_name(keymap_path, available_layouts)
            if layout_name is None:
                results.append((
                    display_name, "SKIP",
                    f"couldn't match a LAYOUT_xxx macro in {keymap_path} against {available_layouts}",
                ))
                continue

        cmd = [
            sys.executable, CONVERTER,
            "--keyboard-json", kb_json_path,
            "--keymap", keymap_path,
            "--layer", "0",
            "--name", display_name,
            "--out", out_path,
        ]
        if layout_name:
            cmd += ["--layout-name", layout_name]

        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            results.append((display_name, "FAIL", proc.stderr.strip().splitlines()[-1] if proc.stderr else "unknown error"))
            continue

        warn_lines = [l for l in proc.stderr.splitlines() if l.startswith("WARNING")]
        note_lines = [l for l in proc.stderr.splitlines() if l.startswith("NOTE")]
        status = "OK" if not warn_lines else "OK (needs review)"
        detail = "; ".join(warn_lines) if warn_lines else (f"{len(note_lines)} shared-keycode note(s)" if note_lines else "")
        results.append((display_name, status, detail))

    print(f"\n{'BOARD':32s} {'STATUS':20s} DETAIL")
    print("-" * 100)
    for name, status, detail in results:
        print(f"{name:32s} {status:20s} {detail}")

    ok = sum(1 for _, s, _ in results if s.startswith("OK"))
    print(f"\n{ok}/{len(results)} converted.")


if __name__ == "__main__":
    main()
