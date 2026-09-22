import {
  ActionPanel,
  Action,
  List,
  LocalStorage,
  Icon,
  showHUD,
  popToRoot,
  environment,
  getPreferenceValues,
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
  // undefined = not read from LocalStorage yet (avoid flashing the wrong
  // row's "現在の選択" while that read is in flight). null = read finished,
  // no override saved, so open.tsx falls back to the Preferences pane's
  // Keyboard Layout setting. Distinct from the string "auto", which is an
  // override that was explicitly set to Auto-detect from this list.
  const [current, setCurrent] = useState<string | null | undefined>(undefined);
  const preferenceLayoutMode = getPreferenceValues<Preferences>().layoutMode;

  useEffect(() => {
    setLayouts(loadLayouts());
    LocalStorage.getItem<string>(OVERRIDE_KEY).then((v) =>
      setCurrent(v ?? null),
    );
  }, []);

  async function restart(stem: string, displayName: string) {
    // The helper only reads --layout-mode at startup, so if a window is
    // already open, changing the selection alone wouldn't do anything
    // until the user closed and reopened it by hand — restart it here
    // instead, reusing the same start/stop flow "Open KeyProbe" uses.
    const existingPid = readPidOrNull();
    if (existingPid !== null) {
      await stopHelper(existingPid);
      const result = await startHelper(stem);
      if (!result.success) {
        await showHUD(`⚠️ ${result.error}`);
        return;
      }
      await showHUD(`KeyProbe layout set: ${displayName}（再起動しました）`);
    } else {
      await showHUD(`KeyProbe layout set: ${displayName}`);
    }
    await popToRoot();
  }

  async function select(stem: string, displayName: string) {
    await LocalStorage.setItem(OVERRIDE_KEY, stem);
    await restart(stem, displayName);
  }

  async function useDefault() {
    await LocalStorage.removeItem(OVERRIDE_KEY);
    await restart(preferenceLayoutMode, "Preferences の設定");
  }

  const builtIns = layouts.filter((l) => BUILT_IN.has(l.stem));
  const custom = layouts.filter((l) => !BUILT_IN.has(l.stem));

  return (
    <List searchBarPlaceholder="Search keyboard layouts...">
      <List.Section title="標準">
        <List.Item
          title="Preferences の設定に戻す"
          subtitle={`このコマンドでの選択を解除し、Raycastの環境設定（現在: ${preferenceLayoutMode}）に従う`}
          icon={Icon.ArrowCounterClockwise}
          accessories={current === null ? [{ text: "現在の選択" }] : []}
          actions={
            <ActionPanel>
              <Action title="この設定を使う" onAction={useDefault} />
            </ActionPanel>
          }
        />
        <List.Item
          title="Auto-detect"
          subtitle="接続中のキーボードのハードウェア種別から自動選択"
          icon={Icon.MagnifyingGlass}
          accessories={current === "auto" ? [{ text: "現在の選択" }] : []}
          actions={
            <ActionPanel>
              <Action
                title="この設定を使う"
                onAction={() => select("auto", "Auto-detect")}
              />
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
                  onAction={() => select(l.stem, l.name)}
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
                  onAction={() => select(l.stem, l.name)}
                />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
    </List>
  );
}
