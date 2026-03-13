/* ===========================================================================
   TURAS PRICING REPORT - Pin System
   Capture sections for curated pinned views collection
   =========================================================================== */

(function() {
  "use strict";

  var pinnedViews = [];
  var pinCounter = 0;

  // Section metadata for display
  var sectionMeta = {
    summary: "Summary",
    vw: "Van Westendorp",
    gg: "Gabor-Granger",
    monadic: "Monadic",
    segments: "Segments",
    recommendation: "Recommendation",
    simulator: "Simulator"
  };

  // ── Load pinned data from hidden store ──
  function loadPinnedData() {
    var store = document.getElementById("pinned-views-data");
    if (store) {
      try {
        pinnedViews = JSON.parse(store.textContent) || [];
        pinCounter = pinnedViews.length;
      } catch(e) { pinnedViews = []; }
    }
  }

  // ── Save pinned data to hidden store ──
  function savePinnedData() {
    var store = document.getElementById("pinned-views-data");
    if (store) {
      store.textContent = JSON.stringify(pinnedViews);
    }
  }

  // ── Update pin badge counter ──
  function updatePinBadge() {
    var badge = document.getElementById("pin-badge");
    if (badge) {
      badge.textContent = pinnedViews.length;
      badge.style.display = pinnedViews.length > 0 ? "inline-flex" : "none";
    }
  }

  // ── Update pin button states ──
  function updatePinButtons() {
    var btns = document.querySelectorAll(".pr-pin-btn");
    for (var i = 0; i < btns.length; i++) {
      var sectionId = btns[i].getAttribute("data-section");
      var isPinned = pinnedViews.some(function(p) { return p.sectionId === sectionId; });
      btns[i].classList.toggle("pinned", isPinned);
      btns[i].textContent = isPinned ? "Unpin" : "Pin";
    }
  }

  // ── Capture current view of a section ──
  function captureView(sectionId) {
    var panel = document.getElementById("panel-" + sectionId);
    if (!panel) return null;

    // Capture SVG chart
    var chartSvg = "";
    var svgEl = panel.querySelector("svg");
    if (svgEl) {
      chartSvg = new XMLSerializer().serializeToString(svgEl);
    }

    // Capture table HTML
    var tableHtml = "";
    var tableEl = panel.querySelector(".pr-table");
    if (tableEl) {
      tableHtml = tableEl.outerHTML;
    }

    // Capture insight text
    var insightText = "";
    var insightEditor = panel.querySelector(".pr-insight-editor");
    if (insightEditor && insightEditor.textContent.trim()) {
      insightText = insightEditor.textContent.trim();
    }

    return {
      chartSvg: chartSvg,
      tableHtml: tableHtml,
      insightText: insightText
    };
  }

  // ── Toggle pin for a section ──
  window.togglePin = function(sectionId) {
    var existingIdx = -1;
    for (var i = 0; i < pinnedViews.length; i++) {
      if (pinnedViews[i].sectionId === sectionId) {
        existingIdx = i;
        break;
      }
    }

    if (existingIdx >= 0) {
      // Unpin
      pinnedViews.splice(existingIdx, 1);
    } else {
      // Pin
      var captured = captureView(sectionId);
      if (!captured) return;

      pinCounter++;
      pinnedViews.push({
        id: "pin-" + pinCounter,
        sectionId: sectionId,
        title: sectionMeta[sectionId] || sectionId,
        chartSvg: captured.chartSvg,
        tableHtml: captured.tableHtml,
        insightText: captured.insightText,
        timestamp: new Date().toISOString()
      });
    }

    savePinnedData();
    updatePinBadge();
    updatePinButtons();
    renderPinnedCards();
  };

  // ── Remove a specific pin ──
  window.removePinned = function(pinId) {
    pinnedViews = pinnedViews.filter(function(p) { return p.id !== pinId; });
    savePinnedData();
    updatePinBadge();
    updatePinButtons();
    renderPinnedCards();
  };

  // ── Move pinned item ──
  window.movePinned = function(fromIdx, toIdx) {
    if (fromIdx < 0 || fromIdx >= pinnedViews.length) return;
    if (toIdx < 0 || toIdx >= pinnedViews.length) return;
    var item = pinnedViews.splice(fromIdx, 1)[0];
    pinnedViews.splice(toIdx, 0, item);
    savePinnedData();
    renderPinnedCards();
  };

  // ── Render pinned cards in the Pinned Views panel ──
  function renderPinnedCards() {
    var container = document.getElementById("pinned-cards-container");
    if (!container) return;

    var empty = document.getElementById("pinned-empty-state");

    if (pinnedViews.length === 0) {
      container.innerHTML = "";
      if (empty) empty.style.display = "block";
      return;
    }

    if (empty) empty.style.display = "none";

    var html = "";
    for (var i = 0; i < pinnedViews.length; i++) {
      var pin = pinnedViews[i];
      html += '<div class="pinned-card" data-pin-id="' + pin.id + '">';
      html += '<div class="pinned-card-header">';
      html += '<span class="pinned-card-title">' + escapeHtml(pin.title) + '</span>';
      html += '<div class="pinned-card-actions">';
      if (i > 0) {
        html += '<button class="pinned-move-btn" onclick="movePinned(' + i + ',' + (i - 1) + ')" title="Move up">&uarr;</button>';
      }
      if (i < pinnedViews.length - 1) {
        html += '<button class="pinned-move-btn" onclick="movePinned(' + i + ',' + (i + 1) + ')" title="Move down">&darr;</button>';
      }
      html += '<button class="pinned-remove-btn" onclick="removePinned(\'' + pin.id + '\')" title="Remove">&times;</button>';
      html += '</div></div>';

      // Chart
      if (pin.chartSvg) {
        html += '<div class="pinned-card-chart">' + pin.chartSvg + '</div>';
      }

      // Table
      if (pin.tableHtml) {
        html += '<div class="pinned-card-table">' + pin.tableHtml + '</div>';
      }

      // Insight
      if (pin.insightText) {
        html += '<div class="pinned-card-insight">' + escapeHtml(pin.insightText) + '</div>';
      }

      html += '</div>';
    }

    container.innerHTML = html;

    // Scale SVGs to fit cards
    var svgs = container.querySelectorAll("svg");
    for (var j = 0; j < svgs.length; j++) {
      svgs[j].style.width = "100%";
      svgs[j].style.height = "auto";
    }
  }

  function escapeHtml(str) {
    var div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }

  // ── Export all pinned views as PNG ──
  window.exportAllPinned = function() {
    if (pinnedViews.length === 0) {
      alert("No pinned views to export.");
      return;
    }

    var container = document.getElementById("pinned-cards-container");
    if (!container) return;

    // Export each card's SVG
    var cards = container.querySelectorAll(".pinned-card");
    for (var i = 0; i < cards.length; i++) {
      var svg = cards[i].querySelector("svg");
      if (svg) {
        var svgData = new XMLSerializer().serializeToString(svg);
        var canvas = document.createElement("canvas");
        var ctx = canvas.getContext("2d");
        var img = new Image();
        (function(title, idx) {
          img.onload = function() {
            canvas.width = img.width * 2;
            canvas.height = img.height * 2;
            ctx.scale(2, 2);
            ctx.fillStyle = "white";
            ctx.fillRect(0, 0, img.width, img.height);
            ctx.drawImage(img, 0, 0);
            var link = document.createElement("a");
            link.download = "pinned_" + (idx + 1) + "_" + title.replace(/\s+/g, "_") + ".png";
            link.href = canvas.toDataURL("image/png");
            link.click();
          };
        })(pinnedViews[i].title, i);
        img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgData)));
      }
    }
  };

  // ── Initialize on load ──
  function init() {
    loadPinnedData();
    updatePinBadge();
    updatePinButtons();
    renderPinnedCards();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

})();
