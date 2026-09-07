# Hardening a composed report: the VAS integrated report, and the ones after it

> BUILT, 6 September 2026, on branch `feature/composed-report-hardening`.
> What shipped differs from this plan in four places, all recorded in
> "What changed during the build" at the end. Read that section before the
> stage list, which is the plan as written rather than the work as done.

6 September 2026. Written after reading the code and running the pipeline, not
from the brief alone. Every number and filename below was checked this session;
the two things I did not finish checking are named as such at the end.

The question Duncan asked: the minification does not reach the VAS integrated
report, because minification happens before that report is composed. Can it be
solved here, or does it need a Fable review?

Short answer. It can be solved here, and it is smaller than the brief suggests.
The fix is one new step in `turas_minify.R`, one attribute in the VAS Python
builders, and one line in each builder's script tag. Fable should see the design
before it merges, for the reason given in the last section.

---

## 1. What is actually true today

The ChatGPT brief is right on the facts. I checked its claims against the
delivered file rather than accepting them.

In `VAS Integrated Report (data).html`:

| Marker | Occurrences |
|---|---|
| `_0x` (the obfuscated Turas core) | 146,100 |
| `itemStats` | 65 |
| `applyNamedFilters` | 39 |
| `channelRows` | 39 |
| `build_vas_dashboard.py` | 1 |
| `sourceMappingURL` | 0 |

So the core engine is protected and the VAS layer is not. There is no source
map, which is one acceptance test already passing.

The reason is structural, and it is not quite "minification runs too early". It
is that the VAS layer never enters the minifier at all, by two separate routes.

The section pages travel as JSON islands. `build_vas_integrated_report.py`
writes them at line 656 as `<script type="application/json" id="vas-section-KEY">`
holding the whole page HTML as a JSON string. The page is later handed to an
iframe as a `srcdoc` property in JavaScript, not as a `srcdoc` attribute in
markup. `turas_minify()` has a step 2b that hardens embedded documents, but it
looks for the `srcdoc="` attribute, so it never sees these. Step 6b, the
obfuscation pass, explicitly skips `application/json` blocks. Step 8c encodes
data islands, but only those marked `data-island="v2"`, and the VAS islands
carry no such marker.

The wrapper script is injected after the fact. `build_vas_integrated_report.py`
appends its `<script id="vas-sections-js">` patch to a crosstab report that was
already minified and closed. Nothing runs over the composed file afterwards.

Both routes have the same cure, which is to run the hardening pass last, over
the composed file. That is recommendation 6 in the brief and it is correct.

## 2. The finding that changes the shape of the work

Running the existing hardening pass over a VAS page does not remove the
function names. I tested this rather than assuming it.

I copied `VAS Section Report — Bills.html` (1,107 KB) and ran
`turas_minify(deliverable = TRUE)` on it. It passed, in 4.1 seconds, and
stripped 93 of the 94 developer comments. Every analytical function name
survived: `itemStats` 5, `itemTxn` 5, `channelRows` 3, `applyNamedFilters` 3,
`renderTracking` 2, `MICRO` 13. So simply extending the boundary would satisfy
the comment-stripping test and fail the name test.

The cause is in `minify_profile.json`. The obfuscator runs with
`renameGlobals: false`, and terser with `--mangle toplevel=false`. Names in the
top-level scope of a script are therefore left alone by design. The Turas core
escapes this because its bundle is wrapped in an IIFE, so its functions are
inner-scope and get renamed. I confirmed that: in the crosstab report,
`escapeHtml` appears 269 times in the dev copy and 0 times in the deliverable.

Every VAS page has exactly one script block, and every one of them opens with a
top-level `const D = {...}`. I checked the dashboard, Channels, Channel
associations, Additional services and Bills. None uses an IIFE, and none uses
inline `onclick` handlers.

So I wrapped the Bills script in `(function(){"use strict"; ... })()` and ran
the same hardening pass again. Same runtime, 3.7 seconds, still PASS. Every
name went to zero:

| Name | Hardened as-is | Hardened after IIFE wrap |
|---|---|---|
| `itemStats` | 5 | 0 |
| `itemTxn` | 5 | 0 |
| `channelRows` | 3 | 0 |
| `applyNamedFilters` | 3 | 0 |
| `renderSegTable` | 3 | 0 |
| `renderTracking` | 2 | 0 |
| `segTSV` | 2 | 0 |
| `countView` | 2 | 0 |
| `medianOf`, `meanOf`, `compareModel` | 1, 1, 2 | 0, 0, 0 |
| `MICRO` | 13 | 0 |

