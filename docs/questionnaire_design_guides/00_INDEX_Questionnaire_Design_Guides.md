# TURAS Questionnaire Design Guides - Index

**The Research LampPost (Pty) Ltd**
**Purpose:** Prevent bad data through smart questionnaire design
**Audience:** Research professionals designing surveys for TURAS analysis

---

## About These Guides

These guides ensure your surveys collect clean, analyzable data for TURAS modules. Each guide focuses on **preventing design mistakes** that lead to unusable data, analysis failures, or misleading results.

**Philosophy:** Bad data in = bad analysis out. These guides help you get it right the first time.

---

## Quick Navigation

| Module | Guide | Key Focus |
|--------|-------|-----------|
| **KeyDriver** | [Link](01_KeyDriver_Questionnaire_Guide.md) | Rating scales, consistent measurement, avoiding "importance" questions |
| **CatDriver** | [Link](02_CatDriver_Questionnaire_Guide.md) | Categorical outcomes, balanced categories, mixed driver types |
| **Conjoint** | [Link](03_Conjoint_Questionnaire_Guide.md) | Attribute selection, level design, choice task construction |
| **MaxDiff** | [Link](04_MaxDiff_Questionnaire_Guide.md) | Item comparability, task design, experimental balance |
| **Pricing** | [Link](05_Pricing_Questionnaire_Guide.md) | Van Westendorp questions, purchase intent, price range selection |
| **Segment** | [Link](06_Segment_Questionnaire_Guide.md) | Variable selection, attitudinal batteries, outcome measures |

---

## Guide Structure

Each guide follows the same format for easy reference:

### 1. What The Analysis Needs
- Data requirements
- Question types that work
- Sample size minimums

### 2. The Golden Rules
- 3-4 critical design principles
- Non-negotiable requirements
- Common assumptions

### 3. Question Design Best Practices
- ✅ DO: Recommended approaches
- ❌ DON'T: Common mistakes
- Examples of good vs. bad questions

### 4. Common Pitfalls & Solutions
- Design mistakes and how to avoid them
- Real-world failure examples
- Practical fixes

### 5. Real-World Example
- Complete survey design
- Business context
- Full question flow

### 6. Quick Reference Checklist
- Pre-launch validation
- Quality checks
- Design specifications

---

## Critical Design Principles (All Modules)

### Universal Best Practices

**1. Use Consistent Scales**
- Don't mix 1-5 and 1-10 scales
- Keep anchors consistent (e.g., all "Dissatisfied to Satisfied")
- Use same scale for all items in a battery

**2. Ask Specific Questions**
- "Product quality" is better than "Quality"
- "Response time to customer inquiries" is better than "Service"
- Concrete beats abstract

**3. Test for Variation**
- Pilot survey with 50-100 respondents
- Check that responses spread across scales
- If >80% select same answer, revise question

**4. Question Order Matters**
- Ask specific before general (drivers before outcomes)
- Behaviors before attitudes (when both present)
- Demographics last (unless used for screening)

**5. Sample Size Matters**
- More complex analysis = larger sample needed
- Account for subgroups and segments
- See individual guides for module-specific minimums

---

## By Research Objective

### "Which factors drive satisfaction/loyalty?"
→ **KeyDriver** or **CatDriver** Guide
- KeyDriver: Continuous outcomes (1-10 satisfaction)
- CatDriver: Categorical outcomes (High/Medium/Low segments)

### "What features should we prioritize?"
→ **MaxDiff** Guide
- Ranking 10-30 items by importance/preference
- Best/worst choice tasks

### "How should we price our product?"
→ **Pricing** Guide
- Van Westendorp PSM method
- Gabor-Granger purchase intent
- Willingness-to-pay estimation

### "What product configuration will win?"
→ **Conjoint** Guide
- Feature trade-offs
- Price sensitivity
- Market share simulation

### "Who are our different customer groups?"
→ **Segment** Guide
- Attitudinal/behavioral clustering
- Persona development
- Targeting strategy

---

## By Question Type

### Rating Scales (1-10, 1-5)
**Use for:**
- KeyDriver (outcome + drivers)
- CatDriver (drivers)
- Segment (attitudinal variables)
- Conjoint/MaxDiff (follow-up questions)

**Best Practices:**
- Prefer 1-10 for more granularity
- Consistent anchors throughout
- Label endpoints clearly

