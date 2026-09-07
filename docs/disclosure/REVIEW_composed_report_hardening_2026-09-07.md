# Production Review: composed report hardening

**Date:** 2026-09-07
**Branch:** `feature/composed-report-hardening`, reviewed at tip `e4c5b5b7` (four
commits over merge base `d0fc5723`). Not merged, not pushed.
**Reviewer:** Claude Fable 5.1, independent re-review mode. I did not write the
change. Every claim in the brief was treated as a claim to test against the code
and against something executed in this session.
**Language/Stack:** R (`modules/shared/lib/turas_minify.R`, a CLI in
`scripts/`), with terser and javascript-obfuscator as the tools under it.
**Brief:** `docs/disclosure/BRIEF_FOR_REVIEW_composed_report_hardening.md`.

## The one-line verdict

DEPLOY, with the two fixes made in this review left uncommitted on the branch
for Duncan to read and commit. The mask, which the brief rightly put first, held
up under every attack I could think of. The leak gate did not: it had a hole the
exact shape of a Python template, and that is now closed and tested.

## Verification gates

All runs are from this checkout with the renv library active. The first pair
of runs I made had the renv autoloader disabled, which hid `readxl` and
`lintr` and produced failures that were pure environment. Those numbers are not
quoted anywhere here.

| Gate | Command | Result |
|------|---------|--------|
| Shared suite, branch as submitted | `testthat::test_dir("modules/shared/tests/testthat")` | PASS: 1,278 passed, 0 failed, 4 skipped |
| Tabs suite, branch as submitted | `testthat::test_dir("modules/tabs/tests/testthat")` | PASS: 5,937 passed, 0 failed, 1 skipped |
| Node gates | `node <file>` for each of the 49 `.mjs` files in `modules/tabs/lib/html_report_v2/tests` | PASS: 49 files, 49 exit 0 |
| Island test file, as submitted | `testthat::test_file(".../test_minify_island_documents.R")` | PASS: 44 assertions in 17 tests |
| Island test file, after this review | same | PASS: 84 assertions in 25 tests |
| Shared suite, after this review | same as above | PASS: 1,318 passed, 0 failed, 4 skipped (40 more than before: the new tests) |
| Tabs suite, after this review | same as above | PASS: 5,937 passed, 0 failed, 1 skipped |
| Lint | `lintr::lint()` on the three R files | Not a clean gate in this repo. `turas_minify.R` has 120 lints on main, all style (line length, indentation, name length); the branch adds 49 of the same kinds and this review adds 13 more of the same kinds. No lint is a correctness class. Recorded under Observations. |

The shared suite count differs from the brief's 2,052. I ran `test_dir` on the
`testthat` folder with the summary reporter and got 1,278 before the fixes and
1,318 after them (the 40 new assertions), with zero failures both times. I could not find what the author ran
to get 2,052 and did not chase it, because the number that matters is the
failure count and it is zero either way. The node gate figure in the brief (927
assertions) I did not reproduce either: my sum over the files' own "N passed"
lines double counts, so I report the file exit codes, which are what the gate
is.

## What I checked, and how

The brief asked for the mask to be attacked first. I did that with probes
rather than by reading:

- Multi-byte text before, inside and after islands (`é`, an em dash, a middot,
  CJK, an emoji): the masked copy has the same character count as the
  original, its byte count differs (the blanks are ASCII, the text was not), and
  every position the extractor takes from the masked copy indexes the right
  character in the original. A `<style>` placed after two islands is found with
  its own content. Every island's payload decodes back to the page it carried.
- A report with no islands: the mask is the identity.
- An island with no closing tag: unchanged, at the same length; the extractor
  returns nothing for it, which is what it did before this branch.
- A page inside an island that carries its own JSON island: the inner opening
  tag is seen by the mask too, and because masking is idempotent it re-blanks
  the same span and cannot run past the real close.
- A real JS block whose string literal contains the island's opening tag: the
  mask blanks the tail of that block in the search copy only; the extractor
  still returns the block whole from the original.
- The comment stripper's placeholder round trip, which uses `sub(fixed = TRUE)`
  on the island body: `<\/` and `\"` survive it. I checked this because R's
  `fixed = TRUE` still interprets `\1` in a replacement, which I confirmed
  separately, and an island body is full of backslashes.

These probes are now the unit tests in section 8 of the test file. The brief
was right that none existed, and right that a multi-byte case was the one to
add.

For the gate I ran real builds through `turas_minify(deliverable = TRUE)` on a
composed fixture in six shapes: wrapped; unwrapped at column 0; unwrapped
indented four spaces; unwrapped on one line; unwrapped with a `$` in a name;
and `window.name = function`. Then I ran the obfuscator directly on a script
that declares a function, a const, a let, a var, a class, a named function
expression and a block-level function inside an IIFE, plus two true top-level
declarations, one indented and one with a `$`, and checked which declarations
survive.