The page still works. I rendered the unwrapped dev copy and the wrapped hardened
copy in headless Chrome and compared the visible text of each. Both are 6,702
characters and the two are identical, with no JavaScript errors in either.

That is the whole of acceptance test 1, from a one-line change per builder. It
is worth saying plainly: the existing obfuscation profile is already strong
enough, and changing it would be the wrong move. The VAS pages just have to be
shaped so the profile can bite.

## 3. The design

One rule, stated so it applies to the next integrated report as well as this
one. Compose from the development copy, and harden once, last, over the
composed file.

Four pieces.

A new step 2c in `turas_minify.R`, a sibling of the existing 2b. For each
`<script type="application/json">` island carrying an opt-in marker, read the
body as JSON to recover the inner document, write it to a temp file, recurse
into `turas_minify()` with the same options, serialise the result back to JSON
and re-apply the `</` to `<\/` escape. Without that escape the browser closes
the script tag early. It must set an `island_doc_obfuscated` flag the way 2b
sets `srcdoc_obfuscated`, or step 10's size check applies its "must be smaller"
rule to a file that obfuscation has just made larger. It must run before step
8c, so the hardened payload is what gets encoded.

An opt-in marker rather than automatic detection. The island writer emits
`data-embed="document"`. Explicit beats implicit here for the usual Turas
reason: a page that genuinely needs a global would be broken silently by an
automatic wrap. Note that this marker is deliberately NOT `data-island="v2"`,
so step 8c leaves these islands alone. Section 5 explains why that is the right
call and what it saves.

The IIFE wrap belongs to the page builders, not the minifier. Each of the five
VAS builders emits `<script>(function(){"use strict";` and closes with
`})();`. The builder owns its own scoping and the minifier owns the hardening,
which is the cleaner split and does not ask the minifier to guess whether a
wrap is safe.

A repo-side entry point so a `.command` can call this. Something like
`modules/shared/lib/turas_harden_cli.R`, which sources the four files the
pipeline needs and calls `turas_minify(path, deliverable = TRUE)`. Step 8 of
`Run VAS Integrated Report.command` calls it. This is the piece that generalises:
any future composed report gets hardening by calling one script.

Two consequences for the Python side. The builder must read
`VAS_Crosstabs_report_dev.html` in preference to the plain name, and refuse if
the file it picked carries the minified build tag. The detector for that already
exists in the script, near line 254. And the composed file should be written as
`..._dev.html`, with the hardened copy taking the plain name, mirroring what
`turas_prepare_deliverable()` already does for the crosstab report.

The wrapper patch script needs no special handling. Once it is in the composed
file it is a plain `<script>` block, so step 6b obfuscates it. And because
section 5 recommends leaving these islands unencoded, its `island(id)` reader
keeps its plain `JSON.parse` and needs no change at all. If the encoding option
is ever taken, that reader becomes
`JSON.parse(TR.shell._decodeIsland(el.textContent, el.getAttribute("data-k")))`,
which works because the profile sets `renameProperties: false`.

## 4. A gate worth adding while we are here

The name-survival problem was invisible until I grepped for it. It will be
invisible again on the next project that forgets the IIFE. The check is cheap
and generic: after hardening an embedded document, collect the top-level
`function NAME` and `const NAME` identifiers from the source, and grep the
output for them. Any survivor is a leak. Warn on a working build, refuse on a
deliverable.

That turns the brief's acceptance test 1 from a manual grep into something the
build enforces, which is the difference between a fix and a fix that stays
fixed.

## 5. Cost, measured on all nineteen pages

Build time is not a problem. I wrapped and hardened all nineteen VAS pages,
which is the thirteen section reports plus the cross-cutting, wallet, profile
and dashboard pages. All nineteen returned PASS, and the whole set took 38
seconds. The outer pass over the composed file is work the crosstab build
already does today, and the obfuscator only processes script blocks, so the
island payloads ride along as text rather than adding to its work.

File size is the real cost, and it is bigger than the Bills page suggested.
Bills grew 15 percent, but Bills is mostly data, which dilutes the code growth.
A page that is mostly code grows far more. Betting went from 262 KB to 486 KB.
Across all nineteen the set goes from 5.95 MB to 9.70 MB, up 63 percent.

There is a choice here that changes the answer materially, and it is worth
making deliberately rather than by default.

Once a page has been hardened, its data is already unreadable. In the hardened
Bills page, `"meta"`, `"section"`, `"Bills"` and `"micro"` all drop to zero
occurrences, because the obfuscator's string array swallows the JSON payload
along with everything else. So the base64 island encoding of step 8c, which
exists to hide data that would otherwise sit in plain sight, has very little
left to hide on these particular islands. It would still cost the usual third.