### Categorical Questions
**Use for:**
- CatDriver (outcome variable)
- Segment (behavioral variables)
- Conjoint (attributes)
- Profiling/demographics

**Best Practices:**
- Mutually exclusive categories
- Comprehensive option list
- "Other (specify)" when appropriate

### Choice Tasks
**Use for:**
- Conjoint (product profiles)
- MaxDiff (best/worst from set)

**Best Practices:**
- Use experimental design software
- Randomize task order
- Include progress indicators

### Open-Ended Numeric
**Use for:**
- Pricing (Van Westendorp)
- Spending/usage estimates

**Best Practices:**
- Provide reasonable bounds
- Show currency symbol ($)
- Validate entries (no negative numbers)

---

## Common Mistakes Across All Methods

### Mistake #1: Survey Too Long
**Problem:** Respondent fatigue → random clicking, dropouts

**Symptoms:**
- Completion rates <70%
- Straight-lining (all 5s or all 8s)
- Fast completions (<50% of median time)

**Solutions:**
- Target 15 minutes max for most studies
- Cut unnecessary questions ruthlessly
- Use batteries/grids for efficiency
- Pilot test actual completion time

---

### Mistake #2: Mixed Scales
**Problem:** Respondents confused, data requires transformation

**Example:**
```
Q1. Satisfaction (1-10)
Q2. Quality (1-5) ❌
Q3. Value (0-100) ❌
```

**Solution:**
```
Q1. Satisfaction (1-10)
Q2. Quality (1-10) ✓
Q3. Value (1-10) ✓
```

---

### Mistake #3: Leading/Biased Questions
**Problem:** Inflates scores, reduces variation, distorts analysis

**Bad:**
```
"Our award-winning customer service"
"Industry-leading product quality"
```

**Good:**
```
"Customer service"
"Product quality"
```

---

### Mistake #4: Asking "Importance" Directly
**Problem:** (KeyDriver especially)
- Everyone rates everything "important"
- No discrimination
- Stated ≠ actual importance

**Bad:**
```
How important is product quality? (1-10)
How important is price? (1-10)
How important is service? (1-10)

→ All get rated 8-10
```

**Good:**
```
How satisfied are you with product quality? (1-10)
How satisfied are you with price? (1-10)
How satisfied are you with service? (1-10)

→ Actual variation, derived importance from correlations
```

---

### Mistake #5: Insufficient Sample Size
**Problem:** Unstable estimates, unreliable results, can't detect effects

**Minimums by Module:**
- KeyDriver: 200+
- CatDriver: 200+ (50+ per outcome category)
- Conjoint: 200+ (300+ preferred)
- MaxDiff: 150+ (200+ for HB)
- Pricing: 300+
- Segment: 500+ for 4-5 segments

**Rule of Thumb:** When in doubt, get more respondents.

---

## Mobile Optimization (Critical for All)

**60-70% of respondents use mobile devices.**

**Mobile-Friendly Design:**

✅ **DO:**
- Vertical layouts (stacked options, not side-by-side)
- Large, touch-friendly buttons (44x44px minimum)
- Readable fonts (14-16pt minimum)
- Short questions (≤15 words)
- Progress indicators
- Single-column grids on mobile

❌ **DON'T:**
- Small text requiring zoom
- Side-by-side comparison tables (too wide)
- Tiny radio buttons (hard to tap)
- Dense grids (>5 items on mobile)

**Test on Actual Devices:**
- iPhone (various sizes)
- Android phones
- Tablets
- Different orientations

---

## Data Quality Checks

### Include in Every Survey

**1. Attention Checks (1-2 per survey)**
```
"For quality purposes, please select '8' for this question."

or

[Show obviously superior option in choice task]
```

**2. Speeders (too fast)**
- Flag completions <50% of median time
- Review for quality before including in analysis

**3. Straight-Liners (no variation)**
- All 5s, all 8s, all middle
- Check for respondent engagement

**4. Impossible Patterns**
- Logically inconsistent answers
- Contradictory responses

**Quality Thresholds:**
- Target >85% valid completion rate
- Remove <5% for quality issues
- Document all exclusions

---

## Pilot Testing Checklist

**Before Full Launch (n=50-100):**

**Technical:**
- [ ] Survey loads on mobile and desktop
- [ ] All skip logic works correctly
- [ ] Data exports properly
- [ ] Completion time acceptable (15 min max)

