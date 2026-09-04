"""Render a RECORDS build and a CUBE build of the same project headlessly, at
the same URL states, and compare what the reader actually sees in #app.

Both the table cells and the whole rendered text of #app are compared, because
several tabs render cards rather than tables and a cell-only comparison would
pass over them without looking.

A fragment prefixed with "!" is one the two builds SHOULD render differently,
and it is asserted both ways: an expected difference that stopped happening is
a regression too. There are exactly two of those. The Report tab, where a cube
build states what it carries and what it withholds. And any cut above the
order cap, where the cube shows its refusal sentence and the records build
computes the table.

Usage, with RECORDS and CUBE pointing at the two reports:
  python3 cube_render_compare.py [fragment ...]

Run on the Karoo integrated demo, 4 September 2026: fourteen states, twelve
identical and two different as expected.
"""
import json, os, re, subprocess, sys, tempfile

SP = os.path.dirname(os.path.abspath(__file__))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
RECORDS = os.environ.get("RECORDS", os.path.join(SP, "demo/tabs/report/Karoo_Demo_Crosstabs_report.html"))
CUBE = os.environ.get("CUBE", os.path.join(SP, "demo_cube/tabs/report/Karoo_Demo_Crosstabs_report.html"))

PROBE = ('<script>window.addEventListener("load",function(){setTimeout(function(){'
         'var app=document.getElementById("app");'
         'var cells=[].slice.call(app.querySelectorAll("td,th")).map(function(e){'
         'return (e.textContent||"").replace(/\\s+/g," ").trim();});'
         'var d=document.createElement("div");d.id="__probe__";'
         'd.setAttribute("data-probe",JSON.stringify({fatal:!!document.querySelector(".fatal"),'
         'src:(window.TR&&TR.stats&&TR.stats.source)?TR.stats.source():"?",'
         'nodes:app.querySelectorAll("*").length,'
         'text:(app.innerText||app.textContent||"").replace(/\\s+/g," ").trim(),'
         'micro:(window.TR&&TR.MICRO)?TR.MICRO.n:null,cells:cells}));'
         'document.body.appendChild(d);},2500)})</script>')

def probed(src):
    html = open(src, encoding="utf-8").read()
    assert "</body>" in html
    out = html.replace("</body>", PROBE + "</body>", 1)
    fd, path = tempfile.mkstemp(suffix=".html", dir=SP)
    os.close(fd)
    open(path, "w", encoding="utf-8").write(out)
    return path

def render(path, frag):
    url = "file://" + path + frag
    dom = subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--no-sandbox",
         "--virtual-time-budget=15000", "--dump-dom", url],
        capture_output=True, text=True, timeout=180).stdout
    m = re.search(r'<div id="__probe__" data-probe="(.*?)"></div>', dom, re.S)
    if not m:
        return None
    raw = m.group(1)
    for a, b in (("&quot;", '"'), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">")):
        raw = raw.replace(a, b)
    return json.loads(raw)

FRAGS = sys.argv[1:] or ["#tab=crosstabs&q=Q001",
                         "#tab=crosstabs&q=Q001&filter=Region:3",
                         "#tab=crosstabs&q=Q006&filter=Region:3",
                         "#tab=diffs", "#tab=takeout", "#tab=dashboard"]
rec_p, cub_p = probed(RECORDS), probed(CUBE)
fails = 0
try:
    for frag in FRAGS:
        # A leading "!" marks a state the two builds SHOULD render differently.
        # Asserted both ways: an expected difference that stopped happening is a
        # regression too.
        expect_diff = frag.startswith("!")
        if expect_diff:
            frag = frag[1:]
        a = render(rec_p, frag)
        b = render(cub_p, frag)
        if a is None or b is None:
            print("%-42s PROBE MISSING (records=%s cube=%s)" % (frag, a is not None, b is not None))
            fails += 1
            continue
        same_cells = a["cells"] == b["cells"]
        same_text = a["text"] == b["text"]
        same = same_cells and same_text
        note = ""
        if not same_text:
            # First divergence, in context, so a failure names the sentence.
            i = next((i for i, (x, y) in enumerate(zip(a["text"], b["text"])) if x != y),
                     min(len(a["text"]), len(b["text"])))
            note = " | text differs at char %d: records %r vs cube %r" % (
                i, a["text"][max(0, i - 60):i + 60], b["text"][max(0, i - 60):i + 60])
        if expect_diff:
            verdict = "DIFFERENT as expected" if not same else "IDENTICAL, but a DIFFERENCE was expected"
            if same:
                fails += 1
            note = ""
        else:
            verdict = "IDENTICAL" if same else "DIFFERENT"
            if not same:
                fails += 1
        print("%-52s records src=%-5s n=%-4s nodes=%-5d chars=%-6d | cube src=%-5s nodes=%-5d chars=%-6d | %s%s"
              % (frag, a["src"], a["micro"], a["nodes"], len(a["text"]),
                 b["src"], b["nodes"], len(b["text"]),
                 verdict, note))
        if a["fatal"] or b["fatal"]:
            print("   FATAL on render: records=%s cube=%s" % (a["fatal"], b["fatal"]))
            fails += 1
finally:
    for p in (rec_p, cub_p):
        try: os.remove(p)
        except OSError: pass
print("\n%d comparison(s) failed" % fails)
sys.exit(1 if fails else 0)
