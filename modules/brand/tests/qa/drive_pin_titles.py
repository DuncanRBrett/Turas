#!/usr/bin/env python3
"""Drive the pin picker the way a reader opens it, with the Advanced drawers
still shut, and check the card that lands is named what the picker offered.

Review finding F2. The two Stage 6 pin-title commits fixed a card named after
a hidden sub-tab the reader cannot open, and broke every pin taken from an
Advanced drawer. Two separate faults, and neither is visible to
drive_chrome.py, which expands every drawer before it captures:

  1. captureFromRoot() and sectionsIn() skipped any heading a reader could not
     see at that instant. A collapsed drawer hides the whole leaf, so every
     anchor under it fell back to the same leaf label. Seven Branded Reach
     entries, six Audience Lens entries, all identically named.

  2. pinnableContent() applied the picker's title only when the capture had
     found none of its own. Once the leaf-label fallback filled that in, the
     category suffix the picker had put on a Category Buying entry was
     dropped, and four categories produced four cards called "Dirichlet
     Norms".

So this script leaves the drawers exactly as it finds them. For every
destination in every category panel it asks brSectionsIn() what the picker
would offer, pins each entry through brPinFrom() the way the picker's own
click handler does, and reads the titles back off TurasPins.getAll().

What it asserts:

  Name kept.     The card's title is the name the picker showed. Nothing
                 between the two may quietly rewrite it.
  Category kept. Every leaf-branch entry, the ones keyed group:leaf with no
                 anchor of their own, carries its category on the card. That
                 is what tells two categories' cards apart on a real
                 multi-category report.
  Distinct.      No scope offering more than one entry names every one of
                 them the same thing.
  No dead tab.   No card is named after the funnel panel's Summary sub-tab,
                 which no nav routes to.
  Leaf name.     The funnel card carries its host's own data-leaf-label,
                 read from the DOM rather than hardcoded, so it holds on a
                 gated report ("Brand Funnel") and on an ungated one, where
                 F5 renames the leaf.

Usage:
    python3 drive_pin_titles.py REPORT.html [--keep]
Exit status 0 when every check passed, 1 otherwise.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

DRIVER = r"""
<script>
(function () {
  var out = { checks: [], errors: [], scopes: 0, items: 0 };
  function check(name, ok, detail) {
    out.checks.push({ name: name, ok: !!ok, detail: detail || '' });
  }

  function run() {
    var panels = document.querySelectorAll('.br-panel');
    check('at least one category panel', panels.length > 0,
          panels.length + ' panel(s)');

    for (var p = 0; p < panels.length; p++) {
      var panel = panels[p];
      var group = panel.id.replace(/^panel-cat-/, '');
      window.switchBrandTab(panel.id.replace(/^panel-/, ''));

      var dests = panel.querySelectorAll('.br-destination');
      for (var d = 0; d < dests.length; d++) {
        var dest = dests[d];
        var did = dest.getAttribute('data-destination');
        var btn = panel.querySelector(
          '.br-destination-btn[data-destination="' + did + '"]');
        if (btn) btn.click();

        // The drawers are left exactly as the page opens them. That is the
        // whole point: this is the state a reader opens the picker in.
        var advBody = dest.querySelector('.br-advanced-body');
        var main = dest.querySelector('.br-dest-main');
        var tiers = [{ name: 'main', root: main || dest }];
        if (advBody) tiers.push({ name: 'advanced', root: advBody });

        for (var t = 0; t < tiers.length; t++) {
          var scope = tiers[t];
          var label = group + '/' + did + '/' + scope.name;
          var items = window.brSectionsIn(scope.root) || [];
          if (!items.length) continue;
          out.scopes++;

          var titles = [];
          for (var i = 0; i < items.length; i++) {
            var it = items[i];
            var offered = it.title || it.label;
            var before = TurasPins.getAll().length;
            var ok = window.brPinFrom(it.el, it.key, offered);
            var all = TurasPins.getAll();
            if (!ok || all.length <= before) {
              check(label + ': ' + it.key + ' produces a card', false,
                    'brPinFrom returned nothing');
              continue;
            }
            out.items++;
            var card = all[all.length - 1];
            var got = String(card.title || '');
            titles.push(got);

            // brTitleWithChartDeviation() may append a deviation note, so
            // the offered name has to lead rather than equal.
            check(label + ': ' + it.key + ' keeps the name the picker showed',
                  got.indexOf(offered) === 0,
                  'offered "' + offered + '", card "' + got + '"');
            check(label + ': ' + it.key + ' is not named after a dead sub-tab',
                  got !== 'Summary', got);

            if (it.key.indexOf(':') !== -1) {
              // A leaf-branch entry. The picker puts the category on it and
              // the card must keep it. catLabelFor() reads the category off
              // the tab button, so read it the same way.
              var tabBtn = document.querySelector(
                '.br-tab-btn[data-tab="' + panel.id.replace(/^panel-/, '') + '"]');
              var cat = tabBtn ? tabBtn.textContent.trim() : '';
              var badge = tabBtn && tabBtn.querySelector('.br-pin-badge');
              if (badge) cat = cat.replace(badge.textContent.trim(), '').trim();
              check(label + ': ' + it.key + ' carries its category',
                    !cat || got.indexOf(cat) !== -1,
                    'category "' + cat + '", card "' + got + '"');
            }

            if (it.key.indexOf('funnel-') === 0) {
              // Read the leaf's own name off the DOM. Hardcoding "Brand
              // Funnel" here would fail on an ungated report, where the leaf
              // is deliberately named something else (review finding F5).
              var host = it.el.closest('[data-leaf-label]');
              var leafName = host ? host.getAttribute('data-leaf-label') : '';
              check(label + ': ' + it.key + ' is named after its leaf',
                    !!leafName && got.indexOf(leafName) === 0,
                    'leaf "' + leafName + '", card "' + got + '"');
            }
          }

          if (titles.length > 1) {
            var distinct = {};
            for (var k = 0; k < titles.length; k++) distinct[titles[k]] = 1;
            check(label + ': the cards are not all named the same thing',
                  Object.keys(distinct).length > 1,
                  titles.length + ' cards, ' + Object.keys(distinct).length +
                  ' distinct: ' + Object.keys(distinct).join(' | '));
          }
        }
      }
    }
    check('some entry was offered and pinned', out.items > 0,
          out.items + ' card(s) from ' + out.scopes + ' scope(s)');
  }

  function boot() { setTimeout(function () {
    try { run(); } catch (e) {
      check('the harness ran', false, String(e && e.stack || e));
    }
    var pre = document.createElement('pre');
    pre.id = 'turas-qa-result';
    pre.textContent = JSON.stringify(out);
    document.body.appendChild(pre);
  }, 1500); }

  if (document.readyState === 'complete') boot();
  else window.addEventListener('load', boot);
})();
</script>
"""


def build_copy(src):
    html = open(src, encoding="utf-8").read()
    j = html.rindex("</body>")
    html = html[:j] + DRIVER + html[j:]
    fd, path = tempfile.mkstemp(suffix="_pintitles.html")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(html)
    return path


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    src = argv[1]
    keep = "--keep" in argv
    if not os.path.exists(CHROME):
        print("Chrome not found at", CHROME)
        return 2
    path = build_copy(src)
    cmd = [CHROME, "--headless", "--disable-gpu", "--no-sandbox",
           "--allow-file-access-from-files", "--window-size=1280,900",
           "--virtual-time-budget=40000", "--dump-dom", "file://" + path]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    m = re.search(r'<pre id="turas-qa-result">(.*?)</pre>', proc.stdout, re.S)
    if not m:
        print("The QA harness did not report. Chrome stderr:")
        print(proc.stderr[-2000:])
        if keep:
            print("copy kept at", path)
        return 1
    body = (m.group(1).replace("&amp;", "&").replace("&lt;", "<")
            .replace("&gt;", ">").replace("&quot;", '"'))
    res = json.loads(body)

    failed = [c for c in res["checks"] if not c["ok"]]
    for c in res["checks"]:
        mark = "ok  " if c["ok"] else "FAIL"
        print("  %s %s%s" % (mark, c["name"],
                             (" -> " + c["detail"]) if c["detail"] else ""))
    print("\n%d checks, %d failed" % (len(res["checks"]), len(failed)))
    if not keep:
        os.unlink(path)
    else:
        print("copy kept at", path)
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