**Question Quality:**
- [ ] No confusing questions (check open-ends)
- [ ] Adequate variation in responses
- [ ] Scales work as intended
- [ ] No unexpected missing data

**Analysis Readiness:**
- [ ] Can run preliminary analysis
- [ ] Data structure matches expectations
- [ ] Variables have correct format
- [ ] Segmentation variables discriminate

**Adjustments:**
- [ ] Revise confusing questions
- [ ] Drop non-varying items
- [ ] Add missing drivers/attributes
- [ ] Adjust sample quotas if needed

---

## When to Consult Multiple Guides

**Many projects combine methods:**

### Brand Health Tracking
→ **KeyDriver** (satisfaction drivers) + **Segment** (customer types)

### Product Development
→ **Conjoint** (feature trade-offs) + **Pricing** (optimal price) + **MaxDiff** (feature prioritization)

### Customer Insights
→ **Segment** (who are they) + **CatDriver** (what drives their choices)

### Pricing Strategy
→ **Pricing** (price sensitivity) + **Conjoint** (price as attribute in trade-offs)

**Integrated Survey Design:**
- Combine sections from multiple guides
- Ensure total length reasonable (20 min max)
- Consider splitting into multiple shorter surveys if needed
- Maintain quality standards from each guide

---

## Resource Quick Links

### External Tools & Software

**Experimental Design:**
- Sawtooth Software (conjoint/MaxDiff design)
- R packages: `AlgDesign`, `support.CEs`, `choiceDes`
- Lighthouse Studio (commercial)

**Survey Platforms:**
- Qualtrics (enterprise)
- SurveyMonkey (mid-market)
- Google Forms (basic)
- Alchemer (mid-market)

**Sample Calculators:**
- Sample size calculators for each method
- Power analysis tools
- Margin of error calculators

---

## Getting Help

### Before Fielding Your Survey

**Review Checklist:**
1. Read relevant guide(s) thoroughly
2. Complete design checklist from guide
3. Pilot test with 50-100 respondents
4. Review pilot data for quality
5. Make adjustments before full launch

**When to Seek Expert Review:**
- First time using a method
- High-stakes project (large budget/critical decision)
- Complex integrated design
- Unusual category or population
- Pilot reveals unexpected issues

**Contact:** The Research LampPost for survey design review and consultation

---

## Module Comparison Table

| Aspect | KeyDriver | CatDriver | Conjoint | MaxDiff | Pricing | Segment |
|--------|-----------|-----------|----------|---------|---------|---------|
| **Outcome Type** | Continuous (1-10) | Categorical | Choice | Preference | Willingness-to-pay | Customer groups |
| **Driver/Input Type** | Rating scales | Mixed | Attributes | Items list | Price points | Attitudes/behaviors |
| **# Questions** | 10-20 | 10-20 drivers | 10-15 tasks | 8-15 tasks | 4-10 | 15-30 |
| **Min Sample** | 200 | 200 | 200 | 150 | 300 | 500 |
| **Survey Length** | 10-12 min | 10-15 min | 15-20 min | 10-12 min | 10-15 min | 15-20 min |
| **Question Order** | Drivers→Outcome | Drivers→Outcome | Tasks only | Tasks only | Product→Price | Behavior→Attitude |
| **Mobile Critical?** | Important | Important | Critical | Critical | Important | Important |
| **Design Software?** | No | No | Yes | Yes | No | No |

---

## Summary Decision Tree

```
START: What do you need to know?

├─ Which factors drive my outcome?
│  ├─ Outcome is continuous (1-10 scale)
│  │  └─ Use KeyDriver Guide
│  └─ Outcome is categorical (High/Med/Low)
│     └─ Use CatDriver Guide
│
├─ What's the optimal product configuration?
│  └─ Use Conjoint Guide
│
├─ How should I prioritize features/benefits?
│  └─ Use MaxDiff Guide
│
├─ What should I charge?
│  └─ Use Pricing Guide
│
└─ Who are my different customer types?
   └─ Use Segment Guide
```

---

## Bottom Line

**These guides exist to prevent the #1 cause of analysis failure: bad questionnaire design.**

**Three Universal Rules:**
1. **Read the guide before designing** - Don't guess
2. **Follow the checklists** - They're based on real failures
3. **Pilot test everything** - Catch problems when they're cheap to fix

**Remember:** TURAS analysis is only as good as the data you collect. Invest time in questionnaire design and you'll save weeks in analysis headaches.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*
*Last Updated: December 2024*
