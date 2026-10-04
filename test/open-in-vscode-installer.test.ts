import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { describe, expect, it } from "vitest";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const rootDirectory = path.resolve(testDirectory, "..");

const installerPath = path.join(
  rootDirectory,
  "open-in-vscode-installer.sh",
);
const readmePath = path.join(rootDirectory, "README.md");

const installer = readFileSync(installerPath, "utf8");
const readme = readFileSync(readmePath, "utf8");

function runSourcedZsh(command: string, args: string[] = []) {
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

describe("Open in VS Code installer", () => {
  it("passes zsh syntax validation", () => {
    const result = spawnSync("zsh", ["-n", installerPath], {
      encoding: "utf8",
    });

    expect(result.status, result.stderr).toBe(0);
  });

  it("uses strict Zsh execution", () => {
    expect(installer).toMatch(/^#!\/bin\/zsh\n/);
    expect(installer).toContain("set -euo pipefail");
  });

  it("is sourceable without executing the installer", () => {
    const result = runSourcedZsh('print -r -- "$STABLE_BUNDLE_ID"');

    expect(result.status, result.stderr).toBe(0);
    expect(result.stdout.trim()).toBe("com.microsoft.VSCode");
  });

  it.each([
    "com.microsoft.VSCode",
    "com.microsoft.VSCodeInsiders",
    "com.example.Editor-Preview_1",
  ])("accepts safe bundle identifier %s", (bundleId) => {
    const result = runSourcedZsh(
      'validate_bundle_id "$1"',
      [bundleId],
    );

    expect(result.status, result.stderr).toBe(0);
  });

  it.each([
    "com.microsoft.VSCode;touch /tmp/pwned",
    "com.microsoft.VSCode&bad",
    "com.microsoft.VSCode bad",
    "com.microsoft.<VSCode>",
    "",
  ])("rejects unsafe bundle identifier %j", (bundleId) => {
    const result = runSourcedZsh(
      'validate_bundle_id "$1"',
      [bundleId],
    );

    expect(result.status).not.toBe(0);
  });

  it("rejects an unsafe explicit bundle override before selection", () => {
    const result = runSourcedZsh(
      'REQUESTED_BUNDLE_ID="$1"; select_vscode_bundle',
      ["com.microsoft.VSCode;echo injected"],
    );

    expect(result.status).not.toBe(0);
    expect(result.stderr).toContain("Invalid VS Code bundle identifier");
  });

  it("reads the configured bundle id from an installed workflow", () => {
    const home = mkdtempSync(
      path.join(tmpdir(), "open-in-vscode-test-"),
    );
    const workflow = path.join(
      home,
      "Open in VS Code.workflow",
      "Contents",
    );

    mkdirSync(workflow, { recursive: true });
    writeFileSync(
      path.join(workflow, "document.wflow"),
      [
        "<plist><dict>",
        "<key>COMMAND_STRING</key>",
        '<string>/usr/bin/open -b com.microsoft.VSCodeInsiders "$@"</string>',
        "</dict></plist>",
      ].join(""),
    );

    const result = runSourcedZsh(
      'DEST="$1"; configured_bundle_id',
      [path.join(home, "Open in VS Code.workflow")],
    );

    expect(result.status, result.stderr).toBe(0);
    expect(result.stdout.trim()).toBe(
      "com.microsoft.VSCodeInsiders",
    );
  });

  it("preserves explicit non-interactive commands", () => {
    expect(installer).toContain("install)");
    expect(installer).toContain("status)");
    expect(installer).toContain("uninstall)");
    expect(installer).toContain("help|-h|--help)");
  });

  it("uses fzf only as an optional interactive picker", () => {
    expect(installer).toContain("command -v fzf");
    expect(installer).toContain("is_interactive_terminal && has_fzf");
    expect(installer).toContain("--prompt='Action > '");
    expect(installer).toContain("--prompt='VS Code > '");
    expect(installer).toContain('MODE="install"');
  });

  it("supports stable and Insiders VS Code bundle identifiers", () => {
    expect(installer).toContain(
      'STABLE_BUNDLE_ID="com.microsoft.VSCode"',
    );
    expect(installer).toContain(
      'INSIDERS_BUNDLE_ID="com.microsoft.VSCodeInsiders"',
    );
  });

  it("passes all Finder selections to the selected VS Code bundle", () => {
    expect(installer).toContain(
      '<key>COMMAND_STRING</key><string>/usr/bin/open -b ${bundle_id} "\\$@"</string>',
    );
    expect(installer).toContain(
      "<key>inputMethod</key><integer>1</integer>",
    );
  });

  it("configures the workflow as a Finder file-system Quick Action", () => {
    expect(installer).toContain(
      "com.apple.Automator.servicesMenu",
    );
    expect(installer).toContain(
      "com.apple.Automator.fileSystemObject",
    );
    expect(installer).toContain(
      "/System/Library/CoreServices/Finder.app",
    );
  });

  it("validates both generated plist files before installation", () => {
    expect(installer).toContain(
      'plutil -lint "$src/Contents/document.wflow"',
    );
    expect(installer).toContain(
      'plutil -lint "$src/Contents/Info.plist"',
    );
  });

  it("documents the actual installer filename and fzf workflow", () => {
    expect(readme).toContain("open-in-vscode-installer.sh");
    expect(readme).not.toContain(
      "install-open-in-vscode-workflow.sh",
    );
    expect(readme).not.toContain(
      "install-open-in-vscode-plugin.sh",
    );
    expect(readme).toContain("brew install fzf");
  });
});
