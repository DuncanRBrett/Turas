# Build note: production build hardening

Opus 5 session, 4 September 2026, on `feature/build-hardening` off `main` at
`6af68c0c`. Implements `HANDOVER_BUILD_HARDENING_FOR_OPUS.md` and the design in
`DESIGN_production_build_hardening_FABLE.md`, all five of whose decisions Duncan
approved on 4 September.

Two commits: `0444b421` (the gates and the deliverable default) and `92cbbc5a`
(the profile, island encoding, module stripping). Nothing merged, nothing
pushed, nothing under `OneDrive*/TurasProjects` touched.

Every number here was produced by a command in this session. Where the design's
measurements and mine differ, mine were taken on the current template, which has
gained the aggregate cube and pricing islands since the design was written.

---

## 1. The answer to the question Duncan asked first

The aggregate cube goes in as a JSON island like the others, and it passes
through the deliverable build intact. Confirmed rather than assumed:

- `data-cube` already carried the `data-island="v2"` marker, added by the cube
  session. It was inert until this work: nothing read it.
- A cube-bearing report renders identically before and after a deliverable
  build, cell text for cell text, with `TR.CUBE` carrying the same key count in
  both. That is one of the four modes the render gate runs on every invocation,
  and it is a permanent gate, not a one-off check.
- On the gate fixture the cube island is one of the three that get encoded.

The cube mode is now the case the gate exercises hardest, because a cube that
decodes but recomputes wrong is the failure that would not announce itself.

---

## 2. What a deliverable contains now

Measured on the render gate's four fixtures, built from the committed parity
islands. Every one of them renders identically to its development build.

| mode | dev | deliverable | islands encoded | contribution renderers |
|---|---|---|---|---|
| records (respondent island) | 1,065 KB | 2,322 KB | 3 | 0 of 4 |
| cube (aggregate cube) | 1,072 KB | 2,332 KB | 3 | 0 of 4 |
| plain (published only) | 1,057 KB | 2,312 KB | 2 | 0 of 4 |
| contrib (all four islands) | 1,281 KB | 2,884 KB | 7 | 4 of 4 |

Those deliverable sizes were measured before `splitStrings` came out; they are
now about 385 KB lower each. The dev column, the encoding and the renderer
counts are unchanged.

Readable identifiers on the Karoo integrated demo, development build against
deliverable:

| string | dev | deliverable |
|---|---|---|
| `TR.` | 1,881 | 0 |
| `renderTab` | 17 | 0 |
| `encodeHash` | 6 | 0 |
| `zPrimary` | 8 | 0 |
| `coverFindings` | 4 | 0 |
| `isWeighted` | 3 | 0 |
| `activeQ` | 46 | 1 |
| `/**` block comments | 622 | 0 |
| `review 2026-` | 27 | 0 |
| `node-testable` | 10 | 0 |
| `unit-tested` | 5 | 0 |
| `fable` | 2 | 0 |
| `prototype` | 21 | 0 |

`fable` and `prototype` were on the list because the design's prototype left
them in a template comment. The R pipeline removes them, as it was expected to.

That demo file cannot demonstrate island encoding: it was built at 09:03 on
4 September, before `8393a7b0` added the markers to the template, so it carries
none and nothing in it is encoded. The encoding numbers above come from reports
built by the gate fixture on the current template.

### The wrapper Duncan actually uses

`turas_prepare_deliverable()` was run end to end on a records-mode report, with
`TURAS_PREPARE_DELIVERABLE` and `TURAS_CLIENT_NAME` set as the GUI sets them:

    Client deliverable: Karoo_Client_Report.html (115.2% larger)
    Dev copy kept: Karoo_Client_Report_dev.html

The development copy is renamed to `_dev` and kept, the deliverable takes the
clean name, the release audit and the verification box print, the watermark is
applied, `31_selftest.js` is absent from the built file, and `data-micro` no
longer parses as JSON. The old wording printed that size line as
"-115.2% smaller", which is not a sentence anyone should read on a client build;
it now says larger or smaller as the case may be.

### Size

The demo goes from 1,228 KB to 2,375 KB. The old profile produced 1,139 KB, so
this is the one number that moved the wrong way. The driver is the default
`hexadecimal` name generator, which had to replace the design's
`mangled-shuffled` (section 4).

`splitStrings` was dropped on Duncan's instruction on 4 September, which took
this from 2,761 KB to 2,375 KB. It cost 385 KB and changed no survivor count:
with the threshold at 1.0 and base64 encoding, every literal is already hidden
in the string array, so splitting them first added depth nobody could measure.
Both simulators render clean without it.

---

## 3. The gates, which came first on purpose

Three, all automatic, all runnable without arguments.

