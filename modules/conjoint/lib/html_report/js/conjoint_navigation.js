/**
 * Conjoint Report Navigation & Core Interactions
 * Tab switching, attribute sidebar, insight system, slides system,
 * save/print, help overlay, simulator mode switching with callout toggle.
 */

(function() {
  "use strict";

  // === TAB NAVIGATION ===

  window.switchReportTab = function(tabName) {
    document.querySelectorAll(".cj-report-tab").forEach(function(t) {
      t.classList.remove("active");
    });
    document.querySelectorAll(".cj-panel").forEach(function(p) {
      p.classList.remove("active");
    });
    var btn = document.querySelector('.cj-report-tab[data-tab="' + tabName + '"]');
    if (btn) btn.classList.add("active");
    var panel = document.getElementById("panel-" + tabName);
    if (panel) panel.classList.add("active");

    // Initialize simulator on first visit
    if (tabName === "simulator" && typeof SimUI !== "undefined" && !SimUI._initialized) {
      SimUI.init();
    }
  };


  // === ATTRIBUTE SIDEBAR ===

  window.selectAttribute = function(attrName) {
    document.querySelectorAll(".cj-util-item").forEach(function(item) {
      item.classList.toggle("active", item.getAttribute("data-attr") === attrName);
    });
    document.querySelectorAll(".cj-attr-detail").forEach(function(d) {
      d.classList.toggle("active", d.getAttribute("data-attr") === attrName);
    });
  };

  window.filterAttributes = function(term) {
    var lower = (term || "").toLowerCase();
    document.querySelectorAll(".cj-util-item").forEach(function(item) {
      var name = (item.getAttribute("data-attr") || "").toLowerCase();
      item.style.display = name.indexOf(lower) >= 0 ? "" : "none";
    });
  };


  // === INSIGHT SYSTEM ===

  window.toggleInsight = function(id) {
    var body = document.getElementById("insight-body-" + id);
    if (body) {
      body.classList.toggle("open");
      var btn = body.previousElementSibling;
      if (btn && btn.classList.contains("cj-insight-toggle")) {
        btn.textContent = body.classList.contains("open") ? "- Hide Insight" : "+ Add Insight";
      }
    }
  };

  window.syncInsight = function(id) {
    var editor = document.getElementById("insight-editor-" + id);
    var store = document.getElementById("insight-store-" + id);
    if (editor && store) {
      store.value = editor.innerHTML;
    }
  };

  window.syncAllInsights = function() {
    document.querySelectorAll(".cj-insight-editor").forEach(function(editor) {
      var id = editor.id.replace("insight-editor-", "");
      syncInsight(id);
    });
  };

  window.syncAboutNotes = function() {
    var editor = document.getElementById("cj-about-notes");
    var store = document.getElementById("cj-about-notes-store");
    if (editor && store) {
      store.value = editor.innerHTML;
    }
  };

  function hydrateInsights() {
    document.querySelectorAll(".cj-insight-store").forEach(function(store) {
      var id = store.id.replace("insight-store-", "");
      var editor = document.getElementById("insight-editor-" + id);
      if (editor && store.value && store.value.trim()) {
        editor.innerHTML = store.value;
        var body = document.getElementById("insight-body-" + id);
        if (body) body.classList.add("open");
      }
    });
  }


  // === SLIDES SYSTEM ===

  var slides = [];

  window.addSlide = function() {
    slides.push({
      id: "slide-" + Date.now(),
      title: "",
      body: "",
      timestamp: new Date().toISOString()
    });
    renderSlides();
    saveSlides();
  };

  window.removeSlide = function(idx) {
    slides.splice(idx, 1);
    renderSlides();
    saveSlides();
  };

  window.moveSlide = function(idx, direction) {
    var newIdx = idx + direction;
    if (newIdx < 0 || newIdx >= slides.length) return;
    var temp = slides[idx];
    slides[idx] = slides[newIdx];
    slides[newIdx] = temp;
    renderSlides();
    saveSlides();
  };

  window.updateSlideTitle = function(idx, text) {
    if (slides[idx]) { slides[idx].title = text; saveSlides(); }
  };

  window.updateSlideBody = function(idx, html) {
    if (slides[idx]) { slides[idx].body = html; saveSlides(); }
  };

  function renderSlides() {
    var container = document.getElementById("cj-slides-cards");
    var empty = document.getElementById("cj-slides-empty");
    if (!container) return;

    if (slides.length === 0) {
      container.innerHTML = "";
      if (empty) empty.style.display = "";
      return;
    }
    if (empty) empty.style.display = "none";

    var html = "";
    slides.forEach(function(slide, idx) {
      html += '<div class="cj-slide-card">';
      html += '<div class="cj-slide-actions">';
      if (idx > 0) html += '<button class="cj-export-btn" onclick="moveSlide(' + idx + ',-1)">&uarr;</button>';
      if (idx < slides.length - 1) html += '<button class="cj-export-btn" onclick="moveSlide(' + idx + ',1)">&darr;</button>';
      html += '<button class="cj-export-btn" onclick="pinSlide(' + idx + ')">\ud83d\udccc</button>';
      html += '<button class="cj-export-btn" onclick="removeSlide(' + idx + ')">\u00d7</button>';
      html += '</div>';
      html += '<div class="cj-slide-title" contenteditable="true" oninput="updateSlideTitle(' + idx + ', this.textContent)">' + escHtmlNav(slide.title) + '</div>';
      html += '<div class="cj-slide-body" contenteditable="true" oninput="updateSlideBody(' + idx + ', this.innerHTML)">' + (slide.body || '') + '</div>';
      html += '</div>';
    });
    container.innerHTML = html;
  }

  function saveSlides() {
    var store = document.getElementById("slides-data");
    if (store) store.textContent = JSON.stringify(slides);
  }

  function hydrateSlides() {
    var store = document.getElementById("slides-data");
    if (store) {
      try {
        var data = JSON.parse(store.textContent);
        if (Array.isArray(data) && data.length > 0) {
          slides = data;
          renderSlides();
        }
      } catch (e) { /* invalid JSON */ }
    }
  }

  window.pinSlide = function(idx) {
    var slide = slides[idx];
    if (!slide) return;
    if (typeof window._addPinnedEntry === "function") {
      window._addPinnedEntry({
        id: slide.id,
        title: slide.title || "Slide " + (idx + 1),
        chart: "",
        table: '<div style="padding:12px;font-size:13px;">' + (slide.body || '') + '</div>',
        note: "",
        timestamp: new Date().toISOString()
      });
    }
  };

  window.exportAllSlidesPNG = function() {
    slides.forEach(function(slide, idx) {
      setTimeout(function() { exportSlideCardPNG(slide, idx); }, idx * 300);
    });
  };

  function exportSlideCardPNG(slide, idx) {
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
    ctx.fillText(slide.title || "Slide " + (idx + 1), 24, 34);

    // Body text (simple rendering)
    ctx.fillStyle = "#334155";
    ctx.font = "14px system-ui, sans-serif";
    var bodyText = (slide.body || "").replace(/<[^>]*>/g, " ").replace(/&nbsp;/g, " ").trim();
    var words = bodyText.split(/\s+/);
    var line = "", lineY = 90, maxW = slideW - 48;
    for (var i = 0; i < words.length; i++) {
      var testLine = line + (line ? " " : "") + words[i];
      if (ctx.measureText(testLine).width > maxW && line) {
        ctx.fillText(line, 24, lineY);
        line = words[i];
        lineY += 22;
        if (lineY > slideH - 40) break;
      } else {
        line = testLine;
      }
    }
    if (line && lineY <= slideH - 40) ctx.fillText(line, 24, lineY);

    ctx.fillStyle = "#94a3b8";
    ctx.font = "10px system-ui, sans-serif";
    ctx.fillText("Generated by TURAS Analytics Platform", 24, slideH - 12);

    canvas.toBlob(function(blob) {
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "slide_" + (idx + 1) + ".png";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
    }, "image/png");
  }

  window.printSlides = function() {
    switchReportTab("slides");
    setTimeout(function() { window.print(); }, 200);
  };

  function escHtmlNav(s) {
    var d = document.createElement("div");
    d.textContent = s || "";
    return d.innerHTML;
  }


  // === SAVE REPORT ===

  window.saveReportHTML = function() {
    syncAllInsights();

    // Update date badge
    var badge = document.getElementById("cj-header-date");
    if (badge) {
      var now = new Date();
      badge.textContent = "Last saved " + now.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
    }

    // Serialize HTML
    var clone = document.documentElement.cloneNode(true);

    // Remove help overlay open state
    var helpEl = clone.querySelector("#cj-help-overlay");
    if (helpEl) helpEl.classList.remove("open");

    var html = "<!DOCTYPE html>\n" + clone.outerHTML;

    // Determine filename
    var meta = document.querySelector('meta[name="turas-source-filename"]');
    var baseName = meta ? meta.getAttribute("content") : "Conjoint_Report";
    baseName = baseName.replace(/\.[^/.]+$/, "");
    var filename = baseName + "_Updated.html";

    downloadBlob(html, filename, "text/html");
  };


  // === PRINT ===

  window.printReport = function() {
    syncAllInsights();
    // Show all panels for printing
    document.querySelectorAll(".cj-panel").forEach(function(p) {
      p.classList.add("active");
    });
    window.print();
    // Restore active tab
    var activeBtn = document.querySelector(".cj-report-tab.active");
    if (activeBtn) {
      var tab = activeBtn.getAttribute("data-tab");
      switchReportTab(tab);
    }
  };


  // === HELP OVERLAY ===

  window.toggleHelpOverlay = function() {
    var overlay = document.getElementById("cj-help-overlay");
    if (overlay) overlay.classList.toggle("open");
  };


  // === SIMULATOR MODE SWITCH (with callout toggle) ===

  window.switchSimMode = function(mode) {
    // Toggle mode buttons
    document.querySelectorAll(".cj-sim-mode-btn").forEach(function(btn) {
      btn.classList.remove("active");
    });
    var clicked = document.querySelector('.cj-sim-mode-btn[onclick*="' + mode + '"]');
    if (clicked) clicked.classList.add("active");

    // Toggle callouts
    document.querySelectorAll(".cj-sim-callout").forEach(function(c) {
      c.classList.remove("active");
    });
    var calloutId = "cj-sim-callout-" + mode;
    var callout = document.getElementById(calloutId);
    if (callout) callout.classList.add("active");

    if (typeof SimUI !== "undefined") {
      SimUI.switchMode(mode);
    }
  };


  // === DOWNLOAD BLOB UTILITY ===

  window.downloadBlob = function(content, filename, mimeType) {
    var blob = new Blob([content], { type: mimeType || "application/octet-stream" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };


  // === INIT ===

  document.addEventListener("DOMContentLoaded", function() {
    // Initialize simulator engine with embedded data
    var dataEl = document.getElementById("cj-simulator-data");
    if (dataEl) {
      try {
        var simData = JSON.parse(dataEl.textContent);
        if (simData && simData.attributes) {
          SimEngine.init(simData);
        }
      } catch (e) {
        console.warn("Failed to parse simulator data:", e);
      }
    }

    // Set brand colour for charts
    var brand = getComputedStyle(document.documentElement).getPropertyValue("--cj-brand").trim();
    if (brand && typeof SimCharts !== "undefined") {
      SimCharts.setBrand(brand);
    }

    // Hydrate saved insights
    hydrateInsights();

    // Hydrate pinned views
    if (typeof hydratePinnedViews === "function") {
      hydratePinnedViews();
    }

    // Hydrate saved slides
    hydrateSlides();

    // Show help on first visit
    try {
      if (!localStorage.getItem("cj-help-seen")) {
        var overlay = document.getElementById("cj-help-overlay");
        if (overlay) overlay.classList.add("open");
        localStorage.setItem("cj-help-seen", "1");
      }
    } catch (e) { /* localStorage unavailable */ }

    // Start on overview tab
    switchReportTab("overview");
  });

})();
