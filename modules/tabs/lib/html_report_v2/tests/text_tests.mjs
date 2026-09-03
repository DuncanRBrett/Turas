// TR.txt (02_text.js): the lookup every authored sentence goes through.
//
// Covered here because the rest of the suite exercises it only in passing: a
// regression in escaping or substitution would show up as garbled prose in a
// client's report rather than as a failing assertion anywhere else.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) { if (a !== b) throw new Error(msg + "\n      got: " + a + "\n      want: " + b); }

function boot(catalogue) {
  const sb = { console };
  sb.globalThis = sb; sb.window = sb;
  vm.createContext(sb);
  vm.runInContext(readFileSync(path.join(JS_DIR, "02_text.js"), "utf8"), sb);
  vm.runInContext(readFileSync(path.join(JS_DIR, "01_format.js"), "utf8"), sb);
  sb.TR.txt.load(catalogue || {});
  return sb.TR;
}

console.log("Authored text lookup (TR.txt):");

run("returns the authored string", () => {
  eq(boot({ "a.b": "Hello." }).txt("a.b"), "Hello.", "plain lookup");
});

run("blank text renders nothing. That is how a block is switched off", () => {
  const TR = boot({ "a.b": "" });
  eq(TR.txt("a.b"), "", "blank key returns empty");
  eq(TR.txt.block("a.b"), "", "and leaves no empty element behind");
  eq(TR.txt.has("a.b"), false, "has() reports it as not renderable");
});

run("a key the catalogue lacks returns '' and is recorded as a miss", () => {
  const TR = boot({});
  eq(TR.txt("nope.missing"), "", "no wording is invented");
  eq(TR.txt.misses().join(","), "nope.missing", "the selftest can report it");
});

run("placeholders substitute", () => {
  eq(boot({ "a.b": "Produced by {company}." }).txt("a.b", { company: "Acme" }),
    "Produced by Acme.", "token replaced");
});

run("token VALUES are escaped exactly as fmt.escapeHtml would", () => {
  // The renderer used to escape these values itself. Any divergence changes the
  // emitted HTML of every report. The apostrophe was the one that got away.
  const TR = boot({ "a.b": "{v}" });
  ["each scale's maximum", 'He said "no" & left', "<script>x</script>", "a > b"]
    .forEach((v) => eq(TR.txt("a.b", { v: v }), TR.fmt.escapeHtml(v),
      "escaping matches fmt.escapeHtml for: " + v));
});

run("{html:} values are inserted raw. Markup the renderer built itself", () => {
  eq(boot({ "a.b": "See {link}." }).txt("a.b", { link: { html: "<button>go</button>" } }),
    "See <button>go</button>.", "raw markup survives");
});

run("an unsupplied token is left as written, not blanked", () => {
  // A silently swallowed subject reads as finished prose; a visible {token}
  // does not, and gets noticed in review.
  eq(boot({ "a.b": "For {who}." }).txt("a.b", { other: 1 }), "For {who}.",
    "the brace group stays");
});

run("authored markup is NOT escaped. The text is trusted, the values are not", () => {
  eq(boot({ "a.b": "A <strong>claim</strong>." }).txt("a.b"),
    "A <strong>claim</strong>.", "inline markup renders");
});

run("block() wraps, tags with its key, and takes a tag and class", () => {
  const TR = boot({ "a.b": "Body." });
  eq(TR.txt.block("a.b"), '<p data-txt-key="a.b">Body.</p>', "default is a paragraph");
  eq(TR.txt.block("a.b", null, { tag: "li" }), '<li data-txt-key="a.b">Body.</li>', "tag honoured");
  eq(TR.txt.block("a.b", null, { tag: "div", cls: "hint" }),
    '<div data-txt-key="a.b" class="hint">Body.</div>', "class honoured");
});

run("load() replaces the catalogue and clears past misses", () => {
  const TR = boot({});
  TR.txt("gone.away");
  TR.txt.load({ "a.b": "x" });
  eq(TR.txt.misses().length, 0, "misses reset with the catalogue");
  eq(TR.txt.keys().join(","), "a.b", "keys() lists what is loaded");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
if (failed) process.exit(1);
