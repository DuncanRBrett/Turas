# First look: respondent protection and IP protection in delivered Turas reports

Opus 5 session, 3 September 2026. Assessment only, no code changed.
Source of the request: two briefs Duncan received from ChatGPT after showing it a
Turas demo report.

Everything below that is stated as fact was read or run in this session. Two
things were executed and are the spine of the assessment.

---

## 1. The two executed facts

### 1.1 A default report can be turned back into a respondent dataset

File: `examples/integrated_demo/Output/tabs/report/Karoo_Demo_Crosstabs_report.html`
(1.20 MB, built 3 Sep 2026, the integrated Karoo demo).

Islands present and their sizes:

| island | size | contents |
|---|---|---|
| `data-agg` | 36,492 chars | published tables, row labels, banner columns |
| `data-micro` | 37,502 chars | `n=600`, 11 question arrays, 4 banner arrays, 600 weights, 1 score array, boxes |
| `data-text` | 18,971 chars | report copy |
| `data-cj` | 3,238 chars | conjoint, aggregate only (utilities, importance, WTP) |
| `data-md` | 4,630 chars | maxdiff, aggregate only (scores, discrimination, turf, anchor) |
| `data-qual`, `data-prev`, `data-verify`, `user-state` | null | not used in this demo |

Using only that HTML file, about twenty lines of Python joined `data-micro`
indices to `data-agg` labels and produced a respondent by question table. First
three rows, verbatim from the run:

```
{"row": 0, "weight": 1, "Region": "KwaZulu-Natal", "Gender": "Female", "Age_Group": "55+",
 "Segment": "Premium", "Q001": "7", "Q002": "9", "Q003": "8", "Q004": "6", "Q005": "7",
 "Q006": "Agree", "Q007": "Strongly agree", "Q008": "Monthly", "Q009": "In store"}
{"row": 1, ... "Region": "Western Cape", "Gender": "Male", "Age_Group": "35 - 44",
 "Segment": "Standard", "Q006": "Strongly disagree", "Q008": "Quarterly", "Q009": "Subscription"}
{"row": 2, ... "Region": "Gauteng", "Gender": "Female", "Age_Group": "35 - 44",
 "Segment": "Standard", "Q006": "Strongly agree", "Q008": "Weekly", "Q009": "Subscription"}
```

ChatGPT's acceptance test is "a competent developer, given only the HTML, must
not be able to reconstruct a respondent by question dataset". A default Turas
build fails that test. This is not a hypothetical.

What the file does NOT contain, by deliberate design
(`modules/tabs/lib/microdata_writer.R`, header): no respondent identifier, no raw
answer strings, no free text. Only zero-based row and column indices plus
weights. That is a real mitigation for direct identifiers, and it is worth saying
out loud in any client conversation. It does not save the acceptance test,
because the labels those indices point at are in `data-agg` in the same file.

### 1.2 The IP brief is roughly 80 percent already built, and was simply not run

`modules/shared/lib/turas_minify.R` (v2.0, April 2026) plus
`turas_minify_verify.R` and `turas_minify_watermark.R`. All five node tools are
installed on this machine (node, terser, cleancss, html-minifier-terser,
javascript-obfuscator).

Ran it on a copy of the demo, watermark "Karoo Coffee Roasters":

```
Input:     1,226 KB   Output: 1,139 KB   Reduction 7.1%
JS blocks: 1 minified, 1 obfuscated      CSS: 1 processed
Watermark: Karoo Coffee Roasters (ID: e44510d4)
Verification: ALL CHECKS PASSED          STATUS: PASS
```

Forbidden-string counts, dev build then minified build:

| string | dev | minified |
|---|---|---|
| `/**` block comments | 613 | 0 |
| `review 2026-` | 27 | 0 |
| `weighting.R` | 4 | 0 |
| `node-testable` | 10 | 0 |
| `unit-tested` | 5 | 0 |
| `TODO` / `FIXME` / `sourceMappingURL` | 0 | 0 |
| `effectiveBase` | 6 | 0 |
| `renderHighlighted` | 5 | 0 |
| `zPrimary` | 8 | 2 |
| `isWeighted` | 3 | 1 |
| `coverFindings` | 4 | 1 |
| `selftest` | 21 | 4 |
| `data-micro` island | present | present |

