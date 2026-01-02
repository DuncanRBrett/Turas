# KeyDriver Analysis: Questionnaire Design Guide

**Purpose:** Ensure your survey collects clean data for correlation-based driver analysis

---

## What KeyDriver Analysis Needs

KeyDriver identifies which factors have the strongest relationship with your key outcome metric (satisfaction, loyalty, NPS, etc.). To work properly, it needs:

1. **One clear outcome variable** - What you're trying to understand
2. **Multiple potential driver variables** - Factors that might influence the outcome
3. **Rating scales** - Numeric data showing variation
4. **Sufficient sample size** - Enough respondents to detect relationships

---

## The Golden Rules

### Rule #1: Your Outcome Must Vary
**Bad:**
- 95% of respondents rate overall satisfaction 8-10
- No variation = no ability to find drivers

**Good:**
- Responses spread across the scale (some 3s, some 5s, some 8s, some 10s)
- Natural variation lets you see what drives high vs. low scores

**How to Achieve:**
- Don't pre-screen for only satisfied customers
- Use full scale range (1-10, not 7-10)
- Ask general population, not just loyalists

---

### Rule #2: Use Numeric Rating Scales

**Best Practices:**
- **1-10 scale** (most common, easy for respondents)
- **1-5 scale** (works, but less variation)
- **0-10 scale** (good for NPS-style questions)

**What Works:**
```
On a scale of 1-10, where 1 is "Very Dissatisfied" and 10 is "Very Satisfied,"
how satisfied are you with [attribute]?

○ 1 - Very Dissatisfied
○ 2
○ 3
○ 4
○ 5
○ 6
○ 7
○ 8
○ 9
○ 10 - Very Satisfied
```

**What Doesn't Work:**
- Yes/No questions (no variation to correlate)
- Select all that apply (not continuous)
- Open-ended text (not numeric)
- Unordered categories (Red/Blue/Green)

---

### Rule #3: Ask About the Same Topic

**Good - Coherent Set of Drivers:**
```
Outcome: Overall satisfaction with hotel stay

Drivers (all about hotel experience):
- Cleanliness of room
- Friendliness of staff
- Quality of breakfast
- Speed of check-in
- Comfort of bed
- Value for money
```

**Bad - Mixed Topics:**
```
Outcome: Overall satisfaction with hotel

Drivers (all over the map):
- Cleanliness of room
- How often do you travel for business? ❌ (not an attribute)
- Your age ❌ (demographic, not experience driver)
- Friendliness of staff
- Brand awareness ❌ (different construct)
```

**Why:** KeyDriver correlates ratings. Mixing apples (experience) and oranges (demographics) produces meaningless results.

---

### Rule #4: Include 8-20 Driver Questions

**Too Few Drivers (< 5):**
- Might miss the real drivers
- Limited insight value
- Could have done this in Excel

**Sweet Spot (8-15 drivers):**
- Comprehensive coverage
- Clear importance rankings
- Manageable for respondents
- Statistically robust

**Too Many Drivers (> 25):**
- Respondent fatigue
- Some drivers likely redundant
- Consider if you really need all of them

---

## Question Writing Tips

### ✅ DO: Use Consistent Scale Anchors

**Good:**
```
All questions use same 1-10 scale:
1 = Very Dissatisfied
10 = Very Satisfied
```

**Bad:**
```
Question 1: 1-10 (Dissatisfied to Satisfied)
Question 2: 1-5 (Poor to Excellent) ❌ Different scale
Question 3: 0-100 (Low to High) ❌ Different scale
```

**Why:** Mixed scales confuse respondents and require transformation for analysis.

---

### ✅ DO: Be Specific and Measurable

**Good:**
- "Speed of response to my inquiry"
- "Accuracy of information provided"
- "Ease of finding what I needed on the website"

