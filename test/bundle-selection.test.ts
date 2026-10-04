import { describe, expect, it } from "vitest";
import {
  installer,
  runSourcedZsh,
} from "./test-utils";

describe("VS Code bundle selection", () => {
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

  it("supports stable and Insiders bundle identifiers", () => {
    expect(installer).toContain(
      'STABLE_BUNDLE_ID="com.microsoft.VSCode"',
    );
    expect(installer).toContain(
      'INSIDERS_BUNDLE_ID="com.microsoft.VSCodeInsiders"',
    );
  });

  it("uses fzf only as an optional interactive picker", () => {
    expect(installer).toContain("command -v fzf");
    expect(installer).toContain("is_interactive_terminal && has_fzf");
    expect(installer).toContain("--prompt='Action > '");
    expect(installer).toContain("--prompt='VS Code > '");
    expect(installer).toContain('MODE="install"');
  });
});
