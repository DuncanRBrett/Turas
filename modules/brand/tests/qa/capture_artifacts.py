#!/usr/bin/env python3
"""Produce, and keep on disk, one of each artefact a destination toolbar makes.

drive_chrome.py proves the three export controls run without throwing. It
never looks at what they produce: the pinned card, the PNG and the workbook
are asserted through the interception hook and then dropped. Stage 5's log
records that gap in one line, "No pinned card, PNG or workbook was opened."

This script closes it. It drives the same report in the same headless Chrome,
the same way drive_chrome.py does (no selenium and no playwright in this
checkout: the report is copied, a harness is injected into the copy, and
Chrome renders the copy once per mode), and it writes four files a person can
open:

    view.png            a screenshot of the destination view itself
    popover.png         a screenshot of the pin picker
    pinned.png          a screenshot of the Pinned Views tab after a pin
    export_<slug>.png   the image the PNG control produced, under the exact
                        name the report gave the download
    <download name>     the workbook the Excel control produced, likewise
                        under the report's own name

Each control is driven by clicking it, not by calling its handler. The pin
and PNG controls lose their picker to a document-level click handler, so
when a click comes back with no picker the same handler is called directly,
that is recorded as a defect, and the picker is then driven for real. The
Excel control has no picker and its click works.

Usage:
    python3 capture_artifacts.py REPORT.html --out DIR [--dest buying]
                                 [--group dss] [--keep]
Exit status 0 when every artefact landed and parsed, 1 otherwise.
"""
import argparse
import base64
import json
import os
import re
import struct
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drive_chrome import CHROME, HOOK  # the same interception hook