For the CLI I ran it with no arguments, with a missing file, from a working
directory that was not the repo, on a fresh composed fixture, on its own output
(hardening twice), and with `TURAS_DELIVERY_CLIENT_SAFE=TRUE` and a watermark.
Exit codes and the presence or absence of the output file were checked
directly, not through a pipe.

Cold start for the CLI: the header comment says what it is for, where it lives
and why, what the exit codes mean, and that nothing is written on failure. All
four of those claims held when tested. The `claude.md` gotchas section carries
the four rules a composed report has to follow. That is sufficient for someone
arriving cold.

## CRITICAL

None.

## IMPORTANT

### I1. The leak gate could not see an indented top-level declaration (fixed in this review)

**File:** `modules/shared/lib/turas_minify.R`, `.minify_leaked_top_level_names()`

The gate collected declarations with `(?m)^function NAME`, on the stated
reasoning that "an indented declaration is already inside something, so it is
one scope down and will be renamed". Scope is syntactic. A page whose script is
indented by four spaces, which is exactly what a Python template does when it
writes a page script inside an indented block, declares at top level, and the
obfuscator leaves those names alone.

Proved by a build: a composed fixture with its page script unwrapped and
indented four spaces came back `PARTIAL`, one island hardened, no refusal, and
`itemStatistics`, `renderTheSummary` and `SECTIONDATA` all readable in the
output island. The same page at column 0 was refused. The existing test
"the leak gate only reads declarations that start a line" asserted this blind
spot as the intended behaviour.

Not CRITICAL, because the gate is the second line and the first line held: all
nineteen VAS pages are wrapped, and Duncan's regenerated report greps clean. But
the gate exists for the next project, and the next project's template is at
least as likely to indent as not.

**Fix applied:** the anchor is gone. Declarations are collected from anywhere in
the source. This costs nothing on the other side, because the obfuscator run I
made showed that every non-global binding (function, const, let, var, class,
named function expression, block-level function) is renamed inside an IIFE, so
an inner declaration can never survive verbatim into the output and can never
match. Two guards were added at the same time so the wider net has nothing
false to catch: a `(?<![\w$])` lookbehind so `myvar x` is not a declaration,
and the source is now only the page's real script blocks (`.minify_script_source()`,
the same set step 6b obfuscates), so a JSON island quoting "we let staff go"
cannot contribute a candidate. The output side is likewise searched in script
source only, which retires the `<div id="shares">` class of false positive
entirely rather than by the declaration-not-name trick alone.

Tests: the inverted unit test, the real-build test for the indented page (now
refused, no file written), the verbatim-JSON test, and the `$` cases below.

### I2. A `$` in a name silently escaped the gate (fixed in this review, same change)

**File:** same function.

The output check built its regex by pasting the bare name, and `$` is legal in
a JavaScript identifier and an anchor in a regex. `function $helper` surviving
verbatim in the output returned nothing from the gate. Proved with the function
in isolation. The name is now wrapped in `\Q...\E` and followed by `(?![\w$])`
instead of `\b`, which misbehaves after a `$`. Tested both ways.

## MINOR

### M1. Hardening an already-hardened composed report refused for the wrong stated reason (fixed in this review)

**File:** `.minify_harden_document_islands()`.

The CLI header says hardening cannot be applied twice, and nothing enforced it.
Running the CLI on its own output did refuse, exit 1, no file written, which is
the right outcome. But the code was `CALC_MINIFY_ISLAND_NAMES_LEAKED`, the
leaked name was `a0_0x5f3a`, and the fix text told the operator to wrap a page
that was already wrapped. The names it found were the obfuscator's own
top-level string-array machinery from the first pass.

**Fix applied:** when every leaked name is obfuscator output (`_0x` followed by
hex), the refusal is `CALC_MINIFY_ISLAND_ALREADY_HARDENED` with a fix that says
compose from the `_dev` copy and harden once, last. Confirmed through the CLI:
exit 1, new code, no file. Tested in the suite.

### M2. Step 2c did not surface an embedded page's own warnings, and skipped the status check step 2b makes (fixed in this review)

**File:** `.minify_harden_document_islands()`.

Step 2b prints each embedded document's warnings as notes and refuses if the
inner result is neither PASS nor PARTIAL or wrote no file. Step 2c did
neither, so a PARTIAL one level down became a PASS one level up with nothing on
the console, and an inner result with no file would have died inside
`readLines()` with a temp path in the message. Both now mirror 2b. The notes
are visible in the CLI probe output, prefixed with the island id.

### M3. The plan document's verification numbers are stale

**File:** `docs/disclosure/PLAN_composed_report_hardening.md`, "What was
verified" section.

