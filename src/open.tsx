import { showHUD, getPreferenceValues, LocalStorage } from "@raycast/api";
import { readPidOrNull, focusExisting, startHelper } from "./helper";

export default async function Command() {
  const existingPid = readPidOrNull();

  if (existingPid !== null) {
    focusExisting(existingPid);
    return;
  }

  // "Select Keyboard Layout" (search-layout.tsx) overrides the preference
  // when set, so picking a custom board there doesn't require also
  // changing Raycast's Preferences pane.
  const override = await LocalStorage.getItem<string>("selectedLayout");
  const layoutMode = override ?? getPreferenceValues<Preferences>().layoutMode;
  const result = await startHelper(layoutMode);
  if (!result.success) {
    await showHUD(`⚠️ ${result.error}`);
  }
}