The four surviving `selftest` hits are three CSS class names and one string
inside the obfuscated array. The surviving identifiers are the handful that stay
public because something references them by name.

So the demo Duncan showed ChatGPT was a development build. The client
deliverable path exists and does most of what the IP brief asks. The gap is that
`run_tabs_gui.R:319` renders "Prepare client deliverable (minify for delivery)"
as a checkbox with `value = FALSE`. It is opt-in, and it was off.

---

## 2. Where ChatGPT is wrong

**"C. FROZEN, existing protected mode."** There is no whole-report frozen mode.
"Frozen" in the codebase means two unrelated things: analysis tabs that do not
recompute (`27z_pricing.js`, `27y_maxdiff.js`) and pinned story cards that hold a
snapshot (`30_story.js`). Nothing freezes a report as a delivery mode.

**"CLIENT_SAFE must be introduced."** It exists. `html_report_v2_microdata = N`
on the Settings sheet ships `TR.MICRO = null` and no respondent records
(`run_crosstabs.R:983`, `test_report_v2_bundler.R:144`). Default is TRUE.
Tracking already survives it: `published_wave_contribution()` builds the current
wave from published figures, merged to local main as `04e1eb19` on 27 Aug 2026.

**"Verbatims must not contain hidden respondent metadata."** The qualitative
layer is ahead of the brief. `qual_island_builder.R` has a three-way text dial
(hidden, redacted, full) where hidden means the text is NA in R and never enters
the file, a direct-identifier PII scrub in redacted mode, k-anonymised
demographic tags computed R-side against `min_reporting_base`, and a
`demographic_cuts = block` setting. `qual_reader_keys.R` mints an opaque
64-bit random token per respondent precisely so a shipped ResponseID cannot join
an anonymous comment back to a named person, and the token sidecar never ships.

**"Encrypt nothing, obfuscate everything."** Fine as principle, but the current
obfuscator config has a specific documented constraint: `renameGlobals` and
`renameProperties` are false because inline `onclick` handlers reference
top-level functions by name. Counted in this session: 829 `onclick=` in
`Demo_CX_Crosstabs.html`, 59 in the pricing report, 0 in the integrated demo
report. So the constraint is real for some report types and possibly stale for
the current v2 tabs report. That is worth checking before touching the config.

---

## 3. Where ChatGPT is right, and where it did not go far enough

Right, and it matters:

- The default is the wrong way round. A file that safe by default is a stronger
  design than a warning that clients must understand.
- Its acceptance test is the correct test, and it should be automated.
- There is no build manifest and no automated pre-release audit.
- Unused analytical runtimes ship regardless of whether their island exists.
  `27x_conjoint.js`, `27y_maxdiff.js`, `27z_pricing.js`, `27q_qualitative.js` (149 KB
  on its own) are concatenated unconditionally.
- The self-test runtime (`31_selftest.js`, 17 KB) ships in client builds.

Three things it did not have.

### 3.1 Every disclosure dial except two is enforced in the browser

`min_reporting_base` is enforced at render time by `21d_disclosure.js`. It hides
sub-k detail on screen. It does nothing about page source. The only controls that
remove data at build time are the qual text mode and the k-anonymised qual tags.

Turas already knows this and warns about it. `run_crosstabs.R:1018-1035` prints a
disclosure warning box saying the k-gate hides cells on screen while the
microdata island still carries them. The problem is the condition: that box only
prints when `min_reporting_base` is set. On a build with k unset, which is the
common case, the full respondent matrix ships and the console says nothing at
all.

### 3.2 Verbatims and the answer matrix share an index space

Read from code, not executed, because the demo has `data-qual` null.

