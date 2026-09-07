# Growth Path: composed report hardening

**Date:** 2026-09-07
**Current state:** A report assembled by stitching finished pages into a Turas
report can be hardened once, last, from outside R, and the build refuses rather
than writes when a page inside it would ship readable.
**Stack:** R (`turas_minify.R` step 2c, a CLI in `scripts/`), terser,
javascript-obfuscator, jsonlite.

## Architecture readiness

What the current design supports without rework:

- Any composed report, from any composer, in any language. The contract is
  three attributes and one wrapper: `type="application/json"`,
  `data-embed="document"`, a JSON string body with `</` escaped, and an IIFE
  round the page script. The VAS composer is the first client; nothing in the
  R side knows about VAS.
- Pages that carry their own islands, styles and scripts. The mask makes the
  extractor blind to them by construction, and the recursive pass handles them
  one level down exactly as it handles the outer document.
- Both encodings at once. A composer that wants a page hardened AND its island
  XOR-encoded sets both attributes; step 2c runs before 8c so the encoded bytes
  are the hardened ones.

What would need real work:

- A composer that wraps its page in an object rather than a bare string. The
  unmarked-island detector would not see it. Supporting that means agreeing a
  key name, which is a design decision, not a code one.
- A client-safe composed report. The release audit looks for a respondent
  island, and a page can carry respondent rows as a JavaScript constant. The
  brief names this as out of scope and Duncan has accepted it for now. Closing
  it means the audit reading inside embedded pages, or the composer declaring
  what each page carries.

## Natural next steps

### 1. Fold the VAS composer's "refuse a hardened input" rule into the CLI

**What:** The CLI now refuses when a page inside an island has already been
hardened (the review added that). It does not yet refuse when the OUTER
document has, because `turas_minify()` must keep accepting re-minified files
for report_hub. The VAS composer enforces it on its side. A check in the CLI
for the Turas build tag in the input, with an override flag, would make the
rule generic.
**Why now:** It is the one of the four composed-report rules still enforced by
one project's Python rather than by the platform.
**Effort:** Small. One `grepl` and one refusal in `scripts/turas_harden_report.R`.
**Dependencies:** Decide whether a minified-but-not-hardened dev build is a
legitimate input. If it is, the check must look for obfuscation, not the tag.
**Risk:** Blocking a flow that was working. Mitigated by the override flag.

### 2. A one-pass mask, if a report ever carries islands in the hundreds

**What:** Replace the per-island `substr<-` loop with a single pass over all
`</script>` positions.
**Why now:** It does not need doing now. Measured cost is about a second per
extraction on the largest real report. Recorded so the next person does not
rediscover it under a deadline.
**Effort:** Small, but it touches the function every report goes through, so
it needs the section 8 mask tests green and a timing before and after.

### 3. Let the release audit see inside embedded pages

**What:** When a deliverable is declared client-safe, run the audit's
respondent and identifier checks over each embedded page's script source as
well as the outer document.
**Why now:** It is the gap the brief names as the one this change does not
close. A client-safe VAS build today would pass the audit with respondent
arrays aboard.
**Effort:** Medium. The audit's checks are island-shaped; a page's data is a
constant. Either the checks learn a second shape or the composer declares
per-page contents in the manifest.
**Risk:** False confidence if done by halves. Better not started than half
done.

## Known limitations

| Limitation | When it matters | Mitigation |
|---|---|---|
| Hardening is not encryption | A determined reader with a browser console | None intended; the brief says so |
| The leak gate matches declarations, not every way a name can be published | A page that publishes via a pattern the string array does not rewrite | Wrapper stays the first line; gate is the second |
| Unmarked detection needs a bare JSON string | A composer that nests the page in an object | Document the contract; add the key if a second composer needs it |
| Eighteen of nineteen VAS pages unrendered after hardening | A page whose script breaks under strict mode in a way the parser and acorn scan did not catch | Duncan's eyeball, which the brief already lists as owed |

## Technical debt

| Debt | Why accepted | When to pay down |
|---|---|---|
| `turas_minify.R` is not lint-clean (120 lints on main, style only) | Never was; the file's own style is consistent | A dedicated mechanical pass, not mixed with behaviour changes |
| Suite fixtures are tiny, so composed builds are always PARTIAL in tests | Real reports pass the size rule; fixtures cannot | A mid-size fixture if a PASS-specific behaviour ever needs asserting |
| report_hub embeds reports the hardening pass skips | Likely to be deprecated | Only if it is not deprecated |

## External dependencies to watch

| Dependency | Concern |
|---|---|
| javascript-obfuscator | The gate's "inner names are always renamed" premise is a property of the current profile (`renameGlobals: false`, string array on). A profile change needs the gate's tests rerun, and the review's obfuscator probe is the quickest way to re-establish the premise. |
| terser `--mangle toplevel=false` | Same premise, other tool. |
| PCRE match limit in R | The mask exists because of it. A future R that raises the limit does not remove the correctness reason for the mask, only the performance one. |

## Summary

The change is generic, small, and enforced by refusals rather than by
convention, which is the right shape for a boundary whose failure is invisible.
The clearest next step is the client-safe gap, which is a real one and is
already known. The biggest constraint is that verification of a composed
report still ends with a human opening nineteen pages.