| | Composed file | Change |
|---|---|---|
| Today | 14.68 MB | |
| Harden the pages, no island encoding | 18.27 MB | +24% |
| Harden the pages and encode the islands | 21.50 MB | +46% |

Recommend the first of those. Use one marker, `data-embed="document"`, to tell
step 2c to harden the inner document, and do not also mark these islands
`data-island="v2"`. That keeps the two mechanisms independent, which is the
right shape anyway: hardening an embedded document and encoding an island are
different jobs, and a future project may want either one alone.

That still leaves the composed file about a quarter larger, going from 14.7 MB
to roughly 18.3 MB. There is no version of this that makes the file smaller.
Protection costs bytes, and the crosstab report already pays the same tax, at
5.84 MB dev to 8.56 MB delivered.

## 6. Traps, in the order they will cost time

The `.command` is launched from Finder, so it gets a minimal PATH. `Rscript`,
`terser`, `javascript-obfuscator` and the `jsonlite` library all have to
resolve. The script already finds `python3`, so some PATH exists, but this must
be verified by double-clicking the file, not by running it from a terminal that
has a full environment. On this machine `Rscript` is at `/usr/local/bin/Rscript`
and the node tools are in `/opt/homebrew/bin`.

The VAS scripts live in OneDrive and are not in git. Snapshot
`build_vas_integrated_report.py`, the four page builders and the `.command`
before editing any of them.

The brand session is working concurrently. It is in a separate worktree, so
there is no file collision, but `turas_minify.R` is on main and should be
touched on a branch.

## 7. Deferred, and named rather than quietly skipped

Duncan has said the VAS report is fine with full respondent data for now, and a
client-safe version may be wanted later. That is a reasonable call and this plan
does not build the client-safe path. Two things should be on the record.

The section pages do carry respondent-level data. `MICRO.n`, `MICRO.dims` and
`MICRO.m.buy` are per-respondent arrays for the 2024 wave, thirteen references
in the Bills page alone.

The release audit cannot see it. When I ran the hardening pass over Bills, the
audit printed "Respondent-level island: absent" and passed. That is not the
audit failing; it is the audit looking for an island, and `MICRO` is a JavaScript
const inside a page. Encoding makes it opaque on disk, and a determined reader
can still recover it from the DOM, exactly as the brief says. So if a client-safe
VAS build is ever asked for, nothing in the current pipeline would stop it
shipping respondent data under a client-safe label. That is the one part of the
brief I would not defer indefinitely.

## 8. Stages

Each stage ends with something that can fail.

1. Branch, snapshot the OneDrive scripts, confirm the node and R toolchain
   resolves from a Finder-launched `.command`.
2. Step 2c in `turas_minify.R`, with an R fixture: a small composed HTML holding
   one marked document island. It must assert the inner names are gone and the
   island still decodes to `<html`.
3. The name-survival gate from section 4, with a fixture that deliberately leaks.
4. The IIFE wrap and the island marker in the five VAS builders. Regenerate the
   pages and render each one headless, checking for console errors.
5. `turas_harden_cli.R` and step 8 in the `.command`. Run the whole chain.
6. Acceptance grep over the composed file, using the brief's name list. Then
   Duncan opens it and exercises tabs, filters, saved views, section switching
   and the dashboard.
7. Extend `test_minify_render_gate.R` so the decoded island is rendered in a
   srcdoc and checked, and update the gotchas section of CLAUDE.md.

Stage 6 is Duncan's, per the standing rule that a session does not run the
pipeline on a real config.

## 9. Here or Fable

Build it here. Step 2c is a sibling of `.minify_harden_srcdoc()`, which already
does a recursive `turas_minify()` over an embedded document, so this extends an
existing pattern rather than designing a new one. The load-bearing unknown, which
was whether the profile could reach the VAS names at all, is closed and measured.

Fable should review before it merges. This touches the deliverable hardening
boundary, and that boundary has already failed silently once: on 6 September the
release audit was found to have been skipped in every real build, because
`exists("turas_release_audit")` was false in all eight module GUIs. A change
that adds a new way for hardening to be quietly skipped deserves the same
scrutiny that found that one. The natural shape is the pattern already in this
folder, which is Opus builds and Fable gates before merge.

---

## What I verified, and what I did not

Verified by running it this session: the leakage counts in the delivered file;
the 4.1 second and 3.7 second hardening runs on Bills; the before and after name
counts in both hardened copies; the comment stripping, 94 down to 1; the script
shape of five VAS pages; that `escapeHtml` goes from 269 to 0 in the crosstab
deliverable; that the node tools and `Rscript` are installed.