It says 35 assertions in the island test file and a shared suite of 2,043. The
brief says 44, which is what the file had at the reviewed tip. Not changed by
me: the plan is a record of its date. Anyone quoting a number should take it
from a run, which is the repo's rule anyway.

## OBSERVATIONS

### O1. The mask is O(islands × document size) per extraction, and extraction runs several times per build

Measured on a synthetic 12.7 MB document with 200 JSON islands: the mask alone
takes 12.9 seconds, and `.minify_extract_blocks()` goes from 14.8 seconds on
main to 28.2 seconds on the branch, returning identical blocks. Each island does
a `substr()` of the document tail and a whole-document `substr<-`. Real reports
carry 2 to 14 islands (counted across the fixtures in `examples/` and the
module test fixtures) and VAS carries 19, so the cost today is about a second
per call on the largest file. Not a finding. If a report ever carries islands
in the hundreds, the fix is one pass: find every `</script>` once, pair each
open with the first close after it, and rebuild the string from the pieces.

### O2. "Once a page is hardened its data is already unreadable" is doing about the right amount of work

The brief invited a second look. What the obfuscator does to a page's data is
put every string literal into a shuffled, base64-encoded array; numbers stay
as numbers unless something else wraps them. What step 8c does to an island is
XOR against a keystream whose seed is in the file, then base64. Neither is
encryption and both are reversible by a developer in minutes; both stop
grepping, pasting into a JSON tool, and casual reading. Skipping 8c for a
hardened page is therefore a fair trade for a third of the file. In the probe
build the fixture's `1100` was not visible in the hardened island, but I would
not rely on that for a page whose data is a large numeric array, and the brief
already says hardening is not a client-safe control.

### O3. `window.name = function` is caught after all, by the string array

The brief listed this as a known false negative of the declaration-based gate.
It is, but in this obfuscator configuration the property access itself is
rewritten through the string array, so the name is not readable in the output
anyway. Checked by build: `window.itemStatistics` did not appear in the hardened
island. Worth knowing, not worth a test, because it depends on
`stringArrayCallsTransform` staying on.

### O4. The unmarked-island detector's first condition is a bare JSON string

A composer that wraps its page in an object, `{"html": "<!doctype ..."}`, is
not detected. The three-condition design is right for what exists and is
documented as such. A grep of every `application/json` writer in `modules/`
found no module that writes a bare-string island holding a document, so the
detector cannot false-positive on today's reports, and the tabs suite (5,937
assertions, many of them deliverable builds) agrees.

### O5. Lint is not enforced on this file and never was

120 lints on main, all line length, indentation and name length. The branch
and this review follow the file's existing style rather than the linter's.
Making the file lint-clean would be a separate, mechanical change and is not
part of this review.

### O6. Test fixtures are tiny, so every real build in the suite is PARTIAL

The obfuscator's string array dwarfs a 400-byte page and trips the verifier's
size rule. The tests accept PASS or PARTIAL for that reason and say so. On the
real 12.5 MB report the same rule passed. Fine, but it means the suite never
sees a PASS from a composed build, so a future change that turns PASS into
PARTIAL for a real reason would not be noticed by these tests.

## What was NOT verified

- No real VAS page was hardened in this session. The templates and the
  composer live on OneDrive, outside git, and the rule is that regenerating
  deliverables is Duncan's job through the `.command`. The brief's report that
  Duncan's 7 September regeneration grepped clean stands as his evidence, not
  mine.
- No page was rendered in a browser. The brief already names eighteen of
  nineteen as unrendered; this review adds nothing there.
- The node gates were run once, on the branch as submitted. The two files this
  review changed are R, so they were not rerun.
- The report_hub path was left alone, as the brief says, on Duncan's call.

## Changes made in this review

Uncommitted, on `feature/composed-report-hardening`:

- `modules/shared/lib/turas_minify.R`: `.minify_leaked_top_level_names()`
  rewritten as described in I1 and I2; new helpers `.minify_script_source()`
  and `.minify_names_are_obfuscator_output()`; step 2c gains the status check,
  the warning notes and the already-hardened refusal (M1, M2).
- `modules/shared/tests/testthat/test_minify_island_documents.R`: the
  line-anchor test inverted; tests for the indented page, the `$` name, the
  verbatim-JSON false positive, `.minify_script_source()`, the obfuscator-name
  predicate, and hardening twice; a new section 8 with the mask tests the brief
  asked for.

No documentation was changed. The `claude.md` sentence "Step 2c of
`turas_minify.R` refuses a deliverable whose embedded page still declares its
own names" is true after I1 and was not true before it.

## Verdict

**DEPLOY.** The shared extractor change, which every report goes through, held
under every attack in the brief and several it did not list, and is now pinned
by tests. The one real gap was in the safety net rather than the fence, it is
closed, and the closing is proved by a build that used to ship names and now
refuses. Duncan should read the diff of the two changed files, commit them on
the branch, and then merge.