**Bad:**
- "Quality" (too vague - quality of what?)
- "Overall experience" (too broad - that's your outcome!)
- "Everything about the service" (not measurable)

---

### ✅ DO: Use Satisfaction or Performance Ratings

**Recommended Question Formats:**

**Satisfaction Rating:**
```
How satisfied are you with [attribute]?
1 = Very Dissatisfied
10 = Very Satisfied
```

**Performance Rating:**
```
How would you rate [company] on [attribute]?
1 = Very Poor
10 = Excellent
```

**Agreement Rating:**
```
[Company] provides [attribute]
1 = Strongly Disagree
10 = Strongly Agree
```

All of these work! Pick one and stick with it.

---

### ❌ DON'T: Mix Importance and Satisfaction

**Bad Survey Design:**
```
Q1. How IMPORTANT is cleanliness? (1-10)
Q2. How SATISFIED are you with cleanliness? (1-10)
Q3. How IMPORTANT is staff friendliness? (1-10)
Q4. How SATISFIED are you with staff friendliness? (1-10)
```

**Problems:**
- Doubles survey length
- Stated importance ≠ actual importance
- Respondents rate everything "important"
- Wastes questions

**Better Approach:**
```
Just ask satisfaction ratings (Q2, Q4 above).
The analysis reveals actual importance through correlations.
```

**Why:** KeyDriver calculates importance from the data. You don't need to ask "importance" directly—it's derived from what correlates with your outcome.

---

### ❌ DON'T: Use Leading or Biased Language

**Bad:**
- "Our award-winning customer service"
- "Industry-leading product quality"
- "Unbeatable value for money"

**Good:**
- "Customer service"
- "Product quality"
- "Value for money"

**Why:** Biased wording inflates ratings and reduces variation.

---

## Sample Survey Structure

### Section 1: Outcome Question (The DV)
```
Q1. Overall, how satisfied are you with [Company/Product/Service]?

○ 1 - Very Dissatisfied
○ 2
...
○ 10 - Very Satisfied
```

### Section 2: Driver Questions (The IVs)
```
Please rate your satisfaction with each of the following aspects of [Company]:

Q2. Product quality
○ 1 - Very Dissatisfied ... ○ 10 - Very Satisfied

Q3. Customer service
○ 1 - Very Dissatisfied ... ○ 10 - Very Satisfied

Q4. Value for money
○ 1 - Very Dissatisfied ... ○ 10 - Very Satisfied

[... 8-15 driver questions total ...]
```

### Section 3: Demographics (separate section)
```
Finally, a few questions about you...

Q20. Age
Q21. Gender
Q22. Income
```

**Key:** Keep drivers separate from demographics.

---

## Common Pitfalls & How to Avoid Them

### Pitfall #1: "Everything Rates 9-10"
**Problem:** No variation in responses
**Causes:**
- Only surveying delighted customers
- Biased question wording
- Social desirability bias

**Solutions:**
- Survey broader audience (including detractors)
- Use neutral wording
- Consider anonymous surveys
- Test with real respondents

---

### Pitfall #2: "Only 3 Drivers Matter"
**Problem:** Most drivers show no correlation
**Causes:**
- Asking about unrelated topics
- Drivers don't actually vary (everyone rates them 8+)
- Sample too homogeneous

**Solutions:**
- Focus drivers on your outcome topic
- Ensure driver ratings vary
- Include range of experiences in sample

---

### Pitfall #3: "Drivers Are All Correlated"
**Problem:** All drivers correlate equally (multicollinearity)
**Causes:**
- Halo effect (overall satisfaction bleeds into everything)
- Drivers are conceptually overlapping

**Example of Overlapping Drivers:**
- "Quality of product"
- "Excellence of product" ← Same thing!
- "Product superiority" ← Still the same!

**Solutions:**
- Make drivers conceptually distinct
- Ask drivers BEFORE overall satisfaction (reduces halo)
- Use specific, granular attributes

---

## Question Order Matters

**Recommended Order:**

1. **Screening/qualification** (if needed)
2. **Driver questions** (ask specific attributes first)
3. **Outcome question** (overall satisfaction/NPS last)
4. **Demographics** (age, gender, etc.)

**Why This Order:**
- Prevents halo effect (overall satisfaction influencing driver ratings)
- Respondents think through specifics before forming overall opinion
- More accurate driver data

**Bad Order:**
```
Q1. Overall satisfaction (asked first) ❌
Q2-Q15. Driver ratings
```
→ Overall satisfaction "contaminates" driver ratings

---

## Sample Size Requirements

**Minimum Recommendations:**

| Number of Drivers | Minimum Sample | Recommended Sample |
|-------------------|----------------|-------------------|
| 5-10 drivers | 100 | 200+ |
| 10-15 drivers | 150 | 300+ |
| 15-20 drivers | 200 | 400+ |

**Why:** You need enough respondents to detect correlations reliably. Small samples produce unstable results.

**Rule of Thumb:** At least 10-15 respondents per driver variable.

---

## Testing Your Questionnaire

### Pre-Launch Checklist

**Data Quality Checks:**
- [ ] All drivers use same numeric scale
- [ ] Outcome question is separate and clear
- [ ] No "Select all that apply" in driver section
- [ ] No Yes/No questions mixed with ratings
- [ ] Question order: Drivers → Outcome → Demographics

**Content Checks:**
- [ ] 8-15 driver questions (not too few, not too many)
- [ ] All drivers relate to same outcome topic
- [ ] No redundant/overlapping drivers
- [ ] No biased/leading language
- [ ] Specific, measurable attributes

**Respondent Experience:**
- [ ] Survey length reasonable (10-15 min max)
- [ ] Instructions clear
- [ ] Mobile-friendly
- [ ] Progress bar included

---

## Pilot Testing Recommendations

**Before Full Launch:**

1. **Soft Launch (n=50-100):**
   - Check for straight-lining (all 10s or all 5s)
   - Look at variation in responses
   - Identify confusing questions

2. **Preliminary Analysis:**
   - Run quick correlations
   - Ensure drivers show variation
   - Check for expected relationships

3. **Adjust if Needed:**
   - Reword confusing questions
   - Drop non-varying drivers
   - Add missing drivers

---

## Real-World Example: Good vs. Bad Design

### ❌ Bad Driver Analysis Survey

```
Q1. How important is product quality? (1-10)
Q2. Rate product quality (1-5) ← Different scale!
Q3. Overall satisfaction (1-10)
Q4. How often do you purchase? ← Not a rating!
Q5. Do you recommend us? (Yes/No) ← Not continuous!
Q6. Age bracket ← Demographic, not driver
Q7. Service quality - it's excellent, right? ← Leading!
```

**Problems:**
- Mixed scales (1-10 and 1-5)
- Asks importance (not needed)
- Mixed question types
- Demographics mixed with drivers
- Leading language
- Only 2 actual drivers!

---

### ✅ Good Driver Analysis Survey

```
SECTION 1: Your Experience with [Company]

Please rate your satisfaction with each aspect below.
(1 = Very Dissatisfied, 10 = Very Satisfied)

Q1. Product quality (1-10)
Q2. Product reliability (1-10)
Q3. Customer service responsiveness (1-10)
Q4. Staff knowledge and expertise (1-10)
Q5. Ease of ordering process (1-10)
Q6. Delivery speed (1-10)
Q7. Packaging quality (1-10)
Q8. Value for money (1-10)
Q9. Website usability (1-10)
Q10. Product selection/variety (1-10)

SECTION 2: Overall Assessment

Q11. Overall, how satisfied are you with [Company]? (1-10)

SECTION 3: About You

Q12. Age [dropdown]
Q13. Gender [select]
Q14. How long have you been a customer? [select]
```

**Why This Works:**
- Consistent 1-10 scale throughout
- 10 distinct, specific drivers
- Drivers asked before outcome
- Demographics separate
- Neutral wording
- Clear sections

---

## Quick Reference Checklist

**Before Fielding Your Survey:**

**Scale & Format:**
- ✓ All drivers use same numeric scale (1-10 recommended)
- ✓ All drivers use same question format
- ✓ Outcome uses same scale as drivers

**Content:**
- ✓ 8-15 driver questions included
- ✓ All drivers relate to outcome topic
- ✓ Drivers are specific and measurable
- ✓ No overlapping/redundant drivers
- ✓ Neutral, unbiased wording

**Structure:**
- ✓ Drivers asked BEFORE outcome
- ✓ Demographics in separate section at end
- ✓ Clear section breaks
- ✓ No mixed question types in driver section

**Sample:**
- ✓ Minimum 10-15 respondents per driver
- ✓ Sample includes range of satisfaction levels
- ✓ Not pre-screened for only satisfied customers

---

## Bottom Line

KeyDriver analysis is only as good as your survey design. The key principles:

1. **Use consistent numeric scales** (1-10 throughout)
2. **Ask 8-15 specific driver questions** about the same topic
3. **Ask drivers BEFORE the outcome** question
4. **Ensure variation** in responses (don't survey only happy customers)
5. **Keep it simple** - ratings, ratings, ratings

Follow these guidelines and you'll collect clean data that produces meaningful, actionable driver insights.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*
