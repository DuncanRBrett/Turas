# Which simulators ship readable, and why

Written 4 September 2026, answering Duncan's question: does the MaxDiff
simulator `srcdoc` problem also apply to conjoint and pricing? Read
`HANDOVER_maxdiff_simulator_srcdoc.md` first. This note corrects one claim in
it and adds three wiring gaps found while checking.

The audit below was measured on `main` at `ca27c506`. Duncan then said to fix
both, and the work is on `fix/simulator-minify-coverage`. What shipped differs
from the recommendation at the end of this note: see "What was built, and where
it moved to".

## The literal answer

No. The `srcdoc` mechanism is maxdiff's alone. `grep` over every `.R`, `.js`,
`.py` and `.md` file finds `srcdoc` written at build time in exactly one place,
`modules/maxdiff/lib/html_report/03_page_builder.R:345`. Conjoint and pricing
each produce a standalone simulator file that the v2 report links to, which is
programme decision D2, recorded in the header comment of both
`99_simulator_main.R` files. Nothing is embedded, so nothing is hidden from the
minifier.

## The claim in the handover that needs correcting

The handover says the `srcdoc` is "the piece the profile does not reach". It is
not the only one. Three deliverables ship readable, by three different routes.

| What ships | Minified? | Why |
|---|---|---|
| maxdiff report, `Generate_HTML_Report = Y` | report yes, simulator no | the `srcdoc` hole the handover describes |
| maxdiff standalone `_simulator.html`, `Generate_HTML_Report` off | no | written at `modules/maxdiff/R/00_main.R:1343`, never passed to `turas_prepare_deliverable()` |
| conjoint standalone `_simulator.html` | no | no call site anywhere in the module |
| pricing standalone `_simulator.html` | yes | `modules/pricing/R/00_main.R:685-686` |
| brand report | no | no call site anywhere in the module |

The maxdiff two are exclusive: `00_main.R:1340-1344` embeds the simulator when
the HTML report is on and writes the standalone file when it is off. Either
branch leaves the simulator readable.

## The conjoint and brand checkboxes promise something they do not do

Both GUIs offer "Prepare client deliverable (minify for delivery, dev copy
kept)": `run_conjoint_gui.R:207` and `run_brand_gui.R:267`. Both set
`TURAS_PREPARE_DELIVERABLE` and source the three minifier files. Neither module
then calls `turas_prepare_deliverable()` or `turas_minify()` anywhere.

`turas_deliverable_default()` in `modules/shared/lib/gui_theme.R:252` returns
TRUE when `javascript-obfuscator` is on the PATH, and it is on this machine, so
both boxes have been showing ticked while doing nothing.

Conjoint's call site is not missing by oversight. It was deleted with the
module's HTML report in `fc27160a` on 27 August 2026 and never re-pointed at
the simulator that survived the retirement. The brand gap is present on `main`
and also on the unmerged `feature/brand-v2-lift` branch at `f75ef18e`.

## The machinery already works on all three simulators

Measured, not inferred. Each of the three example simulators was copied to a
scratch directory and run through `turas_minify(deliverable = TRUE)`:

    pricing    status=PASS  js_blocks=2  obfuscated=2   41,533 -> 69,180 bytes
    conjoint   status=PASS  js_blocks=2  obfuscated=2  107,643 -> 185,046 bytes
    maxdiff    status=PASS  js_blocks=6  obfuscated=6  1,025,320 -> 1,267,201 bytes

Internal function names go: in the pricing simulator `interpolateIntent` falls
from 7 occurrences to 0, `renderComparisonTable` from 6 to 0, `calcRevenue`
from 5 to 0.

## What "obfuscated" actually protects

The public API names survive, because the obfuscator does not rename object
properties. `PricingSimulator`, `SimEngine`, `SimUI`, `SimCharts` and
`TurasPins` remain, and so do their method names: `computeShares`,
`headToHead`, `turfReach`, `turfOptimize`, `getTopK`, `TurasPins.move`.

That is not a defect, it is load-bearing. The maxdiff simulator builds pin
buttons at runtime carrying `onclick="TurasPins.move(...)"`, so those names
have to survive or the buttons break. The handover's "grep finds none of the
simulator's function names" is achievable for the internals only, which is the
same bar every other Turas deliverable meets.

## The srcdoc job is smaller than the handover thinks

The handover plans to unescape the `srcdoc`, minify the inner document, and
re-escape, and says the bulk of the work is factoring a string-level entry
point out of the 1,600-line `turas_minify()`. There is a shape that avoids all
of that: minify the simulator as a file before it is ever escaped.

`build_simulator_html_string()` and `generate_maxdiff_html_simulator()` in
`99_simulator_main.R` both call `build_simulator_page()` with the same inputs,
so the string embedded in the report and the standalone file are the same
document. Write the string to a temp file, run `turas_minify()`, read it back,
then escape and embed exactly as today. No unescaping, no round trip to get
wrong, no refactor.

Four of the handover's worries were tested against that shape and none of them
held:

The islands survive. `sim-data` and `pinned-views-data` carry no
`data-island="v2"` marker, so the encoder skips them. Their contents are
byte-identical before and after minification, checked directly.

The escaping holds. The minified document was escaped with the builder's own
two `gsub()` calls, spliced into an `srcdoc` iframe, and rendered.

The render gate can see in, as the handover said. A probe in the top document
reached `iframe.contentDocument` in both the plain and the minified page and
returned identical readings: 8 inner scripts, 744 body elements, the same
title, `SimEngine`, `SimUI`, `SimCharts`, `SimExport` and `TurasPins` all
present, all five `TurasPins` methods resolving as functions, both engines'
public key lists unchanged, zero console errors.

