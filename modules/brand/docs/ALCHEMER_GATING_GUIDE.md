# Gating the funnel questions

**For whoever programmes the next brand survey.** Two pages. Read it before
you build Section 4.

A funnel is a claim that people move through stages in order. Turas can only
draw that claim honestly if the questionnaire enforced the order. If every
question was asked of everyone, the stages are four separate measures that
happen to be printed next to each other, and Turas will say so on the face of
the report instead of drawing a funnel.

That is not a threat. It is a choice you are making at programming time, and
this page is here so you make it deliberately.

---

## What Turas does with what you give it

`detect_instrument_gating()` in `modules/brand/R/03a_funnel_derive.R` counts
respondents who sit at a later stage without the earlier one. Routing makes
such a row impossible, so a single one is proof the questionnaire did not
route.

| You programmed | The report you get |
|---|---|
| Gated questions, no impossible rows | The nested funnel, with a line saying the questionnaire routed the questions |
| Any question asked of everyone | The stages as separate measures, each on its own base, with conversion ratios beside them, and a line saying why the funnel view is unavailable |

The second report is not a broken report. It is a correct one. But it is not
the one people picture when they ask for a funnel, so decide before fieldwork,
not after.

---

## The four rules

### 1. Gate attitude on awareness

Show `BRANDATT1_{CAT}_{BRAND}` only to respondents who selected that brand in
`BRANDAWARE_{CAT}`. Alchemer's built-in Show Logic on each per-brand question,
no scripting.

Asking someone how they feel about a brand they have just told you they do
not know produces an answer, and the answer is noise. Gating it also removes
the largest single source of impossible rows: on the IPK 2026 shape, this one
question accounts for most of them.

### 2. Gate the longer purchase window on awareness

Show only the brands the respondent named in `BRANDAWARE_{CAT}` as options in
`BRANDPEN1_{CAT}`. Alchemer option piping, no scripting.

A respondent who buys a brand they cannot recall is possible in life and
common in data, and it is exactly the row that breaks a nested funnel. If you
want to measure it deliberately, that is a different question and it belongs
in the ad-hoc section, not in the funnel battery.

### 3. Keep the target window gated on the longer one

`BRANDPEN2_{CAT}` pipes its options from the answers to `BRANDPEN1_{CAT}`.
The template already says to do this ("ideally via Alchemer piping"). Make it
mandatory, not ideal. "Bought in the last three months but not in the last
twelve" is not a finding, it is a routing failure.

### 4. Do not gate purchase on attitude

Turas does not check that pair and you should not build it. People buy brands
they are lukewarm about, all the time, and that gap between preference and
purchase is one of the more useful things the funnel shows. Gating it away
deletes the finding.

---

## What gating costs you

Say it out loud before you commit, because you cannot recover it afterwards.

**You lose the attitude distribution for brands people do not recall.** The
ungated attitude question is the Romaniuk / Ehrenberg-Bass approach, and it is
in the CBM template this study was built on (`Better Brand Health
CBMquestionnaireTemplate.docx` in this directory) for a good reason: the "no
opinion / I don't know this brand" option is itself a measure, and the split
between "never heard of it" and "heard of it, no view" is real information
about a small brand's memory footprint.

If that distribution matters more to the client than a nested funnel, do not
gate, and tell them the funnel will be reported as separate measures. Both are
defensible. What is not defensible is drawing a nested funnel from an ungated
instrument and letting the reader assume the ordering was measured.

**You lose nothing else.** Mental Availability, which is where the
Ehrenberg-Bass memory-footprint story properly lives, uses the CEP battery,
not the attitude question, and the CEP battery is unaffected by any of this.

**A middle path exists.** Gate the funnel battery and add one ungated
attitude question on the focal brand alone, in the ad-hoc section. You get the
routed funnel and the unaided-view read on the brand that matters most, at the
cost of one question.

---

## Checking it worked, before fieldwork closes

Run the brand module on the soft-launch data and read the console. An ungated
instrument prints:

```
=== TURAS BRAND: FUNNEL NOT GATED ===
Respondents at a later stage without the earlier one:
  consideration    not aware    ...
```

naming the stage, the count and the number of brands. If you meant to gate and
you see that box, the logic is not doing what you think it is. Fix it while
you still have a live survey.

---

## Related

- `ALCHEMER_PROGRAMMING_SPEC.md` sections 4a to 4d, the questions themselves.
  Its section 4a currently prescribes the ungated attitude question; this page
  is the decision that overrides it when you want a measured funnel.
- `FUNNEL_SPEC_v2.md` section 3.4, what Turas checks and what each report
  looks like.
- `FUNNEL_SPEC_v2.md` section 3.1a, which attitude levels count as
  consideration. Note that a six-level scale must declare itself on the
  OptionMap sheet or the price-conditional level is invisible.