# The blob interception in HOOK swallows a.click() on any download anchor and
# keeps the blob. Everything below is layered on top of it.
DRIVER_TEMPLATE = r"""
<script>
(function () {
  var qa = window.__turasQa;
  var MODE  = "__MODE__";
  var GROUP = "__GROUP__";
  var DEST  = "__DEST__";
  var out = { mode: MODE, log: [], metrics: {}, artifacts: {}, ok: false,
              errors: qa.errors, alerts: [], defects: [] };

  // An empty scope calls alert(). Recording it beats a blocked render.
  window.alert = function (m) { out.alerts.push(String(m)); };

  function log(s) { out.log.push(s); }
  function txt(el) { return el ? (el.textContent || "").replace(/\s+/g, " ").trim() : ""; }

  function openDest() {
    window.switchBrandTab("cat-" + GROUP);
    var panel = document.getElementById("panel-cat-" + GROUP);
    if (!panel) { log("no panel for group " + GROUP); return null; }
    var btn = panel.querySelector('.br-destination-btn[data-destination="' + DEST + '"]');
    if (btn) btn.click();
    var dest = panel.querySelector('.br-destination[data-destination="' + DEST + '"]');
    if (!dest) log("no destination " + DEST);
    return dest;
  }

  // The pin and PNG controls both go through TurasPins' checkbox popover
  // whenever the scope holds more than one anchor. Keeping one box ticked is
  // what a reader does when they want one card, so that is what is driven.
  //
  // A real click on either control is swallowed: brand_pins.js registers a
  // document-level click listener that closes any open popover unless the
  // target is inside .br-pin-btn, .br-png-btn, .ma-png-btn or .fn-png-btn.
  // Stage 5's toolbar buttons are .br-dest-pin and .br-dest-png, so the
  // popover the inline onclick just created is removed as the same click
  // finishes bubbling. The click is driven anyway, because that is the check;
  // when it comes back with nothing, the same handler is called directly,
  // which is the identical code path minus the bubbling, and the picker is
  // then driven for real.
  function openPicker(btn, which, fn) {
    btn.click();
    if (document.querySelector(".pin-mode-popover")) {
      log(which + ": the picker opened on a click");
      return true;
    }
    fn(btn);
    var now = !!document.querySelector(".pin-mode-popover");
    if (now) {
      out.defects.push(which + ": a click on ." + btn.className.split(" ").pop() +
        " opens the picker and then loses it. The same handler called " +
        "directly leaves the picker open, so the popover is being closed " +
        "while the click bubbles. brand_pins.js closes any open popover on " +
        "a document click whose target is not inside .br-pin-btn, " +
        ".br-png-btn, .ma-png-btn or .fn-png-btn, and Stage 5's controls " +
        "are none of those.");
      log(which + ": the click lost the picker; the direct call kept it");
    } else {
      log(which + ": no picker either way (a single-anchor scope runs straight through)");
    }
    return now;
  }

  function drivePopover(which) {
    var pop = document.querySelector(".pin-mode-popover");
    if (!pop) { log(which + ": nothing to drive, no popover on screen"); return null; }
    var boxes = pop.querySelectorAll('input[type="checkbox"]');
    var labels = [];
    pop.querySelectorAll(".pin-mode-checkbox").forEach(function (row) {
      labels.push(txt(row));
    });
    log(which + ": popover offered " + boxes.length + " item(s): " + labels.join(" | "));
    for (var i = 1; i < boxes.length; i++) {
      boxes[i].checked = false;
      boxes[i].dispatchEvent(new Event("change", { bubbles: true }));
    }
    var act = pop.querySelector(".pin-mode-action");
    if (!act) { log(which + ": popover has no action button"); return null; }
    var chosen = labels.length ? labels[0] : "";
    act.click();
    return chosen;
  }

  function viewMetrics(dest) {
    var main = dest.querySelector(".br-dest-main");
    var tables = main.querySelectorAll("table");
    var m = out.metrics;
    m.tables = tables.length;
    m.docHeight = Math.max(document.body.scrollHeight,
                           document.documentElement.scrollHeight);
    m.destHeight = dest.scrollHeight;
    m.headings = [];
    main.querySelectorAll(".br-subpanel").forEach(function (p) {
      var h = p.querySelector("h2, h3, h4, .br-subpanel-title, [data-leaf-label]");
      m.headings.push(txt(h).substring(0, 80) ||
                      (p.getAttribute("data-leaf-label") || ""));
    });
    // The first table, as text, so the PNG and the workbook can be read
    // against what the page actually showed.
    if (tables.length) {
      var rows = [];
      tables[0].querySelectorAll("tr").forEach(function (tr, i) {
        if (i > 4) return;
        var cells = [];
        tr.querySelectorAll("th, td").forEach(function (c) { cells.push(txt(c)); });
        rows.push(cells.join(" | "));
      });
      m.firstTable = rows;
      var host = tables[0].closest("[data-section]") ||
                 tables[0].closest("[data-leaf-label]");
      m.firstTableHost = host ? (host.getAttribute("data-section") ||
                                 host.getAttribute("data-leaf-label")) : "";
    }
  }

  function readBlobs(done) {
    var want = {};
    var tries = 0;
    (function poll() {
      tries += 1;
      qa.downloads.forEach(function (d) {
        if (!d || !d.blob || !d.name) return;
        var ext = /\.([a-z0-9]+)$/i.exec(d.name);
        ext = ext ? ext[1].toLowerCase() : "bin";
        if (!want[ext]) want[ext] = d;
      });
      var have = Object.keys(want);
      if ((have.indexOf("png") !== -1 && have.length >= 2) || tries > 600) {
        log("downloads intercepted: " + qa.downloads.map(function (d) {
          return d.name + " (" + (d.blob ? d.blob.size + "B" : "no blob") + ")";
        }).join(", "));
        var keys = Object.keys(want), n = keys.length, seen = 0;
        if (!n) { done(); return; }
        keys.forEach(function (k) {
          var d = want[k];
          var fr = new FileReader();
          fr.onloadend = function () {
            out.artifacts[k] = { name: d.name, size: d.blob.size,
                                 type: d.blob.type,
                                 b64: String(fr.result).split(",")[1] || "" };
            if (++seen === n) done();
          };
          fr.onerror = function () { if (++seen === n) done(); };
          fr.readAsDataURL(d.blob);
        });
        return;
      }
      setTimeout(poll, 200);
    })();
  }

  // Chrome's style recalculation lags a class change under
  // --virtual-time-budget: getComputedStyle still returns the old values
  // immediately after switchBrandTab, and a forced reflow does not help. A
  // screenshot taken then shows the previous tab underlined. Letting a
  // timer run, and reading a computed style back, lets the lifecycle catch
  // up before Chrome captures. The result block is hidden so it never
  // appears in a screenshot.
  function emit() {
    out.ok = true;
    var pre = document.createElement("pre");
    pre.id = "turas-qa-result";
    pre.style.display = "none";
    pre.textContent = JSON.stringify(out);
    document.body.appendChild(pre);
  }

  function finish() {
    setTimeout(function () {
      // The tab strip keeps its old paint even once the style engine has
      // caught up, so it is taken out of the layout and put back, which
      // forces the strip to be painted again from the current style.
      var nav = document.querySelector(".br-tab-nav");
      if (nav) { nav.style.display = "none"; void nav.offsetHeight; nav.style.display = ""; }
      void document.body.offsetHeight;
      var active = document.querySelector(".br-tab-btn.active");
      if (active) {
        out.metrics.activeTab = active.getAttribute("data-tab");
        out.metrics.activeTabColour = getComputedStyle(active).color;
      }
      setTimeout(emit, 400);
    }, 1500);
  }

  function run() {
    var dest = openDest();
    if (!dest) { finish(); return; }
    var bar = dest.querySelector(".br-dest-main > .br-dest-toolbar");
    if (!bar) { log("no main toolbar"); finish(); return; }
    viewMetrics(dest);

    if (MODE === "view") { finish(); return; }

    if (MODE === "popover") {
      openPicker(bar.querySelector(".br-dest-pin"), "pin", window.brDestPin);
      var pop = document.querySelector(".pin-mode-popover");
      log("popover present: " + !!pop);
      if (pop) { pop.scrollIntoView(); out.metrics.popoverTop = pop.getBoundingClientRect().top + window.scrollY; }
      finish();
      return;
    }

    if (MODE === "pin" || MODE === "blobs") {
      var before = document.querySelectorAll(".br-pinned-card").length;
      openPicker(bar.querySelector(".br-dest-pin"), "pin", window.brDestPin);
      var chose = drivePopover("pin");
      var after = document.querySelectorAll(".br-pinned-card").length;
      log("pin: chose " + JSON.stringify(chose) + ", cards " + before + " -> " + after);
      out.metrics.pinnedCards = after;
      var card = document.querySelectorAll(".br-pinned-card")[after - 1];
      if (card) {
        var t = card.querySelector(".br-pinned-card-title");
        out.metrics.pinnedTitle = t ? txt(t) : "(no .br-pinned-card-title)";
        out.metrics.pinnedCardHasTable = !!card.querySelector("table");
        out.metrics.pinnedCardHasSvg = !!card.querySelector("svg");
      }
    }

    if (MODE === "pin") {
      window.switchBrandTab("pinned");
      var pp = document.getElementById("panel-pinned");
      out.metrics.pinnedPanelHeight = pp ? pp.scrollHeight : 0;
      out.metrics.docHeightPinned = Math.max(document.body.scrollHeight,
                                             document.documentElement.scrollHeight);
      finish();
      return;
    }

    if (MODE === "blobs") {
      openPicker(bar.querySelector(".br-dest-png"), "png", window.brDestPng);
      var pngChose = drivePopover("png");
      log("png: chose " + JSON.stringify(pngChose));
      bar.querySelector(".br-dest-excel").click();
      readBlobs(finish);
      return;
    }

    finish();
  }

  function boot() {
    setTimeout(function () {
      try { run(); } catch (e) {
        out.log.push("harness threw: " + String(e && e.stack || e));
        emit();
      }
    }, 1200);
  }
  if (document.readyState === "complete") boot();
  else window.addEventListener("load", boot);
})();
</script>
"""


