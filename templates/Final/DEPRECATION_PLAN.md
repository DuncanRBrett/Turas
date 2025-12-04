# Template Deprecation Plan

**Date:** 2025-12-03
**Purpose:** Establish Final templates as single source of truth and deprecate old versions

---

## 📋 Summary

- **Final Templates (Keep):** 9 files in `/templates/Final/`
- **Old Templates (Deprecate):** 18 files in `/templates/`
- **Documentation Files (Update):** 27 files across system

---

## 🗑️ Old Templates to DEPRECATE

These files should be **removed** or **moved to archive** after validation:

### Annotated Templates (Non-Final) - DEPRECATE

```
templates/Confidence_Config_Template_Annotated.xlsx
templates/Conjoint_Config_Template_Annotated.xlsx
templates/Crosstab_Config_Template_Annotated.xlsx
templates/KeyDriver_Config_Template_Annotated.xlsx
templates/Pricing_Config_Template_Annotated.xlsx
templates/Segment_Config_Template_Annotated.xlsx
templates/Survey_Structure_Template_Annotated.xlsx
templates/Tracker_Config_Template_Annotated.xlsx
templates/Tracker_Question_Mapping_Template_Annotated.xlsx
```

**Reason:** Replaced by Final versions with comprehensive validation

---

### Non-Annotated Templates - DEPRECATE

```
templates/Confidence_Config_Template.xlsx
templates/Conjoint_Config_Template.xlsx
templates/Crosstab_Config_Template.xlsx
templates/KeyDriver_Config_Template.xlsx
templates/Pricing_Config_Template.xlsx
templates/Segment_Config_Template.xlsx
templates/Survey_Structure_Template.xlsx
templates/Tracker_Config_Template.xlsx
templates/Tracker_Question_Mapping_Template.xlsx
```

**Reason:** Less comprehensive than Final annotated versions

---

## ✅ Final Templates to KEEP (Single Source of Truth)

```
templates/Final/Confidence_Config_Template_Annotated_Final.xlsx
templates/Final/Conjoint_Config_Template_Annotated_Final.xlsx
templates/Final/Crosstab_Config_Template_Annotated_Final.xlsx
templates/Final/KeyDriver_Config_Template_Annotated_Final.xlsx
templates/Final/Pricing_Config_Template_Annotated_Final.xlsx
templates/Final/Segment_Config_Template_Annotated_Final.xlsx
templates/Final/Survey_Structure_Template_Annotated_Final.xlsx
templates/Final/Tracker_Config_Template_Annotated_Final.xlsx
templates/Final/Tracker_Question_Mapping_Template_Annotated_Final.xlsx
```

---

## 📚 Documentation Files Requiring Updates

### **HIGH PRIORITY** - Main User-Facing Documentation

1. **`/templates/README.md`**
   - Status: References old template structure
   - Action: Complete rewrite to reference Final templates only
   - Lines to update: ALL

2. **`/templates/TEMPLATE_REFERENCE_GUIDE.md`**
   - Status: References 6 templates, missing 3 (Pricing, KeyDriver, Conjoint)
   - Action: Update to include all 9 Final templates
   - Add: Pricing, KeyDriver, Conjoint sections

3. **`/templates/ANNOTATED_TEMPLATES_SUMMARY.md`**
   - Status: Claims "6 templates" but there are 9
   - Action: Update counts, add missing 3 modules
   - Update: Deliverables table, feature lists

4. **`/docs/SETUP_AND_TEMPLATES_GUIDE.md`**
   - Status: May reference old templates
   - Action: Update all template paths to `/templates/Final/`

5. **`/docs/USER_MANUAL.md`**
   - Status: Main user manual
   - Action: Update template references to Final versions

---

### **MEDIUM PRIORITY** - Module-Specific Manuals

6. **`/modules/confidence/USER_MANUAL.md`**
   - Action: Update config file examples to Final template

7. **`/modules/conjoint/USER_MANUAL.md`**
   - Action: Update config examples, add validation report notes

8. **`/modules/pricing/README.md`**
   - Action: Reference Final template, note critical fixes needed

9. **`/modules/segment/USER_MANUAL.md`**
   - Action: Reference Final template (already perfect alignment!)

10. **`/modules/tracker/README_TEMPLATES.md`**
    - Action: Update to Final templates only

11. **`/modules/tracker/USER_MANUAL.md`**
    - Action: Update template paths

