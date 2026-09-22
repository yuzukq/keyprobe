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
import { getStrings } from "./i18n";

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
  // row's "current selection" badge while that read is in flight). null =
  // read finished, no override saved, so open.tsx falls back to the
  // Preferences pane's Keyboard Layout setting. Distinct from the string
  // "auto", which is an override that was explicitly set to Auto-detect
  // from this list.
  const [current, setCurrent] = useState<string | null | undefined>(undefined);
  const preferenceLayoutMode = getPreferenceValues<Preferences>().layoutMode;
  const t = getStrings();

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
      await showHUD(t.layoutSetHud(displayName, true));
    } else {
      await showHUD(t.layoutSetHud(displayName, false));
    }
    await popToRoot();
  }

  async function select(stem: string, displayName: string) {
    await LocalStorage.setItem(OVERRIDE_KEY, stem);
    await restart(stem, displayName);
  }

  async function useDefault() {
    await LocalStorage.removeItem(OVERRIDE_KEY);
    await restart(preferenceLayoutMode, t.preferenceDisplayName);
  }

  const builtIns = layouts.filter((l) => BUILT_IN.has(l.stem));
  const custom = layouts.filter((l) => !BUILT_IN.has(l.stem));

  return (
    <List searchBarPlaceholder="Search keyboard layouts...">
      <List.Section title={t.builtInSection}>
        <List.Item
          title={t.usePreferenceTitle}
          subtitle={t.usePreferenceSubtitle(preferenceLayoutMode)}
          icon={Icon.ArrowCounterClockwise}
          accessories={current === null ? [{ text: t.currentSelection }] : []}
          actions={
            <ActionPanel>
              <Action title={t.useThisAction} onAction={useDefault} />
            </ActionPanel>
          }
        />
        <List.Item
          title="Auto-detect"
          subtitle={t.autoDetectSubtitle}
          icon={Icon.MagnifyingGlass}
          accessories={current === "auto" ? [{ text: t.currentSelection }] : []}
          actions={
            <ActionPanel>
              <Action
                title={t.useThisAction}
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
            accessories={
              current === l.stem ? [{ text: t.currentSelection }] : []
            }
            actions={
              <ActionPanel>
                <Action
                  title={t.useThisAction}
                  onAction={() => select(l.stem, l.name)}
                />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
      <List.Section title={t.customSection}>
        {custom.map((l) => (
          <List.Item
            key={l.stem}
            title={l.name}
            subtitle={`${l.keyCount} keys`}
            icon={Icon.Keyboard}
            accessories={
              current === l.stem ? [{ text: t.currentSelection }] : []
            }
            actions={
              <ActionPanel>
                <Action
                  title={t.useThisAction}
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
