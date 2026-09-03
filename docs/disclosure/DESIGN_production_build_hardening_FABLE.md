# Production build hardening: first look and design

Fable 5.1, 4 September 2026. Answers `BRIEF_FOR_FABLE_production_build_hardening.md`
and Duncan's addition of the same night: size does not matter, IP protection does,
and if the data island ships it must be hard to get at.

Every number below was measured this session on a copy of
`examples/integrated_demo/Output/tabs/report/Karoo_Demo_Crosstabs_report.html`
(1,255,689 bytes, built 3 September) in the session scratchpad. No repo file was
changed. The experiment scripts and the proposed obfuscator profile are in
`docs/disclosure/experiments/` so the numbers can be re-run.

The implementation brief for Opus is `HANDOVER_BUILD_HARDENING_FOR_OPUS.md`
beside this file.

---

## 0. A concurrent session is already building the respondent-protection half

While this was being written, another session in this same checkout wrote,
uncommitted, between 00:30 and 00:40 on 4 September:

- `modules/tabs/lib/delivery_manifest.R` plus its test, wired into
  `run_crosstabs.R` (line 213 sources it, line 1202 prints it on every build).
- `modules/shared/lib/turas_release_audit.R`, wired into `import_all.R` and
  into `turas_minify()` as step 10b with a new `client_safe` parameter. It
  refuses with `CFG_CLIENT_SAFE_VIOLATED` when a client-safe build still carries
  `data-micro`, and reports a short forbidden-string list.
- `32_report.js`: `saveCopy()` now confirms before writing a copy that carries
  microdata, and the toast no longer says "send it to anyone".
- `21d_disclosure.js`: `audienceBase()` falls back to the published total when
  microdata is absent, so a confidential ship keeps its comments.

That is steps 1 to 4 of the first-look's recommended order. This design is the
IP half and builds on it. Two consequences for sequencing: the hardening work
must not edit `turas_minify.R` or the release audit until that session commits,
and the release audit has to run before island encoding, because once the
islands are encoded it can no longer read `"n":` out of `data-micro`.

---

## 1. Five measured facts that reshape the brief

### 1.1 Top-level mangling is a no-op on the v2 report

All 43 files in `modules/tabs/lib/html_report_v2/assets/js/` are IIFEs closing
with `})(typeof window !== "undefined" ? window : globalThis);`. There are zero
top-level `function`, `var`, `let` or `const` declarations in the bundle.
Terser with `toplevel=false` and `toplevel=true` produced byte-identical output,
437,261 bytes each, from the 1,043,620-byte bundle.

So question 2 of the brief has a plain answer: the lever the brief called the
biggest single readability win does nothing for the tabs v2 report, and it
would break the legacy reports that still carry inline handlers (829 `onclick=`
in `Demo_CX_Crosstabs.html`, 84 in the maxdiff report, 59 in pricing, 12 in the
maxdiff simulator, 10 in the conjoint simulator). Leave `toplevel=false` and
`renameGlobals=false` globally. No per-report-type configuration is needed.

### 1.2 What is readable today is property names and one string in five

Terser already mangles every local inside the IIFEs. What survives the current
pipeline is the property names the modules hang off `TR` (`TR.shell.renderTab`,
`e.state.activeQ`) and the 20 percent of string literals that
`stringArrayThreshold: 0.8` leaves alone. The obfuscator rewrites dotted access
as string-array lookups, which is why the current build already removes most
names; the remainder is the threshold.

Profile P1 (`experiments/obfuscator_profile_p1.json`) closes that. It keeps
`renameGlobals`, `renameProperties` and `selfDefending` false and adds:
threshold 1.0, string-array rotate, index shift, two function wrappers with
chained calls, calls transform at 0.5, split strings at 12 characters,
`transformObjectKeys`, `simplify`, and the mangled-shuffled name generator.

Surviving identifiers in the obfuscated JS, current config (p0) against P1:

| identifier | p0 | P1 |
|---|---|---|
| `zPrimary` | 1 | 0 |
| `coverFindings` | 1 | 0 |
| `renderTab` | 4 | 0 |
| `encodeHash` | 2 | 0 |
| `activeQ` | 8 | 1 |
| `isWeighted`, `saveCopy`, `audienceBase`, `selftest` | 0 | 0 |
| `TR.` in the whole HTML | 1,855 in dev | 0 |

Cost of P1 against p0, same terser input:

| | p0 | P1 |
|---|---|---|
| obfuscated JS bytes | 981,779 | 1,379,487 |
| obfuscation wall time | 2.3 s | 3.3 s |
| whole report bytes | 1,194,258 | 1,591,966 |
| parity suite wall time in node, 25 tests | 0.13 s (terser only) | 0.19 s |
| boot probe in headless Chrome, crosstabs tab | 2,587 ms | 2,600 ms |

The boot probe includes a fixed 2,500 ms settle, so the engine cost of P1 is
tens of milliseconds. Duncan has said size is not a concern.