12. **`/modules/tabs/USER_MANUAL.md`**
    - Action: Update Survey_Structure and Crosstab template refs

---

### **LOW PRIORITY** - Additional Documentation

13-27. Various README.md, MAINTENANCE.md files across:
- `/docs/TurasTabs_Composite_Scores_User_Manual.md`
- `/docs/TurasTracker_User_Manual.md`
- `/docs/Index_Summary_User_Manual.md`
- `/examples/` directories
- `/tests/` directories

**Action:** Search-and-replace template paths as needed

---

## 🔄 Migration Steps

### Phase 1: Preparation (TODAY)

- [x] Create validation reports (COMPLETE)
- [ ] Review validation findings with team
- [ ] Get approval on critical fixes
- [ ] Backup old templates

### Phase 2: Fix Critical Issues (THIS WEEK)

- [ ] Fix Pricing name mismatch (response_coding → response_type)
- [ ] Add Conjoint missing parameters
- [ ] Add Confidence Population_Margins sheet
- [ ] Update all 9 Final templates with fixes
- [ ] Re-run validation to verify fixes

### Phase 3: Update Documentation (NEXT WEEK)

- [ ] Update `/templates/README.md`
- [ ] Update `/templates/ANNOTATED_TEMPLATES_SUMMARY.md`
- [ ] Update `/templates/TEMPLATE_REFERENCE_GUIDE.md`
- [ ] Update main `/docs/USER_MANUAL.md`
- [ ] Update all module USER_MANUAL.md files

### Phase 4: Deprecate Old Files (NEXT WEEK)

Option A: **DELETE** (recommended after backup)
```bash
cd /home/user/Turas/templates
rm -f *_Template.xlsx
rm -f *_Template_Annotated.xlsx
# Keep only Final/ directory
```

Option B: **ARCHIVE** (safer but clutters repo)
```bash
cd /home/user/Turas/templates
mkdir -p Archive/deprecated_2025-12-03
mv *_Template.xlsx Archive/deprecated_2025-12-03/
mv *_Template_Annotated.xlsx Archive/deprecated_2025-12-03/
```

**Recommendation:** Option A (DELETE) after Phase 2-3 complete

### Phase 5: Verification (END OF MONTH)

- [ ] Search entire codebase for template references
- [ ] Verify all point to `/templates/Final/`
- [ ] Test each module with Final template
- [ ] Update .gitignore if needed
- [ ] Commit all changes

---

## 📊 Impact Assessment

### Modules Affected
- ✅ Confidence
- ✅ Conjoint
- ✅ Crosstab (Tabs)
- ✅ KeyDriver
- ✅ Pricing
- ✅ Segment
- ✅ Survey Structure (Tabs)
- ✅ Tracker
- ✅ Tracker Question Mapping

**Total:** All 9 major modules

### Users Impacted
- **Existing users:** Must update config file paths
- **New users:** Start with Final templates (better experience)
- **Documentation readers:** Clearer single source of truth

### Risk Assessment
- **LOW RISK** if validation fixes applied first
- **MEDIUM RISK** if old templates deleted without user migration plan
- **HIGH RISK** if critical issues (Pricing name mismatch) not fixed

---

## 🎯 Success Criteria

✅ **Technical Success:**
1. All validation issues fixed (39 identified)
2. All old templates removed from `/templates/`
3. Only `/templates/Final/` directory remains
4. All documentation references `/templates/Final/`
5. `.gitignore` configured correctly (already done)

✅ **User Success:**
1. Clear migration guide for existing users
2. Updated documentation easy to find
3. No broken links in docs
4. Example projects updated with Final templates

✅ **Maintenance Success:**
1. Single source of truth established
2. Validation reports linked from documentation
3. Process for future template updates documented
4. Version control strategy in place

---

## 📝 Communication Plan

### Internal Announcement
- Subject: "Template Cleanup - Action Required"
- Audience: Development team
- Content: Link to this deprecation plan, timeline, required actions

### User Announcement
- Subject: "New Validated Templates Available"
- Audience: All Turas users
- Content: Benefits of Final templates, migration guide, support contact

### Documentation Updates
- Add "⚠️ DEPRECATION NOTICE" to old template files
- Add prominent links to `/templates/Final/` in all docs
- Update README.md with migration instructions

---

**Status:** DRAFT - Awaiting Approval
**Next Review:** After Phase 2 fixes complete
**Questions:** Contact template validation team
