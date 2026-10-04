import { describe, expect, it } from "vitest";
import { readme } from "./test-utils";

describe("README", () => {
  it("documents the current installer filename", () => {
    expect(readme).toContain("open-in-vscode-installer.sh");
    expect(readme).not.toContain(
      "install-open-in-vscode-workflow.sh",
    );
    expect(readme).not.toContain(
      "install-open-in-vscode-plugin.sh",
    );
  });

  it("documents optional fzf support", () => {
    expect(readme).toContain("brew install fzf");
    expect(readme).toContain(
      "zsh ./open-in-vscode-installer.sh",
    );
  });

  it("documents macOS test execution", () => {
    expect(readme).toContain("CI runs the suite on macOS");
    expect(readme).toContain("npm test");
  });
});
