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
