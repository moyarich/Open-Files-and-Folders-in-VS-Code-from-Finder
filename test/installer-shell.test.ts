import { spawnSync } from "node:child_process";
import { describe, expect, it } from "vitest";
import {
  installer,
  installerPath,
  runSourcedZsh,
} from "./test-utils";

describe("installer shell", () => {
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

  it("preserves explicit non-interactive commands", () => {
    expect(installer).toContain("install)");
    expect(installer).toContain("status)");
    expect(installer).toContain("uninstall)");
    expect(installer).toContain("help|-h|--help)");
  });
});
