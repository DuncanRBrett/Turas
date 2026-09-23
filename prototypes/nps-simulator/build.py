"""Inject each build/model_*.json into its template, writing build/<name>_prototype.html.

Run from this folder after the fit scripts: python3 build.py
"""
import pathlib

HERE = pathlib.Path(__file__).parent
for name in ["sacap", "ccpb", "ccpb_v3", "sacap_safe"]:
    tpl, data = HERE / f"template_{name}.html", HERE / "build" / f"model_{name}.json"
    if tpl.exists() and data.exists():
        out = HERE / "build" / f"{name}_nps_simulator_prototype.html"
        out.write_text(tpl.read_text().replace("%%DATA%%", data.read_text()))
        print("wrote", out.name)

# What if tab mockups: one per study, each built from its engine outputs.
tpl = HERE / "template_whatif.html"
for safe in sorted((HERE / "build").glob("whatif_*_safe.json")):
    sid = safe.name[len("whatif_"):-len("_safe.json")]
    opn = HERE / "build" / f"whatif_{sid}_open.json"
    if tpl.exists() and opn.exists():
        out = HERE / "build" / f"whatif_{sid}_mockup.html"
        out.write_text(tpl.read_text().replace("%%SAFE%%", safe.read_text()).replace("%%OPEN%%", opn.read_text()))
        print("wrote", out.name)
