# DEPRECATED - Use /modules/shared/lib/ Instead

This directory (`/shared/`) is deprecated. All shared utilities have been consolidated into:

```
/modules/shared/lib/
```

## Migration

Replace:
```r
source(file.path(turas_root, "shared", "formatting.R"))
source(file.path(turas_root, "shared", "weights.R"))
source(file.path(turas_root, "shared", "config_utils.R"))
```

With:
```r
source(file.path(turas_root, "modules/shared/lib/import_all.R"))
```

Or individual files:
```r
source(file.path(turas_root, "modules/shared/lib/formatting_utils.R"))
source(file.path(turas_root, "modules/shared/lib/weights_utils.R"))
source(file.path(turas_root, "modules/shared/lib/config_utils.R"))
```

## Files Relocated

| Old Location | New Location |
|-------------|--------------|
| /shared/config_utils.R | /modules/shared/lib/config_utils.R (merged) |
| /shared/formatting.R | /modules/shared/lib/formatting_utils.R |
| /shared/weights.R | /modules/shared/lib/weights_utils.R |

## Retained for Compatibility

The files in this directory are retained temporarily for backward compatibility.
They will be removed in a future version.
