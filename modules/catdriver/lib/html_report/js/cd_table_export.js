/* ==============================================================================
 * CATDRIVER HTML REPORT - TABLE EXPORT
 * ==============================================================================
 * Per-table CSV and Excel (XML Spreadsheet) export for all cd-table elements.
 * Export buttons appear on hover over any .cd-table-wrapper container.
 * All functions prefixed cd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  // --------------------------------------------------------------------------
  // Extract table data as 2D array
  // --------------------------------------------------------------------------

  /**
   * Extract all rows from a table as a 2D string array.
   * @param {HTMLTableElement} table
   * @returns {string[][]}
   */
  function extractCdTableData(table) {
    if (!table) return [];
    var data = [];
    var rows = table.querySelectorAll('tr');
    rows.forEach(function(row) {
      if (row.style.display === 'none') return;
      var cells = row.querySelectorAll('th, td');
      var rowData = [];
      cells.forEach(function(cell) {
        if (cell.style.display === 'none') return;
        var clone = cell.cloneNode(true);
        // Remove inline bar fills (visual only)
        var bars = clone.querySelectorAll('.cd-bar-container, .cd-bar-fill');
        bars.forEach(function(b) { b.remove(); });
        // Remove badges (keep text)
        var badges = clone.querySelectorAll('.cd-badge, .cd-or-effect-badge');
        badges.forEach(function(badge) {
          var text = badge.textContent;
          badge.parentNode.replaceChild(document.createTextNode(text), badge);
        });
        rowData.push(clone.textContent.trim());
      });
      if (rowData.length > 0) data.push(rowData);
    });
    return data;
  }

  /**
   * Infer a filename from the closest section title.
   * @param {HTMLElement} wrapper - The .cd-table-wrapper element
   * @returns {string}
   */
  function inferTableName(wrapper) {
    var section = wrapper.closest('.cd-section');
    if (section) {
      var title = section.querySelector('.cd-section-title');
      if (title) {
        return title.textContent.trim()
          .replace(/[^a-zA-Z0-9_\- ]/g, '')
          .replace(/\s+/g, '_')
          .substring(0, 40);
      }
    }
    return 'catdriver_table';
  }

  // --------------------------------------------------------------------------
  // CSV Export
  // --------------------------------------------------------------------------

  /**
   * Export a table as CSV.
   * @param {HTMLTableElement} table
   * @param {string} filename
   */
  window.cdExportCSV = function(table, filename) {
    var data = extractCdTableData(table);
    if (data.length === 0) return;

    var csv = data.map(function(row) {
      return row.map(function(cell) {
        var text = String(cell);
        if (text.indexOf(',') >= 0 || text.indexOf('\n') >= 0 || text.indexOf('"') >= 0) {
          text = '"' + text.replace(/"/g, '""') + '"';
        }
        return text;
      }).join(',');
    }).join('\n');

    var blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
    cdDownloadBlob(blob, (filename || 'table') + '.csv');
  };

  // --------------------------------------------------------------------------
  // Excel XML Export
  // --------------------------------------------------------------------------

  /**
   * Escape XML special characters.
   * @param {string} s
   * @returns {string}
   */
  function escXml(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  /**
   * Export a table as Excel XML Spreadsheet (.xls).
   * @param {HTMLTableElement} table
   * @param {string} filename
   */
  window.cdExportExcel = function(table, filename) {
    var data = extractCdTableData(table);
    if (data.length === 0) return;

    var sheetName = (filename || 'Table').substring(0, 31);

    var xml = [];
    xml.push('<?xml version="1.0" encoding="UTF-8"?>');
    xml.push('<?mso-application progid="Excel.Sheet"?>');
    xml.push('<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"');
    xml.push(' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">');
    xml.push('<Styles>');
    xml.push('<Style ss:ID="header"><Font ss:Bold="1" ss:Size="11"/>');
    xml.push('<Interior ss:Color="#F8F9FA" ss:Pattern="Solid"/></Style>');
    xml.push('<Style ss:ID="normal"><Font ss:Size="11"/></Style>');
    xml.push('</Styles>');
    xml.push('<Worksheet ss:Name="' + escXml(sheetName) + '">');
    xml.push('<Table>');

    data.forEach(function(row, rowIdx) {
      xml.push('<Row>');
      row.forEach(function(cell) {
        var styleId = rowIdx === 0 ? 'header' : 'normal';
        // Detect numeric values
        var cleaned = cell.replace(/[,%]/g, '');
        var num = parseFloat(cleaned);
        var isNum = !isNaN(num) && cleaned.trim() !== '' && /^[\d,.\-%\s]+$/.test(cell);
        if (isNum) {
          xml.push('<Cell ss:StyleID="' + styleId + '"><Data ss:Type="Number">' + num + '</Data></Cell>');
        } else {
          xml.push('<Cell ss:StyleID="' + styleId + '"><Data ss:Type="String">' + escXml(cell) + '</Data></Cell>');
        }
      });
      xml.push('</Row>');
    });

    xml.push('</Table></Worksheet></Workbook>');

    var blob = new Blob([xml.join('\n')], {
      type: 'application/vnd.ms-excel;charset=utf-8'
    });
    cdDownloadBlob(blob, (filename || 'table') + '.xls');
  };

  // --------------------------------------------------------------------------
  // Inject export buttons into all .cd-table-wrapper containers
  // --------------------------------------------------------------------------

  /**
   * Initialize table export buttons. Called on DOMContentLoaded.
   * Adds a small CSV | Excel button bar to each .cd-table-wrapper.
   */
  window.cdInitTableExport = function() {
    var wrappers = document.querySelectorAll('.cd-table-wrapper');
    wrappers.forEach(function(wrapper) {
      // Skip if already initialized
      if (wrapper.querySelector('.cd-table-export-bar')) return;

      var table = wrapper.querySelector('table');
      if (!table) return;

      var bar = document.createElement('div');
      bar.className = 'cd-table-export-bar';

      var csvBtn = document.createElement('button');
      csvBtn.className = 'cd-table-export-btn';
      csvBtn.textContent = 'CSV';
      csvBtn.title = 'Download as CSV';
      csvBtn.onclick = function() {
        var name = inferTableName(wrapper);
        cdExportCSV(table, name);
      };

      var xlsBtn = document.createElement('button');
      xlsBtn.className = 'cd-table-export-btn';
      xlsBtn.textContent = 'Excel';
      xlsBtn.title = 'Download as Excel';
      xlsBtn.onclick = function() {
        var name = inferTableName(wrapper);
        cdExportExcel(table, name);
      };

      bar.appendChild(csvBtn);
      bar.appendChild(xlsBtn);
      wrapper.appendChild(bar);
    });
  };

})();
