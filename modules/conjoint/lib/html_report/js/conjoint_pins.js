/**
 * Conjoint Report Pin System
 * Pin views with mode selection (chart, table, or both), render pinned cards,
 * persist to JSON store, clipboard copy, download PNG, batch export.
 * Supports utility attributes (util-*), panel cards (pin-*), and custom entries.
 */

(function() {
  "use strict";

  var pinnedViews = [];
  var activePopover = null;

  // === PIN POPOVER ===

  window.showPinPopover = function(viewId, btnEl) {
    // Close any open popover
    dismissPopover();

    var isSimulator = (viewId === "pin-simulator");
    var isPinned = !isSimulator && pinnedViews.some(function(v) { return v.id === viewId; });

    // Determine available pin modes based on what the source has
    var modes = getPinModes(viewId);

    var pop = document.createElement("div");
    pop.className = "cj-pin-popover";

    modes.forEach(function(mode) {
      var item = document.createElement("button");
      item.className = "cj-pin-popover-item";
      item.textContent = mode.label;
      item.addEventListener("click", function(e) {
        e.stopPropagation();
        dismissPopover();
        togglePin(viewId, mode.key);
      });
      pop.appendChild(item);
    });

    // Unpin option if already pinned
    if (isPinned) {
      var unpin = document.createElement("button");
      unpin.className = "cj-pin-popover-item unpin";
      unpin.textContent = "Unpin";
      unpin.addEventListener("click", function(e) {
        e.stopPropagation();
        dismissPopover();
        unpinView(viewId);
      });
      pop.appendChild(unpin);
    }

    btnEl.style.position = "relative";
    btnEl.appendChild(pop);
    activePopover = { el: pop, btn: btnEl };

    // Click outside to dismiss
    setTimeout(function() {
      document.addEventListener("click", onDocClick);
    }, 0);
  };

  function onDocClick(e) {
    if (activePopover && !activePopover.el.contains(e.target) && e.target !== activePopover.btn) {
      dismissPopover();
    }
  }

  function dismissPopover() {
    if (activePopover) {
      activePopover.el.remove();
      activePopover = null;
    }
    document.removeEventListener("click", onDocClick);
  }

  function getPinModes(viewId) {
    // Default modes available depend on what the source panel has
    var source = findSource(viewId);
    var hasChart = source && source.querySelector("svg");
    var hasTable = source && (source.querySelector(".cj-table") || source.querySelector("table"));

    var modes = [];
    if (hasChart && hasTable) {
      modes.push({ key: "both", label: "Chart + Table" });
      modes.push({ key: "chart", label: "Chart only" });
      modes.push({ key: "table", label: "Table only" });
    } else if (hasChart) {
      modes.push({ key: "chart", label: "Pin chart" });
    } else if (hasTable) {
      modes.push({ key: "table", label: "Pin table" });
    } else {
      modes.push({ key: "both", label: "Pin view" });
    }
    return modes;
  }


  // === TOGGLE PIN ===

  function togglePin(viewId, mode) {
    var isSimulator = (viewId === "pin-simulator");

    if (isSimulator) {
      var captured = captureView(viewId, mode);
      if (captured) {
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

    // Non-simulator: check if already pinned
    var idx = pinnedViews.findIndex(function(v) { return v.id === viewId; });
    if (idx >= 0) {
      // Re-pin with new mode (replace existing)
      pinnedViews.splice(idx, 1);
    }

    var captured = captureView(viewId, mode);
    if (captured) {
      pinnedViews.push(captured);
    }

    updatePinButtons();
    renderPinnedCards();
    savePinnedData();
    updatePinnedBadge();
    showPinToast("Pinned to collection");
    bounceButton(viewId);
  }

  function unpinView(viewId) {
    var idx = pinnedViews.findIndex(function(v) { return v.id === viewId; });
    if (idx >= 0) {
      pinnedViews.splice(idx, 1);
      updatePinButtons();
      renderPinnedCards();
      savePinnedData();
      updatePinnedBadge();
      showPinToast("Removed from collection");
    }
  }


  // === FIND SOURCE ELEMENT ===

  function findSource(viewId) {
    var source = null;

    if (viewId.indexOf("util-") === 0) {
      source = document.querySelector('.cj-attr-detail.active');
    } else if (viewId.indexOf("pin-") === 0) {
      var panelPart = viewId.replace(/^pin-/, "");

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
      } else if (panelPart.indexOf("lc-") === 0) {
        var lcPart = panelPart.replace("lc-", "");
        var lcPanel = document.getElementById("panel-latentclass");
        if (lcPanel) {
          var lcTarget = {"bic": "Model Comparison", "sizes": "Class Sizes", "importance": "Importance by Class"};
          lcPanel.querySelectorAll(".cj-card").forEach(function(card) {
            var h2 = card.querySelector("h2");
            if (h2 && h2.textContent === lcTarget[lcPart]) source = card;
          });
        }
      } else if (panelPart.indexOf("wtp-") === 0) {
        var wtpPart = panelPart.replace("wtp-", "");
        var wtpPanel = document.getElementById("panel-wtp");
        if (wtpPanel) {
          var wtpTarget = {"main": "Willingness to Pay", "demand": "Demand Curve"};
          wtpPanel.querySelectorAll(".cj-card").forEach(function(card) {
            var h2 = card.querySelector("h2");
            if (h2 && h2.textContent === wtpTarget[wtpPart]) source = card;
          });
        }
      } else if (panelPart === "overview") {
        source = document.querySelector("#panel-overview .cj-card");
      } else if (panelPart === "simulator") {
        source = document.getElementById("cj-sim-results");
        if (source) {
          var modeBtn = document.querySelector(".cj-sim-mode-btn.active");
          source._simMode = modeBtn ? modeBtn.textContent : "Simulator";
        }
      }
    }

    if (!source) {
      var panelId = viewId.replace(/^util-/, "").replace(/^panel-/, "");
      source = document.getElementById("panel-" + panelId);
    }

    return source;
  }


  // === CAPTURE VIEW ===

  function captureView(viewId, mode) {
    var source = findSource(viewId);
    if (!source) return null;

    mode = mode || "both";

    // Get title
    var titleEl = source.querySelector("h2") || source.querySelector("h3");
    var title = titleEl ? titleEl.textContent : viewId;
    if (source._simMode) {
      var now = new Date();
      var timeStr = now.getHours().toString().padStart(2, "0") + ":" + now.getMinutes().toString().padStart(2, "0");
      title = source._simMode + " \u2014 " + timeStr;
      delete source._simMode;
    }

    // Capture chart SVG (if mode allows)
    var chartSvg = "";
    if (mode === "both" || mode === "chart") {
      var svgEl = source.querySelector("svg");
      if (svgEl) {
        chartSvg = new XMLSerializer().serializeToString(svgEl);
      }
    }

    // Capture table HTML (if mode allows)
    var tableHtml = "";
    if (mode === "both" || mode === "table") {
      var tableEl = source.querySelector(".cj-table") || source.querySelector("table");
      if (tableEl) {
        tableHtml = tableEl.outerHTML;
      }
    }

    // Fallback: if no SVG chart and no table found, capture the full
    // source HTML so it can be rendered via html2canvas in the export
    // pipeline. This handles simulator share bars and other div content.
    if (!chartSvg && !tableHtml) {
      var clone = source.cloneNode(true);
      // Remove buttons and interactive elements
      clone.querySelectorAll("button, input, select, .cj-sim-controls").forEach(function(el) { el.remove(); });
      tableHtml = clone.innerHTML;
    }

    return {
      id: viewId,
      title: title,
      chart: chartSvg,
      table: tableHtml,
      mode: mode,
      note: "",
      timestamp: new Date().toISOString()
    };
  }


  // === UPDATE PIN BUTTONS ===

  function updatePinButtons() {
    document.querySelectorAll(".cj-pin-btn").forEach(function(btn) {
      var onclick = btn.getAttribute("onclick") || "";
      var match = onclick.match(/showPinPopover\('([^']+)'/);
      if (match) {
        var id = match[1];
        var isPinned = pinnedViews.some(function(v) { return v.id === id; });
        btn.classList.toggle("pinned", isPinned);
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

      html += '<div class="cj-pinned-card" id="cj-pinned-card-' + idx + '">';
      html += '<div class="cj-pinned-card-header">';
      html += '<div class="cj-pinned-card-title">' + escHtml(view.title) + '</div>';
      html += '<div class="cj-pinned-card-actions">';
      // Overflow menu
      html += '<div class="cj-pinned-menu-wrap" style="position:relative;">';
      html += '<button class="cj-export-btn" onclick="togglePinnedMenu(' + idx + ')" title="Actions">\u22ee</button>';
      html += '<div class="cj-pinned-menu" id="cj-pinned-menu-' + idx + '" style="display:none;">';
      html += '<button class="cj-pin-popover-item" onclick="copyPinnedToClipboard(' + idx + ')">Copy to clipboard</button>';
      html += '<button class="cj-pin-popover-item" onclick="downloadPinnedPNG(' + idx + ')">Download PNG</button>';
      html += '<button class="cj-pin-popover-item" onclick="exportPinnedSlide(' + idx + ')">Slide PNG</button>';
      html += '<button class="cj-pin-popover-item unpin" onclick="removePinned(' + idx + ')">Remove</button>';
      html += '</div></div>';
      html += '</div></div>';

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

  // Overflow menu toggle
  window.togglePinnedMenu = function(idx) {
    var menu = document.getElementById("cj-pinned-menu-" + idx);
    if (!menu) return;
    var isOpen = menu.style.display !== "none";
    // Close all menus first
    document.querySelectorAll(".cj-pinned-menu").forEach(function(m) { m.style.display = "none"; });
    if (!isOpen) {
      menu.style.display = "block";
      setTimeout(function() {
        document.addEventListener("click", function closer(e) {
          if (!menu.contains(e.target)) {
            menu.style.display = "none";
            document.removeEventListener("click", closer);
          }
        });
      }, 0);
    }
  };

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


  // === CLIPBOARD COPY ===

  window.copyPinnedToClipboard = function(idx) {
    var card = document.getElementById("cj-pinned-card-" + idx);
    if (!card) return;

    renderCardToCanvas(card, 3, function(canvas) {
      canvas.toBlob(function(blob) {
        if (navigator.clipboard && typeof ClipboardItem !== "undefined") {
          navigator.clipboard.write([
            new ClipboardItem({ "image/png": blob })
          ]).then(function() {
            showPinToast("Copied to clipboard");
          }).catch(function() {
            // Fallback: download instead
            downloadBlobAsFile(blob, "pinned_" + (idx + 1) + ".png");
            showPinToast("Downloaded (clipboard not available)");
          });
        } else {
          downloadBlobAsFile(blob, "pinned_" + (idx + 1) + ".png");
          showPinToast("Downloaded (clipboard not available)");
        }
      }, "image/png");
    });
  };


  // === DOWNLOAD PINNED PNG ===

  window.downloadPinnedPNG = function(idx) {
    var card = document.getElementById("cj-pinned-card-" + idx);
    if (!card) return;

    renderCardToCanvas(card, 3, function(canvas) {
      canvas.toBlob(function(blob) {
        downloadBlobAsFile(blob, "pinned_" + (idx + 1) + ".png");
        showPinToast("PNG downloaded");
      }, "image/png");
    });
  };

  function downloadBlobAsFile(blob, filename) {
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  }


  // === RENDER CARD TO CANVAS (for clipboard + PNG) ===

  function renderCardToCanvas(cardEl, scale, callback) {
    var rect = cardEl.getBoundingClientRect();
    var w = rect.width;
    var h = rect.height;

    var canvas = document.createElement("canvas");
    canvas.width = w * scale;
    canvas.height = h * scale;
    var ctx = canvas.getContext("2d");
    ctx.scale(scale, scale);

    // White background
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, w, h);

    // Use SVG foreignObject to render HTML to canvas
    var svgNS = "http://www.w3.org/2000/svg";
    var svgStr = '<svg xmlns="' + svgNS + '" width="' + w + '" height="' + h + '">' +
      '<foreignObject width="100%" height="100%">' +
      '<div xmlns="http://www.w3.org/1999/xhtml" style="font-family:system-ui,sans-serif;font-size:13px;color:#1e293b;">' +
      cardEl.innerHTML +
      '</div></foreignObject></svg>';

    var svgBlob = new Blob([svgStr], { type: "image/svg+xml;charset=utf-8" });
    var url = URL.createObjectURL(svgBlob);
    var img = new Image();
    img.onload = function() {
      ctx.drawImage(img, 0, 0, w, h);
      URL.revokeObjectURL(url);
      callback(canvas);
    };
    img.onerror = function() {
      URL.revokeObjectURL(url);
      // Fallback: just use background canvas
      callback(canvas);
    };
    img.src = url;
  }


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


  // === EXPORT PINNED SLIDE ===

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
      ctx.fillStyle = brand;
      ctx.fillRect(0, 0, slideW, 50);
      ctx.fillStyle = "#ffffff";
      ctx.font = "bold 18px system-ui, sans-serif";
      ctx.fillText(view.title, 24, 34);
      ctx.fillStyle = "#94a3b8";
      ctx.font = "10px system-ui, sans-serif";
      ctx.fillText("Generated by TURAS Analytics Platform", 24, slideH - 12);
    }

    function downloadCanvas() {
      canvas.toBlob(function(blob) {
        downloadBlobAsFile(blob, "pinned_" + (idx + 1) + ".png");
      }, "image/png");
    }

    drawBackground();

    if (view.chart) {
      var svgBlob = new Blob([view.chart], { type: "image/svg+xml;charset=utf-8" });
      var url = URL.createObjectURL(svgBlob);
      var img = new Image();
      img.onload = function() {
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
        downloadCanvas();
      };
      img.src = url;
    } else {
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
    switchReportTab("pinned");
    document.body.classList.add("cj-printing-pinned");
    setTimeout(function() {
      window.print();
      setTimeout(function() { document.body.classList.remove("cj-printing-pinned"); }, 500);
    }, 200);
  };


  // === TOAST NOTIFICATION ===

  function showPinToast(message) {
    var toast = document.createElement("div");
    toast.className = "cj-toast";
    toast.textContent = message;
    document.body.appendChild(toast);
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
