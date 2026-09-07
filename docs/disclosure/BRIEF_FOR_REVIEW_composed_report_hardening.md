# Brief for review: hardening a composed report

Pre-merge review requested on `feature/composed-report-hardening`, three commits,
tip `95a3752d`. Not merged, not pushed. Written by the session that built it, so
treat every claim here as something to check rather than accept.

Read the change as an independent reviewer. The author's context is the author's
blind spots.

## The one-line version

Reports that are assembled by stitching finished pages into a finished Turas
report were shipping those pages readable inside an otherwise hardened file.
This makes the hardening pass reach them, and refuses a deliverable where it
cannot.

## Where to look first, and why

`.minify_mask_island_bodies()` and its two call sites inside
`.minify_extract_blocks()` in `modules/shared/lib/turas_minify.R`.

That is the highest-risk part of the change and the least related to the
feature. `.minify_extract_blocks()` is the function every Turas report goes
through, for both `<style>` and `<script>`, in every module. The change makes it
match against a copy of the HTML with JSON island bodies blanked out, then
extract real content from the original by position. The premise is that blanking
preserves length so positions still line up.

Attack that premise. What happens with a multi-byte character in an island body,
given R's `substr` is character-based and `nchar(type="bytes")` is used
elsewhere in the file. What happens with an island whose closing tag is missing.
What happens with nested or malformed islands. What happens on a report with no
islands at all, which is every report today.

The reason it is here at all: a page carried inside an island brings its own
`<style>` and `<script>` opening tags, while its closing tags are escaped to
`<\/`. On the 12.5 MB composed report the `<style>` search therefore scanned for
a close that does not exist, exceeded PCRE's match limit, and returned 2 blocks
with a warning. It was correct only because both real style elements happen to
sit ahead of the islands. A style element placed after them would pair with a
page's opening tag and the CSS pass would rewrite a span straddling island
boundaries.

## What else changed

**Step 2c, `.minify_harden_document_islands()`.** For each island marked
`data-embed="document"`, read the body as JSON to recover the page, recurse into
`turas_minify()`, serialise back and re-apply the `</` to `<\/` escape. A
sibling of the existing `.minify_harden_srcdoc()` (step 2b), which does the same
for a page written into a `srcdoc` attribute. Runs before step 8c so a caller
marking both ways encodes hardened bytes.

**Two refusals.** `CALC_MINIFY_ISLAND_NAMES_LEAKED` when a hardened page still
declares its own top-level names, and `CALC_MINIFY_ISLAND_DOC_UNMARKED` when an
island carries a page but was not marked. Both deliverable-only.

**`scripts/turas_harden_report.R`.** The entry point a non-R composing step
calls. In `scripts/` because three tabs tests source every `.R` in
`modules/shared/lib/`, and a script that runs on source calls `quit()` mid-suite.

**VAS side, not in git.** Five page templates gained an IIFE wrapper,
`build_vas_integrated_report.py` reads the `_dev` crosstab and calls the
hardening step last, and `Run VAS Integrated Report.command` checks for Rscript
up front. Snapshots of the originals are in the session scratchpad. Reviewing
these is optional; they are one project's plumbing, not platform code.

## The finding the whole design rests on, which is worth re-deriving

Extending the hardening boundary is not sufficient. `minify_profile.json` sets
`renameGlobals: false` and terser runs `--mangle toplevel=false`, both
deliberately. So a name declared in a script's outermost scope is never renamed.
The Turas core escapes this only because its bundle sits inside an IIFE.

A page without a wrapper therefore passes the entire hardening pass with every
function name intact while its comments are stripped, which looks exactly like
success. Measured on the VAS Bills page: comments 94 to 1, and `itemStats` still
present five times. Wrapping the same page in an IIFE took every name to zero
and left the rendered visible text byte-identical at 6,702 characters.

If that reasoning is wrong, the whole shape of this change is wrong, so it is
the first thing worth checking independently.

