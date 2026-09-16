import { spawn } from "child_process";
import { environment } from "@raycast/api";
import path from "path";
import fs from "fs";

// supportPath is stable across runs (unlike os.tmpdir(), which on macOS
// resolves to a per-login-session directory under /var/folders/... — not
// the /tmp you'd expect, and not guessable ahead of time).
const PID_FILE = path.join(environment.supportPath, "keyprobe-helper.pid");
const LOG_FILE = path.join(environment.supportPath, "keyprobe-helper.log");

function getHelperPath(): string {
  return path.join(environment.assetsPath, "KeyProbeHelper");
}

function readPid(): number | null {
  try {
    const pid = parseInt(fs.readFileSync(PID_FILE, "utf8").trim(), 10);
    if (isNaN(pid)) return null;
    try {
      process.kill(pid, 0); // check alive
      return pid;
    } catch {
      try {
        fs.unlinkSync(PID_FILE);
      } catch {
        // ignore
      }
      return null;
    }
  } catch {
    return null;
  }
}

export function isRunning(): boolean {
  return readPid() !== null;
}

// Signals the already-running helper to bring its window to the front,
// instead of spawning a second instance (settled: Q11).
export function focusExisting(pid: number): void {
  process.kill(pid, "SIGUSR1");
}

function prepareHelper(
  helperPath: string,
): { success: true } | { success: false; error: string } {
  if (!fs.existsSync(helperPath)) {
    return {
      success: false,
      error: `Helper binary is missing at ${helperPath}. Run "npm run build-helper" first.`,
    };
  }
  try {
    fs.accessSync(helperPath, fs.constants.X_OK);
  } catch {
    try {
      fs.chmodSync(helperPath, 0o755);
    } catch (error) {
      return {
        success: false,
        error: `Helper is not executable: ${error instanceof Error ? error.message : String(error)}`,
      };
    }
  }
  return { success: true };
}

export async function startHelper(): Promise<{
  success: boolean;
  error?: string;
}> {
  const helperPath = getHelperPath();
  const prepared = prepareHelper(helperPath);
  if (!prepared.success) return prepared;

  let out: number | null = null;
  try {
    out = fs.openSync(LOG_FILE, "a");
    const child = spawn(helperPath, ["--pid", PID_FILE, "--log", LOG_FILE], {
      detached: true,
      stdio: ["ignore", out, out],
    });
    child.unref();
  } catch (error) {
    return {
      success: false,
      error: `Helper failed to launch: ${error instanceof Error ? error.message : String(error)}`,
    };
  } finally {
    if (out !== null) fs.closeSync(out);
  }

  // Poll for the helper to write its PID (event tap + window ready).
  for (let attempt = 0; attempt < 30; attempt++) {
    await new Promise((r) => setTimeout(r, 100));
    const pid = readPid();
    if (pid) return { success: true };
  }

  try {
    const log = fs.readFileSync(LOG_FILE, "utf8");
    return {
      success: false,
      error: `Helper failed to start. Log tail: ${log.slice(-300)}`,
    };
  } catch {
    return { success: false, error: "Helper failed to start." };
  }
}

export function readPidOrNull(): number | null {
  return readPid();
}