### 1.3 Control-flow flattening and dead-code injection buy nothing measurable

P2 is P1 plus `controlFlowFlattening` at 0.3: 1,717,457 bytes, 4.4 s, parity
suite 0.20 s, boot probe 2,613 ms. P3 is P1 plus `deadCodeInjection` at 0.2:
1,643,644 bytes, 4.8 s. Both passed every check below. Neither reduced any
survivor count, because P1 already reaches zero on everything measured.

Scoping flattening to the statistics files is not coherent. The build inlines
one script block and the obfuscator selects by file, not by function (its
per-function controls belong to the paid VM options). So flattening is all or
nothing, its only value is against someone reading control structure rather
than names, and it is the transform most likely to surface an edge case in a
statistics engine three years from now. Recommendation: not in this release.

### 1.4 Nothing broke, at three levels

Rendered in headless Chrome with a probe script that reports the fatal panel,
the element and cell counts under `#app`, and whether `TR.MICRO` and `TR.AGG`
loaded. Every variant (dev, p0, P1, P2, P1 with encoded islands) returned
`OK`, 612 elements, 102 cells, `micro=600`, `agg=7`, zero console errors.

The 101 rendered cell texts on the crosstabs tab for Q001 were identical between
the dev build and every hardened variant.

The cross-engine parity suite (`parity_stats_tests.mjs`, 25 tests) was re-run
against a single-file bundle of its eleven engine modules after terser, after
P1 and after P2: 25 passed, 0 failed, each time. The loader variant is
`experiments/parity_bundle_tests.mjs` and takes the bundle path in `BUNDLE`.
This is the cheap automatic numerical gate the brief asked for.

### 1.5 The data island can be made hard to read with about thirty lines

Prototype: each non-null `application/json` island is UTF-8 encoded, XORed
against a keystream from a linear congruential generator seeded by a per-build
integer carried in a `data-k` attribute, and base64 encoded. `parseIsland()` in
`24_shell.js` gained thirteen lines: if `data-k` is present, `atob`, XOR with the
same generator, `TextDecoder`, then `JSON.parse` as before. The generator uses
only multiply-add-modulo below 2^53, so R and JavaScript produce the same bytes
without any bit operations.

Result on the demo, all nine islands encoded: renders identically (see 1.4),
the first-look's twenty-line reconstruction fails at `json.loads`, and label
greps drop to zero (`KwaZulu` 2 to 0, `Strongly agree` 4 to 0). Cost is 40 KB.
`html-minifier-terser` leaves the encoded islands intact (re-rendered after it,
same probe, still not JSON-parseable).

The honest limit: the key is in the file, and a developer who reads the
decoder undoes it in an hour. It defeats View Source, grep, pasting the file
into an AI tool, and the script that triggered this work. That is the brief's
stated goal, copying made expensive rather than impossible.

---

## 2. Answers to the brief's five questions

**Q1, how far to push obfuscation.** Revised ordering by value per unit of
risk: (1) `stringArrayThreshold` 1.0 with rotate, shift and wrappers, (2)
`stringArrayCallsTransform` at 0.5, (3) `splitStrings` at 12, (4)
`transformObjectKeys`, (5) `simplify` plus mangled-shuffled names. Those five
are P1 and they are where to stop. Not `controlFlowFlattening`, not
`deadCodeInjection` (1.3), not `selfDefending` (agreed), not
`renameProperties` (the renderer reads JSON keys such as `q.code` and
`col.base` straight off the islands, and a renamed accessor against an
unrenamed key is a silent null), not `numbersToExpressions` (it rewrites the
constants in a statistics engine for no readability gain), and not
`debugProtection` or `domainLock` (a file that must open offline in 2029).

**Q2, per-report-type mangling.** Moot, see 1.1. One profile for every module.

**Q3, flattening a one-megabyte bundle.** Cost is small, scoping is incoherent,
gain is unmeasurable against P1. Skip.

**Q4, module stripping.** Sound and worth doing, second. The bundler
(`bundle_report_v2_js()`) reads every file in `assets/js`; the build already
knows which islands it produced. Drop `27x_conjoint.js` when `cj_json` is null,
`27y_maxdiff.js` when `md_json` is null, `27z_pricing.js` when `pr_json` is
null, `27q_qualitative.js` when `qual_json` is null, and `31_selftest.js` in
every deliverable build. That is 213,365 source bytes before minification. The
shell already guards each of these namespaces (`TR.conjoint && ...` at
`24_shell.js:31`, `TR.qual &&` in `25_cards.js` and `30_story.js`,
`TR.selftest2` at `24_shell.js:110`), and the text-manifest check is
`setdiff(keys_used, names(manifest))`, so fewer keys used cannot refuse a build.

The failure mode the brief worried about, a silently dead tab, is closed by
making it loud: `shell.boot()` asserts that every non-null island has its
renderer (`TR.CJ` needs `TR.conjoint`, and so on) and calls `fatal()` with
`IO_RENDERER_MISSING` otherwise. The R side asserts the same before writing,
and the delivery manifest gains a line listing the renderers included.

