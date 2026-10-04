import {
  chmodSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import path from "node:path";
import process from "node:process";
import { describe, expect, it } from "vitest";
import { rootDirectory } from "./test-utils";

const cliPath = path.join(rootDirectory, "scripts", "generate-docs.mjs");

function writeExecutable(filePath: string, content: string) {
  writeFileSync(filePath, content, "utf8");
  chmodSync(filePath, 0o755);
}

function runCli(args: string[], binDirectory: string) {
  return spawnSync(process.execPath, [cliPath, ...args], {
    cwd: rootDirectory,
    encoding: "utf8",
    env: {
      ...process.env,
      PATH: `${binDirectory}:${process.env.PATH ?? ""}`,
    },
  });
}

describe("open-in-vscode-docs CLI", () => {
  it("prefers shdoc-ng and writes a MoyaForge page.mdx", () => {
    const temp = mkdtempSync(path.join(tmpdir(), "open-in-vscode-docs-"));
    const bin = path.join(temp, "bin");
    const output = path.join(temp, "docs", "03-reference", "01-cli", "page.mdx");

    spawnSync("mkdir", ["-p", bin]);

    writeExecutable(
      path.join(bin, "shdoc-ng"),
      `#!/bin/sh
if [ "$1" = "generate" ]; then
  printf '%s\\n' '# Generated API' '' 'Function docs'
  exit 0
fi
if [ "$1" = "check" ]; then
  exit 0
fi
exit 1
`,
    );

    writeExecutable(
      path.join(bin, "shdoc"),
      `#!/bin/sh
printf '%s\\n' '# Wrong generator'
`,
    );

    const result = runCli(["--output", output], bin);

    expect(result.status, result.stderr).toBe(0);
    expect(result.stdout).toContain("with shdoc-ng");

    const page = readFileSync(output, "utf8");
    expect(page).toContain("# Generated API");
    expect(page).toContain("docs:generate");
    expect(page).toContain("Generated from open-in-vscode-installer.sh with shdoc-ng");
  });

  it("falls back to shdoc when shdoc-ng is unavailable", () => {
    const temp = mkdtempSync(path.join(tmpdir(), "open-in-vscode-docs-"));
    const bin = path.join(temp, "bin");
    const output = path.join(temp, "page.mdx");

    spawnSync("mkdir", ["-p", bin]);

    writeExecutable(
      path.join(bin, "shdoc"),
      `#!/bin/sh
printf '%s\\n' '# shdoc fallback'
`,
    );

    const result = runCli(["--output", output], bin);

    expect(result.status, result.stderr).toBe(0);
    expect(result.stdout).toContain("with shdoc");
    expect(readFileSync(output, "utf8")).toContain("# shdoc fallback");
  });

  it("uses shdoc-ng check mode without writing docs", () => {
    const temp = mkdtempSync(path.join(tmpdir(), "open-in-vscode-docs-"));
    const bin = path.join(temp, "bin");

    spawnSync("mkdir", ["-p", bin]);

    writeExecutable(
      path.join(bin, "shdoc-ng"),
      `#!/bin/sh
[ "$1" = "check" ] && exit 0
exit 1
`,
    );

    const result = runCli(["--check"], bin);

    expect(result.status, result.stderr).toBe(0);
    expect(result.stdout).toContain("annotations are valid (shdoc-ng)");
  });

  it("fails clearly when no generator is installed", () => {
    const temp = mkdtempSync(path.join(tmpdir(), "open-in-vscode-docs-"));
    const emptyBin = path.join(temp, "bin");

    spawnSync("mkdir", ["-p", emptyBin]);

    const result = spawnSync(
      process.execPath,
      [cliPath],
      {
        cwd: rootDirectory,
        encoding: "utf8",
        env: {
          ...process.env,
          PATH: emptyBin,
        },
      },
    );

    expect(result.status).toBe(1);
    expect(result.stderr).toContain("No shell documentation generator was found");
    expect(result.stderr).toContain("brew install jdevera/tap/shdoc-ng");
  });
});
