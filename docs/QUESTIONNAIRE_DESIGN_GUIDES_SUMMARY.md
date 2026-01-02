# Questionnaire Design Guides - Delivery Summary

**Created:** December 31, 2024
**Location:** `/questionnaire_design_guides/`
**Total Documents:** 7 files (1 index + 6 module guides)
**Total Size:** ~96 KB

---

## What Was Created

I've created comprehensive questionnaire design guides for 6 TURAS modules that require careful survey design. Each guide is written in accessible language for research professionals and focuses on **preventing bad data through smart design**.

---

## Philosophy: Prevention Over Repair

**Core Principle:** Bad data in = bad analysis out

These guides exist because:
- Most analysis failures stem from questionnaire design errors
- It's cheaper to fix survey design than to rerun studies
- Many "analysis problems" are actually data collection problems
- Researchers often don't know what the analysis needs

**Focus:** Practical, actionable guidance on what works and what doesn't.

---

## Files Created

### Index Document
📄 **00_INDEX_Questionnaire_Design_Guides.md** (12 KB)
- Overview of all guides
- Universal design principles
- Decision trees for choosing guides
- Common mistakes across all methods
- Mobile optimization standards
- Quality check protocols

### Module-Specific Guides

1. **01_KeyDriver_Questionnaire_Guide.md** (12 KB)
   - **Focus:** Rating scales, consistent measurement
   - **Key Issue:** Don't ask "importance" - derive it from correlations
   - **Sample Minimum:** 200 respondents
   - **Survey Length:** 10-12 minutes

2. **02_CatDriver_Questionnaire_Guide.md** (13 KB)
   - **Focus:** Categorical outcomes, balanced categories
   - **Key Issue:** Ensure 50+ cases per outcome category
   - **Sample Minimum:** 200+ (50+ per category)
   - **Survey Length:** 10-15 minutes

3. **03_Conjoint_Questionnaire_Guide.md** (15 KB)
   - **Focus:** Attribute selection, level design, choice tasks
   - **Key Issue:** 4-5 attributes with 2-4 levels each
   - **Sample Minimum:** 200 (300+ recommended)
   - **Survey Length:** 15-20 minutes

4. **04_MaxDiff_Questionnaire_Guide.md** (15 KB)
   - **Focus:** Item comparability, experimental design
   - **Key Issue:** All items must be on same dimension
   - **Sample Minimum:** 150 (200+ for HB)
   - **Survey Length:** 10-12 minutes

5. **05_Pricing_Questionnaire_Guide.md** (15 KB)
   - **Focus:** Van Westendorp PSM, Gabor-Granger
   - **Key Issue:** Use exact standard wording for Van Westendorp
   - **Sample Minimum:** 300 respondents
   - **Survey Length:** 10-15 minutes

6. **06_Segment_Questionnaire_Guide.md** (14 KB)
   - **Focus:** Variable selection, attitudinal batteries
   - **Key Issue:** Segment on attitudes/behaviors, not just demographics
   - **Sample Minimum:** 500+ for 4-5 segments
   - **Survey Length:** 15-20 minutes

---

## What Each Guide Contains

### Standard Structure (All Guides)

**Section 1: What The Analysis Needs**
- Data requirements explained
- Question types that work
- Sample size minimums
- Survey length targets

**Section 2: The Golden Rules**
- 3-4 non-negotiable principles
- Critical design requirements
- Core assumptions

**Section 3: Question Design**
- ✅ DO: Best practices with examples
- ❌ DON'T: Common mistakes to avoid
- Good vs. Bad question comparisons
- Real survey snippets

**Section 4: Common Pitfalls & Solutions**
- Actual failure modes
- Why they happen
- How to prevent them
- Practical fixes

**Section 5: Real-World Example**
- Complete survey design
- Business context
- Full question flow
- Expected results

**Section 6: Quick Reference Checklist**
- Pre-launch validation points
- Design specification checklist
- Quality control steps

---

## Key Themes Across All Guides

