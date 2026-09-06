# Brand funnel: settling how the stages are defined

**Date:** 6 September 2026. Worktree `/Users/duncan/Dev/Turas-funnel-def`,
branch `fix/brand-funnel-consideration`, cut from main at 088736c9.

Four pieces of work, all agreed with Duncan: fix the consideration override,
set the default consideration set, detect whether the instrument gated the
questions, and write the questionnaire guidance.

Every R run in this log was prefixed
`TURAS_ROOT=/Users/duncan/Dev/Turas-funnel-def`.

## Baseline, executed before the first edit

`Rscript -e 'testthat::test_dir("modules/brand/tests/testthat")'` from the
worktree root: **FAIL 0, WARN 1, SKIP 2, PASS 3247**, 99.8 s. Matches the
brief exactly.

Working tree clean at 088736c9. The other two worktrees
(`/Users/duncan/Dev/Turas` on main, `/Users/duncan/Dev/Turas-brand-simplify`
on `feature/brand-insight-number-check`) were left alone.

---

## Stage 1: the override changed the mechanism, not just the membership

### What the code did

`.stage_consideration()` in `modules/brand/R/03a_funnel_derive.R` compared the
passed codes against `.FUNNEL_POSITIVE_ATTITUDE_CODES`, which was `c("1","2")`:

```r
is_default_pos_codes <- identical(as.character(pos_codes),
                                  as.character(.FUNNEL_POSITIVE_ATTITUDE_CODES))
role_to_codes <- if (is_default_pos_codes) {
  tryCatch(.resolve_attitude_role_codes(entry), error = function(e) NULL)
} else NULL
```

When they matched, the scale was resolved through the OptionMap by role, so
the stage found the right respondents whatever the data encoded. When they
differed, the resolution was skipped and the raw codes were matched literally
against the data. The `tryCatch` was a second silent route to the same
literal path.

### The bug, executed rather than argued

Ten respondents, three brands, a six-level OptionMap, and the config
overriding with codes 1, 2 and 4. Run against the code at 088736c9:

| Attitude columns export | Consider, IPK | base |
|---|---|---|
| labels ("Love", "Prefer", "Price only") | 0.0 | 0 |
| numeric codes ("1", "2", "4") | 0.6 | 6 |

Same config, same respondents, same answers. The category whose columns
carried labels collapsed to zero, silently. This is what Duncan hit when he
overrode Dry Seasonings and Baking Mixes with the same setting and got a
plausible number from one and nothing from the other.

The script that produced the table sourced `03a_funnel_derive.R` and
`03_funnel.R` as they stood at HEAD alongside the current metrics layer and
the new test fixture, so the two rows differ only in how the data encodes the
answers.

### What changed

- **One resolution path.** `derive_funnel_stages()` resolves the consideration
  set once, before the stage loop, through `.funnel_resolve_consideration()`,
  and passes the resolved accepted values down. `.stage_consideration()` now
  has a single matching path and no fallback. The `is_default_pos_codes`
  branch and the swallowing `tryCatch` are gone.
- **The config names roles, not codes.** New Settings key
  `funnel_consideration_roles`, comma separated, short names or full ones
  ("love, prefer, price" or "attitude.love"). Normalised by
  `.funnel_normalise_consideration_roles()`, which folds the spellings an
  operator is likely to type ("price only", "no opinion") onto the canonical
  role, and reuses `.funnel_canonical_attitude_role()` for the legacy
  reject-to-avoid alias.
- **Refusals replace the empty stage.** A role the operator names that the
  scale does not declare refuses with `CFG_CONSIDERATION_ROLE_ABSENT`; a role
  Turas does not recognise refuses with `CFG_CONSIDERATION_ROLE_UNKNOWN`.
  Both go through `brand_refuse()`, so the boxed message reaches the console
  where Duncan debugs the Shiny app.
- **Raw codes still work.** `funnel.positive_attitude_codes` is read, and each
  code is resolved back to the role whose accepted set contains it, then
  expanded to that role's full set of codes and labels. So the pre-fix config
  above now reads 0.6 on both encodings. A code matching no declared position
  is matched literally and reported. The deprecation is written to the console
  and carried in `meta$consideration$notes`.
- **The knob now reaches the config workbook.** `.funnel_config_from_global()`
  in `00_main.R` never passed `funnel.positive_attitude_codes` through, so the
  old knob was unreachable from `Brand_Config.xlsx` at all. Both keys are
  wired now, and `funnel_consideration_roles` is in the FUNNEL OPTIONS block
  of `generate_config_templates.R`.

### The trap in the presence check

