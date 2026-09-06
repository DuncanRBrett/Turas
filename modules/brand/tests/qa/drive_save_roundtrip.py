#!/usr/bin/env python3
"""Prove a saved and reopened brand report shows what the reader saw.

Two selections used to be lost on Save. The header's comparison set, because
a checkbox's .checked and an option's .selected are properties that outerHTML
never sees. And each chart's "Chart brands" deviation, because it lives on a
BrandSelector handle and never touched the DOM at all.

The second one was the dangerous one, and it is the case this script exists
for. The note above a narrowed chart is a plain text node, so it DID survive
serialisation while the state behind it did not. A reopened copy could carry
a note saying the chart omits three brands above a chart that showed all
fifteen: a client-facing artefact making a false statement.

There is no puppeteer or playwright in this checkout, so the round trip is
two Chrome runs.

  Pass 1  A harness is injected into a copy of the report. It drives the
          header to a focal brand and two comparators, deviates every chart
          that can deviate, records what is on screen, calls the report's own
          window._brSerialiseReport() and asserts the returned string carries
          the mirrored attributes. Then it removes itself from the DOM.
          --dump-dom emits document.documentElement.outerHTML, which is the
          exact string _brSaveReport() writes into the file, so the dump IS
          the saved copy.

  Pass 2  The dump is reopened with a second harness and pass 1's record
          injected beside it. Every recorded value is compared. The note is
          not trusted: the numbers in its sentence are read back against the
          brand rows actually in the chart and actually in the table.

Usage:
    python3 drive_save_roundtrip.py REPORT.html [--keep]
Exit status 0 when every check passed, 1 otherwise.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

HOOK = """
<script id="turas-qa-hook">
window.__turasQa = { errors: [] };
window.addEventListener('error', function (e) {
  window.__turasQa.errors.push('uncaught: ' + (e.message || String(e)));
});
window.addEventListener('unhandledrejection', function (e) {
  window.__turasQa.errors.push('rejection: ' + String(e.reason));
});
(function () {
  var real = console.error;
  console.error = function () {
    window.__turasQa.errors.push('console.error: ' +
      Array.prototype.map.call(arguments, String).join(' '));
    return real.apply(console, arguments);
  };
  var warn = console.warn;
  console.warn = function () {
    window.__turasQa.errors.push('console.warn: ' +
      Array.prototype.map.call(arguments, String).join(' '));
    return warn.apply(console, arguments);
  };
})();
</script>
"""

# Shared between the two passes: how a report's live state is read off the
# page. Both passes must read it the same way or the comparison means
# nothing, so there is one copy of these functions.
COMMON = """
  function visible(el) {
    if (!el) return false;
    return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
  }
  var BRAND_ATTRS = ['data-brand', 'data-cb-brand', 'data-fn-brand',
                     'data-ma-brand', 'data-demo-brand', 'data-wom-brand'];
  function visibleBrandCodes(host) {
    var seen = {};
    BRAND_ATTRS.forEach(function (a) {
      host.querySelectorAll('[' + a + ']').forEach(function (el) {
        if (el.closest('.br-cmp-popover')) return;
        var v = el.getAttribute(a);
        if (!v || v === '__avg__') return;
        if (!visible(el)) return;
        seen[v] = true;
      });
    });
    return Object.keys(seen).sort();
  }
  function exposeHost(panel, host) {
    var dest = host.closest('.br-destination');
    if (dest) {
      var b = panel.querySelector('.br-destination-btn[data-destination="' +
                                  dest.getAttribute('data-destination') + '"]');
      if (b) window.switchBrandDestination(b);
    }
    var item = host.closest('.br-adv-item');
    if (item) {
      var drawer = item.closest('.br-advanced');
      var drawerBtn = drawer ? drawer.querySelector('.br-advanced-toggle') : null;
      if (drawerBtn && drawerBtn.getAttribute('aria-expanded') !== 'true') {
        drawerBtn.click();
      }
      var it = item.querySelector('.br-adv-toggle');
      if (it && it.tagName === 'BUTTON' &&
          it.getAttribute('aria-expanded') !== 'true') it.click();
    }
  }
  function exposeAll(panel) {
    panel.querySelectorAll('.br-subpanel').forEach(function (h) {
      exposeHost(panel, h);
    });
  }
  function noteFor(mount) {
    var scope = mount.getAttribute('data-chartfocus');
    var parent = mount.parentElement;
    if (!parent) return null;
    return parent.querySelector(
      '.br-cf-note[data-chartfocus-note="' + scope + '"]');
  }
  // What one category looks like right now: the header, every host's visible
  // brand codes, and every chart's deviation as the page states it.
  function readReport() {
    var panel = document.querySelector('.br-panel[id^="panel-cat-"]');
    if (!panel) return null;
    window.switchBrandTab(panel.id.replace(/^panel-/, ''));
    exposeAll(panel);
    var focalSel = panel.querySelector('.br-focal-select');
    var pop = panel.querySelector('.br-cmp-popover');
    var comparators = [];
    var locked = [];
    if (pop) {
      pop.querySelectorAll('.br-cmp-check').forEach(function (b) {
        if (b.checked) comparators.push(b.value);
        if (b.disabled) locked.push(b.value);
      });
    }
    var text = panel.querySelector('.br-cmp-text');
    var badge = panel.querySelector('.br-cmp-count');
    // One host at a time. Only the active destination has geometry, so a
    // sweep that laid every host out first and then read them would read
    // nothing but the last one, and two empty readings would agree.
    var hosts = {};
    panel.querySelectorAll('.br-subpanel').forEach(function (h) {
      exposeHost(panel, h);
      hosts[h.getAttribute('data-leaf')] = visibleBrandCodes(h);
    });
    var charts = {};
    panel.querySelectorAll('.br-cf[data-chartfocus]').forEach(function (m) {
      var scope = m.getAttribute('data-chartfocus');
      var ownHost = m.closest('.br-subpanel');
      if (ownHost) exposeHost(panel, ownHost);
      var note = noteFor(m);
      var trig = m.querySelector('.br-cf-trigger');
      var lbl = trig ? trig.querySelector('.br-cf-label') : null;
      var host = m.closest('.br-subpanel');
      charts[scope] = {
        leaf: host ? host.getAttribute('data-leaf') : '',
        label: lbl ? lbl.textContent : '',
        on: !!(trig && trig.classList.contains('br-cf-on')),
        noteHidden: note ? !!note.hidden : null,
        noteText: note ? note.textContent : '',
        clause: note ? (note.getAttribute('data-chartfocus-clause') || '') : '',
        triggers: m.querySelectorAll('.br-cf-trigger').length
      };
    });
    return {
      group: panel.getAttribute('data-group') ||
             panel.id.replace(/^panel-cat-/, ''),
      focal: focalSel ? focalSel.value : '',
      mode: pop ? (pop.getAttribute('data-cmp-mode') || '') : '',
      comparators: comparators.sort(),
      locked: locked.sort(),
      triggerText: text ? text.textContent : '',
      badge: badge ? badge.textContent : '',
      badgeHidden: badge ? !!badge.hidden : null,
      headerFocalSelects: Array.prototype.filter.call(
        panel.querySelectorAll('.br-focal-select'), visible).length,
      headerCmpTriggers: Array.prototype.filter.call(
        panel.querySelectorAll('.br-cmp-trigger'), visible).length,
      hosts: hosts,
      charts: charts
    };
  }
  // The lying-note check. The sentence claims two numbers; both are read
  // back off the DOM rather than believed. Only the stacked-bar hosts key
  // both their chart rows and their table rows on data-cb-brand, which is
  // what makes them readable apart.
  function auditNotes() {
    var panel = document.querySelector('.br-panel[id^="panel-cat-"]');
    var found = [];
    if (!panel) return found;
    panel.querySelectorAll('.br-cf[data-chartfocus]').forEach(function (m) {
      var note = noteFor(m);
      if (!note || note.hidden) return;
      var mm = /Chart shows (\\d+) of the (\\d+) brands/.exec(note.textContent);
      if (!mm) return;
      var host = m.closest('.br-subpanel');
      if (!host) return;
      // A table row only has geometry while its destination is active.
      exposeHost(panel, host);
      var chartRows = host.querySelectorAll('.fn-rel-chart [data-cb-brand]');
      var tableRows = host.querySelectorAll(
        '.cb-rel-table tbody tr[data-cb-brand]');
      if (!chartRows.length || !tableRows.length) return;
      var cs = {}, ts = {};
      Array.prototype.forEach.call(chartRows, function (el) {
        cs[el.getAttribute('data-cb-brand')] = true;
      });
      Array.prototype.forEach.call(tableRows, function (tr) {
        if (visible(tr)) ts[tr.getAttribute('data-cb-brand')] = true;
      });
      found.push({
        scope: m.getAttribute('data-chartfocus'),
        claimChart: parseInt(mm[1], 10), claimTable: parseInt(mm[2], 10),
        realChart: Object.keys(cs).length, realTable: Object.keys(ts).length
      });
    });
    return found;
  }
