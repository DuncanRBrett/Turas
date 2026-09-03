# Brief for Fable: production build hardening for Turas HTML deliverables

Design review requested before changes are made. The pipeline already exists and
works; the ask is how much harder to push it, and what gate makes that safe.

## What exists today, verified by running it

`modules/shared/lib/turas_minify.R` (v2.0, April 2026), with
`turas_minify_verify.R` and `turas_minify_watermark.R`. Invoked as
`turas_prepare_deliverable()` from every module GUI, behind a checkbox
("Prepare client deliverable (minify for delivery)", `run_tabs_gui.R:319`) which
defaults to FALSE. That default is why the report that triggered this review was
a development build.

Run on a copy of the Karoo integrated demo report, all five node tools present
(node, terser, cleancss, html-minifier-terser, javascript-obfuscator):

```
Input 1,226 KB -> output 1,139 KB (7.1% smaller)
1 JS block minified, 1 obfuscated, 1 CSS block processed
Watermark injected (client name + build ID, base64 and zero-width-character encoded)
Verification: ALL CHECKS PASSED
```

Forbidden-string counts before and after: block comments 613 to 0, internal
review references ("review 2026-") 27 to 0, R filenames ("weighting.R") 4 to 0,
"node-testable" 10 to 0, "unit-tested" 5 to 0. No source maps at any point.

Surviving readable identifiers: `zPrimary` 2, `isWeighted` 1, `coverFindings` 1,
and four `selftest` hits which are three CSS class names plus one string inside
the obfuscated array.

## Current obfuscator configuration

`turas_minify.R:52`:

```
compact true, stringArray true, stringArrayThreshold 0.8,
stringArrayEncoding base64, stringArrayShuffle true,
controlFlowFlattening false, renameGlobals false, renameProperties false,
selfDefending false, deadCodeInjection false, disableConsoleOutput false
```

Terser runs with `--compress passes=2,dead_code=true`, `--mangle toplevel=false`,
`--no-mangle-props`, `--comments some`.

`renameGlobals` and `renameProperties` are false because inline `onclick`
handlers reference top-level functions by name. That constraint is real but may
be report-specific. Counted this session: `Demo_CX_Crosstabs.html` 829 `onclick=`,
`Karoo_Pricing_Results.html` 59, the current integrated-demo v2 tabs report 0,
`segment_report_v2.html` 0.

## Known gaps, not yet addressed

Unused analytical runtimes ship regardless of whether their data island exists.
`build_report_v2.R` concatenates the whole `assets/js` directory, so a report
with no conjoint still carries `27x_conjoint.js`, and every report carries
`27q_qualitative.js` (149 KB source) and `31_selftest.js` (17 KB).

There is no build manifest and no automated forbidden-string audit. The existing
`run_minify_verification()` checks that nothing was broken by minification; it
does not check that nothing was leaked by it.

## Questions we want your view on

1. How far to push obfuscation. Candidate levers, in what we think is descending
   value per unit of risk: `stringArrayThreshold` to 1.0; `splitStrings` and
   `numbersToExpressions`; `identifierNamesGenerator` to mangled-shuffled;
   terser `--mangle toplevel=true` for report types with no inline handlers;
   `controlFlowFlattening` at a low threshold; `deadCodeInjection`. We would not
   touch `selfDefending`. Is that ordering right, and where would you stop?

2. Top-level mangling is the biggest single readability win available and it is
   currently disabled globally by a constraint that appears not to apply to the
   current v2 tabs report. Is a per-report-type configuration a sound idea or an
   invitation to a subtle production failure? If sound, how should the build
   decide, by counting inline handlers in the generated HTML or by a declared
   flag per module?

3. Control-flow flattening on a one megabyte bundle. Is the runtime cost
   acceptable if scoped only to the statistics and model files, and is scoping
   even coherent when the whole bundle is concatenated into one script block?

4. Module stripping. The clean approach is to drive concatenation from which
   islands the build actually produced. What is the right failure mode if the
   inclusion logic is wrong, given that a missing module presents as a silently
   dead tab rather than an error?

5. The gate. What must pass before a config change ships, given that this
   pipeline touches every Turas deliverable across every module? Our starting
   position is: render the report, run the JS gate suite, run the numerical
   regression, and diff the rendered figures between dev and production builds.
   Is that sufficient, and is there a cheap way to make it automatic?

## Explicit non-goals

We are not trying to make reverse engineering impossible. The goal is to make
copying Turas substantially more expensive than reading the source, without
harming reliability in a file a client will still be opening in three years with
no support available.

Encryption of the delivered file is not IP protection and is not in scope.

## Constraint

No change to `.MINIFY_OBFUSCATOR_CONFIG_JSON` has been made. It affects every
module's deliverable, so it moves only behind an agreed gate.