`modules/tabs/lib/html_report_v2/tests/production_bundle_tests.mjs` concatenates
the eleven parity engine modules, puts them through the settings the pipeline
ships, and re-runs the cross-engine parity assertions against the obfuscated
bundle. 25 assertions against production bytes. Until now the parity suite
proved the engine agreed with R about the *source*; nothing had ever run a
number through what a client opens.

`modules/shared/tests/testthat/test_minify_render_gate.R` renders in headless
Chrome. The v2 report in four modes, development against deliverable: no fatal
panel, no console error the deliverable introduced, the same islands loaded, the
rendered cells identical text for text, the islands encoded in one and plain in
the other, and a saved copy keeping its encoding. Then every legacy report in
`examples/` that carries inline handlers, where an `onclick` that no longer
resolves is a dead button and nothing else would say so. 112 assertions.

`modules/tabs/lib/html_report_v2/tests/island_encoding_tests.mjs` and
`renderer_presence_tests.mjs` pin the two new mechanisms: R encodes a fixture
and the shipped JavaScript decodes it byte for byte, and an island without its
renderer is reported rather than drawn as an empty tab.

The profile and terser arguments the node gates use come from
`modules/shared/lib/minify_profile.json`, a generated mirror of the R constants
with a test binding the two, so the gate cannot drift from what ships.

### Which report runtimes were actually rendered under the new profile

The profile is shared by every module, and it broke two of the six runtimes that
were tested. So this list is the useful part.

Rendered, development build against deliverable, and clean:
the tabs v2 report in all four modes, the v1 tabs report (`Demo_CX_Crosstabs`),
the pricing report, the maxdiff report, and the conjoint, maxdiff and pricing
simulators. `build_qual_report_v2()` inlines through the same v2 template, so the
comment report is covered by the contrib mode.

NOT rendered under the new profile, and each one is a `turas_prepare_deliverable()`
caller: the Reader report, which has its own runtime under
`modules/tabs/lib/reader_report/`, and the brand, segment, tracker, keydriver,
catdriver and confidence reports. No `report_hub` build was made either. There is
no committed example output for any of them, which is why they are not in the
gate; the way to add one is to build an example and add two lines to the gate's
list. Until then they are Duncan's eyeball.

The `report_hub` change (pass `deliverable = TRUE`, catch the refusal) parses but
was never executed, because it lives inside a Shiny observer. The `data-k`
double-encoding guard it depends on is unit tested; a hub built from a hardened
child is Duncan's build.

### Skips

Both Chrome-dependent gates print a visible reason and skip when Chrome or the
node tools are absent. On this machine nothing skipped.

---

## 4. Two settings the design recommended that do not ship

Both were caught by the render gate on legacy reports, which is the check the
design listed as not yet run. Both were bisected with a build-then-render loop,
because at these rates a single sample says nothing.

**`transformObjectKeys` breaks the MaxDiff simulator.** The donut arc came out
as `A 50 50 0 0 1 NaN NaN`, so the chart did not draw.

| variant | builds with the fault |
|---|---|
| development build | 0 of 20 |
| the old profile | 0 of 20 |
| the design's profile | 3 of 20 |
| the design's profile without `transformObjectKeys` | 0 of 34 |

**The mangled name generators break the Conjoint simulator.** `Uncaught
TypeError: Cannot read properties of undefined (reading 'charAt')`.

| generator | conjoint | maxdiff | demo size |
|---|---|---|---|
| `hexadecimal` (default, shipped) | clean | clean | 249 KB / 1,347 KB |
| `mangled` | breaks | breaks | 143 KB / 1,083 KB |
| `mangled-shuffled` (design) | breaks | clean | 143 KB / 1,083 KB |

Short names collide with globals the profile deliberately does not rename.
Neither generator changed a single survivor count, so both bought nothing.

**The seed is now fixed** (`20260904`). Two settings whose safety depended on
which shuffle you happened to get is the argument for it: a gate that tests
different bytes from the ones that ship is not a gate. Three builds of one input
are byte-identical.

`controlFlowFlattening`, `deadCodeInjection`, `selfDefending`,
`renameProperties`, `numbersToExpressions`, `debugProtection` and `domainLock`
remain off, for the reasons in the design.

---

## 5. Defects the gates found on their first runs

**Script tags inside an iframe srcdoc were treated as JavaScript.** The maxdiff
report embeds its whole simulator in an `srcdoc` attribute, HTML-escaped
(`modules/maxdiff/lib/html_report/03_page_builder.R:345`). The block extractor
regex-scans raw HTML, so it matched those escaped `<script>` tags and handed the
attribute text to terser, which rejected it. Eight blocks, five warnings on
every maxdiff build. That report went from 17 extracted blocks to 8, and from
five obfuscation warnings to none. This is the only `srcdoc` in the codebase;
`report_hub` base64-encodes its children, which hides them from the extractor.

