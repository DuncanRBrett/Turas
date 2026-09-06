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