`.option_map_by_role()` folds a hardcoded set of label aliases into every
role, so its result is never empty for any of the six positions. Asking it
"does this scale carry a price level" always answers yes, which would have
made the absent-role refusal unreachable and, worse, would have let the
default set match the literal string "price only" on a scale that never
declared the level.

`.funnel_declared_scale_roles()` answers the declaration question separately:
the operator's `attitude_role_codes` override, else the OptionMap's own Role
column, else the built-in five-level convention. Presence is tested against
that; matching still uses the alias-tolerant set.

### Decisions taken rather than asked

1. **A deprecation does not degrade the run to PARTIAL.** The note goes to the
   console and to `meta$consideration$notes`, not to `result$warnings`, which
   drives status. A working config should not report itself as a partial run.
2. **New key rather than overloading the old one.** `funnel_consideration_roles`
   sits beside `funnel.positive_attitude_codes` rather than teaching one key to
   take either shape. The Settings sheet is read by humans.
3. **`.FUNNEL_POSITIVE_ATTITUDE_CODES` removed.** It existed only as the
   default that the equality test compared against. Nothing else referenced it.

### Evidence

- `modules/brand/tests/testthat/test_funnel_consideration_roles.R`, 17
  assertions, all passing. It holds the label-encoded override at its
  hand-counted value (6 of 10), asserts label and code encodings now agree,
  asserts codes and the equivalent roles agree, and drives both refusals.
- Full brand suite after Stage 1: **FAIL 0, WARN 1, SKIP 2, PASS 3264**,
  96.0 s. Baseline plus the 17 new assertions.

---

## Stage 2: the standard consideration set is Love, Prefer, Price-conditional

`.FUNNEL_CONSIDERATION_ROLES` is now `attitude.love`, `attitude.prefer`,
`attitude.price`. The stage's default label moves from "Prefer" to
"Consider", because a price-conditional respondent is in the set and does not
prefer the brand, so the old label described something narrower than the
stage measures.

The reasoning, recorded so it does not have to be re-argued: code 4 says the
respondent will buy the brand if the price is right, so they are in the
consideration set price-conditionally. Code 3 says, in the respondent's own
words, that they would only consider it if nothing else were available, so
they are not. Drawing the line on what the respondent said is what makes it
defensible to a client.

The earlier top-2 choice was made against top-4, and top-4 let 85 to 97 per
cent of aware respondents through on popular IPK 2026 brands. That
observation stands. The level responsible for it is Ambivalent, and
Ambivalent is the one that stays out.

### Before and after, every category in the fixture

`run_brand()` on `modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx`,
`project_root` = the fixture directory, once at the Stage 1 tip and once at
the Stage 2 tip. Both runs returned status PASS. Nothing was written into the
repo or into any project folder; `run_brand()` writes no files.

**Eight of the nine categories carry no funnel block** and so have no number
to move: Pour Over Sauces, Pasta Sauces, Baking Mixes, Salad Dressings, Stock
Powder / Liquid, Pestos, Cook-in Sauces, Anti-pasta. Only Dry Seasonings &
Spices is analysed at full depth in this fixture.

**Dry Seasonings & Spices, n = 438 unweighted (the routed subset, not the
1,200 screened), funnel status PARTIAL both runs.**

| Brand | Aware before | Aware after | Consider before | Consider after |
|---|---|---|---|---|
| IPK | 92.5% | 92.5% | 66.9% | 66.9% |
| ROB | 85.2% | 85.2% | 30.8% | 30.8% |
| KNORR | 84.9% | 84.9% | 31.3% | 31.3% |
| CART | 75.1% | 75.1% | 25.8% | 25.8% |
| CHS | 77.2% | 77.2% | 30.8% | 30.8% |
| FNF | 73.1% | 73.1% | 26.0% | 26.0% |
| WWT | 67.6% | 67.6% | 25.1% | 25.1% |
| PNP | 65.5% | 65.5% | 21.7% | 21.7% |
| SSG | 57.8% | 57.8% | 19.4% | 19.4% |
| RAJ | 50.2% | 50.2% | 16.2% | 16.2% |
| SAF | 49.5% | 49.5% | 21.0% | 21.0% |
| SPM | 43.4% | 43.4% | 13.5% | 13.5% |
| CHK | 39.0% | 39.0% | 14.6% | 14.6% |
| HND | 34.5% | 34.5% | 11.6% | 11.6% |
| DEL | 24.9% | 24.9% | 10.3% | 10.3% |

