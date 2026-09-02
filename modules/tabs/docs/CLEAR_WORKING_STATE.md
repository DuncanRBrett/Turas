# Clearing stale working state in a tabs v2 report

## Why old pins and highlights come back

The generated report is clean. `assets/template.html` emits the `user-state`
island as literal `null` and `build_report_v2.R` never writes to it, so a fresh
build from `launch_turas` contains no pins, insights, notes, highlights,
shortlist, hubs, banners, composites or Patterns curation. Everything the report
carries comes from the data layer, the qual island and the config.

What brings the old state back is the browser. Every store is keyed by project
name plus wave, not by file or build (`d2.storeKey`, `20_data.js`):

```
<store>:<slug of project.name + " " + project.wave>
```

So regenerating the same project at the same wave and opening it in the same
browser re-attaches the previous session's state to the new file. This is
deliberate. It is what lets you regenerate ten times while writing a report and
keep your commentary each time, but it means a report you want to see *clean*
needs the state cleared, or a browser that never had it.

## The stores

Eleven state stores plus two reader UI preferences:

| Key | Holds |
|---|---|
| `turas_v2_story` | pinned story items |
| `turas_v2_insights` | per-question analyst insights |
| `turas_v2_annotations` | data-point notes |
| `turas_v2_banners` | saved custom banners |
| `turas_v2_composites` | composite banners |
| `turas_v2_composites_seq` | composite id high-water mark |
| `turas_v2_takeout` | Patterns / takeout curation |
| `turas_v2_report` | Report-tab section text |
| `turas_v2_qualsaved` | qual shortlist (★) |
| `turas_v2_qualhl` | qual highlights (✎) |
| `turas_v2_qualhubs` | comment hubs |
| `v2explain_sig` | "explain significance" toggle |
| `v2pe_seen` | first-run hint dismissed |

There is no clear-everything control in the report, by design. The Story tab's
"Clear" empties story items only.

## Option 1. A private window

For "what will the client see?", open the fresh report in a private/incognito
window. Nothing carries in, nothing persists, nothing to undo.

## Option 2. The bookmarklet (recommended)

One-time setup: make a new bookmark in the bookmarks bar, name it
`Turas: clear working state`, and paste this as the URL.

```
javascript:(function(){var K=["turas_v2_story","turas_v2_insights","turas_v2_annotations","turas_v2_banners","turas_v2_composites","turas_v2_composites_seq","turas_v2_takeout","turas_v2_report","turas_v2_qualsaved","turas_v2_qualhl","turas_v2_qualhubs","v2explain_sig","v2pe_seen"];if(!window.TR||!TR.d2||!TR.d2.storeKey){alert("Not a Turas v2 report page.");return}var p=(TR.AGG&&TR.AGG.project)||{},n=0;K.forEach(function(k){var s=TR.d2.storeKey(k);if(localStorage.getItem(s)!==null){localStorage.removeItem(s);n++}});if(!confirm("Clear "+n+" saved store(s) for “"+(p.name||"this report")+" "+(p.wave||"")+"”?\n\nPins, insights, notes, highlights, shortlist, hubs, banners and Patterns curation for THIS project and wave will be deleted. Other reports are untouched.")){return}location.reload()})();
```

Open the report, click the bookmark, confirm. It scopes every deletion through
`TR.d2.storeKey`, so only this project and wave are affected. Other Turas
reports and other sites keep their state.

Works on every report you have already generated, since it needs nothing baked
into the file.

## Option 3. The console

Same thing, pasted into the report's DevTools console, then reload:

```js
["turas_v2_story","turas_v2_insights","turas_v2_annotations","turas_v2_banners","turas_v2_composites","turas_v2_composites_seq","turas_v2_takeout","turas_v2_report","turas_v2_qualsaved","turas_v2_qualhl","turas_v2_qualhubs","v2explain_sig","v2pe_seen"].forEach(k => localStorage.removeItem(TR.d2.storeKey(k)));
```

## What *not* to use

DevTools "Clear site data" works, but when reports are opened as `file://` URLs
browsers generally treat all local files as one storage origin, so it wipes
every Turas report's state on the machine, not just the one in front of you.

## One thing to know about saved copies

Clearing localStorage removes the `_owns` marker, so on reload every store
re-seeds from the `user-state` island. In a report you generated, that island is
`null` and clearing is permanent. In a **saved copy** the island holds the
author's baked-in version, so clearing means *revert to the version in the
file*, not delete. Same action, different meaning. Check which file you are
looking at.

To hand someone a clean report, send the freshly generated one. `report.saveCopy`
deliberately bakes insights, story, banners, composites, qual shortlist,
highlights and Patterns curation into the file.
