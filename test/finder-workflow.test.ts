import { describe, expect, it } from "vitest";
import { installer } from "./test-utils";

describe("Finder Quick Action workflow", () => {
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

  it("documents why Finder may be restarted", () => {
    expect(installer).toContain(
      "Finder can otherwise retain a stale Quick Actions menu",
    );
  });
});
