/**
 * Conjoint Report Pin System
 * Pin views, render pinned cards, persist to JSON store, batch export.
 * Supports utility attributes (util-*), panel cards (pin-*), and custom entries.
 */

(function() {
  "use strict";

  var pinnedViews = [];

  // === TOGGLE PIN ===

  window.togglePin = function(viewId) {
    // Simulator pins are snapshots — always add, never toggle off
    // This allows multiple market share / revenue / sensitivity snapshots
    var isSimulator = (viewId === "pin-simulator");

    if (isSimulator) {
      var captured = captureView(viewId);
      if (captured) {
        // Give each simulator snapshot a unique ID
        captured.id = "pin-sim-" + Date.now();
        pinnedViews.push(captured);
      }
      renderPinnedCards();
      savePinnedData();
      updatePinnedBadge();
      showPinToast("Snapshot pinned to collection");
      bounceButton(viewId);
      return;
    }

    // Non-simulator pins: standard toggle behavior
    var idx = pinnedViews.findIndex(function(v) { return v.id === viewId; });
    var wasPinned = idx >= 0;

    if (wasPinned) {
      pinnedViews.splice(idx, 1);
    } else {
      var captured = captureView(viewId);
      if (captured) {
        pinnedViews.push(captured);
      }
    }

    updatePinButtons();
    renderPinnedCards();
    savePinnedData();
    updatePinnedBadge();

    showPinToast(wasPinned ? "Removed from collection" : "Pinned to collection");
    bounceButton(viewId);
  };

  function captureView(viewId) {
    var source = null;

    // Utility attribute detail (util-Brand, util-Price, etc.)
    if (viewId.indexOf("util-") === 0) {
      source = document.querySelector('.cj-attr-detail.active');
    }
    // Panel-level pins (pin-overview, pin-diagnostics-fit, etc.)
    else if (viewId.indexOf("pin-") === 0) {
      var panelPart = viewId.replace(/^pin-/, "");

      // Diagnostics sub-cards: pin-diagnostics-fit, pin-diagnostics-convergence, pin-diagnostics-quality
      if (panelPart.indexOf("diagnostics-") === 0) {
        var subPart = panelPart.replace("diagnostics-", "");
        var diagPanel = document.getElementById("panel-diagnostics");
        if (diagPanel) {
          var targetH2 = {"fit": "Model Fit", "convergence": "HB Convergence", "quality": "Respondent Quality"};
          diagPanel.querySelectorAll(".cj-card").forEach(function(card) {
            var h2 = card.querySelector("h2");
            if (h2 && h2.textContent === targetH2[subPart]) source = card;
          });
        }
      }
      // LC sub-cards: pin-lc-bic, pin-lc-sizes, pin-lc-importance
      else if (panelPart.indexOf("lc-") === 0) {
        var lcPart = panelPart.replace("lc-", "");
        var lcPanel = document.getElementById("panel-latentclass");
        if (lcPanel) {
          var lcTarget = {"bic": "Model Comparison", "sizes": "Class Sizes", "importance": "Importance by Class"};
          lcPanel.querySelectorAll(".cj-card").forEach(function(card) {
            var h2 = card.querySelector("h2");
            if (h2 && h2.textContent === lcTarget[lcPart]) source = card;
          });
        }
      }
      // WTP sub-cards: pin-wtp-main, pin-wtp-demand
      else if (panelPart.indexOf("wtp-") === 0) {
        var wtpPart = panelPart.replace("wtp-", "");
        var wtpPanel = document.getElementById("panel-wtp");
        if (wtpPanel) {
          var wtpTarget = {"main": "Willingness to Pay", "demand": "Demand Curve"};
          wtpPanel.querySelectorAll(".cj-card").forEach(function(card) {
            var h2 = card.querySelector("h2");
            if (h2 && h2.textContent === wtpTarget[wtpPart]) source = card;
          });
        }
      }
      // Overview: pin-overview
      else if (panelPart === "overview") {
        source = document.querySelector("#panel-overview .cj-card");
      }
      // Simulator: pin-simulator -> capture the results div with mode label
      else if (panelPart === "simulator") {
        source = document.getElementById("cj-sim-results");
        // Tag with current mode for descriptive snapshot title
        if (source) {
          var modeBtn = document.querySelector(".cj-sim-mode-btn.active");
          source._simMode = modeBtn ? modeBtn.textContent : "Simulator";
        }
      }
    }

    // Fallback: try panel-{id}
    if (!source) {
      var panelId = viewId.replace(/^util-/, "").replace(/^panel-/, "");
      source = document.getElementById("panel-" + panelId);
    }

    if (!source) return null;

    // Get title (simulator snapshots use mode label + timestamp)
    var titleEl = source.querySelector("h2") || source.querySelector("h3");
    var title = titleEl ? titleEl.textContent : viewId;
    if (source._simMode) {
      var now = new Date();
      var timeStr = now.getHours().toString().padStart(2, "0") + ":" + now.getMinutes().toString().padStart(2, "0");
      title = source._simMode + " — " + timeStr;
      delete source._simMode;
    }

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
        // Keep emoji content unchanged — just toggle CSS class
      }
    });
  }


  // === PIN COUNT BADGE ===

  function updatePinnedBadge() {
    var badge = document.getElementById("cj-pinned-count");
    if (!badge) return;
    var count = pinnedViews.filter(function(v) { return v.type !== "section"; }).length;
    badge.textContent = count;
    badge.style.display = count > 0 ? "" : "none";
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
    updatePinnedBadge();
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


  // === ADD PINNED ENTRY (used by Slides panel to push custom entries) ===

  window._addPinnedEntry = function(entry) {
    pinnedViews.push(entry);
    updatePinButtons();
    renderPinnedCards();
    savePinnedData();
    updatePinnedBadge();
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
          updatePinnedBadge();
        }
      } catch (e) { /* invalid JSON */ }
    }
  };


  // === EXPORT PINNED ===

  window.exportPinnedSlide = function(idx) {
    var view = pinnedViews[idx];
    if (!view) return;

    var slideW = 1280, slideH = 720, scale = 2;
    var canvas = document.createElement("canvas");
    canvas.width = slideW * scale;
    canvas.height = slideH * scale;
    var ctx = canvas.getContext("2d");
    ctx.scale(scale, scale);

    var brand = getComputedStyle(document.documentElement).getPropertyValue("--cj-brand").trim() || "#323367";

    function drawBackground() {
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, slideW, slideH);
      // Title bar
      ctx.fillStyle = brand;
      ctx.fillRect(0, 0, slideW, 50);
      ctx.fillStyle = "#ffffff";
      ctx.font = "bold 18px system-ui, sans-serif";
      ctx.fillText(view.title, 24, 34);
      // Footer
      ctx.fillStyle = "#94a3b8";
      ctx.font = "10px system-ui, sans-serif";
      ctx.fillText("Generated by TURAS Analytics Platform", 24, slideH - 12);
    }

    function downloadCanvas() {
      canvas.toBlob(function(blob) {
        var a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = "pinned_" + (idx + 1) + ".png";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      }, "image/png");
    }

    drawBackground();

    // Draw SVG chart content if available
    if (view.chart) {
      var svgBlob = new Blob([view.chart], { type: "image/svg+xml;charset=utf-8" });
      var url = URL.createObjectURL(svgBlob);
      var img = new Image();
      img.onload = function() {
        // Draw chart in content area (below title bar, above footer)
        var contentY = 60, contentH = slideH - 90;
        var aspectRatio = img.width / img.height;
        var drawW = Math.min(slideW - 48, contentH * aspectRatio);
        var drawH = drawW / aspectRatio;
        var drawX = (slideW - drawW) / 2;
        var drawY = contentY + (contentH - drawH) / 2;
        ctx.drawImage(img, drawX, drawY, drawW, drawH);
        URL.revokeObjectURL(url);
        downloadCanvas();
      };
      img.onerror = function() {
        URL.revokeObjectURL(url);
        downloadCanvas();  // Download without chart on error
      };
      img.src = url;
    } else {
      // No chart — draw note text if present
      if (view.note) {
        ctx.fillStyle = "#334155";
        ctx.font = "14px system-ui, sans-serif";
        var noteLines = view.note.replace(/<[^>]*>/g, "").split("\n");
        noteLines.forEach(function(line, i) {
          ctx.fillText(line.substring(0, 120), 40, 80 + i * 22);
        });
      }
      downloadCanvas();
    }
  };

  window.exportAllPinnedSlides = function() {
    pinnedViews.forEach(function(view, idx) {
      if (view.type !== "section") {
        setTimeout(function() { exportPinnedSlide(idx); }, idx * 300);
      }
    });
  };

  window.printPinnedViews = function() {
    // Switch to pinned tab and add print override class
    switchReportTab("pinned");
    document.body.classList.add("cj-printing-pinned");
    setTimeout(function() {
      window.print();
      // Remove the class after print dialog closes
      setTimeout(function() { document.body.classList.remove("cj-printing-pinned"); }, 500);
    }, 200);
  };


  // === TOAST NOTIFICATION ===

  function showPinToast(message) {
    var toast = document.createElement("div");
    toast.className = "cj-toast";
    toast.textContent = message;
    document.body.appendChild(toast);
    // Force reflow before adding visible class
    toast.offsetHeight;
    toast.classList.add("visible");
    setTimeout(function() {
      toast.classList.remove("visible");
      setTimeout(function() { toast.remove(); }, 350);
    }, 2000);
  }

  function bounceButton(viewId) {
    document.querySelectorAll(".cj-pin-btn").forEach(function(btn) {
      var onclick = btn.getAttribute("onclick") || "";
      if (onclick.indexOf("'" + viewId + "'") >= 0) {
        btn.classList.add("bounce");
        setTimeout(function() { btn.classList.remove("bounce"); }, 400);
      }
    });
  }


  // === UTILITY ===

  function escHtml(s) {
    var d = document.createElement("div");
    d.textContent = s || "";
    return d.innerHTML;
  }

})();
