/**
 * PPTX package scaffolding — the fixed OOXML parts (content types, rels,
 * master, layout, theme) and the packager that zips parts + slides into a
 * valid .pptx. Slide content builders live in 15_pptx_slides.js. Pure.
 *
 * SIZE-EXCEPTION: mostly literal OOXML boilerplate strings; splitting the
 * package definition across files would hurt readability, and the active
 * logic is small.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var pptx = TR.pptx = TR.pptx || {};

  var XML = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  var NS_A = "http://schemas.openxmlformats.org/drawingml/2006/main";
  var NS_R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
  var NS_P = "http://schemas.openxmlformats.org/presentationml/2006/main";
  var REL = "http://schemas.openxmlformats.org/package/2006/relationships";
  var RT = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/";
  var CT_BASE = "application/vnd.openxmlformats-officedocument";

  pptx.NS = { a: NS_A, r: NS_R, p: NS_P };

  function contentTypes(slideCount, chartCount) {
    var overrides = [
      ["/ppt/presentation.xml", CT_BASE + ".presentationml.presentation.main+xml"],
      ["/ppt/slideMasters/slideMaster1.xml", CT_BASE + ".presentationml.slideMaster+xml"],
      ["/ppt/slideLayouts/slideLayout1.xml", CT_BASE + ".presentationml.slideLayout+xml"],
      ["/ppt/theme/theme1.xml", CT_BASE + ".theme+xml"],
      ["/ppt/presProps.xml", CT_BASE + ".presentationml.presProps+xml"],
      ["/ppt/viewProps.xml", CT_BASE + ".presentationml.viewProps+xml"],
      ["/ppt/tableStyles.xml", CT_BASE + ".presentationml.tableStyles+xml"]
    ];
    for (var i = 1; i <= slideCount; i++) {
      overrides.push(["/ppt/slides/slide" + i + ".xml",
        CT_BASE + ".presentationml.slide+xml"]);
    }
    for (var c = 1; c <= (chartCount || 0); c++) {
      overrides.push(["/ppt/charts/chart" + c + ".xml",
        CT_BASE + ".drawingml.chart+xml"]);
    }
    return XML + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
      '<Default Extension="xml" ContentType="application/xml"/>' +
      '<Default Extension="xlsx" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"/>' +
      overrides.map(function (o) {
        return '<Override PartName="' + o[0] + '" ContentType="' + o[1] + '"/>';
      }).join("") + "</Types>";
  }

  function rels(list) {
    return XML + '<Relationships xmlns="' + REL + '">' +
      list.map(function (r) {
        return '<Relationship Id="' + r[0] + '" Type="' + RT + r[1] +
          '" Target="' + r[2] + '"/>';
      }).join("") + "</Relationships>";
  }

  function presentation(slideCount) {
    var sldIds = [];
    for (var i = 0; i < slideCount; i++) {
      sldIds.push('<p:sldId id="' + (256 + i) + '" r:id="rId' + (2 + i) + '"/>');
    }
    return XML + '<p:presentation xmlns:a="' + NS_A + '" xmlns:r="' + NS_R +
      '" xmlns:p="' + NS_P + '">' +
      '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>' +
      "<p:sldIdLst>" + sldIds.join("") + "</p:sldIdLst>" +
      '<p:sldSz cx="12192000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/>' +
      "</p:presentation>";
  }

  function presentationRels(slideCount) {
    var list = [["rId1", "slideMaster", "slideMasters/slideMaster1.xml"]];
    for (var i = 0; i < slideCount; i++) {
      list.push(["rId" + (2 + i), "slide", "slides/slide" + (i + 1) + ".xml"]);
    }
    list.push(["rId" + (2 + slideCount), "presProps", "presProps.xml"]);
    list.push(["rId" + (3 + slideCount), "viewProps", "viewProps.xml"]);
    list.push(["rId" + (4 + slideCount), "tableStyles", "tableStyles.xml"]);
    return rels(list);
  }

  var EMPTY_SP_TREE = "<p:spTree><p:nvGrpSpPr>" +
    '<p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>' +
    '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>' +
    '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree>';

  function slideMaster() {
    return XML + '<p:sldMaster xmlns:a="' + NS_A + '" xmlns:r="' + NS_R +
      '" xmlns:p="' + NS_P + '"><p:cSld>' +
      '<p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>' +
      "<a:effectLst/></p:bgPr></p:bg>" + EMPTY_SP_TREE + "</p:cSld>" +
      '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" ' +
      'accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" ' +
      'accent6="accent6" hlink="hlink" folHlink="folHlink"/>' +
      '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>' +
      "<p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>" +
      "</p:sldMaster>";
  }

  function slideLayout() {
    return XML + '<p:sldLayout xmlns:a="' + NS_A + '" xmlns:r="' + NS_R +
      '" xmlns:p="' + NS_P + '" type="blank" preserve="1">' +
      '<p:cSld name="Blank">' + EMPTY_SP_TREE + "</p:cSld>" +
      "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>";
  }

  function theme(brand, accent) {
    var b = String(brand).replace("#", "").toUpperCase();
    var ac = String(accent).replace("#", "").toUpperCase();
    var fill = '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>';
    var line = '<a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>';
    var effect = "<a:effectStyle><a:effectLst/></a:effectStyle>";
    return XML + '<a:theme xmlns:a="' + NS_A + '" name="Turas"><a:themeElements>' +
      '<a:clrScheme name="Turas">' +
      '<a:dk1><a:srgbClr val="1C2333"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>' +
      '<a:dk2><a:srgbClr val="' + b + '"/></a:dk2><a:lt2><a:srgbClr val="F3F4F8"/></a:lt2>' +
      '<a:accent1><a:srgbClr val="' + b + '"/></a:accent1>' +
      '<a:accent2><a:srgbClr val="' + ac + '"/></a:accent2>' +
      '<a:accent3><a:srgbClr val="7A7FB6"/></a:accent3>' +
      '<a:accent4><a:srgbClr val="C0655B"/></a:accent4>' +
      '<a:accent5><a:srgbClr val="5B8FA8"/></a:accent5>' +
      '<a:accent6><a:srgbClr val="6B7280"/></a:accent6>' +
      '<a:hlink><a:srgbClr val="0563C1"/></a:hlink>' +
      '<a:folHlink><a:srgbClr val="954F72"/></a:folHlink></a:clrScheme>' +
      '<a:fontScheme name="Turas">' +
      '<a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>' +
      '<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>' +
      "</a:fontScheme>" +
      '<a:fmtScheme name="Office">' +
      "<a:fillStyleLst>" + fill + fill + fill + "</a:fillStyleLst>" +
      "<a:lnStyleLst>" + line + line + line + "</a:lnStyleLst>" +
      "<a:effectStyleLst>" + effect + effect + effect + "</a:effectStyleLst>" +
      "<a:bgFillStyleLst>" + fill + fill + fill + "</a:bgFillStyleLst>" +
      "</a:fmtScheme></a:themeElements></a:theme>";
  }

  /**
   * Package slides into a complete .pptx archive.
   * @param {Array<string|{xml: string, charts: Array<{xml: string,
   *   workbook: Uint8Array}>}>} slides - plain slide XML strings, or rich
   *   slides carrying NATIVE chart objects (chart XML + embedded Excel
   *   workbook, so PowerPoint's "Edit Data" opens a real sheet).
   * @param {object} payload - report payload (brand colours for the theme).
   * @returns {Uint8Array} the .pptx bytes.
   * @throws {Error} when slides is empty.
   */
  pptx.package = function (slides, payload) {
    if (!Array.isArray(slides) || slides.length === 0) {
      throw new Error("CFG_PPTX_EMPTY: cannot build a deck with zero slides.");
    }
    var slideObjs = slides.map(function (s) {
      return typeof s === "string" ? { xml: s, charts: [] } : s;
    });
    var n = slideObjs.length;
    var chartTotal = slideObjs.reduce(function (sum, s) {
      return sum + (s.charts ? s.charts.length : 0);
    }, 0);
    var entries = [
      { name: "[Content_Types].xml", data: contentTypes(n, chartTotal) },
      { name: "_rels/.rels", data: rels([["rId1", "officeDocument", "ppt/presentation.xml"]]) },
      { name: "ppt/presentation.xml", data: presentation(n) },
      { name: "ppt/_rels/presentation.xml.rels", data: presentationRels(n) },
      { name: "ppt/presProps.xml", data: XML + '<p:presentationPr xmlns:p="' + NS_P + '"/>' },
      { name: "ppt/viewProps.xml", data: XML + '<p:viewPr xmlns:p="' + NS_P + '"/>' },
      { name: "ppt/tableStyles.xml", data: XML + '<a:tblStyleLst xmlns:a="' + NS_A +
        '" def="{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"/>' },
      { name: "ppt/theme/theme1.xml",
        data: theme(TR.charts.brandOf(payload), TR.charts.accentOf(payload)) },
      { name: "ppt/slideMasters/slideMaster1.xml", data: slideMaster() },
      { name: "ppt/slideMasters/_rels/slideMaster1.xml.rels",
        data: rels([["rId1", "slideLayout", "../slideLayouts/slideLayout1.xml"],
          ["rId2", "theme", "../theme/theme1.xml"]]) },
      { name: "ppt/slideLayouts/slideLayout1.xml", data: slideLayout() },
      { name: "ppt/slideLayouts/_rels/slideLayout1.xml.rels",
        data: rels([["rId1", "slideMaster", "../slideMasters/slideMaster1.xml"]]) }
    ];
    var chartIndex = 0;
    slideObjs.forEach(function (slide, i) {
      var slideRels = [["rId1", "slideLayout", "../slideLayouts/slideLayout1.xml"]];
      (slide.charts || []).forEach(function (chart, k) {
        chartIndex++;
        slideRels.push(["rId" + (2 + k), "chart",
          "../charts/chart" + chartIndex + ".xml"]);
        entries.push({ name: "ppt/charts/chart" + chartIndex + ".xml",
          data: chart.xml });
        entries.push({ name: "ppt/charts/_rels/chart" + chartIndex + ".xml.rels",
          data: rels([["rId1", "package",
            "../embeddings/chart_data" + chartIndex + ".xlsx"]]) });
        entries.push({ name: "ppt/embeddings/chart_data" + chartIndex + ".xlsx",
          data: chart.workbook });
      });
      entries.push({ name: "ppt/slides/slide" + (i + 1) + ".xml", data: slide.xml });
      entries.push({ name: "ppt/slides/_rels/slide" + (i + 1) + ".xml.rels",
        data: rels(slideRels) });
    });
    return TR.zip.build(entries);
  };

})(typeof window !== "undefined" ? window : globalThis);
