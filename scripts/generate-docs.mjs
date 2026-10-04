#!/usr/bin/env node

import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import process from "node:process";
import { parseArgs } from "node:util";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const rootDirectory = path.resolve(scriptDirectory, "..");

const defaults = {
  input: path.join(rootDirectory, "open-in-vscode-installer.sh"),
  output: path.join(
    rootDirectory,
    "docs",
    "03-reference",
    "01-cli",
    "page.mdx",
  ),
};

function printHelp() {
  console.log(`Usage:
  open-in-vscode-docs [options]

Options:
  --input <path>        Shell file to document
  --output <path>       MoyaForge page.mdx destination
  --generator <name>    auto | shdoc-ng | shdoc (default: auto)
  --check               Validate annotations without writing docs
  -h, --help            Show this help
`);
}

function commandExists(command) {
  const result = spawnSync(
    "/bin/sh",
    ["-c", 'command -v "$1" >/dev/null 2>&1', "sh", command],
    { stdio: "ignore" },
  );

  return result.status === 0;
}

function resolveGenerator(requested) {
  if (requested !== "auto") {
    if (!["shdoc-ng", "shdoc"].includes(requested)) {
      throw new Error(
        `Unsupported generator "${requested}". Use auto, shdoc-ng, or shdoc.`,
      );
    }

    if (!commandExists(requested)) {
      throw new Error(
        `${requested} is not installed or is not available on PATH.`,
      );
    }

    return requested;
  }

  if (commandExists("shdoc-ng")) {
    return "shdoc-ng";
  }

  if (commandExists("shdoc")) {
    return "shdoc";
  }

  throw new Error(
    [
      "No shell documentation generator was found.",
      "Install shdoc-ng with:",
      "  brew install jdevera/tap/shdoc-ng",
      "or install shdoc and ensure it is available on PATH.",
    ].join("\n"),
  );
}

function generateMarkdown(generator, input) {
  if (generator === "shdoc-ng") {
    return execFileSync(
      "shdoc-ng",
      ["generate", "--format", "markdown", "--input", input],
      { encoding: "utf8" },
    );
  }

  return execFileSync("shdoc", [input], {
    encoding: "utf8",
  });
}

function checkAnnotations(generator, input) {
  if (generator === "shdoc-ng") {
    execFileSync("shdoc-ng", ["check", "--input", input], {
      stdio: "inherit",
    });
    return;
  }

  // Original shdoc has no dedicated annotation lint command.
  // Generating the document is the closest validation available.
  execFileSync("shdoc", [input], {
    stdio: "ignore",
  });
}

function toMoyaForgePage(markdown, generator, input) {
  const relativeInput = path.relative(rootDirectory, input);

  return [
    "{/* This page is generated. Edit shell annotations, then run npm run docs:generate. */}",
    "",
    `<!-- Generated from ${relativeInput} with ${generator}. -->`,
    "",
    markdown.trim(),
    "",
  ].join("\n");
}

function main() {
  const { values } = parseArgs({
    options: {
      input: { type: "string" },
      output: { type: "string" },
      generator: { type: "string", default: "auto" },
      check: { type: "boolean", default: false },
      help: { type: "boolean", short: "h", default: false },
    },
  });

  if (values.help) {
    printHelp();
    return;
  }

  const input = path.resolve(values.input ?? defaults.input);
  const output = path.resolve(values.output ?? defaults.output);
  const generator = resolveGenerator(values.generator);

  if (values.check) {
    checkAnnotations(generator, input);
    console.log(`Shell docs annotations are valid (${generator}).`);
    return;
  }

  const markdown = generateMarkdown(generator, input);
  const page = toMoyaForgePage(markdown, generator, input);

  mkdirSync(path.dirname(output), { recursive: true });
  writeFileSync(output, page, "utf8");

  console.log(
    `Generated ${path.relative(rootDirectory, output)} with ${generator}.`,
  );
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
