#!/usr/bin/env node
/**
 * Run the SHIPPED simulator engine on a simulator's own embedded data and
 * print its shares and greedy TURF as JSON.
 *
 * A helper, not a gate: test_pipeline_end_to_end.R pulls the sim-data block
 * out of a simulator HTML written by a real run, feeds it here, and compares
 * what the engine computes with the workbook the same run wrote.
 *
 * Usage:  node run_engine_on_simdata.mjs <sim-data.json> <maxItems> <topK>
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const ENGINE = path.join(ROOT, "modules/maxdiff/lib/html_simulator/js/simulator_engine.js");

const [file, maxItems, topK] = process.argv.slice(2);
const ctx = vm.createContext({ console, Math });
vm.runInContext(readFileSync(ENGINE, "utf8") + "\nthis.SimEngine = SimEngine;", ctx);
ctx.SimEngine.init(JSON.parse(readFileSync(file, "utf8")));
process.stdout.write(JSON.stringify({
  shares: ctx.SimEngine.computeShares(),
  turf: ctx.SimEngine.turfOptimize(Number(maxItems), Number(topK)),
}));
