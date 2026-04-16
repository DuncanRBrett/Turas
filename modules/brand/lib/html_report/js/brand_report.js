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
  };

  // --- Category sub-tab switching ---
  window.switchCategorySubtab = function(btn) {
    var group = btn.getAttribute("data-group");
    var subtab = btn.getAttribute("data-subtab");

    document.querySelectorAll('.br-subtab-btn[data-group="' + group + '"]').forEach(function(b) {
      b.classList.toggle("active", b.getAttribute("data-subtab") === subtab);
    });
    document.querySelectorAll('.br-subpanel[data-group="' + group + '"]').forEach(function(p) {
      p.classList.toggle("active", p.getAttribute("data-subpanel") === subtab);
    });
  };

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

  // --- Save report ---
  window._brSaveReport = function() {
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
    if (!panel) return;

    var tables = panel.querySelectorAll("table.br-table");
    if (tables.length === 0) return;

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
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
