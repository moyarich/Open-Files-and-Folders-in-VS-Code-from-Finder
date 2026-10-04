import {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { runSourcedZsh } from "./test-utils";

describe("configured workflow status", () => {
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

  it("fails when the workflow does not contain a valid bundle id", () => {
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
      '<string>/usr/bin/open -b invalid;bundle "$@"</string>',
    );

    const result = runSourcedZsh(
      'DEST="$1"; configured_bundle_id',
      [path.join(home, "Open in VS Code.workflow")],
    );

    expect(result.status).not.toBe(0);
  });
});
