import { getPreferenceValues } from "@raycast/api";

export type Language = "en" | "ja";

interface Strings {
  builtInSection: string;
  customSection: string;
  usePreferenceTitle: string;
  usePreferenceSubtitle: (name: string) => string;
  autoDetectSubtitle: string;
  currentSelection: string;
  useThisAction: string;
  layoutSetHud: (name: string, restarted: boolean) => string;
}

const en: Strings = {
  builtInSection: "Built-in",
  customSection: "Custom Keyboards",
  usePreferenceTitle: "Use Preference Setting",
  usePreferenceSubtitle: (name) => `Currently: ${name}`,
  autoDetectSubtitle:
    "Auto-select based on the attached keyboard's hardware type",
  currentSelection: "Current",
  useThisAction: "Use This",
  layoutSetHud: (name, restarted) =>
    `KeyProbe layout set: ${name}${restarted ? " (restarted)" : ""}`,
};

const ja: Strings = {
  builtInSection: "標準",
  customSection: "カスタムキーボード",
  usePreferenceTitle: "Preferences の設定を使う",
  usePreferenceSubtitle: (name) => `現在: ${name}`,
  autoDetectSubtitle: "接続中のキーボードのハードウェア種別から自動選択",
  currentSelection: "現在の選択",
  useThisAction: "この設定を使う",
  layoutSetHud: (name, restarted) =>
    `KeyProbeのレイアウトを設定しました: ${name}${restarted ? "（再起動しました）" : ""}`,
};

const catalogs: Record<Language, Strings> = { en, ja };

export function getStrings(): Strings {
  const { language } = getPreferenceValues<Preferences>();
  return catalogs[language as Language] ?? en;
}
