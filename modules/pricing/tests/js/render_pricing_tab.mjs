#!/usr/bin/env node
/**
 * Render the v2 Pricing tab from a real pricing island and print its visible
 * text, so an R pipeline test can compare what the client reads on the tab
 * with the Results workbook the same run wrote.
 *
 * Loads the shipped modules/tabs/lib/html_report_v2/assets/js/27z_pricing.js
 * into node:vm with the same minimal TR stub the tab's own gate uses
 * (pricing_view_tests.mjs).
 *
 * Run: node modules/pricing/tests/js/render_pricing_tab.mjs <island.json>
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS = path.join(HERE, "..", "..", "..", "tabs", "lib", "html_report_v2", "assets", "js", "27z_pricing.js");

const island = JSON.parse(readFileSync(process.argv[2], "utf8"));
const sb = { console };
sb.globalThis = sb;
sb.window = sb;
sb.TR = { fmt: { escapeHtml: (s) => String(s == null ? "" : s)
  .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") } };
vm.createContext(sb);
vm.runInContext(readFileSync(JS, "utf8"), sb, { filename: "27z_pricing.js" });
sb.TR.PR = island;
const host = { innerHTML: "" };
sb.TR.pricing.render(host);

// Visible text: drop script/style, then tags, then collapse whitespace.
const text = host.innerHTML
  .replace(/<(script|style)[\s\S]*?<\/\1>/g, " ")
  .replace(/<[^>]+>/g, " ")
  .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
  .replace(/\s+/g, " ")
  .trim();
process.stdout.write(text + "\n");
