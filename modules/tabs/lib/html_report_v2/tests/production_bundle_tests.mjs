#!/usr/bin/env node
/**
 * PRODUCTION BUNDLE GATE.
 *
 * The cross-engine parity suite proves the statistics engine agrees with R.
 * It proves it about the SOURCE modules. What a client opens is those modules
 * after terser and after javascript-obfuscator, and no gate had ever run a
 * number through that. A profile change that quietly altered a computed figure
 * would have shipped.
 *
 * This gate concatenates the eleven engine modules, puts them through the
 * settings the pipeline actually ships (read from the generated mirror
 * modules/shared/lib/minify_profile.json, whose source of truth is the R
 * constants in turas_minify.R), and re-runs parity_stats_tests.mjs against the
 * single obfuscated file. Same assertions, production bytes.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/production_bundle_tests.mjs
 * Skips loudly, without failing, when the node build tools are not installed.
 */
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { PARITY_ENGINE_MODULES } from "./parity_engine_modules.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const ROOT = path.join(HERE, "..", "..", "..", "..", "..");
const PROFILE_PATH = path.join(ROOT, "modules", "shared", "lib", "minify_profile.json");

// The same directories .MINIFY_NODE_SEARCH_PATHS searches, in the same order.
const SEARCH_PATHS = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin",
  "/usr/lib/node_modules/.bin"];

function findTool(name) {
  for (const dir of SEARCH_PATHS) {
    const p = path.join(dir, name);
    try { readFileSync(p); return p; } catch (e) { /* keep looking */ }
  }
  const which = spawnSync("which", [name], { encoding: "utf8" });
  return which.status === 0 ? which.stdout.trim() : "";
}

const terser = findTool("terser");
const obfuscator = findTool("javascript-obfuscator");
if (!terser || !obfuscator) {
  console.log("SKIPPED production bundle gate: " +
    (!terser ? "terser " : "") + (!obfuscator ? "javascript-obfuscator " : "") +
    "not found. Install the node build tools to run it.");
  process.exit(0);
}

const profile = JSON.parse(readFileSync(PROFILE_PATH, "utf8"));
const tmp = mkdtempSync(path.join(os.tmpdir(), "turas-bundle-"));

try {
  const source = PARITY_ENGINE_MODULES
    .map((f) => readFileSync(path.join(JS_DIR, f), "utf8"))
    .join("\n\n");
  const srcPath = path.join(tmp, "engine.js");
  const minPath = path.join(tmp, "engine.min.js");
  const obfPath = path.join(tmp, "engine.obf.js");
  const cfgPath = path.join(tmp, "obfuscator.json");
  writeFileSync(srcPath, source, "utf8");
  writeFileSync(cfgPath, JSON.stringify(profile.obfuscator), "utf8");

  const t = spawnSync(terser, [...profile.terser_args, srcPath, "-o", minPath],
    { encoding: "utf8", timeout: 180000 });
  if (t.status !== 0) throw new Error("terser failed: " + (t.stderr || t.error));

  const o = spawnSync(obfuscator, [minPath, "--output", obfPath, "--config", cfgPath],
    { encoding: "utf8", timeout: 180000 });
  if (o.status !== 0) throw new Error("obfuscator failed: " + (o.stderr || o.error));

  const obf = readFileSync(obfPath, "utf8");
  if (!obf.length) throw new Error("obfuscated bundle is empty");
  if (obf === source) throw new Error("obfuscated bundle is byte-identical to source");

  console.log("  source " + source.length + " bytes -> terser " +
    readFileSync(minPath, "utf8").length + " -> obfuscated " + obf.length);
  // Reported, not asserted. A profile change shows its effect here rather than
  // in a survivor count nobody re-measures.
  const survivors = ["renderTab", "encodeHash", "activeQ", "isWeighted", "zPrimary"]
    .map((n) => n + "=" + (obf.split(n).length - 1)).join(" ");
  console.log("  readable identifiers in the shipped bytes: " + survivors);

  const r = spawnSync(process.execPath, [path.join(HERE, "parity_stats_tests.mjs")],
    { encoding: "utf8", env: { ...process.env, TURAS_BUNDLE: obfPath } });
  process.stdout.write(r.stdout.split("\n").filter((l) => l.startsWith("✓") ||
    l.startsWith("✗") || l.includes(" passed")).join("\n") + "\n");
  if (r.status !== 0) {
    process.stdout.write(r.stdout);
    console.log("✗ parity suite failed against the production bundle");
    process.exit(1);
  }
  console.log("✓ the parity suite passes against the production bundle");
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
