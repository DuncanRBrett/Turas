# Handover for Opus: production build hardening

Written by Fable 5.1, 4 September 2026, from the design in
`DESIGN_production_build_hardening_FABLE.md`. Read that first; this file is the
work order. All five decisions in its section 4 were approved by Duncan on
4 September 2026: default the deliverable checkbox on, encode the islands, no
control-flow flattening, strip unused renderers, one profile for every module. Follow `fable-method` and the Turas CLAUDE.md. Nothing is "fixed"
until a command in your session shows it.

## Before the first edit

1. `git branch --show-current`, `git status --short`. Another session wrote,
   uncommitted, on 4 September between 00:30 and 00:40: `delivery_manifest.R`
   and its test, `turas_release_audit.R`, edits to `turas_minify.R`,
   `import_all.R`, `run_crosstabs.R`, `21d_disclosure.js`, `32_report.js`,
   `disclosure_tests.mjs`, `saved_copy_namespace_tests.mjs`. Do not start until
   those are committed. If they are still uncommitted, stop and say so.
2. Work on a branch off main, `feature/build-hardening`.
3. Confirm the tools: `node`, `terser`, `cleancss`, `html-minifier-terser`,
   `javascript-obfuscator` at `/opt/homebrew/bin/`. Versions this session:
   node 25.8.2, terser 5.46.1, cleancss 5.6.3, html-minifier-terser 7.2.0,
   javascript-obfuscator 5.4.1.
4. Baseline before touching anything, and record the counts:
   `Rscript -e 'testthat::test_file("modules/shared/tests/testthat/test_turas_minify.R")'`
   and `for f in modules/tabs/lib/html_report_v2/tests/*_tests.mjs; do node "$f"; done`.

## Stage 1. The gate first

Build the checks before the config moves, so the config change is the first
thing they catch.

1a. Node gate against the production bundle. New file
`modules/tabs/lib/html_report_v2/tests/production_bundle_tests.mjs`. It writes
the eleven parity engine modules (the list at the top of
`parity_stats_tests.mjs`) to a temp file, runs terser with
`.MINIFY_TERSER_ARGS` and the obfuscator with the shipped profile, loads the
single result into the same vm sandbox, and runs the parity assertions.
`docs/disclosure/experiments/parity_bundle_tests.mjs` is a working prototype
that takes the bundle path in `BUNDLE`; lift its loader, not its hard-coded
path. Read the profile from R's constant rather than a copy: simplest is a
small R script the test shells out to, or have `turas_minify.R` write the JSON
to `modules/shared/lib/obfuscator_profile.json` and read that from both sides.

1b. Headless render gate. New testthat file
`modules/shared/tests/testthat/test_minify_render_gate.R`. Skips with a printed
reason when `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` is
absent. For the Karoo demo report and for each legacy report in `examples/`
(`examples/pricing/Output/Karoo_Pricing_Results.html`,
`examples/maxdiff/Output/Karoo_MaxDiff_Results.html`,
`examples/tabs/demo_survey/Output/Demo_CX_Crosstabs.html`,
`examples/integrated_demo/Output/tabs/report/Karoo_Conjoint_Results_simulator.html`):
run `turas_minify()` on a scratch copy, append a probe script to both files,
render each with
`--headless=new --disable-gpu --no-sandbox --virtual-time-budget=8000 --enable-logging=stderr --v=0 --dump-dom`,
and assert: no `.fatal`, zero console lines matching `Error|Uncaught`, and for
the v2 report `TR.MICRO.n` and `Object.keys(TR.AGG).length` equal between dev
and production on `#tab=crosstabs&q=Q001`, plus the `td` texts under `#app`
identical. Extract cells from the dumped DOM after stripping script blocks,
otherwise the dev bundle's template strings match. For the legacy reports the
probe must also evaluate every unique inline handler name (regex
`on(click|change|input)="([A-Za-z_$][\w$]*)\(` over the HTML) as
`typeof window[name]` and report any that is not `"function"`.
`docs/disclosure/experiments/build_variants.py` shows the probe and the
cell-extraction that worked this session.

1c. Close the silent fallback. In `turas_minify()`, when
`TURAS_PREPARE_DELIVERABLE` is set or a new `deliverable = TRUE` argument is
passed, a failed obfuscation or a failed encoding is a TRS refusal
(`CALC_MINIFY_OBFUSCATE_FAILED`), not a warning. Raise
`.MINIFY_TOOL_TIMEOUT_SECS` to 180. Console output on refusal, boxed, as
CLAUDE.md requires. Test: stub the obfuscator path to a script that exits 1 and
assert the refusal.

## Stage 2. The obfuscator profile

Replace `.MINIFY_OBFUSCATOR_CONFIG_JSON` with the contents of
`docs/disclosure/experiments/obfuscator_profile_p1.json`. Keep
`renameGlobals`, `renameProperties`, `selfDefending`, `controlFlowFlattening`
and `deadCodeInjection` false. Update the comment block above it: the reason
`renameGlobals` stays false is the legacy inline handlers, and the reason
`renameProperties` stays false is that the renderer reads island keys directly.

Run stage 1 gates. Expected from this session's measurements: parity 25/25,
every render `OK`, cells identical, obfuscated JS around 1.38 MB for the demo.
If any legacy report fails the handler probe, do not weaken the profile
globally; find which option broke it and report before choosing.

## Stage 3. Island encoding

3a. Template. In `modules/tabs/lib/html_report_v2/assets/template.html`, add
`data-island="v2"` to the nine `data-*` islands. Not to `user-state`.