### 1. Consistent Scales Matter
**Problem:** Mixing 1-5 and 1-10 scales confuses respondents and requires data transformation

**Solution:**
- Pick one scale (1-10 recommended for most)
- Use same scale throughout drivers
- Consistent anchor labels

**Impact:** Reduces error, improves data quality, simplifies analysis

---

### 2. Specificity Beats Generality
**Problem:** Vague questions ("quality") mean different things to different people

**Solution:**
- "Product lasts 5+ years" not "durability"
- "Response within 24 hours" not "service"
- Concrete, measurable attributes

**Impact:** More reliable data, clearer insights

---

### 3. Question Order Affects Responses
**Problem:** Asking overall satisfaction first "contaminates" driver ratings (halo effect)

**Solution:**
- Specific drivers BEFORE general outcome
- Behaviors BEFORE attitudes
- Demographics LAST (unless screening)

**Impact:** Cleaner driver analysis, less bias

---

### 4. Sample Size Is Non-Negotiable
**Problem:** Undersized samples produce unstable, unreliable results

**Solution:**
- KeyDriver/CatDriver: 200+ minimum
- Conjoint/MaxDiff: 200-300+
- Pricing: 300+
- Segment: 500+ for 4-5 segments

**Impact:** Stable estimates, reliable insights, defensible conclusions

---

### 5. Mobile Optimization Is Critical
**Problem:** 60-70% use mobile; poor mobile design = dropouts, errors

**Solution:**
- Vertical layouts (no side-by-side tables)
- Large touch targets (44x44px minimum)
- Readable fonts (14-16pt)
- Single-column grids

**Impact:** Higher completion rates, better data quality

---

## Most Important Warnings

### ⚠️ For KeyDriver: Never Ask "Importance"

**Why This Is Critical:**

❌ **Bad Approach:**
```
How important is product quality? (1-10)
How important is price? (1-10)
How important is service? (1-10)

Result: Everyone rates 8-10 for everything
→ No variation
→ Can't determine actual importance
```

✅ **Correct Approach:**
```
How satisfied are you with product quality? (1-10)
How satisfied are you with price? (1-10)
How satisfied are you with service? (1-10)

Result: Actual variation in responses
→ Derive importance from correlations with outcome
→ Reveals what truly drives satisfaction
```

**Business Impact:** Using "importance" questions wastes survey space and produces misleading priorities.

---

### ⚠️ For CatDriver: Categories Must Be Balanced

**Why This Is Critical:**

❌ **Bad Distribution:**
```
Purchase Intent:
- Will Buy: 92%
- Won't Buy: 8%

→ Can't model with only 8% in one category
→ Need minimum 50 cases per category
```

✅ **Good Distribution:**
```
Purchase Intent:
- Will Buy: 40%
- Maybe: 35%
- Won't Buy: 25%

→ All categories well-represented
→ Modeling possible
```

**Business Impact:** Imbalanced categories make analysis impossible. Must oversample rare categories or combine categories.

---

### ⚠️ For Conjoint: Don't Exceed 5 Attributes

**Why This Is Critical:**

❌ **Too Many:**
```
8 attributes × 3 levels each
→ Respondent cognitive overload
→ Random clicking
→ Unreliable utilities
```

✅ **Right Amount:**
```
4 attributes × 3 levels each
→ Manageable for respondents
→ Sufficient trade-offs
→ Stable estimates
```

**Business Impact:** Too many attributes = wasted money on unusable data.

---

### ⚠️ For MaxDiff: All Items Must Be Comparable

**Why This Is Critical:**

❌ **Not Comparable:**
```
Which is most important?
☐ Water resistance (feature)
☐ Apple brand (brand)
☐ $999 price (price)
☐ I use it daily (behavior)

→ Comparing apples to oranges
→ Meaningless rankings
```

✅ **Comparable:**
```
Which feature is most important?
☐ Water resistance
☐ Fast charging
☐ Premium camera
☐ Long battery life

→ All are features
→ Valid comparison
```

