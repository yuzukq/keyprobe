# Layout conversion tools

These scripts generate the bundled layouts in `assets/layouts/`. They're dev-time tools: they live in this repository but are kept out of the Raycast Store submission via `.gitignore`, since people who install from the Store can't add layouts to the extension.

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

---

## 自作キーボードのレイアウトを追加する

同梱されているボードは、`tools/` 以下のスクリプトでQMK/ZMKファームウェアのソースから変換しています:

```bash
# QMKボード（keyboard.json/info.json + keymap.c または keymap.json）
python3 tools/qmk_to_layout.py \
  --keyboard-json <qmk_firmware>/keyboards/<board>/keyboard.json \
  --keymap <qmk_firmware>/keyboards/<board>/keymaps/default/keymap.json \
  --name "My Board" --out assets/layouts/myboard.json

# ZMKボード（物理レイアウトJSON + .keymap DTSファイル）
python3 tools/zmk_to_layout.py \
  --geometry <zmk-config>/config/myboard.json --layout-name default_layout \
  --keymap <zmk-config>/config/myboard.keymap \
  --name "My Board" --out assets/layouts/myboard.json
```

生成されたJSONを `assets/layouts/` に置くことで、コード変更なしに検索UIから選べるようになります。各スクリプトは `--help` で全オプションを確認できます。