The wrap does not change what the reader sees. I rendered both the unwrapped dev
copy and the IIFE-wrapped hardened copy in headless Chrome and extracted the
visible text from each. Both come to 6,702 characters and the two strings are
identical. The hardened render logged no JavaScript errors, and drew the title,
the headline statistic, the source notes and the same three tables with four
table bodies. That is one page out of nineteen, so stage 4 still renders the
rest, but the mechanism is proven rather than assumed.

The wrap is safe on every page, by inspection of all nineteen. Each one has
exactly one script block, zero inline event handlers, zero `window.X =` or
`globalThis.X =` assignments and no external scripts. So no page publishes a
name that anything outside it could be relying on, which is the only way an
IIFE wrap can break something.

The one thing that does cross the frame boundary still works. The parent reaches
into the section page to click its view toggle, via
`#viewT button[data-v="..."]`. After hardening, `data-v=` no longer appears in
the file, because it is a string the obfuscator moved into its encoded table.
I checked the rendered DOM rather than the source, and the buttons are there:
`data-v="Total"`, `data-v="Own"` and `data-v="Oth"`, with `id="viewT"` intact.

All nineteen pages returned PASS from the hardening pass, in 38 seconds total.

Not verified: anything about the composed file itself, because step 2c does not
exist yet. The claim that hardening the composed report is cheap rests on the
per-page measurement multiplied out, not on a run of the whole chain. The
Finder PATH question in section 6 is untested and deliberately sits first in the
stage list.

---

## What changed during the build

Four things the plan did not anticipate. Each was found by running something.

**The island encoding was dropped, and that was the right call.** Section 5
already recommended it on size grounds. Building it confirmed the reasoning:
once a page has been hardened, `"meta"`, `"section"` and `"micro"` are all at
zero occurrences, because the obfuscator's string array swallows the payload.
So the marker is `data-embed="document"` alone, and step 8c never sees these
islands. The composed file came out at 18.3 MB, against the 18.27 MB predicted.

**The "is this a document" guard was wrong.** It tested for `<html`, copying
step 2b. Three of the nineteen VAS pages have no `<html>` tag at all: the
dashboard, Sample profile and Additional services open `<!doctype html>`
straight into `<meta charset>`, which is valid HTML. The guard now accepts a
doctype or an html tag, and a test covers that shape.

**The leak gate over-reported and would have refused a good build.** Searching
the hardened output for a source function name flags things that are meant to
survive: `shares()` in the betting page also names a `<div id="shares">` and a
`flags.shares` data key, and the obfuscator preserves markup and property names
on purpose. The gate now looks for a DECLARATION, `function shares` rather than
`shares`. Verified both ways: it still catches the real leak in an unwrapped
page, and it clears the betting page whose function was correctly renamed.

**The extractor was hitting PCRE's match limit, and nobody knew.** A page inside
an island brings its own `<style>` and `<script>` opening tags, while its
closing tags are escaped to `<\/`. On the 12.5 MB composed file the `<style>`
search therefore scanned for a close that does not exist, exceeded PCRE's match
limit, and returned 2 blocks with a warning. It was correct only because both
real style elements sit ahead of the islands; a style element placed after them
would have been paired with a page's opening tag and the CSS pass would have
rewritten a span straddling island boundaries. `.minify_extract_blocks()` now
masks island bodies before matching, preserving length so positions still index
the original. This is a change to shared code that every report goes through,
which is the single thing most worth a reviewer's attention.

One smaller thing: the CLI started life in `modules/shared/lib/` and had to move
to `scripts/`. Three tabs tests source every `.R` file in that directory, and a
script that runs on source calls `quit()` in the middle of the suite. It is
`scripts/turas_harden_report.R`.

## What was verified, and how

Run this session, on this branch:

- Shared suite 2,043 passed, 0 failed, 5 skipped. Tabs suite 5,937 passed, 0
  failed, 1 skipped. The tabs number matters because the extractor change is in
  the path of every report.
- Node gates: 927 assertions across 49 files, every file exiting 0, including
  `island_encoding_tests.mjs` at 18 passed.
- 35 new assertions in `test_minify_island_documents.R`, covering the round
  trip, the escape, both refusals, the doctype-only page, the leak gate in both
  directions and the false positive that nearly shipped.
- The whole chain, end to end, on copies in a scratch folder: the real 5.8 MB
  crosstab working copy and all nineteen real pages, composed to 12.5 MB and
  hardened to 18.3 MB. Nineteen embedded pages hardened, verification passed,
  zero warnings.
