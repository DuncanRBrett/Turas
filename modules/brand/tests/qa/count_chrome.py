#!/usr/bin/env python3
"""Count the chrome a reader meets in a rendered brand report.

Counted off the DOM as Chrome parses and scripts it (--dump-dom), so a button
the bundle builds at run time is counted too. Buttons are matched by what they
DO, not by one class name: the demographics cards carried an Excel button whose
only class was .demo-card-tool, and a class-only count missed it.

The word "significant" is counted as a reader meets it: visible text plus the
title, aria-label and placeholder attributes they can surface. Script bodies
are excluded, because the source of a string is not something a reader reads.
"""
import re, subprocess, sys, os, tempfile, json

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

HARNESS = """
<script>
window.__count = function () {
  function n(sel) { return document.querySelectorAll(sel).length; }
  var body = document.body.cloneNode(true);
  body.querySelectorAll('script,style').forEach(function (e) { e.remove(); });
  var text = body.innerText || body.textContent || "";
  var attrText = "";
  body.querySelectorAll('[title],[aria-label],[placeholder]').forEach(function (e) {
    attrText += " " + (e.getAttribute('title') || "")
             +  " " + (e.getAttribute('aria-label') || "")
             +  " " + (e.getAttribute('placeholder') || "");
  });
  function count(s) {
    var m = String(s).match(/significan/gi);
    return m ? m.length : 0;
  }
  return {
    pin: n('.br-pin-btn, .brsum-card-pin, .fn-pin-dropdown-btn, ' +
           '.ma-pin-dropdown-btn, .br-dest-pin, [onclick*="brTogglePin"], ' +
           '[onclick*="brDestPin"]'),
    png: n('.br-png-btn, .fn-png-btn, .ma-png-btn, .br-dest-png, ' +
           '[onclick*="brExportPng"], [onclick*="brDestPng"]'),
    excel: n('.br-export-btn, .fn-export-btn, .fn-rel-export-btn, ' +
             '.ma-export-btn, .br-dest-excel, [onclick*="_brExportPanel"], ' +
             '[onclick*="brDestExcel"], [data-ma-action="exporttable"], ' +
             '[data-fn-action="exporttable"], [data-fn-rel-action="export"]'),
    textarea: n('textarea'),
    sig_text: count(text),
    sig_attr: count(attrText),
    // How many markers exist. How many are ON SCREEN is a different number
    // and a smaller one, because most sit inside a hidden sub-tab or a
    // hidden matrix cell; drive_chrome.py measures that, per destination,
    // with the destination open. Do not read this one as what a reader sees.
    sig_markers_dom: n('.ma-sig, .ma-fv-sig, .ma-adv-sig, .ct-sig, .fn-sig-avg, .fn-sig'),
    // What a reader actually meets. Every category tab and every destination
    // is opened in turn and the word is counted in the VISIBLE text of the
    // active view, which is the measure the brief asks for: text inside a
    // collapsed drawer or an inactive destination is not on the page.
    sig_text_visible: (function () {
      var total = 0;
      document.querySelectorAll('.br-panel[id^="panel-cat-"]').forEach(function (p) {
        window.switchBrandTab(p.id.replace(/^panel-/, ''));
        p.querySelectorAll('.br-destination-btn').forEach(function (b) {
          b.click();
          var d = p.querySelector('.br-destination.active');
          if (!d) return;
          var m = (d.innerText || '').match(/significan/gi);
          total += m ? m.length : 0;
        });
      });
      return total;
    })(),
    sig_toggles: n('.br-sig-toggle'),
    dest_toolbars: n('.br-dest-toolbar'),
    howto_drawers: n('.br-howto:not([hidden])'),
    dest_btn: n('.br-destination-btn')
  };
};
</script>
"""

def run(path):
    src = open(path, encoding="utf-8", errors="replace").read()
    src = src.replace("</head>", HARNESS +
        "\n<script>window.addEventListener('load',function(){setTimeout(function(){"
        "var d=document.createElement('div');d.id='__countout';"
        "d.textContent=JSON.stringify(window.__count());"
        "document.body.appendChild(d);},900);});</script>\n</head>", 1)
    fd, tmp = tempfile.mkstemp(suffix=".html")
    os.write(fd, src.encode("utf-8")); os.close(fd)
    try:
        out = subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-sandbox",
                              "--virtual-time-budget=10000", "--dump-dom",
                              "file://" + tmp],
                             capture_output=True, text=True, timeout=600).stdout
    finally:
        os.unlink(tmp)
    m = re.search(r'<div id="__countout">(.*?)</div>', out, re.S)
    if not m:
        print("no count output for " + path, file=sys.stderr); sys.exit(1)
    return json.loads(m.group(1))

if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(os.path.basename(p), json.dumps(run(p), indent=2))
