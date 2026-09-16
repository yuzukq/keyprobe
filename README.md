# KeyProbe

Raycast から即座に呼び出せるキーボード導通確認ツール。押されたキーをネイティブの半透明パネルで可視化する。詳細な仕様と設計判断の経緯は会話ログ参照。

## 現在の状態: 垂直スライス（v0）

レイアウト描画やテスト済みトラッキングはまだ実装していない。今のビルドで確認できるのは以下のパイプラインだけ：

`Raycast の "Open KeyProbe" コマンド` → `Swift ヘルパー起動` → `CGEventTap 確立` → `半透明の空ウィンドウ表示` → `keyDown/keyUp/flagsChanged をログファイルに記録`

レイアウトJSON化・3状態描画・翻訳色などの本実装に入る前に、実機のキーボード（特にJISコンボやカスタムキーボード）に対してイベントが期待通り取れているかをまず確認するため。

## セットアップ

```bash
npm install
npm run build-helper   # Swift ヘルパーを assets/KeyProbeHelper にビルド
npm run dev            # ray develop — Raycast にロードされる
```

`npm run dev` を初めて実行すると Raycast 上に "Open KeyProbe" コマンドが現れる。実行すると：

1. 初回は **Input Monitoring** 権限が無いため失敗し、HUD にエラーが出る
2. システム設定 → プライバシーとセキュリティ → **入力監視** を開き、`KeyProbeHelper` を許可する
3. 再度コマンドを実行すると、半透明のウィンドウが表示されるはず

権限は「バイナリのパス＋署名」単位で記憶される。`ray develop` は毎回 `.raycast-swift-build/` 以下の同じパスにビルドするので基本的には一度許可すれば十分だが、Swift 側を作り直した直後は再承認を求められることがある（開発中の既知動作）。

## 動作確認したいこと

ウィンドウを開いた状態でキーボードを一通り押し、ログを確認する。ログの場所は Raycast の拡張機能ごとの support ディレクトリ（`environment.supportPath`）以下で、`ray develop` 中は次のコマンドで特定できる：

```bash
find ~/Library/Application\ Support/com.raycast.macos -maxdepth 3 -iname "keyprobe-helper.log"
```

パスが分かったら：

```bash
tail -f "<上で見つかったパス>"
```

（過去のログには `os.tmpdir()`（macOSでは `/var/folders/.../T/` になり `/tmp` ではない）を使っていたため見つからなかった。`environment.supportPath` に切り替え済み。）

特に確認したい項目：

- 修飾キー単体（Shift/Ctrl/Option/Command）が **左右別に** `flagsChanged` として記録されるか
- Fn キー、CapsLock が記録されるか
- 自作キーボードのコンボで送信している JIS の英数/かな/¥/_ キーが `JIS_Eisu` / `JIS_Kana` / `JIS_Yen` / `JIS_Underscore` として認識されるか
- 素早く連打してもイベントが欠落しないか（tapDisabledByTimeout の再有効化が効いているか）
- ウィンドウにフォーカスがある状態でキーを押してもビープ音が鳴らないか
- ⌘W でウィンドウが閉じ、ヘルパープロセスも一緒に終了するか（`pgrep -f KeyProbeHelper` で確認）
- コマンドをもう一度実行したときに、新しいウィンドウではなく既存ウィンドウが前面に出るか

## 既知の挙動（初回検証で判明）

- **`keycode=... name=?` は現時点で想定通り**: v0 では修飾キーとJISキーしか名前を付けていない（`EventTap.swift` の `keyName`）。文字キー等を人間可読名にするのはレイアウトJSONの作業で対応する
- **矢印キーやHome/End/PageUp/Downを押すと `flags` に `fn` が混ざる**: 物理Fnキーを押していなくても、macOSはこのクラスタのキーに `NX_SECONDARYFNMASK` を常時付与する仕様。バグではない
- **Input Monitoring の許可ダイアログが出ず、システム設定にも `KeyProbeHelper` が出てこないのにイベントは取れている**: 未署名の単体バイナリとして子プロセス起動しているため、TCCがこのヘルパーの許可要求をRaycast.app自体の権限に付け替えている可能性が高い。システム設定 → プライバシーとセキュリティ → 入力監視 で **Raycast** が有効になっているか確認するとよい。もしRaycast側の許可を切ると、このヘルパーも一緒に動かなくなるはず

## 次のステップ（未実装）

- キーボードレイアウトの JSON スキーマ（KLE 準拠ジオメトリ、キーは macOS 仮想キーコードで indexing）
- JIS レイアウトの描画 + 3状態（未テスト/押下中/テスト済み）の可視化
- リセットボタン（自動リセット + 手動リセット）
- レイアウト外キー（メディアキー等）向けのテキストログ表示
- 将来: VIA/QMK の matrix.json + キーマップからレイアウトJSONを生成する変換ツール