## Judgement calls to second-guess

**Islands are deliberately NOT marked `data-island="v2"`,** so step 8c does not
base64-encode them. The argument is that once a page has been hardened its data
is already unreadable, because the obfuscator's string array swallows the
payload, so encoding costs about a third of the file to hide what is hidden.
Measured: 18.3 MB against 21.5 MB. Check whether "unreadable" is doing too much
work in that sentence.

**The leak gate matches a declaration, not a name.** Matching the bare name
over-reported: `shares()` in the VAS betting page also names a `<div id="shares">`
and a `flags.shares` data key, and the obfuscator preserves markup and property
names on purpose, so the first version refused a page that was correctly
hardened. The consequence is that a name published as `window.foo = function`
would not be caught. No VAS page does that; all nineteen were checked.

**The wrapper is the page builder's job, not the minifier's.** The minifier
could wrap automatically, but a page that genuinely needs a global would then
break silently. Consider whether the refusal is a good enough substitute for
doing it centrally.

**The unmarked-island detector needs three conditions together** before it
refuses: the body parses as a single JSON string, that string opens as an HTML
document, and it contains a script. Look for a false positive that would block a
legitimate build, and for a false negative that would let a page through.

## What was verified, and how

Everything below was run on this branch. The point of listing it is so you can
find what it does NOT cover.

- Shared suite 2,052 passed, 0 failed, 5 skipped. Tabs suite 5,937 passed, 0
  failed, 1 skipped. Node gates 927 assertions across 49 files, all exiting 0.
- 44 assertions in `modules/shared/tests/testthat/test_minify_island_documents.R`.
- The real delivered VAS report, regenerated by Duncan on 7 September through
  the actual Finder-launched `.command`: 19.2 MB from 12.5 MB composed. Every
  name on the original brief's acceptance list at zero (`itemStats` 65 to 0,
  `applyNamedFilters` 39 to 0, `MICRO` 299 to 0, `build_vas_dashboard.py` 1 to
  0). All 19 islands decode to whole pages with closed script elements. No
  `sourceMappingURL`.
- Strict mode, introduced by the wrapper, checked three ways on all nineteen
  pages: every page parses under `"use strict"`; an acorn scope analysis found
  no assignment to an undeclared identifier; a second acorn pass found no bare
  `this` at program level. Both analysers were validated against a page carrying
  the fault they look for.
- Non-ASCII survives the island round trip: the em dash and middot are still in
  the Bills page after it is decoded out of the hardened file.

## What was NOT verified

- Eighteen of the nineteen pages have not been rendered in a browser after
  hardening. Only Bills was. Headless Chrome on this machine takes minutes per
  page. Duncan's own eyeball of the regenerated report is still outstanding at
  the time of writing.
- No test covers `.minify_mask_island_bodies()` directly. Its behaviour is
  exercised through the island tests and observed on the real 12.5 MB file, but
  there is no unit test for the masking itself, and no test at all for the
  multi-byte case. If you want one thing added before merge, this is my
  candidate.
- The `report_hub` module composes reports the same way, storing each as base64
  in a `text/plain` block that step 6b skips by design. Duncan has said it is
  likely to be deprecated, so it was deliberately left alone. Mentioned so it is
  not mistaken for an oversight.

## Out of scope, and known

Hardening is not a client-safe control and is not claimed to be. The VAS section
pages carry per-respondent arrays as a JavaScript constant named `MICRO`, and
`turas_release_audit()` reports "Respondent-level island: absent" and passes them,
because it looks for an island. Nothing in this change would stop a client-safe
VAS build shipping respondent data. That is a separate job, flagged to Duncan and
accepted by him for now.

## Background

`docs/disclosure/PLAN_composed_report_hardening.md` has the full plan, the four
things the plan got wrong during the build, and the measurements. The gotchas
section of `CLAUDE.md` carries the four rules a composed report has to follow.
