/**
 * Hub Namespace Initialization (iframe approach)
 *
 * Creates the ReportHub namespace object. Must be loaded first.
 * Each report runs in its own iframe — no ID resolution needed.
 */

var ReportHub = ReportHub || {};
ReportHub.reportKeys = ReportHub.reportKeys || [];
ReportHub.loadedIframes = ReportHub.loadedIframes || {};
