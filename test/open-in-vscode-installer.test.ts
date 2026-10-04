import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
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

describe("Finder Quick Action installer", () => {
  it("uses strict Zsh execution", () => {
    expect(installer).toMatch(/^#!\/bin\/zsh\n/);
    expect(installer).toContain("set -euo pipefail");
  });

  it("preserves explicit non-interactive commands", () => {
    expect(installer).toContain('MODE="${1:-}"');
    expect(installer).toContain('if [[ -n "$MODE" ]]; then');
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
    expect(installer).toContain("Visual Studio Code.app");
    expect(installer).toContain("Visual Studio Code - Insiders.app");
  });

  it("supports an explicit bundle-id override", () => {
    expect(installer).toContain(
      'REQUESTED_BUNDLE_ID="${2:-${OPEN_IN_VSCODE_BUNDLE_ID:-}}"',
    );
    expect(installer).toContain('if [[ -n "$REQUESTED_BUNDLE_ID" ]]');
  });

  it("passes all Finder selections to the selected VS Code bundle", () => {
    expect(installer).toContain(
      '<key>COMMAND_STRING</key><string>/usr/bin/open -b ${bundle_id} "\\$@"</string>',
    );
    expect(installer).toContain(
      '<key>inputMethod</key><integer>1</integer>',
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
    expect(installer).toContain(
      "<string>com.apple.finder</string>",
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

  it("keeps diagnostic warnings out of machine-readable selector output", () => {
    expect(installer).toMatch(
      /warn\(\).*printf .* >&2;/,
    );
  });

  it("documents the actual installer filename and fzf workflow", () => {
    expect(readme).toContain("open-in-vscode-installer.sh");
    expect(readme).not.toContain("install-open-in-vscode-plugin.sh");
    expect(readme).toContain("brew install fzf");
    expect(readme).toContain(
      "zsh ./open-in-vscode-installer.sh",
    );
  });

  const zshCheck = spawnSync("zsh", ["--version"], {
    encoding: "utf8",
  });

  const syntaxTest = zshCheck.status === 0 ? it : it.skip;

  syntaxTest("passes zsh syntax validation", () => {
    const result = spawnSync("zsh", ["-n", installerPath], {
      encoding: "utf8",
    });

    expect(result.status, result.stderr).toBe(0);
  });
});
