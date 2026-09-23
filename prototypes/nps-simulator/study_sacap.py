"""SACAP 2025 student survey: the What if study definition.

Same data, levers and groups as fit_sacap_safe.py, expressed as a spec for
whatif_engine. Run: python3 study_sacap.py, then python3 build.py.
"""
import numpy as np
import pandas as pd

import whatif_engine

# SACAP student reports have always run unweighted, so the What if tab does too.
# National studies may run either way: set this per study to match its report.
USE_WEIGHTS = False


def build_spec():
    """Load the data and return the study spec for whatif_engine.run()."""
    ROOT = "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/Student_Annual/03_Waves/Student_Annual-2025/"
    d = pd.read_excel(ROOT + "03_Data/SACAP_Student_Annual-2025_Data_weighted.xlsx", keep_default_na=False, na_values=[""])
    d = d[d.Q001.isin(["Complete", "Converted"])].reset_index(drop=True)
    s = pd.to_numeric(d.Q017, errors="coerce")
    assert s.notna().all()

    LABELS = ["Terrible", "Not very good", "About average", "Good", "Excellent"]
    SCALE = {lab: i + 1 for i, lab in enumerate(LABELS)}
    LEVERS = [("Q025", "Educators delivering content"), ("Q026", "Assessment feedback"), ("Q027", "Course content"),
              ("Q021", "Value for money"), ("Q029", "MySACAP usability"), ("Q063", "Staff friendly and approachable"),
              ("Q064", "Student admin"), ("Q065", "Email responsiveness")]
    levers = []
    for code, label in LEVERS:
        r = d[code].map(SCALE).astype(float)
        levers.append({"key": code, "label": label, "kind": "rating", "missing": int(r.isna().sum()),
                       "values": r.fillna(r.median()).round().values})


    def year_band(v):
        v = str(v)
        if "Honours" in v:
            return "Honours"
        if "Masters" in v:
            return "Masters"
        for k in ["1st", "2nd", "3rd"]:
            if v.startswith(k):
                return k + " year"
        return "Other"


    course_raw = d.Q005.fillna("Other programmes").astype(str).str.strip()
    course = course_raw.where(course_raw.map(course_raw.value_counts()) >= 40, "Other courses")
    context = {
        "campus": ("Campus", d.Q002.astype(str).str.strip()),
        "course": ("Course", course),
        "year": ("Year of study", d.Q006.map(year_band)),
        "reg": ("New or returning", d.Q009.map(lambda v: "First-time" if "1st" in str(v) else "Returning")),
        "gender": ("Gender", d.Q100.fillna("x").map(lambda v: v if v in ("Female", "Male") else "Other or not said")),
        "age": ("Age", d.Q099.fillna("Not said").replace({"Prefer not to say": "Not said"}).astype(str)),
        "intensity": ("Full or part time", d.Q004.map(lambda v: "Part time" if "Part" in str(v) else "Full time")),
    }

    return {
        "id": "sacap", "unit": "student", "units": "students", "min_group": 5, "reliability_floor": 30,
        "y": np.where(s >= 9, 2, np.where(s <= 6, 0, 1)),
        "weights": d.weight.astype(float).values if USE_WEIGHTS else None,
        "meta": {"title": "SACAP Student Survey 2025", "brand": "SACAP",
                 "outcome": "Would you recommend SACAP? (Q017)"},
        "scale": {"min": 1, "max": 5, "centre": 3, "good": 4, "labels": LABELS, "step": "notch"},
        "levers": levers, "context": context,
        "profile": {"keys": ["gender", "reg", "age", "intensity", "course", "year", "campus"],
                    "sentence": [["", "A "], ["gender", "lower"], ["", " "], ["reg", ""], ["", " student aged "], ["age", ""],
                                 ["", ", studying "], ["intensity", "lower"], ["", " on "], ["course", ""], ["", ", in "],
                                 ["year", ""], ["", ", registered with "], ["campus", ""], ["", "."]],
                    "order": {"age": "numeric", "year": ["1st year", "2nd year", "3rd year", "Honours", "Masters", "Other"]}},
        "crossings": [("campus", "course"), ("campus", "year"), ("course", "year"), ("campus", "reg"), ("course", "reg"),
                      ("campus", "gender"), ("course", "gender"), ("campus", "age"), ("course", "age"), ("gender", "age")],
        "bundles": [("Teaching", "Educators, assessment feedback and course content each one notch up",
                     {"Q025": "up1", "Q026": "up1", "Q027": "up1"}),
                    ("Service", "Staff, student admin and email responsiveness each one notch up",
                     {"Q063": "up1", "Q064": "up1", "Q065": "up1"})],
        "notes": ["Value for money behaves partly like a second measure of how students feel about SACAP overall, so its effect is inflated.",
                  "\"Don't know\" answers were set to the middle rating for that question: " +
                  ", ".join(f"{lv['label']} {lv['missing']}" for lv in levers if lv["missing"]) + "."],
    }


if __name__ == "__main__":
    whatif_engine.run(build_spec())