`qual_host_id_to_idx()` (`qual_assemble.R:197`) maps each respondent's ResponseID
to its zero-based survey row index, and that index is the `idx` on every comment
record in `data-qual`. `build_microdata()` (`microdata_writer.R:871`) sets
`n <- nrow(survey_data)` and writes one array position per survey row, in order.
Same index space. In any report carrying both islands, a verbatim joins directly
to that respondent's full answer vector, banner memberships and weight. The
renderer also prints `#idx` on the face of each quote (`27q_qualitative.js:2171`).

For a staff or student climate survey with open ends, that is the disclosure
vector that matters, not the anonymous index in isolation.

This needs an executed demonstration before it is quoted to anyone outside.

### 3.3 Save copy re-exports everything

`32_report.js:501` `report.saveCopy()` clones `document.documentElement`, blanks
`#app`, writes the user state island and downloads the result. Every other
island, `data-micro` included, rides along. The toast reads "Annotated copy
saved. Single file, send it to anyone". The product actively encourages onward
distribution of a file containing the respondent matrix.

### 3.4 Two contextual points

Onward distribution in 2026 includes AI tools. A client pasting a report into
ChatGPT or uploading it to a chat assistant ships the micro island with it. That
is a more likely route than a competitor being handed the file.

Consent wording. Where a survey intro promises that individual responses will not
be shared, a per-respondent matrix in the client's file breaches that promise
even with no direct identifiers in it. The SACS 2026 invite makes exactly that
promise (see the SACS memory note). This is a POPIA and a SAMRA question, not
only an engineering one.

---

## 4. What CLIENT_SAFE actually costs today

`TR.MICRO` is read in fourteen renderer files. Turning it off removes:

- the live filter bar and every filtered recompute (`26_filter.js`, `21_stats.js`)
- custom and composite banners (`28b_banners.js`, `28c_composite.js` paths)
- the Differences tab (`27d_diffs.js`)
- Pattern Recognition / takeout (`27e`, `27f`, `27fa`)
- confidence detail (`21c_confidence.js`)
- disclosure detail panels, which fail closed
- filtered qualitative views (`27q_qualitative.js:209, 2202`)
- the Reader's computed passages (`24a_reader.js`)

Tracking is no longer a cost. That was fixed in August.

So the honest statement is that CLIENT_SAFE today is not a mode with reduced
interactivity. It is a published-figures report. That is a real product
difference, and it is why the default has not been flipped.

---

## 5. The middle path, and its honest limit

ChatGPT's phrase "aggregate sufficient statistics" is the right instinct and
needs to be made specific. Three tiers, in increasing cost:

1. **One filter variable at a time.** Needs question rows by that variable. Those
   are the published crosstabs. Zero extra data.
2. **Two filters combined.** Needs three-way tables, question row by var A by
   var B. Feasible to precompute for a declared filter set.
3. **Arbitrary combinations.** Needs the full joint cube over every filterable
   variable, with per-cell sufficient statistics.

For weighted proportions, weighted means, effective base and both the z and Welch
tests, the per-cell statistics needed are count, sum of weights, sum of squared
weights, sum of x times weight and sum of x squared times weight. That is five
numbers per cell, no respondent rows.

The limit worth being blunt about: a joint cube whose cells contain one person is
microdata in a different shape. The privacy gain comes from suppressing or
collapsing cells below k at build time, not from the format. Any design that
skips the k rule buys nothing.

Second constraint. The "+ Custom" banner lets an analyst build a banner from any
question, which makes the filterable set every question in the study and the
joint cube unbuildable. A CLIENT_SAFE mode has to restrict live filtering to the
declared banner and filter variables. That is a product decision, not a technical
one.

---

## 6. Per-project position

SACS 2026. Duncan already made the rule on 27 August 2026: no individual record
identifiable in the data island, ever, for SACS and every sensitive survey after
it, with loss of on-the-fly filters accepted. The plan is two configs, an
internal build with microdata and a client build with `html_report_v2_microdata = N`,
`qual_demographic_cuts = block`, `qual_confidentiality_mode = redacted` and a
different output filename. Whether the client config on disk currently carries
those settings was NOT verified in this session: the project folders were not
reachable from this checkout.