- Every name on the brief's acceptance list is at zero in that output:
  `itemStats` 65 to 0, `applyNamedFilters` 39 to 0, `MICRO` 299 to 0,
  `build_vas_dashboard.py` 1 to 0, and the shell patch's own `pushAudience` and
  `pickerHtml` with it. No `sourceMappingURL` in either.
- All nineteen output islands decode to whole pages with closed script
  elements, and the manifest parses with nineteen sections listed.
- The refusal paths were exercised, not just written: a missing hardening step
  wrote the readable file and refused to write a client one.
- Strict mode, which the wrapper introduces, was checked three ways across all
  nineteen pages. Every page parses under `"use strict"`. An acorn scope
  analysis found no assignment to an undeclared identifier, which is the failure
  a parse check cannot see. A second acorn pass found no bare `this` at program
  level, which is the failure the scope analysis cannot see: inside the wrapper
  `this` is undefined rather than window, so `this.x = 1` would throw and
  `var me = this` would silently be undefined. Both analysers were validated
  against a page carrying the fault they look for, and both caught it.
- A page builder was run against a wrapped template, rather than the wrap being
  applied to an already-built page as in the earlier tests. All five builders
  substitute with a plain `.replace()` on `__DATA__` and `__THEME__`, so the
  wrap cannot disturb them, but that was reasoning until
  `build_vas_section_report.py data Lotto` was executed. Its output opens with
  the wrapper, passes both strict-mode analysers, hardens to PASS, and leaks no
  declarations: `itemStats` 5 to 0, `MICRO` 13 to 0.
- Non-ASCII survives the island round trip, which adds a `jsonlite::toJSON` hop
  the srcdoc path does not have. The Bills island was decoded out of the
  hardened composed file and still carries both the em dash and the middot its
  titles use.

Not verified, and left to Duncan's run:

- Eighteen of the nineteen pages have not been rendered in a browser after
  hardening. Bills was, and its visible text is identical to the untouched page
  at 6,702 characters with no errors. Headless Chrome on this machine takes
  minutes per page, so the rest is stage 6, which was always Duncan's.
- The real `Run VAS Integrated Report.command`, launched from Finder. A login
  shell finds `Rscript` and all four node tools, and the `.command` now checks
  for them up front, but the double-click itself is untested.
- The leak gate matches declarations, so it cannot see a name published as a
  property: `window.foo = function ...` would survive, because the obfuscator
  preserves property names on purpose. No VAS page does this; all nineteen were
  checked for `window.X =` and `globalThis.X =` and none has either. Worth
  knowing before the next composed report.
- The pages in the OneDrive folder are still the old unwrapped ones. The
  templates carry the wrapper now, so step 2 through step 6 will regenerate them
  wrapped on the next run. Until that run, a build would refuse, which is the
  gate doing its job.


---

## The gap that was closed afterwards, 7 September 2026

The gate described in section 4 protects the careful case: an island was marked,
and the page inside turns out not to be wrapped. It does nothing for the
forgetful one. A composing step that marks NOTHING gives the marked path nothing
to do, and it returns quietly.

That is not hypothetical. I built exactly that case: a deliverable came back
PASS with one unrelated warning, zero islands hardened, and the embedded page's
`computeTheThing` and `SECRETDATA` sitting readable in the output. It is the
same failure the whole job was about, and it would have come back on the next
composed report that omitted one attribute.

So step 2c now looks at unmarked islands too, before it hardens the marked ones,
and refuses a deliverable that carries a page in an unmarked island. Three
conditions have to hold together, which keeps it off ordinary data: the body
parses as a single JSON string, that string opens as an HTML document, and it
contains a script. A manifest, a table island and a user-state island all fail
the first test, because none of them is a bare string. Islands already carrying
`data-k` are skipped, so re-running a minify over a finished file cannot refuse.

Checked against the real delivered report: nineteen marked, zero unmarked. The
new refusal would not have blocked the build that shipped.

That takes the four rules for a composed report from three enforced to four:

| Rule | Enforced by |
|---|---|
| Compose from the `_dev` copy | the composing step refuses a hardened input |
| Mark each embedded page | `CALC_MINIFY_ISLAND_DOC_UNMARKED` |
| Wrap each page's script | `CALC_MINIFY_ISLAND_NAMES_LEAKED` |
| Harden last, and refuse rather than write | the CLI's exit code |

The first is VAS-specific today, because it lives in
`build_vas_integrated_report.py`. The other three are generic and apply to any
composed report without further work.
