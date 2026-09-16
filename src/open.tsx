import { showHUD } from "@raycast/api";
import { readPidOrNull, focusExisting, startHelper } from "./helper";

export default async function Command() {
  const existingPid = readPidOrNull();

  if (existingPid !== null) {
    focusExisting(existingPid);
    return;
  }

  const result = await startHelper();
  if (!result.success) {
    await showHUD(`⚠️ ${result.error}`);
  }
}