3b. Decoder. In `24_shell.js` replace `parseIsland()` with the thirteen-line
version in `docs/disclosure/experiments/build_variants.py` (the `DECODER`
string): if the element carries `data-k`, `atob`, XOR with the generator
`x = (1664525 * x + 1013904223) % 4294967296`, byte `x >>> 24`, then
`TextDecoder("utf-8")`, then `JSON.parse`. Plain islands parse exactly as
before. Add `TR.shell._decodeIsland` as an exported pure function so a node
test can round-trip it without a DOM.

3c. Encoder. In `turas_minify.R`, a new step 6d after the watermark and before
HTML whitespace reduction: for each `application/json` block whose open tag
contains `data-island="v2"` and whose body is not `null`, encode with the same
generator in R (`x <- (1664525 * x + 1013904223) %% 4294967296`,
`byte <- x %/% 16777216`, XOR via `bitwXor` on the integer bytes of
`charToRaw(enc2utf8(body))`, base64 via `jsonlite::base64_enc`), and rewrite
the open tag with `data-k="<seed>"`. One seed per build, from
`sample.int(2^31 - 1, 1)`. Both `jsonlite` and `base64enc` are in `renv.lock`;
use whichever `turas_minify.R` can reach without a new dependency.

3d. Ordering with the release audit. The audit (step 10b, from the other
session) must run on the HTML before 6d, or on a copy taken before 6d, and its
result gains `islands_encoded`. Check its `release_island_body()` regex still
finds `data-micro` when the open tag has extra attributes.

3e. Tests. R: encode then decode in R equals the input, on ASCII, on UTF-8
with a verbatim containing an em dash and an emoji, and on a body that
contains `</script` escaped as `<`. Node: the same fixtures through
`TR.shell._decodeIsland`. Cross: an island encoded by R decodes in node to the
identical string. Integration: after `turas_minify()` on the Karoo demo, every
`data-island="v2"` block with content fails `jsonlite::fromJSON`, and the
render gate (1b) still passes with `micro=600`.

3f. Check `modules/tabs/lib/qual_report.R` (`build_qual_report_v2`). If it
inlines through the v2 template it is covered; if it has its own template,
either mark its islands and confirm its runtime uses `parseIsland`, or leave
it plain and say so in the manifest.

3g. Delivery manifest line. In `tabs_delivery_manifest()` add one line:
whether islands are encoded in the deliverable, and the sentence "Encoding
stops reading and grepping. It does not stop a developer."

## Stage 4. Module stripping

4a. `bundle_report_v2_js()` gains an `exclude` argument. `build_report_v2_html()`
computes it: `27x_conjoint.js` when `cj_json` is null, `27y_maxdiff.js` when
`md_json` is null, `27z_pricing.js` when `pr_json` is null,
`27q_qualitative.js` when `qual_json` is null, and `31_selftest.js` whenever
`TURAS_PREPARE_DELIVERABLE` is set. The text-manifest check tolerates this
(`validate_report_text` uses `setdiff(keys_used, names(manifest))`); expect
"authored but never rendered" notes, not refusals, and confirm that.

4b. Boot assertion. In `shell.boot()` after the islands parse: for each of
`[TR.CJ, TR.conjoint]`, `[TR.MD, TR.maxdiff]`, `[TR.PR, TR.pricing]`,
`[TR.QUAL, TR.qual]`, a non-null island with a missing renderer calls
`fatal([{ code: "IO_RENDERER_MISSING", message: ... }])`. Node test with a
sandbox that has an island and no renderer.

4c. R assertion in `build_report_v2_html()` mirroring 4b before the template
fill, refusing with `CFG_REPORT_V2_RENDERER_MISSING`.

4d. Manifest line listing the renderers included and excluded.

4e. Render gate on the integrated demo (all three contribution islands present)
and on a tabs-only config (all three absent). The tabs-only case is the one
that exercises stripping; `examples/tabs/demo_survey` is a v1 report, so build
a v2 one from the parity fixture project or the integrated demo with the
contribution islands removed.

## Stage 5. The default

Duncan decided yes to all five design decisions on 4 September 2026, so every
stage in this file is in scope, this one included. In every
`run_*_gui.R`, `checkboxInput("prepare_deliverable", ..., value = <tools found>)`
where the value is `nzchar(.minify_find_tool("javascript-obfuscator"))` computed
once at GUI start. Eleven files. Say in the label that the dev copy is kept.

## Done means

- Every stage-1 gate green, counts quoted from the run.
- `test_turas_minify.R` and the full node suite green, counts quoted, before
  and after.
- The Karoo demo through the real `turas_prepare_deliverable()` path: the
  release audit prints, the manifest prints, the production file renders,
  `python3 -c "import json,re; ..."` on `data-micro` fails, and the forbidden
  strings including `fable` and `prototype` count zero.
- A note in `docs/disclosure/` with the before and after byte counts and the
  survivor table re-measured on your build.
- Nothing under `OneDrive*/TurasProjects` touched. Duncan regenerates real
  reports through `launch_turas()` himself.
- Commit on the branch, no merge, no push. Say plainly what is committed.

## Do not

- Do not enable `controlFlowFlattening`, `deadCodeInjection`, `selfDefending`,
  `renameProperties`, `numbersToExpressions`, `debugProtection` or `domainLock`.
- Do not put em dashes in any string that reaches the console, the manifest or
  a report.
- Do not amend or rebase the other session's commits.
- Do not weaken a gate to get past a failure. Report the failure.
