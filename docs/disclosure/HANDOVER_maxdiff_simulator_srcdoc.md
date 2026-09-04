# Handover: the MaxDiff simulator ships readable inside its iframe

> **Done, 4 September 2026, but not the way this handover plans it.** Read
> `FINDINGS_simulator_minify_coverage.md` instead. Two claims below are wrong:
> this is not the only piece the profile does not reach (the conjoint and
> standalone maxdiff simulators and the brand report shipped readable too, for
> a different reason), and the job is not a refactor of `turas_minify()`. The
> shape that shipped hardens the embedded document before it is ever escaped,
> from inside `turas_minify()` as step 2b. What follows is kept as the record
> of what was known on the morning of 4 September.


Written 4 September 2026 by the build-hardening session, from what that session
measured. Read `BUILD_NOTE_production_hardening.md` first; this is the one piece
of work it deliberately did not do.

Nothing here is urgent. It is a hole in IP protection, not a bug: the file works
correctly and always has.

## The situation

`modules/maxdiff/lib/html_report/03_page_builder.R:345` embeds the whole MaxDiff
simulator inside the report as an iframe `srcdoc` attribute, HTML-escaped:

    sim_escaped <- gsub("&", "&amp;", sim_modified, fixed = TRUE)
    sim_escaped <- gsub("\"", "&quot;", sim_escaped, fixed = TRUE)

That is correct and it must stay escaped. The consequence is that everything
inside it is attribute text, not markup, so the minifier cannot see it.

Until 4 September the block extractor matched those escaped `<script>` tags
anyway and handed the attribute text to terser, which rejected it: eight blocks,
five warnings on every maxdiff build, and no obfuscation. `.minify_extract_blocks()`
now excludes any script tag that falls inside a `srcdoc="..."` range, so the
warnings are gone and those blocks are untouched.

Untouched means readable. About 1.9 MB of simulator JavaScript travels inside
that attribute in plain sight, in the one module whose simulator is the
interesting part. This is the same bytes as before the hardening work, so
nothing regressed; it is simply the piece the profile does not reach.

`report_hub` does not have this problem: it base64-encodes each child report, so
the extractor never sees it and the child was hardened on its own before being
embedded. This `srcdoc` is the only one in the codebase.

## The shape of the fix

Between extraction and re-embedding, in `03_page_builder.R` or in a step
`turas_minify()` runs over the outer document:

1. Find the `srcdoc="..."` value.
2. Unescape it, exactly reversing the builder: `&quot;` to `"` first, then
   `&amp;` to `&`. Order matters.
3. Run the JavaScript and CSS steps over the resulting document.
4. Re-escape the same way round as the builder and splice it back.

## Four things that will cost time if you meet them cold

**`turas_minify()` takes a path and runs the whole pipeline.** The inner
document needs the JS and CSS steps only, not meta stripping, not the watermark,
not the build tag, not island encoding. There is no string-level entry point
today. Factoring one out of `turas_minify()` is the bulk of this job, and that
function is 1,600 lines that every module's deliverable goes through, so it is a
refactor to do carefully and on its own.

**The round trip must be exact.** Verify by unescaping and re-escaping an
untouched simulator and asserting the result is byte-identical to the original
before changing anything in between.

**The simulator has its own islands and no decoder.** `sim-data` and
`pinned-views-data`, neither marked `data-island="v2"`. The simulator's runtime
is its own; it does not use `parseIsland()` from `24_shell.js`, so it has no
decoder. Marking those islands without adding one would produce a blank
simulator. Encoding them is a separate decision from obfuscating the JavaScript,
and the JavaScript is the part worth doing first.

**Verification is possible, and cheaper than it looks.** The obvious worry is
that the render gate cannot see inside the iframe, because a `srcdoc` document
reports its origin as `null` (that is what makes the simulator's existing
`history.replaceState` console error happen). Measured on 4 September 2026:
a probe in the top document CAN reach in. `iframe.contentDocument` is
accessible, it sees all nine inner scripts, and `contentWindow.document` reads
fine. So extend `.render_probe()` in
`modules/shared/tests/testthat/test_minify_render_gate.R` to walk into the
iframe and evaluate the inner handler names there, the same check it already
runs on the top document. That gate is what makes this change safe to ship.

## What good looks like

The maxdiff report renders identically before and after, the simulator's tabs
and charts still work, every inline handler inside the iframe still resolves,
and `grep` finds none of the simulator's function names in the delivered file.

## Before you start

Ask Duncan. As of 4 September 2026 he has not said whether this is worth doing.
It is a feature, it was not one of the five decisions he approved for the
hardening release, and the work is a refactor of the file every module's
deliverable passes through.
