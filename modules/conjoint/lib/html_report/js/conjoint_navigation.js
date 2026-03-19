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


  // === SLIDES SYSTEM (tab-based, markdown) ===

  var slides = [];
  var activeSlideIdx = 0;

  window.addSlide = function() {
    slides.push({
      id: "slide-" + Date.now(),
      title: "",
      body: "",
      images: [],
      timestamp: new Date().toISOString()
    });
    activeSlideIdx = slides.length - 1;
    renderSlides();
    saveSlides();
  };

  window.removeSlide = function(idx) {
    slides.splice(idx, 1);
    if (activeSlideIdx >= slides.length) activeSlideIdx = Math.max(0, slides.length - 1);
    renderSlides();
    saveSlides();
  };

  window.moveSlide = function(idx, direction) {
    var newIdx = idx + direction;
    if (newIdx < 0 || newIdx >= slides.length) return;
    var temp = slides[idx];
    slides[idx] = slides[newIdx];
    slides[newIdx] = temp;
    if (activeSlideIdx === idx) activeSlideIdx = newIdx;
    else if (activeSlideIdx === newIdx) activeSlideIdx = idx;
    renderSlides();
    saveSlides();
  };

  window.switchSlide = function(idx) {
    activeSlideIdx = idx;
    renderSlides();
  };

  window.updateSlideTitle = function(idx, text) {
    if (slides[idx]) {
      slides[idx].title = text;
      saveSlides();
      // Update tab label
      var tabs = document.querySelectorAll(".cj-slide-tab");
      if (tabs[idx]) tabs[idx].textContent = text || "Slide " + (idx + 1);
    }
  };

  window.updateSlideBody = function(idx, md) {
    if (slides[idx]) {
      slides[idx].body = md;
      saveSlides();
      // Live preview
      var preview = document.getElementById("cj-slide-preview-" + idx);
      if (preview) preview.innerHTML = renderMarkdown(md) + renderSlideImages(idx);
    }
  };

  // Insert image into a slide via file picker
  window.insertSlideImage = function(idx) {
    var input = document.createElement("input");
    input.type = "file";
    input.accept = "image/*";
    input.style.display = "none";
    input.addEventListener("change", function() {
      var file = input.files[0];
      if (!file) return;
      var reader = new FileReader();
      reader.onload = function(e) {
        if (!slides[idx]) return;
        if (!slides[idx].images) slides[idx].images = [];
        slides[idx].images.push({
          id: "img-" + Date.now(),
          name: file.name,
          data: e.target.result
        });
        saveSlides();
        // Re-render preview to show image
        var preview = document.getElementById("cj-slide-preview-" + idx);
        if (preview) preview.innerHTML = renderMarkdown(slides[idx].body || "") + renderSlideImages(idx);
      };
      reader.readAsDataURL(file);
      input.remove();
    });
    document.body.appendChild(input);
    input.click();
  };

  window.removeSlideImage = function(slideIdx, imgIdx) {
    if (slides[slideIdx] && slides[slideIdx].images) {
      slides[slideIdx].images.splice(imgIdx, 1);
      saveSlides();
      var preview = document.getElementById("cj-slide-preview-" + slideIdx);
      if (preview) preview.innerHTML = renderMarkdown(slides[slideIdx].body || "") + renderSlideImages(slideIdx);
    }
  };

  function renderSlideImages(idx) {
    var slide = slides[idx];
    if (!slide || !slide.images || slide.images.length === 0) return "";
    var html = '<div style="margin-top:12px;border-top:1px solid #e2e8f0;padding-top:12px;">';
    slide.images.forEach(function(img, imgIdx) {
      html += '<div style="position:relative;display:inline-block;margin:4px;">';
      html += '<img src="' + img.data + '" alt="' + escAttrNav(img.name) + '" style="max-width:100%;max-height:300px;border-radius:4px;border:1px solid #e2e8f0;" />';
      html += '<button style="position:absolute;top:2px;right:2px;background:rgba(0,0,0,0.5);color:#fff;border:none;border-radius:50%;width:20px;height:20px;cursor:pointer;font-size:12px;line-height:20px;text-align:center;" onclick="removeSlideImage(' + idx + ',' + imgIdx + ')">&times;</button>';
      html += '</div>';
    });
    html += '</div>';
    return html;
  }

  function renderSlides() {
    var tabStrip = document.getElementById("cj-slide-tabs");
    var container = document.getElementById("cj-slides-cards");
    var empty = document.getElementById("cj-slides-empty");
    if (!container) return;

    if (slides.length === 0) {
      if (tabStrip) tabStrip.innerHTML = "";
      container.innerHTML = "";
      if (empty) empty.style.display = "";
      return;
    }
    if (empty) empty.style.display = "none";

    // Tab strip
    if (tabStrip) {
      var tabHtml = "";
      slides.forEach(function(slide, idx) {
        var active = idx === activeSlideIdx ? " active" : "";
        var label = slide.title || "Slide " + (idx + 1);
        tabHtml += '<button class="cj-slide-tab' + active + '" onclick="switchSlide(' + idx + ')">' + escHtmlNav(label) + '</button>';
      });
      tabStrip.innerHTML = tabHtml;
    }

    // Slide cards
    var html = "";
    slides.forEach(function(slide, idx) {
      var active = idx === activeSlideIdx ? " active" : "";
      html += '<div class="cj-slide-card' + active + '">';

      // Header bar
      html += '<div class="cj-slide-header">';
      html += '<input type="text" class="cj-slide-title-input" placeholder="Slide title..." value="' + escAttrNav(slide.title || "") + '" oninput="updateSlideTitle(' + idx + ',this.value)" />';
      html += '<div class="cj-slide-actions">';
      html += '<button class="cj-export-btn" onclick="insertSlideImage(' + idx + ')" title="Insert Image">&#128247; Image</button>';
      if (idx > 0) html += '<button class="cj-export-btn" onclick="moveSlide(' + idx + ',-1)" title="Move up">&uarr;</button>';
      if (idx < slides.length - 1) html += '<button class="cj-export-btn" onclick="moveSlide(' + idx + ',1)" title="Move down">&darr;</button>';
      html += '<button class="cj-export-btn" onclick="pinSlide(' + idx + ')" title="Pin">\ud83d\udccc</button>';
      html += '<button class="cj-export-btn" onclick="removeSlide(' + idx + ')" title="Delete">\u00d7</button>';
      html += '</div></div>';

      // Editor + Preview
      html += '<div class="cj-slide-editor-layout">';
      html += '<textarea placeholder="Write in Markdown..." oninput="updateSlideBody(' + idx + ',this.value)">' + escHtmlNav(slide.body || "") + '</textarea>';
      html += '<div class="cj-slide-preview" id="cj-slide-preview-' + idx + '">' + renderMarkdown(slide.body || "") + renderSlideImages(idx) + '</div>';
      html += '</div>';

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
          activeSlideIdx = 0;
          renderSlides();
        }
      } catch (e) { /* invalid JSON */ }
    }
  }


  // === INLINE MARKDOWN RENDERER ===

  function renderMarkdown(md) {
    if (!md) return '<p style="color:#94a3b8;font-style:italic;">Preview will appear here...</p>';

    var lines = md.split("\n");
    var html = "";
    var inUl = false, inOl = false;

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];

      // Horizontal rule
      if (/^---+\s*$/.test(line)) {
        if (inUl) { html += "</ul>"; inUl = false; }
        if (inOl) { html += "</ol>"; inOl = false; }
        html += "<hr>";
        continue;
      }

      // Headings
      if (/^### (.+)/.test(line)) {
        if (inUl) { html += "</ul>"; inUl = false; }
        if (inOl) { html += "</ol>"; inOl = false; }
        html += "<h3>" + inlineMarkdown(RegExp.$1) + "</h3>";
        continue;
      }
      if (/^## (.+)/.test(line)) {
        if (inUl) { html += "</ul>"; inUl = false; }
        if (inOl) { html += "</ol>"; inOl = false; }
        html += "<h2>" + inlineMarkdown(RegExp.$1) + "</h2>";
        continue;
      }
      if (/^# (.+)/.test(line)) {
        if (inUl) { html += "</ul>"; inUl = false; }
        if (inOl) { html += "</ol>"; inOl = false; }
        html += "<h1>" + inlineMarkdown(RegExp.$1) + "</h1>";
        continue;
      }

      // Blockquote
      if (/^>\s?(.*)/.test(line)) {
        if (inUl) { html += "</ul>"; inUl = false; }
        if (inOl) { html += "</ol>"; inOl = false; }
        html += "<blockquote>" + inlineMarkdown(RegExp.$1) + "</blockquote>";
        continue;
      }

      // Unordered list
      if (/^[-*]\s+(.+)/.test(line)) {
        if (inOl) { html += "</ol>"; inOl = false; }
        if (!inUl) { html += "<ul>"; inUl = true; }
        html += "<li>" + inlineMarkdown(RegExp.$1) + "</li>";
        continue;
      }

      // Ordered list
      if (/^\d+\.\s+(.+)/.test(line)) {
        if (inUl) { html += "</ul>"; inUl = false; }
        if (!inOl) { html += "<ol>"; inOl = true; }
        html += "<li>" + inlineMarkdown(RegExp.$1) + "</li>";
        continue;
      }

      // Close lists on non-list lines
      if (inUl) { html += "</ul>"; inUl = false; }
      if (inOl) { html += "</ol>"; inOl = false; }

      // Blank line
      if (line.trim() === "") {
        continue;
      }

      // Paragraph
      html += "<p>" + inlineMarkdown(line) + "</p>";
    }

    if (inUl) html += "</ul>";
    if (inOl) html += "</ol>";
    return html;
  }

  function inlineMarkdown(text) {
    // Escape HTML first
    text = text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    // Bold
    text = text.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
    // Italic
    text = text.replace(/\*(.+?)\*/g, "<em>$1</em>");
    // Inline code
    text = text.replace(/`(.+?)`/g, "<code>$1</code>");
    return text;
  }


  window.pinSlide = function(idx) {
    var slide = slides[idx];
    if (!slide) return;
    if (typeof window._addPinnedEntry === "function") {
      var renderedBody = renderMarkdown(slide.body || "") + renderSlideImages(idx);
      window._addPinnedEntry({
        id: slide.id,
        title: slide.title || "Slide " + (idx + 1),
        chart: "",
        table: '<div style="padding:12px;font-size:13px;">' + renderedBody + '</div>',
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

    // Body text (strip markdown/html for PNG)
    ctx.fillStyle = "#334155";
    ctx.font = "14px system-ui, sans-serif";
    var bodyText = (slide.body || "").replace(/<[^>]*>/g, " ").replace(/&nbsp;/g, " ").replace(/[#*>`]/g, "").trim();
    var words = bodyText.split(/\s+/);
    var line = "", lineY = 90, maxW = slideW - 48;
    for (var j = 0; j < words.length; j++) {
      var testLine = line + (line ? " " : "") + words[j];
      if (ctx.measureText(testLine).width > maxW && line) {
        ctx.fillText(line, 24, lineY);
        line = words[j];
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
    // Make all slides visible for printing
    document.querySelectorAll(".cj-slide-card").forEach(function(c) { c.classList.add("active"); });
    switchReportTab("slides");
    setTimeout(function() { window.print(); }, 200);
  };

  function escHtmlNav(s) {
    var d = document.createElement("div");
    d.textContent = s || "";
    return d.innerHTML;
  }

  function escAttrNav(s) {
    return String(s || "").replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/'/g, "&#39;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
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