**Nothing moved, and that is the correct result.** `identical()` on the
before and after `$stages`, `$conversions` and `$attitude_decomposition`
frames all returned TRUE. The fixture's instrument is the five-level scale
from ALCHEMER_PROGRAMMING_SPEC.md (love, prefer, ambivalent, refuse, no
opinion) and it declares no OptionMap sheet, so the scale resolves through
the built-in five-level convention, which has **no price-conditional level at
all**. The new default drops the role it cannot find and reports it:

```
=== TURAS BRAND: FUNNEL CONSIDER STAGE ===
Category: DSS
 * The attitude scale carries no price level, so the Consider stage is love
   plus prefer on this survey.
```

and `meta$consideration$roles_dropped` reads `attitude.price`. The run stays
PARTIAL for the pre-existing nesting reason, not for this.

### What the change does on a scale that carries the level

The fixture cannot show it, so it is shown on the six-level unit fixture in
`test_funnel_consideration_roles.R`, whose ten respondents are hand counted.
IPK's attitudes there are two Love, two Prefer, two Price-conditional, two
Ambivalent, one Avoid, one No opinion.

| Consideration set | Consider, IPK |
|---|---|
| Love + Prefer (the old default) | 40% |
| Love + Prefer + Price (the new default) | 60% |
| Love + Prefer + Price + Ambivalent (the old top-4) | 80% |

**Known limit, stated rather than left to be found.** No report has been
rendered on a six-level scale in this session. Doing that would mean either
running Duncan's real IPK config, which is out of bounds, or inventing
price-conditional answers for a fixture whose instrument never asked the
question. The six-level path is proved by the hand-counted unit fixture and
by the fixture's own dropped-role report, not by a rendered report.

### Documentation updated

- `modules/brand/docs/FUNNEL_SPEC_v2.md`: new §3.1a states the standard, how
  to override it, what happens when a level is missing, and the legacy code
  key. The stage table's derivation column and three §10.2 edge cases were
  corrected.
- `modules/brand/docs/ROLE_REGISTRY.md` §4.2: `attitude.price` added to the
  role table, `attitude.reject` folded into `attitude.avoid` as the pre-2026
  name, and a warning that a six-level instrument must declare its scale on
  the OptionMap sheet or code 4 falls through to Avoid.

### Owed to Duncan, not touched here

The shared callout `brand.funnel` in
`modules/shared/lib/callouts/callouts.json` still says the Prefer stage is
"the top-2 of the 6-point scale (Love + Prefer)", still says Turas "refuses to
render a brand whose aggregate counts violate nesting", which it does not, and
still describes three base toggles when there are four. It sits outside
`modules/brand`, which this task may not touch. The Stage 4 simplification log
already lists the toggle count as owed; the consideration set is a second
reason to rewrite that entry.

Brand suite after Stage 2: **FAIL 0, WARN 1, SKIP 2, PASS 3276**.

---

## Stage 3: whether the questionnaire gated the questions decides the report

Turas must not draw a nested funnel from ungated questions, because the
picture asserts an ordering the survey never enforced.
`detect_instrument_gating()` in `03a_funnel_derive.R` decides which of the two
reports the reader gets.

### The rule, and a deviation from the brief worth flagging

The brief's rule is aggregate: if any brand's consideration exceeds its
awareness, the questions were not gated. **That rule misses the case it
matters most for.** An ungated instrument can easily produce totals that fall
at every stage for every brand, and a nested funnel drawn from it would look
perfectly well behaved. The implemented rule is respondent level: count
respondents who sit at a later stage without the earlier one. Routing makes
such a row impossible, so one row is proof. It subsumes the aggregate rule,
because a brand whose later count exceeds its earlier one must contain at
least one such row.

Head counts, not weighted. Weighting is a property of the sample, not of the
questionnaire, and a fractional weight cannot make an impossible row possible.
Brands whose column is entirely NA at either stage are skipped, the same
exclusion `validate_nesting()` makes.

**Pairs tested:** every stage against awareness, plus the target purchase
window against the longer one, and long tenure against current ownership. Not
purchase against consideration: the CBM template does not gate buying on
attitude, and checking that pair would report a properly gated instrument as
ungated. The gated unit fixture proves this, with respondents who bought a
brand they were lukewarm about and no breach reported.

### What the two modes look like

| | Gated | Ungated |
|---|---|---|
| Notice on the page | "Nested funnel" | "Separate measures" |
| "Funnel, % of all" toggle | rendered, active on load | not rendered at all |
| Default view | the nested chain | each stage on its own |
| "% of those aware" | present | present |
| "% of previous stage" | present | present |
| Table cells before any script runs | chain figure | each stage's own figure |
| Overview mini funnel | nested series | absolute series |
| `data-fn-pct-chn` on each cell | the chain | equals `data-fn-pct-abs` |