**Business Impact:** Mixed item types produce nonsensical rankings.

---

### ⚠️ For Pricing: Use Exact Van Westendorp Wording

**Why This Is Critical:**

❌ **Modified Wording:**
```
"At what price would you think it's overpriced?"
→ Different interpretation than standard
→ Invalidates Van Westendorp methodology
```

✅ **Standard Wording:**
```
"At what price would you consider [Product] to be so expensive
that you would not consider buying it?"
→ Validated phrasing
→ Methodology works correctly
```

**Business Impact:** Changing wording breaks the analytical framework.

---

### ⚠️ For Segment: Don't Segment on Demographics Alone

**Why This Is Critical:**

❌ **Demographics Only:**
```
Segments:
- Young (18-34)
- Middle (35-54)
- Older (55+)

→ Tells you WHO they are
→ Doesn't explain WHY behavior differs
→ Limited actionability
```

✅ **Attitudes/Behaviors:**
```
Segments:
- Price-Conscious Traditionalists
- Tech-Savvy Maximizers
- Convenience Seekers

→ Explains WHY they act differently
→ Profile with demographics afterward
→ Highly actionable
```

**Business Impact:** Demographic-only segments miss the insights that drive strategy.

---

## Pilot Testing Protocol

**Every Guide Recommends Pilot Testing:**

### Soft Launch (n=50-100):

**Check:**
1. Technical functionality (skip logic, data export)
2. Completion time (target: 15 minutes max)
3. Question clarity (check open-ends for confusion)
4. Response variation (no straight-lining, adequate spread)
5. Preliminary analysis (can you run it?)

**Red Flags:**
- Completion rate <70%
- Median time >20 minutes
- >80% give same answer to key questions
- Respondents confused (based on comments)
- Can't produce expected analysis output

**Actions:**
- Revise confusing questions
- Drop non-varying items
- Adjust survey length
- Fix technical issues
- Re-pilot if major changes

---

## Integration Guidance

**Many projects combine methods:**

### Example: New Product Launch

**Integrated Survey Design:**

**PART 1: Product Concept & Category**
- Screening (category usage)
- Concept description

**PART 2: Feature Prioritization (MaxDiff)**
- 15 features, 12 best/worst tasks
- Identifies top priorities

**PART 3: Conjoint Choice Tasks**
- 4 attributes (from MaxDiff winners)
- 12 choice sets
- Includes price as attribute

**PART 4: Pricing Deep-Dive**
- Van Westendorp for optimal price range
- Purchase intent at specific prices

**PART 5: Segmentation**
- 15 attitudinal statements
- Usage behaviors
- Demographics

**Total Length:** ~22 minutes
→ May need to split into 2 surveys or shorten

**Use Multiple Guides:**
- MaxDiff guide for Part 2
- Conjoint guide for Part 3
- Pricing guide for Part 4
- Segment guide for Part 5

---

## Quality Assurance Checklist

**Before Fielding ANY Survey:**

**Design Validation:**
- [ ] Read relevant questionnaire guide(s)
- [ ] Followed all "Golden Rules"
- [ ] Avoided all "DON'T" examples
- [ ] Sample size meets minimum
- [ ] Survey length ≤ 15-20 minutes

**Technical Testing:**
- [ ] Tested on mobile (iPhone + Android)
- [ ] Tested on desktop (Chrome, Safari, Firefox)
- [ ] All skip logic works
- [ ] Data exports correctly
- [ ] No broken elements

**Pilot Results:**
- [ ] Completion rate >70%
- [ ] Adequate response variation
- [ ] Can run preliminary analysis
- [ ] No major confusion/issues
- [ ] Timing acceptable

**Final Checks:**
- [ ] Attention checks included (1-2)
- [ ] Progress bar working
- [ ] Privacy/consent included
- [ ] Thank you message set
- [ ] Data collection tracking enabled

---

## Common Multi-Method Combinations

