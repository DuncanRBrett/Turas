// ==============================================================================
// BRAND REPORT - CORE INTERACTIVITY
// ==============================================================================
// Tab switching, category sub-navigation, insight editor, save, help,
// table sorting, Excel export.
// ==============================================================================

(function() {
  "use strict";

  // --- Tab switching ---
  window.switchBrandTab = function(tabName) {
    document.querySelectorAll(".br-tab-btn").forEach(function(btn) {
      btn.classList.toggle("active", btn.getAttribute("data-tab") === tabName);
    });
    document.querySelectorAll(".br-panel").forEach(function(panel) {
      panel.classList.remove("active");
    });
    var target = document.getElementById("panel-" + tabName);
    if (target) target.classList.add("active");

    var titleEl = document.getElementById("br-header-title");
    if (titleEl) {
      var header = document.querySelector(".br-header");
      var reportTitle = header ? (header.getAttribute("data-report-title") || "") : "";
      var nonCatTabs = ["summary", "pinned", "about", "dba", "wom", "portfolio"];
      if (nonCatTabs.indexOf(tabName) !== -1) {
        titleEl.textContent = reportTitle;
      } else {
        var activeBtn = document.querySelector('.br-tab-btn[data-tab="' + tabName + '"]');
        if (activeBtn) {
          var badge = activeBtn.querySelector(".br-pin-badge");
          var label = activeBtn.textContent.trim();
          if (badge) label = label.replace(badge.textContent.trim(), "").trim();
          titleEl.textContent = label;
        }
      }
    }
  };

  // --- Activating one sub-panel host ---
  // Shared by the destination switcher and by switchCategorySubtab. The two
  // things a host needs on activation, unchanged from the flat sub-tab bar:
  //   1. show only the .br-insight-wrap whose data-insight-internal-tab
  //      matches this host's internal tab, so one Section_Insights box is
  //      visible at a time;
  //   2. click the panel's own hidden sub-tab button, which is how the MA,
  //      funnel and cat-buying panels run their own state updates and
  //      re-render charts that were laid out while hidden.
  function activateHost(host) {
    if (!host) return;
    var internalTab = host.getAttribute("data-internal-tab") || "";
    var cbTab       = host.getAttribute("data-cb-tab") || "";

    if (internalTab) {
      host.querySelectorAll('.br-insight-wrap[data-insight-internal-tab]')
        .forEach(function (w) {
          w.style.display =
            (w.getAttribute('data-insight-internal-tab') === internalTab)
              ? 'block' : 'none';
        });

      // MA panel: click the hidden .ma-subtab-btn
      var maBtn = host.querySelector(
        '.ma-subtab-btn[data-ma-subtab-target="' + internalTab + '"]'
      );
      if (maBtn) { maBtn.click(); return; }

      // Funnel panel: click the hidden .fn-subtab-btn
      var fnBtn = host.querySelector(
        '.fn-subtab-btn[data-fn-subtab-target="' + internalTab + '"]'
      );
      if (fnBtn) { fnBtn.click(); return; }
    }

    if (cbTab) {
      // Cat-buying panel: click the hidden .cb-subtab-btn
      var cbBtn = host.querySelector(
        '.cb-subtab-btn[data-cb-tab="' + cbTab + '"]'
      );
      if (cbBtn) cbBtn.click();
    }
  }
  window.brActivateHost = activateHost;

  function hostsIn(root) {
    return root ? Array.prototype.slice.call(
      root.querySelectorAll(".br-subpanel")) : [];
  }

  // --- Destination switching (five destinations per category) ---
  window.switchBrandDestination = function(btn) {
    var group = btn.getAttribute("data-group");
    var dest  = btn.getAttribute("data-destination");

    document.querySelectorAll('.br-destination-btn[data-group="' + group + '"]')
      .forEach(function(b) {
        b.classList.toggle("active", b.getAttribute("data-destination") === dest);
      });

    var active = null;
    document.querySelectorAll('.br-destination[data-group="' + group + '"]')
      .forEach(function(d) {
        var on = d.getAttribute("data-destination") === dest;
        d.classList.toggle("active", on);
        if (on) active = d;
      });

    if (!active) return;
    // Only hosts that are actually laid out are re-activated: a host inside
    // a collapsed Advanced item is activated when that item is expanded.
    var main = active.querySelector(".br-dest-main");
    hostsIn(main).forEach(activateHost);
    active.querySelectorAll(".br-adv-body:not([hidden])").forEach(function(b) {
      hostsIn(b).forEach(activateHost);
    });
  };

  // --- Advanced drawer, and its one-at-a-time accordion ---
  window.brToggleAdvanced = function(btn) {
    var body = btn.parentNode ? btn.parentNode.querySelector(".br-advanced-body") : null;
    if (!body) return;
    var open = body.hidden;
    body.hidden = !open;
    btn.setAttribute("aria-expanded", open ? "true" : "false");
    if (open) {
      body.querySelectorAll(".br-adv-body:not([hidden])").forEach(function(b) {
        hostsIn(b).forEach(activateHost);
      });
    }
  };

  window.brToggleAdvancedItem = function(btn) {
    var item = btn.closest(".br-adv-item");
    var wrap = item ? item.parentNode : null;
    if (!item || !wrap) return;
    var body = item.querySelector(".br-adv-body");
    if (!body) return;
    var opening = body.hidden;

    // One researcher-grade analysis expanded at a time.
    wrap.querySelectorAll(".br-adv-item").forEach(function(other) {
      var ob = other.querySelector(".br-adv-body");
      var ot = other.querySelector(".br-adv-toggle");
      if (!ob) return;
      ob.hidden = true;
      if (ot) ot.setAttribute("aria-expanded", "false");
    });

    if (opening) {
      body.hidden = false;
      btn.setAttribute("aria-expanded", "true");
      hostsIn(body).forEach(activateHost);
    }
  };

  // --- Overview route into the Summary tab for one category ---
  // The summary panel's category dropdown is keyed on the category's display
  // name, not on the cat id the category tab uses, so the name is passed in
  // and matched first; the id is the fallback for a report whose summary
  // options are keyed differently.
  window.brOpenSummaryFor = function(catId, catName) {
    window.switchBrandTab("summary");
    var sel = document.querySelector("[data-brsum-cat]");
    if (!sel) return;
    var pick = null;
    for (var i = 0; i < sel.options.length; i++) {
      var o = sel.options[i];
      var v = String(o.value || "");
      if (catName && (v === catName || o.textContent.trim() === catName)) {
        pick = o.value; break;
      }
      if (v.toLowerCase().replace(/[^a-z0-9]+/g, "-") === catId) {
        pick = o.value;
      }
    }
    if (pick === null) return;
    sel.value = pick;
    sel.dispatchEvent(new Event("change", { bubbles: true }));
  };

  // --- Category sub-tab switching (kept: the panel-internal route) ---
  // Nothing in the destination shell calls this, but it stays valid and
  // stays the one way a caller reaches a panel's internal tab. Each button
  // carries data-subpanel and data-internal-tab. The internal panel nav bars
  // (.fn-subnav / .ma-subnav / .cb-subnav) are hidden via CSS but remain in
  // the DOM so dispatching a click on them triggers their own JS updates.
  // The host selector now also matches on data-internal-tab, because one
  // category renders several hosts per sub-panel since the render was split.
  window.switchCategorySubtab = function(btn) {
    var group       = btn.getAttribute("data-group");
    var subtab      = btn.getAttribute("data-subtab");
    var subpanel    = btn.getAttribute("data-subpanel");
    var internalTab = btn.getAttribute("data-internal-tab") || "";

    document.querySelectorAll('.br-subtab-btn[data-group="' + group + '"]').forEach(function(b) {
      b.classList.toggle("active", b.getAttribute("data-subtab") === subtab);
    });

    var sel = '.br-subpanel[data-group="' + group + '"]';
    var own = sel + '[data-subpanel="' + subpanel + '"]';
    if (internalTab) own += '[data-internal-tab="' + internalTab + '"]';

    // Show the sub-panel that owns this tab
    document.querySelectorAll(sel).forEach(function(p) {
      p.classList.toggle("active", p.matches(own));
    });

    if (internalTab) activateHost(document.querySelector(own));
  };


  // ==========================================================================
  // Persistent comparison set
  // ==========================================================================
  // One control per category sets the focal brand and up to five comparators,
  // and every destination respects it. Nothing is recomputed and no panel's
  // own filtering is reimplemented: the control drives each panel's existing
  // focal select, and publishes the hidden-brand set to the shared
  // category-scoped store that BrandSelector already keeps.

  var CMP_MAX = 5;

  function cmpState(group) {
    var boxes = document.querySelectorAll(
      '.br-cmp-popover[data-group="' + group + '"] .br-cmp-check');
    var focalSel = document.getElementById("br-focal-select-" + group);
    var focal = focalSel ? focalSel.value : "";
    var comparators = [];
    boxes.forEach(function (b) {
      if (b.checked && b.value !== focal) comparators.push(b.value);
    });
    return { focal: focal, comparators: comparators };
  }

  // Every panel host in this category, whatever its destination.
  function categoryPanels(group) {
    var sel = '.fn-panel[data-category-key="' + group + '"],' +
              '.ma-panel[data-category-key="' + group + '"],' +
              '.cb-panel[data-cb-cat-code="' + group + '"]';
    return Array.prototype.slice.call(document.querySelectorAll(sel));
  }

  function setPanelFocal(panel, code) {
    var sel = panel.querySelector(".fn-focus-select") ||
              panel.querySelector(".ma-focus-select") ||
              panel.querySelector('select.cb-focus-select[data-cb-action="focus"]') ||
              panel.querySelector(".wom-focus-select");
    if (!sel || !code) return;
    var found = false;
    for (var i = 0; i < sel.options.length; i++) {
      if (String(sel.options[i].value) === String(code)) { found = true; break; }
    }
    if (!found || sel.value === code) return;
    sel.value = code;
    sel.dispatchEvent(new Event("change", { bubbles: true }));
  }

  window.brApplyComparisonSet = function(group) {
    var st = cmpState(group);
    var badge = document.querySelector('.br-cmp-count[data-group="' + group + '"]');
    if (badge) badge.textContent = String(st.comparators.length);

    categoryPanels(group).forEach(function (p) { setPanelFocal(p, st.focal); });

    // Visible set = focal plus comparators. With no comparators picked the
    // control makes no claim about visibility and hides nothing, so the
    // panels keep whatever the analyst last chose on them.
    if (typeof window.BrandSelector === "undefined" ||
        !window.BrandSelector.setCategoryHidden) return;
    if (st.comparators.length === 0) {
      window.BrandSelector.setCategoryHidden(group, []);
      return;
    }
    var show = {};
    show[st.focal] = true;
    st.comparators.forEach(function (c) { show[c] = true; });
    var hidden = window.BrandSelector.categoryBrands(group).filter(function (c) {
      return !show[c];
    });
    window.BrandSelector.setCategoryHidden(group, hidden);
  };

  window.brComparisonFocalChanged = function(sel) {
    var group = sel.getAttribute("data-group");
    // The focal brand is always in the comparison set and cannot be unpicked,
    // so its own checkbox follows the dropdown. The brand that was focal
    // before is released rather than silently promoted to a comparator: a
    // slot consumed without a click is a surprise, and there are only five.
    document.querySelectorAll(
      '.br-cmp-popover[data-group="' + group + '"] .br-cmp-check')
      .forEach(function (b) {
        var isFocal = (b.value === sel.value);
        var wasFocal = b.disabled && !isFocal;
        b.disabled = isFocal;
        if (isFocal) b.checked = true;
        else if (wasFocal) b.checked = false;
      });
    window.brApplyComparisonSet(group);
  };

  window.brComparisonSetChanged = function(box) {
    var pop = box.closest(".br-cmp-popover");
    if (!pop) return;
    var group = pop.getAttribute("data-group");
    var st = cmpState(group);
    if (st.comparators.length > CMP_MAX) {
      // Five comparators is the cap the control advertises.
      box.checked = false;
      return;
    }
    window.brApplyComparisonSet(group);
  };

  window.brClearComparisonSet = function(btn) {
    var pop = btn.closest(".br-cmp-popover");
    if (!pop) return;
    var group = pop.getAttribute("data-group");
    pop.querySelectorAll(".br-cmp-check").forEach(function (b) {
      if (!b.disabled) b.checked = false;
    });
    window.brApplyComparisonSet(group);
  };

  window.brToggleComparisonPopover = function(btn) {
    var group = btn.getAttribute("data-group");
    var pop = document.querySelector('.br-cmp-popover[data-group="' + group + '"]');
    if (!pop) return;
    var open = pop.hidden;
    document.querySelectorAll(".br-cmp-popover").forEach(function (p) { p.hidden = true; });
    document.querySelectorAll(".br-cmp-trigger").forEach(function (t) {
      t.setAttribute("aria-expanded", "false");
    });
    pop.hidden = !open;
    btn.setAttribute("aria-expanded", open ? "true" : "false");
  };

  window.brSwitchCategoryFromControl = function(sel) {
    var target = sel.value;
    if (!target) return;
    // Keep the reader on the same destination in the category they move to.
    var group = sel.getAttribute("data-group");
    var activeBtn = document.querySelector(
      '.br-destination-btn[data-group="' + group + '"].active');
    var dest = activeBtn ? activeBtn.getAttribute("data-destination") : null;
    window.switchBrandTab("cat-" + target);
    if (!dest) return;
    var newBtn = document.querySelector(
      '.br-destination-btn[data-group="' + target + '"][data-destination="' + dest + '"]');
    if (newBtn) window.switchBrandDestination(newBtn);
  };

  document.addEventListener("click", function (ev) {
    if (ev.target && ev.target.closest &&
        !ev.target.closest(".br-cmp-popover") &&
        !ev.target.closest(".br-cmp-trigger")) {
      document.querySelectorAll(".br-cmp-popover").forEach(function (p) { p.hidden = true; });
    }
  }, true);

  // --- Insight editor ---
  window._brToggleInsight = function(sectionId) {
    var container = document.querySelector('.br-insight-container[data-section="' + sectionId + '"]');
    if (!container) return;
    var visible = container.style.display !== "none";
    container.style.display = visible ? "none" : "block";
    if (!visible) {
      var editor = container.querySelector(".br-insight-editor");
      if (editor) editor.focus();
    }
  };

  window._brToggleInsightEdit = function(sectionId) {
    var container = document.querySelector('.br-insight-container[data-section="' + sectionId + '"]');
    if (!container) return;
    var editor = container.querySelector(".br-insight-editor");
    var rendered = container.querySelector(".br-insight-rendered");
    if (!editor || !rendered) return;

    if (editor.style.display === "none") {
      editor.style.display = "block";
      rendered.style.display = "none";
      editor.focus();
    } else {
      rendered.innerHTML = _brRenderMd(editor.value);
      editor.style.display = "none";
      rendered.style.display = "block";
    }
  };

  window._brDismissInsight = function(sectionId) {
    var container = document.querySelector('.br-insight-container[data-section="' + sectionId + '"]');
    if (container) container.style.display = "none";
  };

  function _brRenderMd(md) {
    if (!md) return "";
    var html = md
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/^## (.+)$/gm, "<h4>$1</h4>")
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      .replace(/\*(.+?)\*/g, "<em>$1</em>")
      .replace(/^&gt; (.+)$/gm, "<blockquote>$1</blockquote>")
      .replace(/^- (.+)$/gm, "<li>$1</li>");
    html = html.replace(/((?:<li>.*<\/li>\s*)+)/g, function(m) { return "<ul>" + m + "</ul>"; });
    return html.split("\n").map(function(line) {
      var t = line.trim();
      if (!t) return "";
      if (/^<(h4|ul|li|blockquote)/.test(t)) return t;
      return "<p>" + t + "</p>";
    }).join("\n");
  }

  // --- Table sorting ---
  function initTableSort() {
    document.querySelectorAll(".br-table th").forEach(function(th) {
      th.style.cursor = "pointer";
      th.addEventListener("click", function() {
        var table = th.closest("table");
        var tbody = table.querySelector("tbody");
        if (!tbody) return;
        var colIdx = Array.from(th.parentNode.children).indexOf(th);
        var rows = Array.from(tbody.querySelectorAll("tr"));
        var asc = th.getAttribute("data-sort-dir") !== "asc";
        th.setAttribute("data-sort-dir", asc ? "asc" : "desc");

        // Remove arrows from siblings
        th.parentNode.querySelectorAll("th").forEach(function(h) {
          h.textContent = h.textContent.replace(/ [▲▼]/g, "");
        });
        th.textContent += asc ? " ▲" : " ▼";

        rows.sort(function(a, b) {
          var av = a.children[colIdx] ? a.children[colIdx].textContent.trim() : "";
          var bv = b.children[colIdx] ? b.children[colIdx].textContent.trim() : "";
          var an = parseFloat(av.replace(/[%,]/g, ""));
          var bn = parseFloat(bv.replace(/[%,]/g, ""));
          if (!isNaN(an) && !isNaN(bn)) return asc ? an - bn : bn - an;
          return asc ? av.localeCompare(bv) : bv.localeCompare(av);
        });
        rows.forEach(function(r) { tbody.appendChild(r); });
      });
    });
  }

  // --- Commentary persistence: one mechanism for every textarea ---
  // A textarea's .value is live state that outerHTML never sees. Its text
  // content is what a saved file carries and what a browser loads back as
  // the initial value. Mirroring value into text content on every input
  // event (and once more just before Save serialises the page) makes every
  // commentary box in the report survive Save and reopen: the generic
  // .br-insight-editor, the funnel and cat-buying .fn-insight-textarea, the
  // MA / WoM / Branded Reach / Ad Hoc / Audience Lens .ma-insight-box-text
  // and the Summary .brsum-insight-editor. The MA and Audience Lens boxes
  // used sessionStorage / localStorage before, which a saved file never
  // carried and which two clients' reports sharing a category code
  // overwrote in one browser; both are retired (review 2026-07-12, C2 + H3).
  // Mirrors TurasPins, whose textContent store already survives Save.
  window._brSyncCommentary = function(ta) {
    if (!ta || !ta.tagName || ta.tagName !== "TEXTAREA") return;
    if (ta.textContent !== ta.value) ta.textContent = ta.value;
  };
  window._brSyncAllCommentary = function() {
    document.querySelectorAll("textarea").forEach(window._brSyncCommentary);
  };
  function initCommentaryPersistence() {
    ["input", "change"].forEach(function(evt) {
      document.addEventListener(evt, function(ev) {
        window._brSyncCommentary(ev.target);
      }, true);
    });
  }

  // --- Save report ---
  window._brSaveReport = function() {
    // Belt and braces: mirror every textarea once more before serialising,
    // in case a panel wrote .value programmatically without an input event.
    window._brSyncAllCommentary();
    var html = "<!DOCTYPE html>\n" + document.documentElement.outerHTML;
    var blob = new Blob([html], { type: "text/html" });
    var meta = document.querySelector('meta[name="turas-source-filename"]');
    var fname = meta ? meta.content.replace(/\.html$/, "") + "_saved.html" : "brand_report.html";

    if (window.showSaveFilePicker) {
      window.showSaveFilePicker({
        suggestedName: fname,
        types: [{ description: "HTML", accept: { "text/html": [".html"] } }]
      }).then(function(handle) {
        return handle.createWritable().then(function(w) {
          return w.write(blob).then(function() { return w.close(); });
        });
      }).catch(function() {});
    } else {
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = fname;
      a.click();
      URL.revokeObjectURL(a.href);
    }
  };

  // --- Help overlay ---
  window._brToggleHelp = function() {
    var overlay = document.getElementById("br-help-overlay");
    if (overlay) overlay.classList.toggle("open");
  };

  // --- Excel export per section ---
  window._brExportPanel = function(panelId) {
    var panel = document.getElementById("section-" + panelId);
    if (!panel) panel = document.querySelector('[data-section="' + panelId + '"]');
    if (!panel && /^pf-/.test(panelId)) {
      var subId = panelId.replace(/^pf-/, "pf-subtab-");
      panel = document.getElementById(subId);
    }
    if (!panel) return;

    var tables = panel.querySelectorAll("table.br-table");
    if (tables.length === 0) tables = panel.querySelectorAll("table");
    if (tables.length === 0) {
      alert("No table available on this section to export.");
      return;
    }

    var xml = '<?xml version="1.0"?><?mso-application progid="Excel.Sheet"?>';
    xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">';

    tables.forEach(function(table, idx) {
      xml += '<Worksheet ss:Name="' + (panelId.substring(0,25) + (idx > 0 ? "_" + idx : "")) + '"><Table>';
      table.querySelectorAll("tr").forEach(function(tr) {
        xml += "<Row>";
        tr.querySelectorAll("th, td").forEach(function(cell) {
          var val = cell.textContent.trim().replace(/[▲▼]/g, "").trim();
          var num = parseFloat(val.replace(/[%,]/g, ""));
          var type = !isNaN(num) && val !== "" ? "Number" : "String";
          var clean = type === "Number" ? num : val.replace(/&/g, "&amp;").replace(/</g, "&lt;");
          xml += '<Cell><Data ss:Type="' + type + '">' + clean + "</Data></Cell>";
        });
        xml += "</Row>";
      });
      xml += "</Table></Worksheet>";
    });
    xml += "</Workbook>";

    var blob = new Blob([xml], { type: "application/vnd.ms-excel" });
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = panelId + ".xls";
    a.click();
    URL.revokeObjectURL(a.href);
  };

  // --- Init ---
  function init() {
    initTableSort();
    initCommentaryPersistence();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