**Q5, the gate.** Five checks, all automatic, all runnable from one testthat
file and one node command:

1. `test_turas_minify.R` keeps its unit coverage and gains a fixture-level
   test that a marked island round-trips through encode and decode in R.
2. The parity suite against the production bundle (1.4), added as a node test
   that builds the bundle through the real `turas_minify()` and loads it.
3. A headless Chrome render of the Karoo demo, dev against production, on the
   crosstabs, tracking and reader tabs at minimum: probe must be `OK`, micro and
   agg present, console error count zero, and the `#app` cell texts identical.
   Skipped with a visible note when Chrome is absent.
4. The release audit on the production file: every forbidden pattern zero, and
   every marked island fails a plain `JSON.parse`.
5. For every legacy report in `examples/` with inline handlers, a headless
   render with a probe that evaluates `typeof window.<name>` for each unique
   handler name and reports any that is not `"function"`. The existing
   `.verify_js_handler_functions()` is skipped when obfuscated, so today nothing
   checks this.

One trap to close in the same change: `.minify_obfuscate_js_block()` returns
`success = FALSE` on any tool failure, including the 60-second
`.MINIFY_TOOL_TIMEOUT_SECS`, and `turas_minify()` then keeps the plain minified
JS with a warning and a `PARTIAL` status. The file still ships. In a deliverable
build that must be a refusal, and the timeout should rise to 180 seconds; P1
took 3.3 seconds on the demo, but a report with a large qualitative island will
take longer.

---

## 3. The data island: design

Where the pieces live:

- Encoder in `turas_minify()`, as a new step between watermark injection and
  HTML whitespace reduction, applied only to `application/json` islands whose
  open tag carries `data-island="v2"`. The tabs v2 template adds that attribute
  to its nine islands. Other modules' islands (`pr-insight-config-data`,
  `sim-data`, `pinned-views-data`) are untouched because their readers do not
  decode.
- Decoder in `parseIsland()` (`24_shell.js`). Dev builds stay plain JSON, so an
  analyst can still read a working copy's islands and the node suites keep
  loading fixture JSON directly.
- The seed is a fresh integer per build, written to `data-k` on each island.
  Encoding is UTF-8 bytes, XOR with the generator's high byte, base64.
- `user-state` is left plain. `saveCopy()` writes it in the browser and it holds
  the analyst's insights and pins, not respondent records. The clone carries the
  other islands still encoded.
- The release audit runs on the minified HTML before encoding and records
  `islands_encoded = TRUE` in its result. After encoding the same audit would
  report the micro island absent, which is the wrong answer.
- The Reader report has its own `data-reader` island and its own runtime
  (`modules/tabs/lib/reader_report/`). It carries the derived narrative model,
  not respondents. Same treatment in a second pass; not blocking.
- Whether `build_qual_report_v2()` (`qual_report.R`) inlines through the v2
  template was not checked this session. Opus checks it before marking islands.

What it defeats and what it does not, stated in the delivery manifest so the
operator reads it every build: it stops reading and grepping, it does not stop
a developer.

---

## 4. Decisions for Duncan

Duncan said yes to all five on 4 September 2026. They are decided, not open.

1. Default the "Prepare client deliverable" checkbox to on when the node tools
   are found. All eleven GUIs default it to false today
   (`grep -n prepare_deliverable modules/*/run_*_gui.R`), and that default is
   why a dev build reached ChatGPT. The dev copy is kept either way.
   Recommendation: yes.
2. Island encoding in this release. Recommendation: yes, it is the one change
   that answers "if the whole data island is there, make it hard to access".
3. Control-flow flattening. Recommendation: no, see 1.3.
4. Module stripping in this release or the next. Recommendation: this one,
   sequenced last, because the boot assertion that makes it safe is small.
5. Ship P1 to every module's deliverable, or tabs v2 only. Recommendation:
   every module, because the pipeline is shared and a split config is a
   second thing to maintain; the gate's legacy-render check (2, item 5) is
   what makes that safe.

---

## 5. Not done or not verified this session

- The prototype bypassed the R pipeline. Terser, the obfuscator and
  html-minifier-terser were run directly; the R comment stripper, meta stripper
  and watermark were not. The one "fable prototype" string that survived is the
  template's HTML comment, which the R pipeline removes. The words `fable` and
  `prototype` belong on the release audit's list regardless.
- No legacy report (pricing, maxdiff, conjoint, brand, segment, tracker) was
  rendered under P1. `transformObjectKeys` and calls transform are new to those
  files. This is gate item 5 and it must run before the profile ships.
- Runtime under P1 was measured on boot and on the parity suite, not on a heavy
  live-filter recompute on a large study.
- `test_turas_minify.R` was not run this session, because the other session is
  editing `turas_minify.R` at this minute.
- The concurrent session's work is uncommitted and was read, not tested.
