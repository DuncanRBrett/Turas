/**
 * Conjoint Report Pin System
 * Pin views, render pinned cards, persist to JSON store, batch export.
 */

(function() {
  "use strict";

  var pinnedViews = [];

  // === TOGGLE PIN ===

  window.togglePin = function(viewId) {
    var idx = pinnedViews.findIndex(function(v) { return v.id === viewId; });

    if (idx >= 0) {
      // Unpin
      pinnedViews.splice(idx, 1);
    } else {
      // Pin: capture current view
      var captured = captureView(viewId);
      if (captured) {
        pinnedViews.push(captured);
      }
    }

    updatePinButtons();
    renderPinnedCards();
    savePinnedData();
  };

  function captureView(viewId) {
    // Find the source element
    var source = null;

    // Check active attribute detail
    var activeDetail = document.querySelector('.cj-attr-detail.active');
    if (activeDetail) {
      source = activeDetail;
    }

    // Check panel by id prefix
    if (!source) {
      var panelId = viewId.replace(/^util-/, "").replace(/^panel-/, "");
      source = document.getElementById("panel-" + panelId);
    }

    if (!source) return null;

    // Get title
    var titleEl = source.querySelector("h2");
    var title = titleEl ? titleEl.textContent : viewId;

    // Get chart SVG
    var chartSvg = "";
    var svgEl = source.querySelector("svg");
    if (svgEl) {
      chartSvg = new XMLSerializer().serializeToString(svgEl);
    }

    // Get table HTML
    var tableHtml = "";
    var tableEl = source.querySelector(".cj-table");
    if (tableEl) {
      tableHtml = tableEl.outerHTML;
    }

    return {
      id: viewId,
      title: title,
      chart: chartSvg,
      table: tableHtml,
      note: "",
      timestamp: new Date().toISOString()
    };
  }


  // === UPDATE PIN BUTTONS ===

  function updatePinButtons() {
    document.querySelectorAll(".cj-pin-btn").forEach(function(btn) {
      var onclick = btn.getAttribute("onclick") || "";
      var match = onclick.match(/togglePin\('([^']+)'\)/);
      if (match) {
        var id = match[1];
        var isPinned = pinnedViews.some(function(v) { return v.id === id; });
        btn.classList.toggle("pinned", isPinned);
        btn.textContent = isPinned ? "Pinned" : "Pin";
      }
    });
  }


  // === RENDER PINNED CARDS ===

  function renderPinnedCards() {
    var container = document.getElementById("cj-pinned-cards");
    var empty = document.getElementById("cj-pinned-empty");
    if (!container) return;

    if (pinnedViews.length === 0) {
      container.innerHTML = "";
      if (empty) empty.style.display = "";
      return;
    }

    if (empty) empty.style.display = "none";

    var html = "";
    pinnedViews.forEach(function(view, idx) {
      if (view.type === "section") {
        html += '<div class="cj-section-divider">';
        html += '<div class="cj-section-title" contenteditable="true" oninput="updateSectionTitle(' + idx + ', this.textContent)">' + escHtml(view.title) + '</div>';
        html += '<button class="cj-export-btn" style="position:absolute;right:0;top:0;" onclick="removePinned(' + idx + ')">\u00d7</button>';
        html += '</div>';
        return;
      }

      html += '<div class="cj-pinned-card">';
      html += '<div class="cj-pinned-card-title">' + escHtml(view.title) + '</div>';
      html += '<div class="cj-pinned-card-actions">';
      html += '<button class="cj-export-btn" onclick="exportPinnedSlide(' + idx + ')">Slide PNG</button>';
      html += '<button class="cj-export-btn" onclick="removePinned(' + idx + ')">\u00d7</button>';
      html += '</div>';

      if (view.chart) {
        html += '<div class="cj-chart-container">' + view.chart + '</div>';
      }
      if (view.table) {
        html += view.table;
      }

      // Note area
      html += '<div style="margin-top:12px;">';
      html += '<div class="cj-insight-editor" contenteditable="true" data-placeholder="Add a note..." oninput="updatePinnedNote(' + idx + ', this.innerHTML)">' + (view.note || '') + '</div>';
      html += '</div>';

      html += '</div>';
    });

    container.innerHTML = html;
  }

  window.removePinned = function(idx) {
    pinnedViews.splice(idx, 1);
    updatePinButtons();
    renderPinnedCards();
    savePinnedData();
  };

  window.updatePinnedNote = function(idx, html) {
    if (pinnedViews[idx]) {
      pinnedViews[idx].note = html;
      savePinnedData();
    }
  };

  window.updateSectionTitle = function(idx, text) {
    if (pinnedViews[idx]) {
      pinnedViews[idx].title = text;
      savePinnedData();
    }
  };


  // === ADD SECTION DIVIDER ===

  window.addSection = function() {
    pinnedViews.push({
      id: "section-" + Date.now(),
      type: "section",
      title: "",
      timestamp: new Date().toISOString()
    });
    renderPinnedCards();
    savePinnedData();
  };


  // === PERSISTENCE ===

  function savePinnedData() {
    var store = document.getElementById("pinned-views-data");
    if (store) {
      store.textContent = JSON.stringify(pinnedViews);
    }
  }

  window.hydratePinnedViews = function() {
    var store = document.getElementById("pinned-views-data");
    if (store) {
      try {
        var data = JSON.parse(store.textContent);
        if (Array.isArray(data) && data.length > 0) {
          pinnedViews = data;
          updatePinButtons();
          renderPinnedCards();
        }
      } catch (e) { /* invalid JSON */ }
    }
  };


  // === EXPORT PINNED ===

  window.exportPinnedSlide = function(idx) {
    var view = pinnedViews[idx];
    if (!view) return;

    var slideW = 1280, slideH = 720, scale = 3;
    var canvas = document.createElement("canvas");
    canvas.width = slideW * scale;
    canvas.height = slideH * scale;
    var ctx = canvas.getContext("2d");
    ctx.scale(scale, scale);

    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, slideW, slideH);

    var brand = getComputedStyle(document.documentElement).getPropertyValue("--cj-brand").trim() || "#323367";
    ctx.fillStyle = brand;
    ctx.fillRect(0, 0, slideW, 50);
    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 18px system-ui, sans-serif";
    ctx.fillText(view.title, 24, 34);

    ctx.fillStyle = "#94a3b8";
    ctx.font = "10px system-ui, sans-serif";
    ctx.fillText("Generated by TURAS Analytics Platform", 24, slideH - 12);

    canvas.toBlob(function(blob) {
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "pinned_" + (idx + 1) + ".png";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
    }, "image/png");
  };

  window.exportAllPinnedSlides = function() {
    pinnedViews.forEach(function(view, idx) {
      if (view.type !== "section") {
        setTimeout(function() { exportPinnedSlide(idx); }, idx * 300);
      }
    });
  };

  window.printPinnedViews = function() {
    // Switch to pinned tab and print
    switchReportTab("pinned");
    setTimeout(function() { window.print(); }, 200);
  };


  // === UTILITY ===

  function escHtml(s) {
    var d = document.createElement("div");
    d.textContent = s || "";
    return d.innerHTML;
  }

})();
