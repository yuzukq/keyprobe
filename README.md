# KeyProbe

Raycast から即座に呼び出せるキーボード導通確認ツール。押されたキーをネイティブの半透明パネルで可視化する。詳細な仕様と設計判断の経緯は会話ログ参照。

## 現在の状態: v1（ANSI/JIS/ISOレイアウト自動判定 + 3状態可視化）

垂直スライスで実機検証（修飾キー左右判定・ロールオーバー・JISコンボ・⌘W終了）が取れたので、本実装に進んだ状態。

`Raycast の "Open KeyProbe" コマンド` → `Swift ヘルパー起動（--layout-dir/--layout-mode でJSONを選ばせる）` → `CGEventTap 確立` → `ANSI/JIS/ISOいずれかのレイアウトを半透明パネルに描画` → `押下中はハイライト、離すとテスト済み色で確定表示` → `Resetボタンで全キー未テストに戻す`

レイアウトはコードにハードコードせず `assets/layouts/{ansi,jis,iso}.json`（KLE準拠のジオメトリ、キーはmacOS仮想キーコードでindexing）から読み込む。将来のVIA/QMK matrix.json対応は、この同じ形式のJSONを生成するコンバータを足すだけで済む想定（設計判断の経緯は会話ログ参照）。

### ANSI / JIS / ISO の切り替え

macOSの仮想キーコードは印字文字ではなく**物理的なキー位置**を表す。同じ keycode 33 でもANSIでは「[」、JISでは「@」の位置になる。そのため：

- Raycastの設定（Preferences）→ **Keyboard Layout** で `Auto-detect` / `ANSI` / `JIS` / `ISO` を選べる
- `Auto-detect`（デフォルト）は `LMGetKbdType()`/`KBGetLayoutType()` で**物理的に接続されているキーボードのハードウェア種別**を見て自動選択する。macOSの入力ソース（言語設定）とは別物
- **注意**: ANSI形状の自作キーボードがファームウェアのコンボでJISマップのキー（英数/かな/¥/_）を送信してくる場合、自動判定はハードウェア形状を見るのでANSI版のボードを表示してしまい、それらのキーは「レイアウト外キー」表示に回る。その組み合わせを検証したいときは明示的に `JIS` を選ぶこと
- 手動で `JIS`/`ANSI`/`ISO` を選んでいるときに、実際に繋がっているキーボードの形状と食い違う凡例が表示されるのは仕様通り（オーバーライドとはそういうものなので）
- ハードウェア判定は macOS の入力ソース（言語設定）とは無関係なので、OSの入力ソースを英語にしていても、物理的にJISキーボードを使っていれば `Auto-detect` は正しくJISとして扱う

### ISOレイアウトを作る過程で見つけて直した誤り

`Clipy/Sauce`（キーボードレイアウトマッピングの実運用ライブラリ）のソースを確認したところ、JISの「@」「^」「:」がANSIの`[`(33)/`=`(24)/`'`(39)と物理キーコードを共有しているのは事実だった一方、**keycode 10 は `kVK_ISO_Section`というISO配列専用のキー（Shift行左端、Zキーの左）であり、JISの「半角/全角」キーではなかった**。以前の `jis.json` はこれを誤って半角/全角キーに割り当てていたため、`keycode 50`(`kVK_ANSI_Grave`、ANSI/ISOの数字行左端の「\`」キーと同じ物理位置)に修正し、`keycode 10` はISOレイアウトの § キー専用にした。あわせて ANSI レイアウトに漏れていた「\`」キー(keycode 50)も追加した。

### 既知の制約

- `assets/layouts/jis.json` の home 行（; : ] Return まわり、keycode 42 の位置）は実機のJIS配列で未検証のベストエフォート。他のキーはANSI配列と共通のハードウェアキーコードなので信頼度が高いが、この一角だけは実際のJISキーボードで確認してから調整する必要があるかもしれない
- JISの半角/全角キー(keycode 50)は、JIS独自キー(@ ^ :)と同じ「ANSIの物理位置を再利用する」パターンからの推測（Sauceライブラリにも直接の記載なし）。他のJIS専用キーほど裏取りできていない
- ISOレイアウトはAppleのISOキーボードが「ANSIと同じEnter/バックスラッシュ配置＋§キーが1つ追加されるだけ」という前提で構築（Sauceの`kVK_ISO_Section`定義から妥当と判断）。一般的なPC業界のISO配列によくあるEnterキーのL字形状・バックスラッシュのhome行移動は採用していない
- Numpad、Touch ID行は v1 のスコープ外だが、押されれば「レイアウト外キー」のテキストログで検知はできる（keyDown/keyUp/flagsChangedとして飛んでくるため）
- 輝度・音量などのハードウェアメディアキーは対象外。これらは`NSSystemDefined`という別種のCGEventで飛んでくるため、今のイベントタップ（keyDown/keyUp/flagsChangedのみ）では検知できず、「レイアウト外キー」表示にすら出ない
- ANSI/ISOレイアウトには英数/かな/¥/_のスロットが無い（そのハードウェアには存在しないキーのため）。これらのキーコードを送るデバイスをANSI/ISO表示のまま試すと「レイアウト外キー」に回る（上記参照）

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

- レイアウト通りにキーが並んで表示されるか（特に home 行の `; : ] return` まわりと、半角/全角キー）
- キーを押すとハイライトされ、離すと「テスト済み」の色に変わって残るか
- 複数キー同時押し（ロールオーバー）で両方とも正しく状態遷移するか
- レイアウトに無いキー（他レイアウト専用キーなど）を押すと、右上に「Unmapped key: かな (keycode 104, not on this layout)」のように人間可読名つきで表示されるか（`KeyNames.swift` の辞書引き。ログの `name=` も同じ辞書を使う）
- Reset ボタンで全キーが未テスト状態に戻るか
- ウィンドウを閉じて "Open KeyProbe" を再実行すると、まっさらな状態で開き直るか（Q10: 自動リセット）

ログファイルは Raycast の拡張機能ごとの support ディレクトリ（`environment.supportPath`）以下：

```bash
find ~/Library/Application\ Support/com.raycast.macos -maxdepth 3 -iname "keyprobe-helper.log"
tail -f "<上で見つかったパス>"
```

## 既知の挙動（初回検証で判明）

- **`keycode=... name=?` は現時点で想定通り**: v0 では修飾キーとJISキーしか名前を付けていない（`EventTap.swift` の `keyName`）。文字キー等を人間可読名にするのはレイアウトJSONの作業で対応する
- **矢印キーやHome/End/PageUp/Downを押すと `flags` に `fn` が混ざる**: 物理Fnキーを押していなくても、macOSはこのクラスタのキーに `NX_SECONDARYFNMASK` を常時付与する仕様。バグではない
- **Input Monitoring の許可ダイアログが出ず、システム設定にも `KeyProbeHelper` が出てこないのにイベントは取れている**: 未署名の単体バイナリとして子プロセス起動しているため、TCCがこのヘルパーの許可要求をRaycast.app自体の権限に付け替えている可能性が高い。システム設定 → プライバシーとセキュリティ → 入力監視 で **Raycast** が有効になっているか確認するとよい。もしRaycast側の許可を切ると、このヘルパーも一緒に動かなくなるはず

## 次のステップ（未実装）

- 実機でのhome行・半角全角キーの位置検証（上記「既知の制約」）とJSONの微調整
- 将来: VIA/QMK の matrix.json + キーマップからレイアウトJSONを生成する変換ツール
- (任意) Store公開に向けた universal binary ビルド・アイコンの本番デザイン化
