import { showHUD, getPreferenceValues } from "@raycast/api";
import { readPidOrNull, focusExisting, startHelper } from "./helper";

export default async function Command() {
  const existingPid = readPidOrNull();

  if (existingPid !== null) {
    focusExisting(existingPid);
    return;
  }

  const { layoutMode } = getPreferenceValues<Preferences>();
  const result = await startHelper(layoutMode);
  if (!result.success) {
    await showHUD(`⚠️ ${result.error}`);
  }
}