def build_copy(src, mode, group, dest):
    html = open(src, encoding="utf-8").read()
    i = html.index("<head>") + len("<head>")
    html = html[:i] + HOOK + html[i:]
    driver = (DRIVER_TEMPLATE.replace("__MODE__", mode)
              .replace("__GROUP__", group).replace("__DEST__", dest))
    j = html.rindex("</body>")
    html = html[:j] + driver + html[j:]
    fd, path = tempfile.mkstemp(suffix="_capture.html")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(html)
    return path


def run_chrome(src, mode, group, dest, shot=None, size=(1400, 900),
               budget=45000, keep=False):
    path = build_copy(src, mode, group, dest)
    cmd = [CHROME, "--headless", "--disable-gpu", "--no-sandbox",
           "--hide-scrollbars", "--allow-file-access-from-files",
           "--window-size=%d,%d" % size,
           "--virtual-time-budget=%d" % budget, "--dump-dom"]
    if shot:
        cmd.append("--screenshot=" + os.path.abspath(shot))
    cmd.append("file://" + path)
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    m = re.search(r'<pre id="turas-qa-result"[^>]*>(.*?)</pre>', proc.stdout, re.S)
    if keep:
        print("  copy kept at", path)
    else:
        os.unlink(path)
    if not m:
        print("  [%s] the harness did not report. Chrome stderr tail:" % mode)
        print(proc.stderr[-1500:])
        return None
    body = (m.group(1).replace("&amp;", "&").replace("&lt;", "<")
            .replace("&gt;", ">").replace("&quot;", '"'))
    return json.loads(body)