| Primary Goal | Methods Combined | Total Sample | Survey Length |
|--------------|------------------|--------------|---------------|
| Product Development | Conjoint + Pricing | 300+ | 18-20 min |
| Brand Health | KeyDriver + Segment | 500+ | 15-18 min |
| Customer Insights | CatDriver + Segment | 600+ | 18-20 min |
| Feature Prioritization | MaxDiff + Segment | 400+ | 15-17 min |
| Complete Product Optimization | MaxDiff + Conjoint + Pricing | 400+ | 25 min (split into 2 surveys) |

---

## File Locations & Organization

**Main Folder:**
```
/Users/duncan/.claude-worktrees/Turas/adoring-zhukovsky/questionnaire_design_guides/
```

**Files:**
```
questionnaire_design_guides/
├── 00_INDEX_Questionnaire_Design_Guides.md    # Start here
├── 01_KeyDriver_Questionnaire_Guide.md
├── 02_CatDriver_Questionnaire_Guide.md
├── 03_Conjoint_Questionnaire_Guide.md
├── 04_MaxDiff_Questionnaire_Guide.md
├── 05_Pricing_Questionnaire_Guide.md
└── 06_Segment_Questionnaire_Guide.md
```

**Total:** 96 KB (lightweight, easy to share/print)

---

## How to Use These Guides

### For New Projects

**Step 1: Identify Methods Needed**
- Review business objectives
- Determine which analyses required
- Check index for relevant guides

**Step 2: Read Applicable Guides**
- Read completely before drafting survey
- Note all "Golden Rules"
- Review examples carefully

**Step 3: Design Survey**
- Follow guide structure
- Use recommended question formats
- Incorporate all checklists

**Step 4: Review Against Checklist**
- Validate against "Quick Reference"
- Ensure sample size adequate
- Confirm survey length reasonable

**Step 5: Pilot Test**
- Soft launch n=50-100
- Check all quality metrics
- Adjust as needed

**Step 6: Full Launch**
- Monitor data quality during field
- Flag speeders/straight-liners
- Track completion rates

---

### For Ongoing Tracking

**Establish Standard:**
- Design wave 1 using guides
- Document all design decisions
- Create template for future waves

**Wave-to-Wave Consistency:**
- Keep core questions identical
- Document any changes with rationale
- Maintain same sample quotas
- Use same question order

**Continuous Improvement:**
- Review each wave for issues
- Refine questions based on learnings
- Update templates accordingly

---

## Training & Onboarding

### For Research Team

**Onboarding New Researchers:**
1. Provide all 7 guides
2. Review 1-2 guides per method they'll use
3. Practice survey design exercise
4. Review pilot data interpretation

**Ongoing Reference:**
- Keep guides accessible (shared drive)
- Reference during survey design
- Use checklists for QA reviews
- Update based on learnings

**Quality Gates:**
- All surveys reviewed against guides before fielding
- Pilot testing mandatory for new designs
- Senior review for high-stakes projects

---

## Return on Investment

**Why These Guides Save Money:**

**Scenario: $50,000 research project**

**Without Guides:**
- Survey designed with mixed scales
- Insufficient sample (150 vs. 300 needed)
- Wrong question order (outcome before drivers)
- **Result:** Unusable data, $50K wasted, must rerun study

**With Guides:**
- Correct design from start
- Adequate sample
- Clean data
- **Result:** Successful project, actionable insights, $50K well-spent

**ROI:** Preventing one major design error pays for entire guide creation and review time 100x over.

---

## Summary

**What You Have:**
- 7 comprehensive questionnaire design guides
- Prevention-focused, practical guidance
- Real-world examples and warnings
- Complete checklists for quality assurance

**How to Use Them:**
- Read before designing surveys
- Follow all "Golden Rules"
- Use checklists for validation
- Pilot test everything

**Expected Outcome:**
- Higher quality data
- Fewer analysis failures
- More actionable insights
- Better return on research investment

**Bottom Line:** These guides exist to prevent the most common cause of research failure: collecting data that can't answer your business questions.

---

*Created by Claude Code Analysis - December 31, 2024*
