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

# The What if tab mockup takes two data files: client-safe groups and open-mode respondents.
mock, safe, opn = HERE / "template_whatif_mockup.html", HERE / "build" / "model_sacap_safe.json", HERE / "build" / "model_sacap_open.json"
if mock.exists() and safe.exists() and opn.exists():
    out = HERE / "build" / "whatif_tab_mockup.html"
    out.write_text(mock.read_text().replace("%%SAFE%%", safe.read_text()).replace("%%OPEN%%", opn.read_text()))
    print("wrote", out.name)