SACAP student, CCPB CSAT and CCS were judged fine with microdata under the
threat model "the recipient cannot map coded records back to people". That
judgement is recorded in the no-micro-flag note. Onward distribution changes the
threat model from "can this recipient re-identify" to "does the dataset leave the
client's building". Both deserve a re-look under the new model, and CCPB in
particular because it is CATI with a customer base behind it.

---

## 7. Recommended order

Respondent protection first, IP second, which is ChatGPT's ordering and it is
right.

1. Make the delivery mode an explicit choice rather than two independent
   checkboxes that both default to off. One control with three settings, and no
   silent default.
2. Warn on every build that ships microdata, not only when `min_reporting_base`
   is set. This is a small change to the condition at `run_crosstabs.R:1009`.
3. Fix save copy. In a client-safe build it must null the micro island, or the
   button must be off.
4. Build the manifest and the automated audit into the end of `turas_minify()`,
   failing on a populated `data-micro` in a client-safe build and on the
   forbidden-string list. The verification harness (`run_minify_verification`)
   is the natural home.
5. Strip unused runtimes and the self-test at concatenation time in
   `build_report_v2.R`, driven by which islands the build actually produced.
6. The sufficient-statistics cube. This is the real engineering project and the
   only thing that lets CLIENT_SAFE become the default without gutting the
   product.
7. Obfuscation toughening, gated on render plus the numerical regression suite.

## 8. Obfuscation levers, not yet applied

Current config (`turas_minify.R:52`): compact, stringArray on with threshold 0.8,
base64 encoding, shuffle on, control flow flattening off, dead code injection
off, renameGlobals false, renameProperties false, selfDefending false. Terser
runs with `--mangle toplevel=false` and `--no-mangle-props`.

Available, in rough order of value per unit of risk:

- `stringArrayThreshold` 0.8 to 1.0. Cheap, low risk.
- `splitStrings` with a chunk length, and `numbersToExpressions`. Cheap.
- `identifierNamesGenerator: "mangled-shuffled"`. Cheap.
- Terser `--mangle toplevel=true` for report types with no inline handlers. This
  is the biggest single readability win and it is currently blocked globally by
  a constraint that may no longer apply to the v2 tabs report. Worth measuring
  per report type.
- `controlFlowFlattening` at a low threshold. Meaningful protection, real runtime
  cost on a 1 MB bundle, and the one most likely to cause a subtle rendering bug.
  Only worth it if scoped to the engine files.
- `deadCodeInjection`. Adds size for modest gain. Probably not worth it.
- `selfDefending`. Do not. It breaks under any reformatting and makes debugging a
  client-side problem impossible.

Nothing in the config was changed in this session. It affects every Turas
deliverable across every module, so it needs a gate before it moves.

---

# Addendum: what was built, 4 September 2026

Duncan's decisions on the first look: case by case is the policy, most reports
are fine carrying the island, so the work is "no silent default" rather than
"safe by default". SACS must not be identifiable but needs banners by campus or
department or tenure, NOT interlocking. He asked for the disclosure fix and the
week-one set.

Nothing is committed. This checkout also holds another session's in-flight
pricing v2 work.

## 1. SACS needs no engine work

Non-interlocking single-variable banners are the published crosstab columns. So
SACS is `html_report_v2_microdata = N` plus the banners, and nothing waits on the
cube.

## 2. The disclosure fix (the one that changes the SACS config plan)

`disc.audienceBase()` (`21d_disclosure.js`) returned null when there was no
microdata. `audienceTooSmall()` fails closed on null, so a confidentiality ship
hid every comment, tag and quote. The way round that was to clear
`min_reporting_base`, which also switched off `applyDisclosureSuppression()`
(`22_model.js:665`), the thing that blanks a three-person department column and
strips the significance letters pointing at it. That suppression reads the
PUBLISHED bases and works perfectly well with no microdata. So the setting that
protects small groups was being turned off to make the comments readable.

`audienceBase()` now falls back to the largest published Total-column base. With
no microdata there is no filter bar, so the audience genuinely is the full
sample. Null is still returned, and still fails closed, when no question
publishes a base at all.

The SACS client config should therefore KEEP `min_reporting_base`, not clear it.
The August note says to clear it and is superseded.

