import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));

export const rootDirectory = path.resolve(testDirectory, "..");
export const installerPath = path.join(
  rootDirectory,
  "open-in-vscode-installer.sh",
);
export const readmePath = path.join(rootDirectory, "README.md");

export const installer = readFileSync(installerPath, "utf8");
export const readme = readFileSync(readmePath, "utf8");

export function runSourcedZsh(command: string, args: string[] = []) {
  return spawnSync(
    "zsh",
    [
      "-c",
      'OPEN_IN_VSCODE_SOURCE_ONLY=1 source "$1"; shift; ' + command,
      "zsh",
      installerPath,
      ...args,
    ],
    { encoding: "utf8" },
  );
}
