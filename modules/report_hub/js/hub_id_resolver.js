/**
 * Hub ID Resolver - ReportHub Namespace Initialization
 *
 * Creates the ReportHub namespace object used by hub_navigation.js
 * and hub_pinned.js. Must be loaded first.
 *
 * ID resolution for prefixed elements is handled by per-report
 * scoped helper functions (_$id, _$qs) injected into each report's
 * JS block during assembly.
 */

var ReportHub = ReportHub || {};