The cumulative counts stay in the payload in both modes, because "% of
previous stage" and "% of those aware" are the two conversion ratios the
brief asks the separate-measures report to carry, and both are honest
intersections rather than routing claims. What the ungated report withholds
is the "% of all" chain view, the one that draws the whole funnel as a
shrinking bar of the sample.

The notice sits outside `.fn-controls`, next to the control it explains, for
the same reason `.fn_base_howto()` does: the controls bar is hidden in print
and a reader with a printed page cannot open a drawer.

### The reachability gate is honoured, not amended

`reachability_check.py` compares the numeric content of every JSON island on
exact equality, and the gating finding rides in the funnel payload. So the
on-page statement is **digit free** by design, and a testthat case asserts it
stays that way in both modes. The counts behind it go to the console and to
`meta$gating`, not into the island.

Executed: `python3 reachability_check.py report_baseline.html
report_gated.html`, where the baseline was generated from a `git archive` of
088736c9 into a scratch tree. **Result: PASS**, with `fn-panel-data` and every
other island reported as "numeric content identical". No entry was added to
`ADDITIVE`.

### Proved both ways, on rendered reports

Two reports, both generated to the scratchpad only, neither written into the
repo or any project folder.

- **Gated: the IPK fixture itself.** `detect_instrument_gating()` reports
  `gated = TRUE`, mode nested, no breaches. Its generator routes the attitude
  question on awareness, and its purchase picks sit inside awareness. The
  report renders the nested notice, keeps the chain toggle active on load, and
  the mini funnel keeps its nested series.
- **Ungated: a scratch copy of the fixture.** The three fixture files were
  copied to the scratchpad and the data workbook rebuilt from scratch with
  `turas_saveWorkbook()`, never `loadWorkbook()` plus save. 135 attitude cells
  that the gated instrument had left at no-opinion for brands the respondent
  never named were set to Love, a fixed every-twentieth selection. The console
  then reports "135 respondent rows across 15 brands" at the consideration
  stage, the report renders the ungated notice, carries **no** chain button,
  and defaults to each stage on its own.

### QA scripts

Run against both reports.

| Script | Gated | Ungated |
|---|---|---|
| `drive_funnel_base.py` | 99 checks, 0 failed | 79 checks, 0 failed |
| `drive_overview.py` | 60 checks, 0 failed | 58 checks, 0 failed |
| `drive_destinations.py` | 353 checks, 0 failed | 353 checks, 0 failed |
| `drive_two_categories.py` | 15 checks, 0 failed | 15 checks, 0 failed |
| `drive_save_roundtrip.py` | 113 checks, 0 failed | 113 checks, 0 failed |
| `reachability_check.py` | PASS against the 088736c9 baseline | not applicable |

Two of them needed changing, and both changes are the gate becoming
mode-aware rather than the gate being weakened.

- `drive_funnel_base.py` asserted the nested view was active on load and that
  four toggles existed. It now reads the gating flag from the payload, expects
  the right default and the right toggle set for each mode, checks that the
  page carries a notice whose label agrees with the payload and whose text is
  a reason rather than a label, and in the ungated mode checks that no
  rendered cell carries a chain figure of its own and that the chain view
  cannot be reached from the controls.
- `drive_overview.py` asserted the Overview payload always carries the nested
  series. It now asserts the Overview and the funnel destination **agree**
  about the mode. That check caught a real contradiction: the Overview's mini
  funnel was still drawing the nested chain on the ungated report while the
  funnel destination said the nested view was unavailable. Fixed in
  `14_summary_panel.R`, which now drops the nested series when the funnel
  reports ungated.

### Two stale claims corrected on the way

- `.panel_about$methodology_note` said Turas "refuses to render brands whose
  aggregate stage counts violate nesting". It does not, and has not since
  2026-05-24. It now states the gating finding and says non-nesting brands are
  reported as recorded.
- FUNNEL_SPEC_v2.md §3.4 said the stages were nested by construction and that
  a violation refuses with `CALC_NESTING_VIOLATED`. Rewritten to describe the
  two checks that actually run and what each one does.

### A label bug found while checking the rendered report

The generated report still said "Prefer" after the Stage 2 default changed.
`03c_funnel_panel_data.R` and `03d_funnel_output.R` each carry their own copy
of the stage-label table, both commented "must mirror
.FUNNEL_DEFAULT_LABELS", and neither did. Both corrected, and
`test_funnel_consideration_roles.R` now holds the three tables together so
they cannot drift again.

Brand suite after Stage 3: **FAIL 0, WARN 1, SKIP 2, PASS 3360**. Node gate
suite: 23, 40 and 116 assertions, 0 failed.
