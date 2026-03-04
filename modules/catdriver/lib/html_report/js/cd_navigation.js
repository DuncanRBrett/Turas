/* ==============================================================================
 * CATDRIVER HTML REPORT - NAVIGATION JS
 * ==============================================================================
 * Horizontal section nav bar, factor picker (with prefix scoping),
 * OR factor chip filtering, save report, hydrate, and print.
 * Supports multiple section nav bars (unified mode: one per analysis panel).
 * All functions prefixed cd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  // --------------------------------------------------------------------------
  // Section navigation — horizontal bar(s) (.cd-section-nav)
  // In single-report mode there is one nav bar; in unified mode there is
  // one per analysis panel.  Each is independently tracked.
  // --------------------------------------------------------------------------

  var navGroups = [];  // array of { navBar, links, sections }

  function initNavBars() {
    var allNavBars = document.querySelectorAll('.cd-section-nav');

    allNavBars.forEach(function(navBar) {
      var links = navBar.querySelectorAll('a');
      var sections = [];

      links.forEach(function(link) {
        var href = link.getAttribute('href');
        if (href && href.startsWith('#')) {
          var section = document.getElementById(href.slice(1));
          if (section) {
            sections.push({ el: section, link: link });
          }
        }

        link.addEventListener('click', function(e) {
          e.preventDefault();
          var target = document.getElementById(href.slice(1));
          if (target) {
            // Total sticky offset: tab bar (if present) + this nav bar
            var tabBar = document.querySelector('.cd-analysis-tabs');
            var tabBarHeight = tabBar ? tabBar.offsetHeight : 0;
            var navHeight = navBar.offsetHeight;
            var totalOffset = tabBarHeight + navHeight + 8;
            var targetY = target.getBoundingClientRect().top + window.scrollY - totalOffset;
            window.scrollTo({ top: targetY, behavior: 'smooth' });
          }
        });
      });

      navGroups.push({ navBar: navBar, links: links, sections: sections });
    });
  }

  function updateActiveNav() {
    navGroups.forEach(function(group) {
      if (group.sections.length === 0) return;

      // Only update if this nav bar is visible (its panel is active)
      var panel = group.navBar.closest('.cd-analysis-panel');
      if (panel && !panel.classList.contains('active')) return;

      var tabBar = document.querySelector('.cd-analysis-tabs');
      var tabBarHeight = tabBar ? tabBar.offsetHeight : 0;
      var navHeight = group.navBar.offsetHeight;
      var scrollY = window.scrollY + tabBarHeight + navHeight + 40;
      var active = null;

      for (var i = group.sections.length - 1; i >= 0; i--) {
        if (group.sections[i].el.offsetTop <= scrollY) {
          active = group.sections[i];
          break;
        }
      }

      group.links.forEach(function(link) { link.classList.remove('active'); });
      if (active) {
        active.link.classList.add('active');
      }
    });
  }

  document.addEventListener('DOMContentLoaded', function() {
    initNavBars();
    updateActiveNav();
    // Hydrate saved state
    cdHydratePage();
  });

  window.addEventListener('scroll', updateActiveNav, { passive: true });

  // --------------------------------------------------------------------------
  // Factor picker — scoped by optional id_prefix
  // Called as cdShowFactor('varId', 'prefix-') or cdShowFactor('varId', '')
  // --------------------------------------------------------------------------
  window.cdShowFactor = function(factorId, prefix) {
    prefix = prefix || '';

    // Find the target panel first, then scope to its parent section
    var targetPanel = document.getElementById(prefix + 'cd-panel-' + factorId);
    // Walk up from the panel to find the nearest cd-section container
    var container = targetPanel ? targetPanel.closest('.cd-section') : null;
    if (!container) {
      // Fallback: try patterns section ID (legacy)
      container = document.getElementById(prefix + 'cd-patterns') || document;
    }

    // Deactivate all tabs and panels within this container only
    container.querySelectorAll('.cd-factor-tab').forEach(function(tab) {
      tab.classList.remove('active');
    });
    container.querySelectorAll('.cd-factor-panel').forEach(function(fp) {
      fp.classList.remove('active');
    });

    // Activate selected — data-factor includes prefix
    var tab = container.querySelector('.cd-factor-tab[data-factor="' + prefix + factorId + '"]');

    if (tab) tab.classList.add('active');
    if (targetPanel) targetPanel.classList.add('active');
  };

  // --------------------------------------------------------------------------
  // OR factor chip filtering
  // Toggle chip on/off, show/hide OR table rows by data-cd-factor attribute.
  // All chips start active (all rows visible). Toggling off hides matching rows.
  // --------------------------------------------------------------------------
  window.cdToggleOrFactor = function(factorLabel, prefix) {
    prefix = prefix || '';

    // Find the OR section for this prefix
    var sectionId = prefix + 'cd-odds-ratios';
    var section = document.getElementById(sectionId);
    if (!section) return;

    // Toggle chip active state
    var chip = section.querySelector('.cd-or-chip[data-cd-or-factor="' + factorLabel + '"]');
    if (!chip) return;

    chip.classList.toggle('active');
    var isActive = chip.classList.contains('active');

    // Show/hide table rows matching this factor
    var table = section.querySelector('.cd-or-table');
    if (table) {
      table.querySelectorAll('tbody tr[data-cd-factor]').forEach(function(row) {
        if (row.getAttribute('data-cd-factor') === factorLabel) {
          row.style.display = isActive ? '' : 'none';
        }
      });
    }

    // Show/hide forest plot SVG rows matching this factor
    var chart = section.querySelector('.cd-forest-plot');
    if (chart) {
      chart.querySelectorAll('g.cd-forest-row[data-cd-factor]').forEach(function(g) {
        if (g.getAttribute('data-cd-factor') === factorLabel) {
          g.style.display = isActive ? '' : 'none';
        }
      });
      // Compact visible rows and resize the SVG
      cdResizeForestPlot(chart);
    }
  };

  // --------------------------------------------------------------------------
  // Forest plot dynamic resize — compact visible rows after chip filtering
  // Repositions visible <g> rows, adjusts viewBox, ref line, zone labels.
  // --------------------------------------------------------------------------
  function cdResizeForestPlot(svg) {
    var rowHeight = 26;
    var gap = 6;
    var rowStep = rowHeight + gap;   // 32
    var topPad = 30;
    var bottomPad = 50;

    var allRows = svg.querySelectorAll('g.cd-forest-row');
    var visibleIdx = 0;

    allRows.forEach(function(g, i) {
      if (g.style.display === 'none') {
        return;
      }
      // Original y for row i: topPad + i * rowStep
      var originalY = topPad + i * rowStep;
      var targetY = topPad + visibleIdx * rowStep;
      var deltaY = targetY - originalY;

      if (deltaY !== 0) {
        g.setAttribute('transform', 'translate(0,' + deltaY + ')');
      } else {
        g.removeAttribute('transform');
      }
      visibleIdx++;
    });

    if (visibleIdx === 0) return;

    // New total height
    var newHeight = topPad + visibleIdx * rowStep + bottomPad - gap;

    // Update viewBox height
    var vb = svg.getAttribute('viewBox');
    if (vb) {
      var parts = vb.split(/\s+/);
      if (parts.length >= 4) {
        svg.setAttribute('viewBox', parts[0] + ' ' + parts[1] + ' ' + parts[2] + ' ' + newHeight);
      }
    }

    // Update reference line y2 (dashed line)
    var refLine = svg.querySelector('line[stroke-dasharray]');
    if (refLine) refLine.setAttribute('y2', newHeight - 10);

    // Update zone labels (italic text elements at the bottom)
    svg.querySelectorAll('text[font-style="italic"]').forEach(function(t) {
      t.setAttribute('y', newHeight - 2);
    });
  }

  // --------------------------------------------------------------------------
  // Probability lift chip filtering
  // Toggle chip on/off, show/hide lift chart rows by data-cd-factor attribute.
  // --------------------------------------------------------------------------
  window.cdToggleLiftFactor = function(factorLabel, prefix) {
    prefix = prefix || '';

    var sectionId = prefix + 'cd-probability-lifts';
    var section = document.getElementById(sectionId);
    if (!section) return;

    // Toggle chip active state
    var chip = section.querySelector('.cd-or-chip[data-cd-lift-factor="' + factorLabel + '"]');
    if (!chip) return;

    chip.classList.toggle('active');
    var isActive = chip.classList.contains('active');

    // Show/hide lift chart SVG rows matching this driver
    var chart = section.querySelector('.cd-lift-chart');
    if (chart) {
      chart.querySelectorAll('g.cd-lift-row[data-cd-factor]').forEach(function(g) {
        if (g.getAttribute('data-cd-factor') === factorLabel) {
          g.style.display = isActive ? '' : 'none';
        }
      });
      cdResizeLiftChart(chart);
    }
  };

  // --------------------------------------------------------------------------
  // Lift chart dynamic resize — compact visible rows after chip filtering
  // --------------------------------------------------------------------------
  function cdResizeLiftChart(svg) {
    var barHeight = 24;
    var headerHeight = 28;
    var gap = 6;
    var topPad = 30;
    var bottomPad = 20;

    var allRows = svg.querySelectorAll('g.cd-lift-row');
    var visibleIdx = 0;
    var currentY = topPad;

    allRows.forEach(function(g, i) {
      if (g.style.display === 'none') return;

      // Calculate original y position by counting all rows before this one
      var origY = topPad;
      for (var j = 0; j < i; j++) {
        var prev = allRows[j];
        origY += (prev.classList.contains('cd-lift-header') ? headerHeight : barHeight) + gap;
      }

      var deltaY = currentY - origY;
      if (deltaY !== 0) {
        g.setAttribute('transform', 'translate(0,' + deltaY + ')');
      } else {
        g.removeAttribute('transform');
      }

      currentY += (g.classList.contains('cd-lift-header') ? headerHeight : barHeight) + gap;
      visibleIdx++;
    });

    if (visibleIdx === 0) return;

    var newHeight = currentY + bottomPad;

    // Update viewBox height
    var vb = svg.getAttribute('viewBox');
    if (vb) {
      var parts = vb.split(/\s+/);
      if (parts.length >= 4) {
        svg.setAttribute('viewBox', parts[0] + ' ' + parts[1] + ' ' + parts[2] + ' ' + newHeight);
      }
    }

    // Update zero line and gridlines y2
    svg.querySelectorAll('line[stroke-dasharray]').forEach(function(line) {
      line.setAttribute('y2', newHeight - 15);
    });
    svg.querySelectorAll('line[stroke="#f0f0f0"]').forEach(function(line) {
      line.setAttribute('y2', newHeight - 15);
    });
  }

  // --------------------------------------------------------------------------
  // Importance bar filtering — show/hide bars by threshold
  // Modes: 'all', 'top-3', 'top-5', 'top-8', 'significant'
  // --------------------------------------------------------------------------
  window.cdFilterImportanceBars = function(mode, prefix) {
    prefix = prefix || '';

    var sectionId = prefix + 'cd-importance';
    var section = document.getElementById(sectionId);
    if (!section) return;

    // Update chip active state
    var filterBar = section.querySelector('#' + CSS.escape(prefix + 'cd-importance-filter'));
    if (filterBar) {
      filterBar.querySelectorAll('.cd-or-chip').forEach(function(chip) {
        chip.classList.toggle('active', chip.getAttribute('data-cd-imp-mode') === mode);
      });
    }

    // Filter chart rows
    var chart = section.querySelector('svg.cd-importance-chart');
    if (chart) {
      var rows = chart.querySelectorAll('g.cd-importance-row');
      rows.forEach(function(g) {
        var rank = parseInt(g.getAttribute('data-cd-rank'), 10);
        var sig = g.getAttribute('data-cd-sig') === 'yes';
        var show = true;

        if (mode === 'top-3') show = rank <= 3;
        else if (mode === 'top-5') show = rank <= 5;
        else if (mode === 'top-8') show = rank <= 8;
        else if (mode === 'significant') show = sig;
        // 'all' shows everything

        g.style.display = show ? '' : 'none';
      });

      cdResizeImportanceChart(chart);
    }

    // Also filter table rows to match
    var table = section.querySelector('.cd-importance-table');
    if (table) {
      var trs = table.querySelectorAll('tbody tr');
      trs.forEach(function(tr, idx) {
        var rank = idx + 1;
        var show = true;

        if (mode === 'top-3') show = rank <= 3;
        else if (mode === 'top-5') show = rank <= 5;
        else if (mode === 'top-8') show = rank <= 8;
        else if (mode === 'significant') {
          // Check the sig column — cd-sig-none means not significant
          var sigCell = tr.querySelector('.cd-td-sig');
          show = sigCell ? !sigCell.classList.contains('cd-sig-none') : true;
        }

        tr.style.display = show ? '' : 'none';
      });
    }
  };

  // --------------------------------------------------------------------------
  // Importance chart dynamic resize — same approach as forest plot
  // --------------------------------------------------------------------------
  function cdResizeImportanceChart(svg) {
    var barHeight = 28;
    var gap = 8;
    var rowStep = barHeight + gap;  // 36
    var topPad = 25;
    var bottomPad = 15;

    var allRows = svg.querySelectorAll('g.cd-importance-row');
    var visibleIdx = 0;

    allRows.forEach(function(g, i) {
      if (g.style.display === 'none') {
        return;
      }
      var originalY = topPad + i * rowStep;
      var targetY = topPad + visibleIdx * rowStep;
      var deltaY = targetY - originalY;

      if (deltaY !== 0) {
        g.setAttribute('transform', 'translate(0,' + deltaY + ')');
      } else {
        g.removeAttribute('transform');
      }
      visibleIdx++;
    });

    if (visibleIdx === 0) return;

    var newHeight = topPad + visibleIdx * rowStep + bottomPad;

    // Update viewBox height
    var vb = svg.getAttribute('viewBox');
    if (vb) {
      var parts = vb.split(/\s+/);
      if (parts.length >= 4) {
        svg.setAttribute('viewBox', parts[0] + ' ' + parts[1] + ' ' + parts[2] + ' ' + newHeight);
      }
    }

    // Update gridlines — shorten their y2 to new height
    svg.querySelectorAll('line[stroke="#e2e8f0"]').forEach(function(line) {
      var y2 = parseFloat(line.getAttribute('y2'));
      if (y2 > newHeight) {
        line.setAttribute('y2', newHeight - 5);
      }
    });
  }

  // --------------------------------------------------------------------------
  // Save Report — download HTML with current state preserved
  // --------------------------------------------------------------------------
  window.cdSaveReportHTML = function() {
    // Sync all insights to hidden stores
    if (typeof cdSyncAllInsights === 'function') cdSyncAllInsights();

    // Save pinned views data
    if (typeof cdSavePinnedData === 'function') cdSavePinnedData();

    // Stamp saved badge in header
    var savedBadge = document.getElementById('cd-saved-badge');
    if (savedBadge) {
      savedBadge.textContent = 'Last saved: ' + new Date().toLocaleString();
      savedBadge.style.display = 'inline-block';
    }

    // Clean ephemeral DOM before serializing
    var actionBar = document.querySelector('.cd-action-bar');
    var wasVisible = actionBar ? actionBar.style.display : '';
    if (actionBar) actionBar.style.display = 'none';

    // Hide all insight containers that are empty
    document.querySelectorAll('.cd-insight-container').forEach(function(c) {
      var editor = c.querySelector('.cd-insight-editor');
      if (editor && !editor.textContent.trim()) {
        c.setAttribute('data-cd-was-hidden', c.style.display || '');
        c.style.display = 'none';
      }
    });

    // Serialize
    var html = '<!DOCTYPE html>\n' + document.documentElement.outerHTML;
    var blob = new Blob([html], { type: 'text/html;charset=utf-8' });

    // Build filename from meta tag or title
    var metaFilename = document.querySelector('meta[name="turas-source-filename"]');
    var baseName = metaFilename ? metaFilename.getAttribute('content') : document.title;
    baseName = baseName.replace(/\.html$/i, '').replace(/[^a-zA-Z0-9_\-\s]/g, '');
    var filename = baseName + '_Updated.html';

    cdDownloadBlob(blob, filename);

    // Restore DOM
    if (actionBar) actionBar.style.display = wasVisible;
    document.querySelectorAll('.cd-insight-container[data-cd-was-hidden]').forEach(function(c) {
      c.style.display = c.getAttribute('data-cd-was-hidden');
      c.removeAttribute('data-cd-was-hidden');
    });
  };

  // --------------------------------------------------------------------------
  // Hydrate page — restore insights + pins from saved state
  // --------------------------------------------------------------------------
  window.cdHydratePage = function() {
    if (typeof cdHydrateInsights === 'function') cdHydrateInsights();
    if (typeof cdHydratePinnedViews === 'function') cdHydratePinnedViews();
  };

  // --------------------------------------------------------------------------
  // Driver comparison matrix — top N filter
  // --------------------------------------------------------------------------

  /**
   * Filter driver comparison matrix rows by best rank.
   * @param {string} tableId - ID of the <table> element
   * @param {string} mode - 'all', '3', or '5'
   */
  window.cdFilterMatrixRows = function(tableId, mode) {
    var table = document.getElementById(tableId);
    if (!table) return;

    // Update chip active state — find the chip bar within the same section
    var section = table.closest('.cd-section');
    if (section) {
      var chips = section.querySelectorAll('.cd-or-chip-bar .cd-or-chip');
      chips.forEach(function(chip) {
        var isActive = false;
        var text = chip.textContent.trim().toLowerCase();
        if (mode === 'all' && text === 'all') isActive = true;
        else if (mode === '3' && text === 'top 3') isActive = true;
        else if (mode === '5' && text === 'top 5') isActive = true;
        chip.classList.toggle('active', isActive);
      });
    }

    // Filter table rows
    var rows = table.querySelectorAll('tbody tr');
    rows.forEach(function(row) {
      var bestRank = parseInt(row.getAttribute('data-cd-best-rank'), 10);
      var show = true;
      if (mode === '3') show = bestRank <= 3;
      else if (mode === '5') show = bestRank <= 5;
      // 'all' shows everything
      row.style.display = show ? '' : 'none';
    });
  };

  // --------------------------------------------------------------------------
  // Print mode
  // --------------------------------------------------------------------------
  window.cdPrint = function() {
    window.print();
  };

})();