Tests: `disclosure_tests.mjs`, six new assertions covering the full-sample
fallback, a genuinely tiny sample still gating, a question with no bases block,
and the unchanged fail-closed path. 45 passed, 0 failed.

## 3. Delivery manifest on every build

New `modules/tabs/lib/delivery_manifest.R`. Prints, before any delivery step,
what the finished file contains: respondent records and how many, row-level
weights, verbatim mode, comment demographic tags, minimum reporting base, whether
live filtering is on. When records are present it says plainly what someone can
do with the file and names the one-row fix.

It replaces the old conditional warning at `run_crosstabs.R:1018`, which only
fired when `min_reporting_base` was set. The ordinary build said nothing.

One detail worth keeping: `qual_demographic_cuts = safe` with no k is reported as
"declared safe but k is unset, so tags ship raw", matching what the engine
actually does. A manifest that prints a protection the build is not applying is
worse than no manifest.

Tests: `modules/tabs/tests/testthat/test_delivery_manifest.R`, 44 passed.

## 4. Release audit on the delivered file

New `modules/shared/lib/turas_release_audit.R`, wired into `turas_minify()` as
step 10b and printed in its summary. Reads the finished HTML and reports the
microdata island and its respondent count, row-level weights, identifier-looking
keys in the respondent islands, and the IP patterns (comments, review
references, R and Python filenames, source maps, test hooks).

`turas_minify(..., client_safe = TRUE)` turns a surviving microdata island into a
TRS refusal, `CFG_CLIENT_SAFE_VIOLATED`. IP findings are never fatal: a dev build
is meant to have them.

Verified on the real demo report. A normal run prints the audit and passes; the
same file declared client-safe refuses with the fix instructions.

One false positive was found and removed during that run: `data-agg` carries
`report_meta.email` and `report_meta.phone`, which are the analyst's own contact
details for the About page. The scan is now limited to `data-micro` and
`data-qual`, and to keys that actually carry a value.

Tests: `modules/shared/tests/testthat/test_release_audit.R`, 40 passed.

## 5. Save copy tells the truth

`report.saveCopy()` (`32_report.js`) clones the whole document, so a copy of a
report carrying the island carries it too. That is correct for a copy. What was
wrong was the silence, and a toast reading "Single file, send it to anyone" as
the last thing an analyst saw before emailing it.

A copy that will carry records now asks first, naming the record count, what can
be done with the file, and the real mitigation (no names, IDs or raw text). The
toast says which kind of file was written. A confidentiality ship saves straight
through, unchanged.

NOT built: an option to strip the island on save. It would need the dependent
saved state (custom banners, composites, the takeout snapshot) cleared with it,
and that needs browser verification this session cannot do. Flagged rather than
shipped.

Tests: `saved_copy_namespace_tests.mjs`, ten new assertions. 21 passed.

## 6. Delivery mode is now a deliberate choice

`run_tabs_gui.R`. Ticking "Prepare client deliverable" now reveals a two-way
choice with NO preselection: full report, or client safe. The run refuses to
start until one is picked, in the notification, the in-app console and the
terminal. The choice sets `TURAS_DELIVERY_CLIENT_SAFE`, which is what the release
audit enforces, and it is cleared with the other run globals afterwards.

Only the tabs GUI. The other module GUIs share the checkbox, but their reports
carry no microdata island, so a client-safe declaration has nothing to enforce.

## Suites after the change

| suite | result |
|---|---|
| v2 JS gate suite (all `*_tests.mjs`) | 1,058 passed, 0 failed |
| `modules/tabs/tests/testthat` | 5,457 passed, 0 failed, 1 skipped |
| `modules/shared/tests/testthat` | 943 passed, 0 failed, 3 warnings, 1 skipped |

## Not done, and not claimed

The manifest has not been observed in a live pipeline run. Duncan regenerates
reports through `launch_turas()`, and this session does not run the pipeline on a
real config. The function and its call site are tested; the printed output during
an actual crosstab run is unverified.

Module stripping, obfuscation changes and the sufficient-statistics cube are all
untouched, as agreed.
