/**
 * Conjoint Report Navigation & Core Interactions
 * Tab switching, attribute sidebar, insight system, slides system,
 * save/print, help overlay, simulator mode switching with callout toggle.
 */

(function() {
  "use strict";

  // === GLOBAL TOAST NOTIFICATION ===
  // Shared toast function used by save, export, and other operations
  window.showToast = function(message) {
    var existing = document.getElementById("cj-global-toast");
    if (existing) existing.remove();
    var toast = document.createElement("div");
    toast.id = "cj-global-toast";
    toast.textContent = message;
    toast.style.cssText = "position:fixed;bottom:24px;left:50%;transform:translateX(-50%);background:#1e293b;color:#f8fafc;padding:10px 20px;border-radius:8px;font-size:13px;font-weight:500;z-index:10000;opacity:0;transition:opacity 0.2s ease;pointer-events:none;";
    document.body.appendChild(toast);
    setTimeout(function() { toast.style.opacity = "1"; }, 10);
    setTimeout(function() {
      toast.style.opacity = "0";
      setTimeout(function() { toast.remove(); }, 200);
    }, 2500);
  };

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


  // === CHART TYPE TOGGLE (bar vs dot) ===

  var preferredChartType = "bar";  // Persists across attribute switches

  window.switchChartType = function(attrId, type, btn) {
    var barChart = document.getElementById("chart-bar-" + attrId);
    var dotChart = document.getElementById("chart-dot-" + attrId);
    if (!barChart || !dotChart) return;

    preferredChartType = type;  // Remember preference

    barChart.style.display = (type === "bar") ? "" : "none";
    dotChart.style.display = (type === "dot") ? "" : "none";

    // Update toggle button styles
    var parent = btn.parentElement;
    if (parent) {
      parent.querySelectorAll(".cj-chart-type-btn").forEach(function(b) {
        var isActive = b === btn;
        b.classList.toggle("active", isActive);
        b.style.background = isActive ? "#fff" : "transparent";
        b.style.color = isActive ? "#1e293b" : "#64748b";
      });
    }

    // Apply preference to ALL attributes so they stay consistent
    document.querySelectorAll(".cj-attr-detail").forEach(function(detail) {
      var dAttr = detail.getAttribute("data-attr");
      if (!dAttr) return;
      var dId = dAttr.replace(/[^a-zA-Z0-9]/g, "-");
      var bar = document.getElementById("chart-bar-" + dId);
      var dot = document.getElementById("chart-dot-" + dId);
      if (bar) bar.style.display = (type === "bar") ? "" : "none";
      if (dot) dot.style.display = (type === "dot") ? "" : "none";

      // Sync toggle button state
      var toggleBtns = detail.querySelectorAll(".cj-chart-type-btn");
      toggleBtns.forEach(function(b) {
        var isActive = b.getAttribute("data-type") === type;
        b.classList.toggle("active", isActive);
        b.style.background = isActive ? "#fff" : "transparent";
        b.style.color = isActive ? "#1e293b" : "#64748b";
      });
    });
  };


  // === ATTRIBUTE-LEVEL STICKY NOTES ===
  // Notes persist per attribute and show/hide as you navigate between attributes

  var attrNotes = {};  // { attrId: "note text" }

  window.toggleAttrNote = function(attrId) {
    var body = document.getElementById("attr-note-body-" + attrId);
    if (!body) return;
    var isVisible = body.style.display !== "none";
    body.style.display = isVisible ? "none" : "block";
    // Focus the editor when opening
    if (!isVisible) {
      var editor = document.getElementById("attr-note-editor-" + attrId);
      if (editor) setTimeout(function() { editor.focus(); }, 50);
    }
  };

  window.saveAttrNote = function(attrId) {
    var editor = document.getElementById("attr-note-editor-" + attrId);
    if (!editor) return;
    var content = editor.innerText.trim();
    attrNotes[attrId] = content;

    // Update toggle label
    var label = document.getElementById("attr-note-label-" + attrId);
    var toggle = editor.closest(".cj-attr-note").querySelector(".cj-attr-note-toggle");
    if (label) label.textContent = content ? "Edit note" : "Add note";
    if (toggle) toggle.classList.toggle("has-note", !!content);

    // Update sidebar badge
    var badge = document.getElementById("attr-badge-" + attrId);
    if (badge) badge.style.display = content ? "inline-block" : "none";
  };

  // Restore note visibility when switching attributes
  function hydrateAttrNotes() {
    Object.keys(attrNotes).forEach(function(attrId) {
      var content = attrNotes[attrId];
      if (!content) return;
      var editor = document.getElementById("attr-note-editor-" + attrId);
      var body = document.getElementById("attr-note-body-" + attrId);
      var label = document.getElementById("attr-note-label-" + attrId);
      var toggle = editor ? editor.closest(".cj-attr-note").querySelector(".cj-attr-note-toggle") : null;
      var badge = document.getElementById("attr-badge-" + attrId);
      if (editor && !editor.innerText.trim()) editor.innerText = content;
      if (body && content) body.style.display = "block";
      if (label) label.textContent = "Edit note";
      if (toggle) toggle.classList.add("has-note");
      if (badge) badge.style.display = "inline-block";
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

  // Compress an image via canvas resize (max 800px wide, JPEG quality 0.7)
  function compressImage(dataUrl, callback) {
    var img = new Image();
    img.onload = function() {
      var maxW = 800;
      var w = img.naturalWidth;
      var h = img.naturalHeight;
      if (w > maxW) {
        h = Math.round(h * (maxW / w));
        w = maxW;
      }
      var canvas = document.createElement("canvas");
      canvas.width = w;
      canvas.height = h;
      var ctx = canvas.getContext("2d");
      ctx.drawImage(img, 0, 0, w, h);
      // Use JPEG for photos (smaller), keep PNG for transparency
      var isPng = /^data:image\/png/.test(dataUrl);
      var mime = isPng ? "image/png" : "image/jpeg";
      var quality = isPng ? undefined : 0.7;
      var compressed = canvas.toDataURL(mime, quality);
      // Only use compressed if it's actually smaller
      callback(compressed.length < dataUrl.length ? compressed : dataUrl);
    };
    img.onerror = function() { callback(dataUrl); };
    img.src = dataUrl;
  }

  // Insert image into a slide via file picker (with compression)
  window.insertSlideImage = function(idx) {
    var input = document.createElement("input");
    input.type = "file";
    input.accept = "image/png,image/jpeg,image/gif,image/webp";
    input.style.display = "none";
    input.addEventListener("change", function() {
      var file = input.files[0];
      if (!file) return;
      var reader = new FileReader();
      reader.onload = function(e) {
        if (!slides[idx]) return;
        compressImage(e.target.result, function(compressed) {
          if (!slides[idx].images) slides[idx].images = [];
          slides[idx].images.push({
            id: "img-" + Date.now(),
            name: file.name,
            data: compressed
          });
          saveSlides();
          // Re-render preview to show image
          var preview = document.getElementById("cj-slide-preview-" + idx);
          if (preview) preview.innerHTML = renderMarkdown(slides[idx].body || "") + renderSlideImages(idx);
        });
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
          // Normalise: config uses "content", JS uses "body"
          data.forEach(function(s) {
            if (s.content && !s.body) { s.body = s.content; delete s.content; }
            if (!s.images) s.images = [];
          });
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
    // Make all slides visible for printing and add print override class
    document.querySelectorAll(".cj-slide-card").forEach(function(c) { c.classList.add("active"); });
    switchReportTab("slides");
    document.body.classList.add("cj-printing-slides");
    setTimeout(function() {
      window.print();
      setTimeout(function() { document.body.classList.remove("cj-printing-slides"); }, 500);
    }, 200);
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

    // Preserve select element states in the clone
    var selects = document.querySelectorAll("select");
    selects.forEach(function(sel) { sel.setAttribute("data-saved-value", sel.value); });

    // Serialize HTML
    var clone = document.documentElement.cloneNode(true);

    // Restore select values in clone
    var clonedSelects = clone.querySelectorAll("select");
    clonedSelects.forEach(function(sel) {
      var val = sel.getAttribute("data-saved-value");
      if (val) {
        var opts = sel.querySelectorAll("option");
        opts.forEach(function(opt) { opt.selected = (opt.value === val); });
      }
    });

    // Remove help overlay open state
    var helpEl = clone.querySelector("#cj-help-overlay");
    if (helpEl) helpEl.classList.remove("open");

    var html = "<!DOCTYPE html>\n" + clone.outerHTML;

    // Determine default filename
    var meta = document.querySelector('meta[name="turas-source-filename"]');
    var baseName = meta ? meta.getAttribute("content") : "Conjoint_Report";
    baseName = baseName.replace(/\.[^/.]+$/, "");
    var filename = baseName + "_Updated.html";

    // Use File System Access API "Save As" dialog if available (Chrome 86+)
    if (window.showSaveFilePicker) {
      window.showSaveFilePicker({
        suggestedName: filename,
        types: [{
          description: "HTML Report",
          accept: { "text/html": [".html"] }
        }]
      }).then(function(handle) {
        return handle.createWritable().then(function(writable) {
          return writable.write(html).then(function() {
            return writable.close();
          });
        });
      }).then(function() {
        showToast("Report saved successfully");
      }).catch(function(err) {
        // User cancelled the dialog or API error — fall back to download
        if (err.name !== "AbortError") {
          downloadBlob(html, filename, "text/html");
        }
      });
    } else {
      // Fallback for browsers without File System Access API
      downloadBlob(html, filename, "text/html");
    }
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

    // Restore sticky annotation for this mode
    if (typeof restoreSimAnnotation === "function") {
      restoreSimAnnotation(mode);
    }
  };


  // === SIMULATOR ANNOTATIONS (per-mode sticky notes) ===
  // Each simulator mode (shares, revenue, sensitivity, sov) has its own persistent note

  var simNotes = {};  // { "shares": "text", "revenue": "text", ... }

  window.toggleSimAnnotation = function() {
    var body = document.getElementById("cj-sim-annotation-body");
    if (!body) return;
    var visible = body.style.display !== "none";
    body.style.display = visible ? "none" : "block";
    if (!visible) {
      var editor = document.getElementById("cj-sim-annotation-editor");
      if (editor) setTimeout(function() { editor.focus(); }, 50);
    }
  };

  window.saveSimAnnotation = function() {
    var editor = document.getElementById("cj-sim-annotation-editor");
    var label = document.getElementById("cj-sim-annotation-label");
    if (!editor || !label) return;
    var text = editor.innerText.trim();
    var hasContent = text.length > 0;
    label.textContent = hasContent ? "Edit note" : "Add note";

    // Save to the current mode's storage
    var activeBtn = document.querySelector(".cj-sim-mode-btn.active");
    var mode = "shares";
    if (activeBtn) {
      var onclick = activeBtn.getAttribute("onclick") || "";
      var match = onclick.match(/switchSimMode\('(\w+)'\)/);
      if (match) mode = match[1];
    }
    simNotes[mode] = text;
  };

  // Restore note when switching modes
  window.restoreSimAnnotation = function(mode) {
    var editor = document.getElementById("cj-sim-annotation-editor");
    var body = document.getElementById("cj-sim-annotation-body");
    var label = document.getElementById("cj-sim-annotation-label");
    if (!editor) return;

    var text = simNotes[mode] || "";
    editor.innerText = text;

    if (text) {
      if (body) body.style.display = "block";
      if (label) label.textContent = "Edit note";
    } else {
      if (body) body.style.display = "none";
      if (label) label.textContent = "Add note";
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
          // Set default customers from config if available
          if (simData.meta && simData.meta.default_customers && typeof SimUI !== "undefined") {
            SimUI.setRevenueCustomers(simData.meta.default_customers);
          }
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

    // Hydrate attribute-level notes
    hydrateAttrNotes();

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
