/* ==============================================================================
 * KEYDRIVER HTML REPORT - NAVIGATION JS
 * ==============================================================================
 * Horizontal section nav bar, save report, hydrate, and print.
 * Supports multiple section nav bars (unified mode: one per analysis panel).
 * All functions prefixed kd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  // --------------------------------------------------------------------------
  // Page-based section navigation (.kd-section-nav)
  // Each nav link switches to a section page (show/hide) instead of scrolling.
  // --------------------------------------------------------------------------

  /**
   * Switch to a specific section page.
   * @param {string} pageName - The data-kd-section value (e.g., 'importance')
   */
  window.kdSwitchPage = function(pageName) {
    // Find the closest content container (supports unified mode)
    var content = document.querySelector('.kd-content');
    if (!content) return;

    // Hide all sections, show target
    content.querySelectorAll('.kd-section[data-kd-section]').forEach(function(section) {
      section.classList.toggle('kd-page-active',
        section.getAttribute('data-kd-section') === pageName);
    });

    // Update nav link active state
    var navBar = document.querySelector('.kd-section-nav');
    if (navBar) {
      navBar.querySelectorAll('a[data-kd-page]').forEach(function(link) {
        link.classList.toggle('active',
          link.getAttribute('data-kd-page') === pageName);
      });
    }

    // Scroll to top of content area
    window.scrollTo({ top: 0 });
  };

  document.addEventListener('DOMContentLoaded', function() {
    // Hydrate saved state
    kdHydratePage();
    // Initialize table export buttons (CSV/Excel)
    if (typeof kdInitTableExport === 'function') kdInitTableExport();
  });

  // --------------------------------------------------------------------------
  // Importance bar filtering — show/hide bars by threshold
  // Modes: 'all', 'top-3', 'top-5', 'top-8'
  // --------------------------------------------------------------------------
  window.kdFilterImportanceBars = function(mode, prefix) {
    prefix = prefix || '';

    var sectionId = prefix + 'kd-importance';
    var section = document.getElementById(sectionId);
    if (!section) return;

    // Update chip active state
    var filterBar = section.querySelector('#' + CSS.escape(prefix + 'kd-importance-filter'));
    if (filterBar) {
      filterBar.querySelectorAll('.kd-or-chip').forEach(function(chip) {
        chip.classList.toggle('active', chip.getAttribute('data-kd-imp-mode') === mode);
      });
    }

    // Filter chart rows
    var chart = section.querySelector('svg.kd-importance-chart');
    if (chart) {
      var rows = chart.querySelectorAll('g.kd-importance-row');
      rows.forEach(function(g) {
        var rank = parseInt(g.getAttribute('data-kd-rank'), 10);
        var sig = g.getAttribute('data-kd-sig') === 'yes';
        var show = true;

        if (mode === 'top-3') show = rank <= 3;
        else if (mode === 'top-5') show = rank <= 5;
        else if (mode === 'top-8') show = rank <= 8;
        else if (mode === 'significant') show = sig;
        // 'all' shows everything

        g.style.display = show ? '' : 'none';
      });

      kdResizeImportanceChart(chart);
    }

    // Also filter table rows to match
    var table = section.querySelector('.kd-importance-table');
    if (table) {
      var trs = table.querySelectorAll('tbody tr');
      trs.forEach(function(tr, idx) {
        var rank = idx + 1;
        var show = true;

        if (mode === 'top-3') show = rank <= 3;
        else if (mode === 'top-5') show = rank <= 5;
        else if (mode === 'top-8') show = rank <= 8;
        else if (mode === 'significant') {
          // Check the sig column — kd-sig-none means not significant
          var sigCell = tr.querySelector('.kd-td-sig');
          show = sigCell ? !sigCell.classList.contains('kd-sig-none') : true;
        }

        tr.style.display = show ? '' : 'none';
      });
    }
  };

  // --------------------------------------------------------------------------
  // Importance chart dynamic resize — same approach as forest plot
  // --------------------------------------------------------------------------
  function kdResizeImportanceChart(svg) {
    var barHeight = 28;
    var gap = 8;
    var rowStep = barHeight + gap;  // 36
    var topPad = 25;
    var bottomPad = 15;

    var allRows = svg.querySelectorAll('g.kd-importance-row');
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
  // Segment comparison — show/hide segments and sort by segment
  // --------------------------------------------------------------------------

  /**
   * Toggle a single segment on/off in the chart and table.
   * @param {string} segName - Segment name (e.g., 'Premium', 'Total')
   */
  window.kdToggleSegment = function(segName) {
    var section = document.getElementById('kd-segment-comparison');
    if (!section) return;

    // Toggle chip active state
    var chip = section.querySelector('[data-kd-seg-chip="' + segName + '"]');
    if (chip) chip.classList.toggle('active');

    // Update "All" chip
    var allChips = section.querySelectorAll('[data-kd-seg-chip]:not([data-kd-seg-chip="all"])');
    var allActive = true;
    allChips.forEach(function(c) {
      if (!c.classList.contains('active')) allActive = false;
    });
    var allChip = section.querySelector('[data-kd-seg-chip="all"]');
    if (allChip) allChip.classList.toggle('active', allActive);

    kdApplySegmentFilter(section);
  };

  /**
   * Toggle all segments on or off.
   * @param {boolean} show
   */
  window.kdToggleAllSegments = function(show) {
    var section = document.getElementById('kd-segment-comparison');
    if (!section) return;

    section.querySelectorAll('[data-kd-seg-chip]').forEach(function(chip) {
      if (show) chip.classList.add('active');
      else if (chip.getAttribute('data-kd-seg-chip') !== 'all') chip.classList.remove('active');
    });

    kdApplySegmentFilter(section);
  };

  /**
   * Apply segment filter based on active chips.
   * Hides/shows columns in the table and bars in the chart.
   */
  function kdApplySegmentFilter(section) {
    // Determine which segments are active
    var activeSegs = {};
    section.querySelectorAll('[data-kd-seg-chip].active').forEach(function(chip) {
      var seg = chip.getAttribute('data-kd-seg-chip');
      if (seg !== 'all') activeSegs[seg] = true;
    });

    // Filter table columns
    var table = section.querySelector('.kd-segment-comparison-table');
    if (table) {
      // Header cells and body cells with data-kd-seg-col
      table.querySelectorAll('[data-kd-seg-col]').forEach(function(cell) {
        var seg = cell.getAttribute('data-kd-seg-col');
        cell.style.display = activeSegs[seg] ? '' : 'none';
      });
    }

    // Filter chart bars
    var chart = section.querySelector('.kd-segment-chart');
    if (chart) {
      chart.querySelectorAll('.kd-seg-bar').forEach(function(g) {
        var seg = g.getAttribute('data-kd-segment');
        g.style.display = activeSegs[seg] ? '' : 'none';
      });
      // Also toggle legend items
      chart.querySelectorAll('[data-kd-seg-legend]').forEach(function(rect) {
        var seg = rect.getAttribute('data-kd-seg-legend');
        var show = activeSegs[seg];
        rect.style.display = show ? '' : 'none';
        // Hide corresponding text label (next sibling)
        var next = rect.nextElementSibling;
        if (next && next.tagName === 'text') {
          next.style.display = show ? '' : 'none';
        }
      });
    }
  }

  /**
   * Sort the segment comparison table by a segment's percentage.
   * @param {string} segName - Segment name to sort by, or 'default' for original order
   */
  window.kdSortSegmentTable = function(segName) {
    var section = document.getElementById('kd-segment-comparison');
    if (!section) return;
    var table = section.querySelector('.kd-segment-comparison-table');
    if (!table) return;
    var tbody = table.querySelector('tbody');
    if (!tbody) return;

    var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
    if (rows.length === 0) return;

    if (segName === 'default') {
      // Restore original order (by data-kd-sort-val of total, or original DOM order)
      // Store original indices if not already stored
      rows.forEach(function(row, idx) {
        if (!row.hasAttribute('data-kd-orig-idx')) {
          row.setAttribute('data-kd-orig-idx', idx);
        }
      });
      rows.sort(function(a, b) {
        return parseInt(a.getAttribute('data-kd-orig-idx')) -
               parseInt(b.getAttribute('data-kd-orig-idx'));
      });
    } else {
      // Store original indices on first sort
      rows.forEach(function(row, idx) {
        if (!row.hasAttribute('data-kd-orig-idx')) {
          row.setAttribute('data-kd-orig-idx', idx);
        }
      });
      // Sort by the segment's percentage (descending)
      var colName = segName === 'Total' ? 'total' : segName;
      rows.sort(function(a, b) {
        var aCell = a.querySelector('[data-kd-seg-col="' + colName + '"][data-kd-sort-val]');
        var bCell = b.querySelector('[data-kd-seg-col="' + colName + '"][data-kd-sort-val]');
        var aVal = aCell ? parseFloat(aCell.getAttribute('data-kd-sort-val')) : 0;
        var bVal = bCell ? parseFloat(bCell.getAttribute('data-kd-sort-val')) : 0;
        return bVal - aVal;
      });
    }

    // Re-append rows in sorted order
    rows.forEach(function(row) { tbody.appendChild(row); });
  };

  // --------------------------------------------------------------------------
  // Report-level tab switching (Analysis | Pinned Views)
  // --------------------------------------------------------------------------
  window.kdSwitchReportTab = function(tabName) {
    document.querySelectorAll('.kd-report-tab').forEach(function(btn) {
      btn.classList.toggle('active', btn.getAttribute('data-kd-tab') === tabName);
    });
    document.querySelectorAll('.kd-tab-panel').forEach(function(panel) {
      panel.classList.remove('active');
    });
    var target = document.getElementById('kd-tab-' + tabName);
    if (target) target.classList.add('active');

    // Scroll to top when switching tabs
    window.scrollTo({ top: 0 });
  };

  // --------------------------------------------------------------------------
  // Save Report — download HTML with current state preserved
  // --------------------------------------------------------------------------
  window.kdSaveReportHTML = function() {
    // Sync all insights to hidden stores
    if (typeof kdSyncAllInsights === 'function') kdSyncAllInsights();

    // Save pinned views data
    if (typeof kdSavePinnedData === 'function') kdSavePinnedData();

    // Stamp saved badge in header
    var savedBadge = document.getElementById('kd-saved-badge');
    if (savedBadge) {
      savedBadge.textContent = 'Last saved: ' + new Date().toLocaleString();
      savedBadge.style.display = 'inline-block';
    }

    // Clean ephemeral DOM before serializing
    var actionBar = document.querySelector('.kd-action-bar');
    var wasVisible = actionBar ? actionBar.style.display : '';
    if (actionBar) actionBar.style.display = 'none';

    // Hide all insight containers that are empty
    document.querySelectorAll('.kd-insight-container').forEach(function(c) {
      var editor = c.querySelector('.kd-insight-editor');
      if (editor && !editor.textContent.trim()) {
        c.setAttribute('data-kd-was-hidden', c.style.display || '');
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

    kdDownloadBlob(blob, filename);

    // Restore DOM
    if (actionBar) actionBar.style.display = wasVisible;
    document.querySelectorAll('.kd-insight-container[data-kd-was-hidden]').forEach(function(c) {
      c.style.display = c.getAttribute('data-kd-was-hidden');
      c.removeAttribute('data-kd-was-hidden');
    });
  };

  // --------------------------------------------------------------------------
  // Hydrate page — restore insights + pins from saved state
  // --------------------------------------------------------------------------
  window.kdHydratePage = function() {
    if (typeof kdHydrateInsights === 'function') kdHydrateInsights();
    if (typeof kdHydratePinnedViews === 'function') kdHydratePinnedViews();
  };

  // --------------------------------------------------------------------------
  // Generic table sort — click header to toggle sort direction
  // --------------------------------------------------------------------------
  window.kdSortTable = function(th, colIdx, type) {
    var table = th.closest('table');
    if (!table) return;
    var tbody = table.querySelector('tbody');
    if (!tbody) return;

    // Determine sort direction (toggle)
    var asc = th.getAttribute('data-kd-sort-dir') !== 'asc';
    // Clear other sort indicators in this table
    table.querySelectorAll('.kd-sortable').forEach(function(h) {
      h.removeAttribute('data-kd-sort-dir');
      h.classList.remove('kd-sort-asc', 'kd-sort-desc');
    });
    th.setAttribute('data-kd-sort-dir', asc ? 'asc' : 'desc');
    th.classList.add(asc ? 'kd-sort-asc' : 'kd-sort-desc');

    var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
    rows.sort(function(a, b) {
      var aCells = a.querySelectorAll('td');
      var bCells = b.querySelectorAll('td');
      if (colIdx >= aCells.length || colIdx >= bCells.length) return 0;
      var aVal = (aCells[colIdx].textContent || '').trim();
      var bVal = (bCells[colIdx].textContent || '').trim();
      if (type === 'num') {
        aVal = parseFloat(aVal) || 0;
        bVal = parseFloat(bVal) || 0;
        return asc ? aVal - bVal : bVal - aVal;
      }
      return asc ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
    });
    rows.forEach(function(row) { tbody.appendChild(row); });
  };

  // --------------------------------------------------------------------------
  // Print mode
  // --------------------------------------------------------------------------
  window.kdPrint = function() {
    window.print();
  };

})();
