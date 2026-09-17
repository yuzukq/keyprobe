import {
  ActionPanel,
  Action,
  List,
  LocalStorage,
  Icon,
  showHUD,
  popToRoot,
  environment,
} from "@raycast/api";
import { useEffect, useState } from "react";
import fs from "fs";
import path from "path";
import { readPidOrNull, stopHelper, startHelper } from "./helper";

const OVERRIDE_KEY = "selectedLayout";

interface LayoutEntry {
  stem: string;
  name: string;
  keyCount: number;
}

function loadLayouts(): LayoutEntry[] {
  const dir = path.join(environment.assetsPath, "layouts");
  const files = fs.readdirSync(dir).filter((f) => f.endsWith(".json"));
  return files
    .map((file) => {
      const stem = file.replace(/\.json$/, "");
      try {
        const parsed = JSON.parse(
          fs.readFileSync(path.join(dir, file), "utf8"),
        );
        return {
          stem,
          name: parsed.name ?? stem,
          keyCount: parsed.keys?.length ?? 0,
        };
      } catch {
        return { stem, name: stem, keyCount: 0 };
      }
    })
    .sort((a, b) => a.name.localeCompare(b.name));
}

const BUILT_IN = new Set(["ansi", "jis", "iso"]);

export default function Command() {
  const [layouts, setLayouts] = useState<LayoutEntry[]>([]);
  const [current, setCurrent] = useState<string>("auto");

  useEffect(() => {
    setLayouts(loadLayouts());
    LocalStorage.getItem<string>(OVERRIDE_KEY).then((v) =>
      setCurrent(v ?? "auto"),
    );
  }, []);

  async function select(stem: string) {
    await LocalStorage.setItem(OVERRIDE_KEY, stem);

    // The helper only reads --layout-mode at startup, so if a window is
    // already open, changing the selection alone wouldn't do anything
    // until the user closed and reopened it by hand — restart it here
    // instead, reusing the same start/stop flow "Open KeyProbe" uses (and
    // getting the fresh-state reset that a new helper start already gives
    // for free, per Q10).
    const existingPid = readPidOrNull();
    if (existingPid !== null) {
      await stopHelper(existingPid);
      const result = await startHelper(stem);
      if (!result.success) {
        await showHUD(`⚠️ ${result.error}`);
        return;
      }
      await showHUD(`KeyProbe layout set: ${stem}（再起動しました）`);
    } else {
      await showHUD(`KeyProbe layout set: ${stem}`);
    }
    await popToRoot();
  }

  const builtIns = layouts.filter((l) => BUILT_IN.has(l.stem));
  const custom = layouts.filter((l) => !BUILT_IN.has(l.stem));

  return (
    <List searchBarPlaceholder="Search keyboard layouts...">
      <List.Section title="標準">
        <List.Item
          title="Auto-detect"
          subtitle="接続中のキーボードのハードウェア種別から自動選択"
          icon={Icon.MagnifyingGlass}
          accessories={current === "auto" ? [{ text: "現在の選択" }] : []}
          actions={
            <ActionPanel>
              <Action title="この設定を使う" onAction={() => select("auto")} />
            </ActionPanel>
          }
        />
        {builtIns.map((l) => (
          <List.Item
            key={l.stem}
            title={l.name}
            subtitle={`${l.keyCount} keys`}
            icon={Icon.Keyboard}
            accessories={current === l.stem ? [{ text: "現在の選択" }] : []}
            actions={
              <ActionPanel>
                <Action
                  title="この設定を使う"
                  onAction={() => select(l.stem)}
                />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
      <List.Section title="カスタムキーボード">
        {custom.map((l) => (
          <List.Item
            key={l.stem}
            title={l.name}
            subtitle={`${l.keyCount} keys`}
            icon={Icon.Keyboard}
            accessories={current === l.stem ? [{ text: "現在の選択" }] : []}
            actions={
              <ActionPanel>
                <Action
                  title="この設定を使う"
                  onAction={() => select(l.stem)}
                />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
    </List>
  );
}