The cost is size. The embedded part grows from 1,215,649 to 1,439,009 bytes,
about 18 percent, which is the obfuscation overhead the hardening release
already accepted elsewhere.

## What was not tested

Two things, and they are the first two steps of the job rather than reasons to
doubt it.

The document tested did not carry the `sim_hide_injection` that
`03_page_builder.R:326-341` splices in before `</head>`. That injection is a
small block of CSS and a `setTimeout` click, and it can be added after
minification, but it was not part of what rendered.

The full outer maxdiff report carrying a minified inner simulator was never
built and never put through `turas_minify()` and the render gate. Only the
inner document and a hand-built iframe wrapper were.

## What was built, and where it moved to

Duncan approved both jobs on 4 September 2026. The wiring fixes landed as
described. The `srcdoc` job did not: it moved out of maxdiff and into
`turas_minify()` itself, for a reason the audit above could not have seen.

### The wiring fixes

Three call sites, each mirroring `pricing/R/00_main.R`:

- `modules/conjoint/R/00_main.R`, after a PASS from the simulator builder.
- `modules/maxdiff/R/00_main.R`, in the `else` branch that writes the
  standalone simulator when the HTML report is off.
- `modules/brand/run_brand_gui.R`, after `generate_brand_html_report()`
  returns PASS. That is the only place brand generates its report.

`modules/shared/tests/testthat/test_deliverable_wiring.R` is the gate. Its
first test walks every module, finds the ones whose GUI offers the checkbox,
and fails on any that never call `turas_prepare_deliverable()` or
`turas_minify()`. It reports 11 offering and 11 acting. Removing the conjoint
call was tried and the gate failed, so the gate can fail.

### The srcdoc job, and why it moved

The plan in this note was to harden the simulator string in
`modules/maxdiff/R/00_main.R` before the page builder escapes it. That was
built and it worked: a full pipeline run wrote the report and the deliverable,
and no simulator function name survived in either.

In either. That is the problem. The hardening ran while the report was being
written, so the `_dev` copy got the obfuscated simulator too. "Prepare client
deliverable (minify for delivery, dev copy kept)" promises a readable
development build, and that is the file someone opens when a nine-minute run
produces a report that misbehaves.

The failure path was worse. An inner obfuscation failure printed its box, kept
the readable simulator and returned, and the outer build then succeeded and
wrote a hardened report with a readable simulator inside it. That is the hole
this job exists to close, reopened on the error branch.

So the step moved into `turas_minify()` as step 2b, `.minify_harden_srcdoc()`.
It runs on the deliverable path only, finds every `srcdoc="..."`, unescapes it,
puts the document through `turas_minify()` again, and splices the re-escaped
result back. maxdiff is untouched by it.

The round trip the handover worried about is exact, and now has a test. `&` to
`&amp;` then `"` to `&quot;`, reversed the other way round. An `&quot;` already
in the source becomes `&amp;quot;`, which contains no `&quot;` substring, so
the first reverse pass cannot touch it. Checked byte for byte against the real
report's 1,375,996-character attribute before anything was changed.

The recursion needs no depth guard: an embedded document has no `srcdoc` of its
own, so the step is a no-op one level down.

`.minify_srcdoc_ranges()` is now one function used by both the block extractor,
which skips those script tags, and the hardener, which processes them. They
cannot drift apart into a block that is both skipped and unprotected.

One thing had to change alongside it. A report whose only JavaScript lives
inside a `srcdoc` has no block of its own to obfuscate, so `obfuscation_applied`
stayed FALSE and verification applied its strict "must be smaller" rule to a
file obfuscation had just made 18 percent bigger. The verification call now
also asks whether the embedded document was obfuscated.

### One thing observed and not fixed

The maxdiff deliverable build warns "HTML whitespace reduction skipped (tool
failed or result larger)". It is not caused by this change: running `main`'s
`turas_minify()` and this branch's over the same report gives the identical
single warning and the identical PARTIAL status. html-minifier-terser exits 1
on the string the pipeline hands it at step 7, though the same tool exits 0 on
the same report read from disk, so the cause is something the earlier steps
produce. Left alone deliberately. The deliverable is written either way and
only loses whitespace collapsing.

### What was run

- `test_turas_minify.R`: 299 pass, 0 fail, 2 warnings. On `main` the same file
  is 278 pass, 0 fail, and the same 2 warnings, so they are pre-existing.
- `test_minify_render_gate.R`: 132 pass, 0 fail, 0 skip. Section 3 is new: it
  builds the wrapper the way the page builder does, runs the deliverable
  build, and reads the result from inside the iframe.
- `test_deliverable_wiring.R`: 5 pass, 0 fail.
- The maxdiff pipeline, end to end on `examples/maxdiff`, with the deliverable
  flag set. Nine minutes, run status PASS. The proof is the two files side by
  side: `updateShares` appears 5 times in `Karoo_MaxDiff_Results_dev.html` and
  0 times in `Karoo_MaxDiff_Results.html`, and the same for `buildH2HSVG`,
  `buildTurfSVG` and `buildSegmentExcelData`. `TurasPins` survives in both,
  because it must. `examples/maxdiff/Output` was restored from its snapshot
  afterwards, so nothing in the repo changed.
- `modules/shared/tests/testthat` as a directory: 1,964 pass, 0 fail, 5 skips,
  all pre-existing.

## How to reproduce

The probe scripts and their outputs were written to the session scratchpad and
are not committed. The method: copy the three files from
`examples/integrated_demo/Output/tabs/report/`, source
`turas_minify_verify.R`, `turas_minify_watermark.R` and `turas_minify.R` from
`modules/shared/lib`, call `turas_minify(path, deliverable = TRUE)`, then
render with headless Chrome using the same flags `.render_probe()` uses in
`modules/shared/tests/testthat/test_minify_render_gate.R:148-153`.