def png_size(path):
    """Width and height from the IHDR chunk, or None when it is not a PNG."""
    with open(path, "rb") as fh:
        head = fh.read(33)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    if head[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", head[16:24])


def jpeg_size(path):
    """Width and height from the first SOF marker, or None when not a JPEG."""
    with open(path, "rb") as fh:
        data = fh.read()
    if data[:2] != b"\xff\xd8":
        return None
    i = 2
    while i + 9 < len(data):
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
            i += 2
            continue
        seg = struct.unpack(">H", data[i + 2:i + 4])[0]
        if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                      0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
            h, w = struct.unpack(">HH", data[i + 5:i + 9])
            return (w, h)
        i += 2 + seg
    return None


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--out", required=True)
    ap.add_argument("--group", default="dss")
    ap.add_argument("--dest", default="buying")
    ap.add_argument("--keep", action="store_true")
    a = ap.parse_args(argv)

    if not os.path.exists(CHROME):
        print("Chrome not found at", CHROME)
        return 2
    os.makedirs(a.out, exist_ok=True)
    produced, problems, defects = [], [], []

    # --- 1. the blobs, from the real PNG and Excel controls ---------------
    print("[1/4] driving the PNG and Excel controls")
    res = run_chrome(a.report, "blobs", a.group, a.dest, budget=120000,
                     keep=a.keep)
    if res is None:
        return 1
    for line in res["log"]:
        print("   ", line)
    if res.get("alerts"):
        print("    alert():", res["alerts"])
    for d in res.get("defects", []):
        print("    DEFECT:", d)
        defects.append(d)
    metrics = res["metrics"]
    print("    view metrics:", json.dumps({k: metrics[k] for k in metrics
                                           if k != "firstTable"}))
    if metrics.get("firstTable"):
        print("    first table on the view, as the page shows it:")
        for r in metrics["firstTable"]:
            print("      " + r)

    for ext, art in sorted(res["artifacts"].items()):
        dest_path = os.path.join(a.out, art["name"])
        with open(dest_path, "wb") as fh:
            fh.write(base64.b64decode(art["b64"]))
        produced.append(dest_path)
        print("    wrote %s (%d bytes, blob type %s)"
              % (dest_path, os.path.getsize(dest_path), art["type"]))
    if "png" not in res["artifacts"]:
        problems.append("the PNG control produced no download")
    if not any(k in res["artifacts"] for k in ("xls", "xlsx", "xml")):
        problems.append("the Excel control produced no workbook download")

    # --- 2. the destination view itself -----------------------------------
    print("[2/4] screenshotting the destination view")
    view_png = os.path.join(a.out, "view.png")
    h = min(int(metrics.get("docHeight") or 2000) + 40, 12000)
    r2 = run_chrome(a.report, "view", a.group, a.dest, shot=view_png,
                    size=(1400, h), budget=30000, keep=a.keep)
    if r2 is None:
        problems.append("the view screenshot run did not report")
    if os.path.exists(view_png):
        produced.append(view_png)

    # --- 3. the pinned card -----------------------------------------------
    print("[3/4] pinning, then screenshotting the Pinned Views tab")
    r3 = run_chrome(a.report, "pin", a.group, a.dest, budget=45000,
                    keep=a.keep)
    if r3 is None:
        problems.append("the pin run did not report")
        ph = 1800
    else:
        for line in r3["log"]:
            print("   ", line)
        for d in r3.get("defects", []):
            if d not in defects:
                defects.append(d)
        print("    pinned metrics:", json.dumps(r3["metrics"].get("pinnedTitle")),
              "cards=", r3["metrics"].get("pinnedCards"),
              "table=", r3["metrics"].get("pinnedCardHasTable"),
              "svg=", r3["metrics"].get("pinnedCardHasSvg"))
        ph = min(int(r3["metrics"].get("docHeightPinned") or 1800) + 40, 12000)
        if not r3["metrics"].get("pinnedCards"):
            problems.append("the pin control added no card")
    pin_png = os.path.join(a.out, "pinned.png")
    run_chrome(a.report, "pin", a.group, a.dest, shot=pin_png,
               size=(1400, ph), budget=35000, keep=a.keep)
    if os.path.exists(pin_png):
        produced.append(pin_png)

    # --- 4. the picker, which nobody has looked at either ------------------
    print("[4/4] screenshotting the pin picker")
    pop_png = os.path.join(a.out, "popover.png")
    run_chrome(a.report, "popover", a.group, a.dest, shot=pop_png,
               size=(1400, min(int(metrics.get("docHeight") or 2000) + 40, 12000)),
               budget=30000, keep=a.keep)
    if os.path.exists(pop_png):
        produced.append(pop_png)

    # --- plausibility, not file size --------------------------------------
    print("\nArtefacts")
    for p in produced:
        n = os.path.getsize(p)
        note = ""
        if p.lower().endswith(".png"):
            dims = png_size(p)
            if dims is None:
                jdims = jpeg_size(p)
                if jdims is None:
                    problems.append("%s is neither a PNG nor a JPEG" % p)
                    note = "UNRECOGNISED IMAGE"
                else:
                    dims = jdims
                    note = "%dx%d px, but JPEG bytes under a .png name" % jdims
                    twin = p[:-4] + "_as_delivered.jpg"
                    with open(twin, "wb") as out_fh:
                        out_fh.write(open(p, "rb").read())
                    defects.append(
                        "the PNG control wrote %s: the bytes are JPEG, not PNG. "
                        "TurasPins.EXPORT_QUALITY defaults to \"standard\", whose "
                        "preset is image/jpeg at 0.85, while exportContentAsPNG "
                        "names the file .png. Copied to %s so it opens."
                        % (os.path.basename(p), os.path.basename(twin)))
            else:
                note = "%dx%d px" % dims
            if dims and (dims[0] < 200 or dims[1] < 80):
                problems.append("%s is %dx%d, too small to hold a view"
                                % (p, dims[0], dims[1]))
        else:
            head = open(p, "rb").read(4096)
            if head[:2] == b"PK":
                note = "zip container (a real xlsx)"
            elif head.lstrip()[:5] == b"<?xml":
                note = "XML, not a zip"
                whole = open(p, "rb").read()
                if b"<Worksheet" not in whole:
                    problems.append("%s has no <Worksheet> element" % p)
                if b'ss:Type="Number"' not in whole:
                    problems.append("%s carries no numeric cell" % p)
                note += " (%d Worksheet elements)" % whole.count(b"<Worksheet")
            else:
                problems.append("%s is neither a zip nor XML" % p)
                note = "unrecognised"
        if n < 1024:
            problems.append("%s is only %d bytes" % (p, n))
        print("  %-70s %9d bytes  %s" % (p, n, note))

    if defects:
        print("\nDefects seen while driving the controls (%d):" % len(defects))
        for d in defects:
            print("  " + d)
    if problems:
        print("\nProblems (%d):" % len(problems))
        for p in problems:
            print("  " + p)
        return 1
    if defects:
        print("\nEvery artefact landed and parsed, with %d defect(s) above."
              % len(defects))
    else:
        print("\nEvery artefact landed and parsed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