"""

PASS1 = """
<script id="turas-qa-driver">
(function () {
  var qa = window.__turasQa;
  var out = { checks: [], errors: qa.errors, expect: null, audit: [] };
  function check(name, ok, detail) {
    out.checks.push({ name: 'save/' + name, ok: !!ok, detail: detail || '' });
  }
__COMMON__

  function run() {
    var panel = document.querySelector('.br-panel[id^="panel-cat-"]');
    check('a category panel exists', !!panel);
    if (!panel) return finish();
    window.switchBrandTab(panel.id.replace(/^panel-/, ''));
    exposeAll(panel);

    // 1. A focal brand the report did not open on, so the restore is proved
    //    rather than coinciding with the default.
    var focalSel = panel.querySelector('.br-focal-select');
    check('the header has a focal select', !!focalSel);
    if (!focalSel) return finish();
    var opened = focalSel.value;
    var wantFocal = null;
    for (var i = 0; i < focalSel.options.length; i++) {
      if (focalSel.options[i].value !== opened) {
        wantFocal = focalSel.options[i].value; break;
      }
    }
    focalSel.value = wantFocal;
    focalSel.dispatchEvent(new Event('change', { bubbles: true }));
    check('the focal brand moved off the default', focalSel.value === wantFocal,
          opened + ' to ' + wantFocal);

    // 2. Two comparators.
    var pop = panel.querySelector('.br-cmp-popover');
    var picked = [];
    pop.querySelectorAll('.br-cmp-check').forEach(function (b) {
      if (b.disabled || picked.length >= 2) return;
      b.checked = true;
      b.dispatchEvent(new Event('change', { bubbles: true }));
      picked.push(b.value);
    });
    check('two comparators are picked', picked.length === 2, picked.join(','));

    // 3. Deviate every chart that can deviate. The header is not touched
    //    again after this: any header change resets every deviation, which
    //    is the control's own rule.
    exposeAll(panel);
    var deviated = 0, mounts = 0;
    panel.querySelectorAll('.br-cf[data-chartfocus]').forEach(function (m) {
      mounts++;
      var host = m.closest('.br-subpanel');
      if (host) exposeHost(panel, host);
      var trig = m.querySelector('.br-cf-trigger');
      if (!trig || trig.hidden) return;
      trig.click();
      var dropped = null;
      m.querySelectorAll('.br-cf-check').forEach(function (b) {
        if (dropped || b.disabled) return;
        dropped = b.value;
        b.checked = false;
        b.dispatchEvent(new Event('change', { bubbles: true }));
      });
      if (dropped) deviated++;
      trig.click();
    });
    check('at least one chart deviates before the save',
          deviated > 0, deviated + ' of ' + mounts + ' mounts');
    out.audit = auditNotes();
    check('a stacked-bar note was audited before the save',
          out.audit.length > 0, JSON.stringify(out.audit));

    // 4. What the reader is looking at, recorded.
    out.expect = readReport();

    // 5. The report's own serialiser, not a re-implementation of it.
    check('the report exposes _brSerialiseReport',
          typeof window._brSerialiseReport === 'function');
    var html = '';
    try { html = window._brSerialiseReport(); }
    catch (e) { check('_brSerialiseReport ran', false, String(e)); }
    check('the serialised string is the whole document',
          html.length > 100000 && html.indexOf('<!DOCTYPE html>') === 0,
          String(html.length) + ' chars');
    // The three mirrors, asserted in the string rather than in the DOM.
    check('the serialised string carries the picked focal brand',
          html.indexOf('value="' + wantFocal + '" selected') >= 0 ||
          new RegExp('value="' + wantFocal +
                     '"[^>]*selected').test(html),
          wantFocal);
    var ok = true;
    picked.forEach(function (c) {
      if (!new RegExp('class="br-cmp-check" value="' + c +
                      '"[^>]*checked').test(html)) ok = false;
    });
    check('the serialised string carries both comparators as attributes', ok,
          picked.join(','));
    // Both needles are assembled at runtime. The serialised string contains
    // this harness, so a literal needle would match its own source and the
    // count would be luck rather than evidence. The same trap the island
    // gate hit earlier on this branch.
    var savedNeedle = 'data-cf-' + 'saved="';
    var nSaved = html.split(savedNeedle).length - 1;
    check('the serialised string carries the chart deviations',
          nSaved === deviated,
          nSaved + ' saved for ' + deviated + ' deviating');
    // The CSS block names .br-cf-pop, so the needle is the class attribute
    // an element would carry, not the class name.
    var popNeedle = 'class="br-cf-' + 'pop"';
    check('no open Chart brands popover is serialised',
          html.indexOf(popNeedle) < 0,
          String(html.split(popNeedle).length - 1) + ' popovers');
    check('_brSaveReport goes through the same serialiser',
          typeof window._brSaveReport === 'function' &&
          /_brSerialiseReport\\(\\)/.test(String(window._brSaveReport)));

    finish();
  }

  function finish() {
    check('no console error and no uncaught exception', qa.errors.length === 0,
          qa.errors.slice(0, 8).join(' | '));
    // The harness must not travel into the saved copy: it would re-drive the
    // controls on reopen and the round trip would prove nothing.
    ['turas-qa-hook', 'turas-qa-driver'].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.remove();
    });
    var pre = document.createElement('pre');
    pre.id = 'turas-qa-result';
    pre.textContent = JSON.stringify(out);
    document.body.appendChild(pre);
  }

  function boot() { setTimeout(function () { try { run(); } catch (e) {
    var pre = document.createElement('pre');
    pre.id = 'turas-qa-result';
    pre.textContent = JSON.stringify({ checks: [{ name: 'save/pass 1 ran',
      ok: false, detail: String(e && e.stack || e) }], errors: qa.errors,
      expect: null, audit: [] });
    document.body.appendChild(pre);
  } }, 1500); }

  if (document.readyState === 'complete') boot();
  else window.addEventListener('load', boot);
})();
</script>
"""

PASS2 = """
<script id="turas-qa-driver">
(function () {
  var qa = window.__turasQa;
  var want = window.__turasExpect || {};
  var wantAudit = window.__turasAudit || [];
  var out = { checks: [], errors: qa.errors };
  function check(name, ok, detail) {
    out.checks.push({ name: 'reopen/' + name, ok: !!ok, detail: detail || '' });
  }
  function sameList(a, b) {
    return (a || []).join(',') === (b || []).join(',');
  }
__COMMON__

  function run() {
    var got = readReport();
    check('the reopened copy has a category panel', !!got);
    if (!got) return finish();

    check('the focal brand is the one the reader picked',
          got.focal === want.focal, got.focal + ' want ' + want.focal);
    check('the comparison mode is the one the reader left',
          got.mode === want.mode, got.mode + ' want ' + want.mode);
    check('the comparators are the ones the reader picked',
          sameList(got.comparators, want.comparators),
          got.comparators.join(',') + ' want ' + want.comparators.join(','));
    check('the focal brand is still the locked box',
          sameList(got.locked, want.locked),
          got.locked.join(',') + ' want ' + want.locked.join(','));
    check('the trigger reads what it read before',
          got.triggerText === want.triggerText,
          got.triggerText + ' want ' + want.triggerText);
    check('the badge reads what it read before',
          got.badge === want.badge && got.badgeHidden === want.badgeHidden,
          got.badge + '/' + got.badgeHidden);

    // The control census, on the reopened copy. A trigger built by
    // JavaScript serialises; a copy that appended a second one would show
    // two "Chart brands" buttons per chart and no census would catch it.
    check('exactly one header focal select is visible',
          got.headerFocalSelects === 1, String(got.headerFocalSelects));
    check('exactly one header brand-set trigger is visible',
          got.headerCmpTriggers === 1, String(got.headerCmpTriggers));

    var scopes = Object.keys(want.charts || {});
    check('the same charts carry a control', scopes.length ===
          Object.keys(got.charts || {}).length,
          Object.keys(got.charts || {}).length + ' of ' + scopes.length);
    scopes.forEach(function (s) {
      var w = want.charts[s], g = got.charts[s];
      if (!g) { check(s + ': the control is present', false); return; }
      check(s + ': exactly one Chart brands trigger', g.triggers === 1,
            String(g.triggers));
      check(s + ': the trigger reads what it read before',
            g.label === w.label, g.label + ' want ' + w.label);
      check(s + ': the amber deviating style is the same', g.on === w.on,
            String(g.on) + ' want ' + String(w.on));
      check(s + ': the note is shown or hidden as before',
            g.noteHidden === w.noteHidden,
            String(g.noteHidden) + ' want ' + String(w.noteHidden));
      check(s + ': the note says the same thing', g.noteText === w.noteText,
            g.noteText + ' want ' + w.noteText);
      check(s + ': the pin and PNG clause is the same', g.clause === w.clause,
            g.clause + ' want ' + w.clause);
    });

    Object.keys(want.hosts || {}).forEach(function (leaf) {
      check(leaf + ': shows the same brands as before',
            sameList(got.hosts[leaf], want.hosts[leaf]),
            (got.hosts[leaf] || []).join(',') + ' want ' +
            (want.hosts[leaf] || []).join(','));
    });

    // The case that would have shipped a lying note: a note claiming the
    // chart omits brands above a chart that shows all of them. Both numbers
    // in the sentence are read back off the DOM.
    var audit = auditNotes();
    check('the same notes are auditable after the round trip',
          audit.length === wantAudit.length,
          audit.length + ' of ' + wantAudit.length);
    audit.forEach(function (a) {
      check(a.scope + ': the note does not lie about the chart',
            a.claimChart === a.realChart,
            'note says ' + a.claimChart + ', chart has ' + a.realChart);
      check(a.scope + ': the note does not lie about the table',
            a.claimTable === a.realTable,
            'note says ' + a.claimTable + ', table has ' + a.realTable);
      check(a.scope + ': the chart really is narrower than the table',
            a.realChart < a.realTable,
            a.realChart + ' chart, ' + a.realTable + ' table');
    });

    finish();
  }

  function finish() {
    check('no console error and no uncaught exception', qa.errors.length === 0,
          qa.errors.slice(0, 8).join(' | '));
    var pre = document.createElement('pre');
    pre.id = 'turas-qa-result';
    pre.textContent = JSON.stringify(out);
    document.body.appendChild(pre);
  }

  function boot() { setTimeout(function () { try { run(); } catch (e) {
    var pre = document.createElement('pre');
    pre.id = 'turas-qa-result';
    pre.textContent = JSON.stringify({ checks: [{ name: 'reopen/pass 2 ran',
      ok: false, detail: String(e && e.stack || e) }], errors: qa.errors });
    document.body.appendChild(pre);
  } }, 1500); }

  if (document.readyState === 'complete') boot();
  else window.addEventListener('load', boot);
})();
</script>
"""

RESULT_RE = re.compile(r'<pre id="turas-qa-result">(.*?)</pre>', re.S)


def inject(html, head_extra, body_extra):
    i = html.index("<head>") + len("<head>")
    html = html[:i] + head_extra + html[i:]
    j = html.rindex("</body>")
    return html[:j] + body_extra + html[j:]


def write_tmp(html, suffix):
    fd, path = tempfile.mkstemp(suffix=suffix)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(html)
    return path


def run_chrome(path):
    cmd = [CHROME, "--headless", "--disable-gpu", "--no-sandbox",
           "--allow-file-access-from-files",
           "--virtual-time-budget=40000", "--dump-dom", "file://" + path]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=420)
    return proc


def read_result(dom):
    m = RESULT_RE.search(dom)
    if not m:
        return None
    body = (m.group(1).replace("&amp;", "&").replace("&lt;", "<")
            .replace("&gt;", ">").replace("&quot;", '"'))
    return json.loads(body)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    src = argv[1]
    keep = "--keep" in argv
    if not os.path.exists(CHROME):
        print("Chrome not found at", CHROME)
        return 2

    original = open(src, encoding="utf-8").read()
    p1_path = write_tmp(inject(original, HOOK,
                               PASS1.replace("__COMMON__", COMMON)),
                        "_save1.html")
    proc1 = run_chrome(p1_path)
    res1 = read_result(proc1.stdout)
    if res1 is None:
        print("Pass 1 did not report. Chrome stderr:")
        print(proc1.stderr[-2000:])
        return 1

    # The dump IS the saved copy: --dump-dom emits
    # document.documentElement.outerHTML, which is the string _brSaveReport()
    # writes into the file. The harness removed its own two scripts before
    # the dump; the result block is stripped here.
    saved = RESULT_RE.sub("", proc1.stdout)
    if not saved.lstrip().startswith("<"):
        print("Pass 1 dump did not look like a document")
        return 1
    saved_path = write_tmp(saved, "_saved.html")

    # The lying note, checked in the file rather than in a browser. Before
    # the fix a saved copy carried eight visible deviation notes and eight
    # data-chartfocus-clause attributes with no state behind any of them:
    # the sentence is a text node, so it serialised, while the set it
    # described lived on a JavaScript handle and did not. A browser repaint
    # clears the note a tick after load, but the file itself stated it, and
    # the clause attribute is what a pin and a PNG title read.
    doc_checks = []
    n_notes = len(re.findall(r'class="br-cf-note"[^>]*data-chartfocus-clause=',
                             saved))
    n_saved = len(re.findall(r'\sdata-cf-saved="', saved))
    doc_checks.append({
        "name": "file/every deviation note in the saved markup has state "
                "behind it",
        "ok": n_notes == n_saved,
        "detail": "%d notes claiming a deviation, %d deviations saved"
                  % (n_notes, n_saved)})
    # A deviating trigger carries br-cf-on beside its base class, so the
    # class attribute is matched with its tail rather than exactly.
    n_trig = len(re.findall(r'class="br-cf-trigger[^"]*"', saved))
    n_mount = len(re.findall(r'class="br-cf" data-chartfocus=', saved))
    doc_checks.append({
        "name": "file/the saved markup holds one Chart brands trigger "
                "per mount",
        "ok": n_trig == n_mount and n_mount > 0,
        "detail": "%d triggers for %d mounts" % (n_trig, n_mount)})

    expect = ("<script id=\"turas-qa-expect\">window.__turasExpect = " +
              json.dumps(res1.get("expect")) + "; window.__turasAudit = " +
              json.dumps(res1.get("audit", [])) + ";</script>")
    p2_path = write_tmp(inject(saved, HOOK + expect,
                               PASS2.replace("__COMMON__", COMMON)),
                        "_save2.html")
    proc2 = run_chrome(p2_path)
    res2 = read_result(proc2.stdout)
    if res2 is None:
        print("Pass 2 did not report. Chrome stderr:")
        print(proc2.stderr[-2000:])
        if keep:
            print("saved copy kept at", saved_path)
        return 1

    checks = res1["checks"] + doc_checks + res2["checks"]
    failed = [c for c in checks if not c["ok"]]
    for c in checks:
        mark = "ok  " if c["ok"] else "FAIL"
        print("  %s %s%s" % (mark, c["name"],
                             (" -> " + c["detail"]) if c["detail"] else ""))
    errors = res1["errors"] + res2["errors"]
    if errors:
        print("\nConsole errors and exceptions (%d):" % len(errors))
        for e in errors[:20]:
            print("  " + e)
    print("\nSaved copy: %d bytes (original %d)" % (len(saved), len(original)))
    print("%d checks, %d failed" % (len(checks), len(failed)))
    if keep:
        print("kept:", p1_path, saved_path, p2_path)
    else:
        for p in (p1_path, saved_path, p2_path):
            os.unlink(p)
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
