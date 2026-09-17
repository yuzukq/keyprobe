# KeyProbe

Test every key on your keyboard from Raycast. KeyProbe opens a native, translucent panel that highlights each key as you press it, so you can confirm a remapped or custom keyboard actually works at the OS level — no more hunting for a browser-based key tester.

## Features

- Highlights a key while held, then marks it "tested" once released, so you can see at a glance which keys you haven't tried yet
- Built-in ANSI / JIS / ISO layouts, auto-detected from your attached keyboard's hardware type
- 50+ bundled custom keyboard layouts (Corne, Lily58, Planck, HHKB, Keychron Q11, moNa2, Kinesis Advantage 360, and more), searchable via **Select Keyboard Layout**
- Keys with no fixed OS keycode (layer keys, media keys) are drawn as non-testable instead of looking like dead keys
- Reset button clears all state without closing the panel

## Setup

1. Run **Open KeyProbe** from Raycast
2. The first run needs **Input Monitoring** permission — grant it in System Settings → Privacy & Security → Input Monitoring (enable KeyProbeHelper), then run the command again
3. The panel should appear; press any key to see it highlight

## Choosing a layout

- The **Keyboard Layout** preference sets the default: Auto-detect, ANSI, JIS, or ISO
- **Select Keyboard Layout** searches all bundled layouts — including the custom keyboards — and switches live, even while the panel is open
- Auto-detect reads the physically attached keyboard's hardware type, not your macOS input source language. An ANSI-shaped board stays "ANSI" even if its firmware sends JIS key combos; pick JIS explicitly to test those.

## Known limitations

- Hardware media/volume/brightness keys arrive as a different event type this tool doesn't capture, so they won't register at all — not even as an unmapped key
- A few JIS/ISO punctuation positions are best-effort, not verified on real hardware (see comments in `assets/layouts/jis.json` / `iso.json`)
- Some ZMK-based split boards ship with heavily customized keymaps that can't be safely auto-parsed. On those (e.g. cornix), the thumb cluster and a few symbol keys are drawn as non-testable placeholders — correct shape, but not read from the actual firmware

## Adding a custom keyboard layout

Bundled boards are converted from QMK/ZMK firmware sources using the scripts in `tools/`:

```bash
# QMK boards (keyboard.json/info.json + keymap.c or keymap.json)
python3 tools/qmk_to_layout.py \
  --keyboard-json <qmk_firmware>/keyboards/<board>/keyboard.json \
  --keymap <qmk_firmware>/keyboards/<board>/keymaps/default/keymap.json \
  --name "My Board" --out assets/layouts/myboard.json

# ZMK boards (a physical layout JSON + a .keymap DTS file)
python3 tools/zmk_to_layout.py \
  --geometry <zmk-config>/config/myboard.json --layout-name default_layout \
  --keymap <zmk-config>/config/myboard.keymap \
  --name "My Board" --out assets/layouts/myboard.json
```

Drop the resulting JSON into `assets/layouts/` — it's picked up automatically by the search UI, no code changes needed. Run each script with `--help` for the full set of options.