**`contents[[i]] <- NULL` deleted the element** and shortened the list, so every
later index stopped matching the block list. Real reports survived only because
their last script block is the JS one and the final real assignment extended the
list back to length. A document whose last script block is a JSON island errored
with a subscript out of bounds. Fixed in all three loops.

**Two example reports log a console error before minification touches them.**
The maxdiff simulator calls `history.replaceState` from inside an opaque
`srcdoc` iframe; the v1 tabs report references `TurasPins` before it loads.
Both are identical in the development build, so neither comes from this work.
The gate compares the deliverable against the development build rather than
against zero, so it catches what minification introduces and does not absolve
what was already there. Worth fixing in those modules; not fixed here.

---

## 6. Open, and needing Duncan's decision

**The MaxDiff simulator still ships readable.** Excluding the srcdoc blocks from
the pipeline was the correct fix and it regresses nothing: those eight blocks
failed terser before this session and are simply untouched now. But it means
about 1.9 MB of simulator JavaScript travels inside the srcdoc attribute
unobfuscated, in the one module whose simulator is the clever part. Hardening it
means unescaping the payload, running the pipeline over a string rather than a
path, deciding what to do with the simulator's own `sim-data` islands,
re-escaping and splicing. That is a feature, not part of the five approved
decisions, and nothing here could verify it: the legacy handler probe evaluates
`typeof window[name]` in the top document, and the simulator's handlers live in
the iframe's window. Recommend it as its own piece of work.

**The VAS integrated report: FIXED, it now takes either build.**
`build_vas_integrated_report.py` on OneDrive anchored on the literal string
`shell.tabGroups = tabGroups` and did `json.loads` on `data-micro` and
`data-agg`. Minification destroys the first, so that pipeline already required a
development build before any of this work; island encoding would have added a
second reason. Duncan asked for it to work on both, so it now does.

Three changes, snapshot first at
`Archive/build_vas_integrated_report.py.before-minified-support-20260904`:

- An island reader that decodes the deliverable's encoding, the same generator
  as the R and JavaScript halves, and returns plain JSON either way.
- The build is detected by the `<!-- Turas Build v -->` tag, which
  `turas_minify()` injects after the whitespace pass and which therefore
  survives. That is a better detector than `data-k`, because a report built
  before the island markers existed and then minified has no `data-k` but is
  still minified.
- The anchor list gained `data-agg`, the app container and the end of document,
  all of which survive minification. The shell source anchor is still checked on
  a working build, where a Turas engine change gets noticed first, and is not
  asked for on a deliverable.

Nothing else needed changing: the patch it injects works entirely through the
rendered DOM and the public `TR.*` runtime API, and the profile renames neither
globals nor properties.

Verified end to end, in a scratch copy of the reporting folder, writing nothing
to OneDrive but the script and its snapshot. The real VAS crosstab report, and a
minified copy of it, each produced a full integrated report: 1,100 respondents,
7 banner variables, 40 of 40 sections, 18 pages. Both rendered in headless
Chrome with no fatal panel, no console errors, the Sections tab injected, Group
overview removed, and the crosstab cell text identical between the two. The
island reader was unit tested on four shapes, including a current-template
deliverable whose islands are actually encoded.

**The deliverable is about 1.9 times the size of the development build.**
Section 2.

---

## 7. Counts, before and after

| suite | before | after |
|---|---|---|
| `test_turas_minify.R` | 234 passed, 0 failed | 278 passed, 0 failed |
| tabs testthat | 5,468 (quoted from `29b5e158`, not measured here) | 5,700 passed, 0 failed, 1 skipped |
| node gate suite | 1,091 passed, 42 files | 1,145 passed, 45 files |
| `test_minify_render_gate.R` | did not exist | 116 passed, 0 failed, 0 skipped |

The tabs "before" figure is quoted from the commit message of `29b5e158`, which
is what the previous session measured. Five cube commits landed after it and this
session did not run the suite before editing, so treat it as context rather than
a baseline. The "after" figure was measured here.

The tabs suite needed five test files updated: they matched the island open tag
as `id="data-cj">` and it now carries `data-island="v2"`.

The render gate covers six legacy reports; a seventh and eighth example output
are byte-identical copies of runtimes already in the list.

---

## 8. What Duncan does next

1. Run a project through `launch_turas()` with the deliverable checkbox on, which
   is now its default, and open four things: the crosstabs deliverable, the
   Reader deliverable, the comment report, and one `report_hub` build. The Reader
   has its own runtime and no gate; the hub path was never executed. This session
   never ran the pipeline on a real config and never wrote to a project folder.
2. Say whether the MaxDiff simulator srcdoc becomes its own piece of work.
3. The next VAS integrated build needs no change from you. It reads whichever
   crosstab report is under the plain filename, minified or not. Worth one run
   to see it for yourself.
