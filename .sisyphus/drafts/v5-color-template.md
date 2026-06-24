# Noctalia v5 Color Template Export — Research

> **Date**: 2026-06-22
> **Status**: DRAFT — research complete, implementation-ready
> **Sources**:
> - [Template Reference](https://docs.noctalia.dev/v5/theming/templates/)
> - [Palette Docs](https://docs.noctalia.dev/v5/theming/palette/)
> - [Hooks Docs](https://docs.noctalia.dev/v5/automation/hooks/)
> - [example.toml](https://github.com/noctalia-dev/noctalia/blob/main/example.toml)
> - [builtin.toml](https://github.com/noctalia-dev/noctalia/blob/main/assets/templates/builtin.toml)
> - [config_types.h](https://github.com/noctalia-dev/noctalia/blob/main/src/config/config_types.h#L1065)

---

## 1. Template Variable Syntax

Noctalia v5 uses a `TemplateEngine` with two syntax forms:

### Inline Expressions
```
{{ colors.<name>.<mode>.<format> }}
```

### Control Blocks
```
<* for name, value in colors *> {{ name }}={{ value.default.hex }} <* endfor *>
<* if {{ condition }} *> … <* else *> … <* endif *>
```

### Special Values (directly available)
| Variable | Description |
|----------|-------------|
| `{{ mode }}` | Current default mode (`dark`/`light`) |
| `{{ image }}` | Source image path (for wallpaper themes) |
| `{{ closest_color }}` | Result of `compare_to` / `colors_to_compare` |
| `{{ config_dir }}` | Noctalia config directory |
| `{{ config_file }}` | Config file path |

### Loop Metadata
Inside `for` loops, `loop.index` (zero-based), `loop.first`, and `loop.last` are available.

---

## 2. Complete Color Format Reference

### Output Formats
| Format | Example |
|--------|---------|
| `hex` | `#rrggbb` |
| `hex_stripped` | `rrggbb` (no `#`) |
| `rgb` | `rgb(r, g, b)` |
| `rgb_csv` | `r,g,b` |
| `rgba` | `rgba(r, g, b, a)` |
| `hsl` | `hsl(h, s%, l%)` |
| `hsla` | `hsla(h, s%, l%, a)` |
| `red` | Integer 0–255 |
| `green` | Integer 0–255 |
| `blue` | Integer 0–255 |
| `alpha` | Float 0.0–1.0 |
| `hue` | Integer 0–360 |
| `saturation` | Integer 0–100 |
| `lightness` | Integer 0–100 |

### Modes
- `dark`
- `light`
- `default` — resolves to the configured default mode

---

## 3. ALL Color Role Variables

The 16 palette roles from Material Design 3, accessed via `colors.<role>.<mode>.<format>`:

| Template Access | Palette Field | Role |
|----------------|---------------|------|
| `colors.primary.default.hex` | `mPrimary` | Primary accent (buttons, links, highlights) |
| `colors.on_primary.default.hex` | `mOnPrimary` | Text/icons on primary surfaces |
| `colors.secondary.default.hex` | `mSecondary` | Secondary accent |
| `colors.on_secondary.default.hex` | `mOnSecondary` | Text/icons on secondary surfaces |
| `colors.tertiary.default.hex` | `mTertiary` | Tertiary accent |
| `colors.on_tertiary.default.hex` | `mOnTertiary` | Text/icons on tertiary surfaces |
| `colors.error.default.hex` | `mError` | Error/destructive-action color |
| `colors.on_error.default.hex` | `mOnError` | Text/icons on error surfaces |
| `colors.surface.default.hex` | `mSurface` | Main shell background |
| `colors.on_surface.default.hex` | `mOnSurface` | Primary text/icon on shell surfaces |
| `colors.surface_variant.default.hex` | `mSurfaceVariant` | Secondary background (cards, panels) |
| `colors.on_surface_variant.default.hex` | `mOnSurfaceVariant` | Secondary text/icons |
| `colors.outline.default.hex` | `mOutline` | Borders, separators, subtle outlines |
| `colors.shadow.default.hex` | `mShadow` | Shadow color |
| `colors.hover.default.hex` | `mHover` | Hover/interactive highlight |
| `colors.on_hover.default.hex` | `mOnHover` | Text/icons on hover surfaces |

### Terminal Tokens
Additionally available:
`terminal_foreground`, `terminal_background`, `terminal_cursor`, `terminal_cursor_text`,
`terminal_selection_fg`, `terminal_selection_bg`, plus all 16 ANSI terminal colors
(`terminal_normal_black`, `terminal_normal_red`, …, `terminal_bright_white`).

### Color Aliases
- `hover` → `surface_container_high`
- `on_hover` → `on_surface`

> ⚠️ **Note on `background`/`onBackground`**: These are NOT separate roles in v5's palette. For the dynamic island, use `surface` as the island background and `on_surface` for text/icons. The template below uses `surface`/`on_surface` for this purpose.

---

## 4. Filters (Pipe Syntax)

### Color Filters
| Filter | Syntax | Effect |
|--------|--------|--------|
| `grayscale` | `| grayscale` | Convert to gray (luminance weighting) |
| `invert` | `| invert` | Invert each RGB channel |
| `set_alpha` | `| set_alpha 0.5` | Set alpha 0–1 |
| `set_lightness` | `| set_lightness 50` | Set HSL lightness 0–100 |
| `set_hue` | `| set_hue 180` | Set absolute hue in degrees |
| `rotate_hue` | `| rotate_hue 30` | Rotate hue by relative degrees |
| `set_saturation` | `| set_saturation 50` | Set HSL saturation 0–100 |
| `set_red` / `set_green` / `set_blue` | `| set_red 200` | Set channel 0–255 |
| `lighten` | `| lighten 10` | +lightness in percentage points |
| `darken` | `| darken 10` | −lightness in percentage points |
| `saturate` | `| saturate 10` | +saturation in percentage points |
| `desaturate` | `| desaturate 10` | −saturation in percentage points |
| `auto_lightness` | `| auto_lightness 10` | Shift away from mid (lightens dark, darkens light) |

### Color-Argument Filters
| Filter | Syntax |
|--------|--------|
| `blend` | `| blend: "#ff0000", 0.5` |
| `harmonize` | `| harmonize: "#00ff88"` |
| `to_color` | `| to_color | darken 0.1` |

### String Filters
`replace`, `lower_case`, `camel_case`, `pascal_case`, `snake_case`, `kebab_case`

---

## 5. TOML Template Config for Color Export

Create at `~/.config/noctalia/templates/dynamic-island.toml`:

```toml
# ── Noctalia v5 Color Export for Dynamic Island ──
# Saves a JSON palette file the island watches for changes.
# Usage: noctalia theme <image> -c ~/.config/noctalia/templates/dynamic-island.toml

[config]

[templates.island]
input_path  = "./dynamic-island/colors.json"
output_path = "$XDG_CONFIG_HOME/dynamic-island/colors.json"
post_hook   = "pkill -SIGUSR2 --full 'dynamic-island' || true"
```

**Template file** (`~/.config/noctalia/templates/dynamic-island/colors.json`):

```json
{
  "mode": "{{ mode }}",
  "image": "{{ image }}",
  "palette": {
    "primary": "{{ colors.primary.default.hex }}",
    "onPrimary": "{{ colors.on_primary.default.hex }}",
    "surface": "{{ colors.surface.default.hex }}",
    "onSurface": "{{ colors.on_surface.default.hex }}",
    "background": "{{ colors.surface.default.hex }}",
    "onBackground": "{{ colors.on_surface.default.hex }}",
    "error": "{{ colors.error.default.hex }}",
    "outline": "{{ colors.outline.default.hex }}"
  },
  "surfaceVariants": {
    "surfaceVariant": "{{ colors.surface_variant.default.hex }}",
    "onSurfaceVariant": "{{ colors.on_surface_variant.default.hex }}"
  },
  "terminal": {
    "background": "{{ colors.terminal_background.default.hex }}",
    "foreground": "{{ colors.terminal_foreground.default.hex }}",
    "cursor": "{{ colors.terminal_cursor.default.hex }}",
    "selectionBg": "{{ colors.terminal_selection_bg.default.hex }}"
  }
}
```

> Alternative: If the template engine supports `output_path_dynamic` for templated paths,
> you can use `output_path_dynamic` instead, which runs a shell command and appends each
> non-empty stdout line as an output path.

---

## 6. JSON Schema for `~/.config/dynamic-island/colors.json`

```jsonc
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Dynamic Island Color Palette",
  "description": "Color palette exported by Noctalia v5 for Dynamic Island consumption",
  "type": "object",
  "required": ["mode", "palette"],
  "properties": {
    "mode": {
      "type": "string",
      "enum": ["dark", "light"],
      "description": "Active theme mode"
    },
    "image": {
      "type": ["string", "null"],
      "description": "Source wallpaper path, empty string when using built-in palette"
    },
    "palette": {
      "type": "object",
      "required": [
        "primary", "onPrimary", "surface", "onSurface",
        "background", "onBackground", "error", "outline"
      ],
      "properties": {
        "primary":       { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" },
        "onPrimary":     { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" },
        "surface":       { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" },
        "onSurface":     { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" },
        "background":    { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" },
        "onBackground":  { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" },
        "error":         { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" },
        "outline":       { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" }
      }
    },
    "surfaceVariants": {
      "type": "object",
      "properties": {
        "surfaceVariant":    { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" },
        "onSurfaceVariant":  { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" }
      }
    },
    "terminal": {
      "type": "object",
      "properties": {
        "background":  { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" },
        "foreground":  { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" },
        "cursor":      { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" },
        "selectionBg": { "type": "string", "pattern": "^#[0-9a-fA-F]{6}$" }
      }
    }
  }
}
```

### Example Output

```json
{
  "mode": "dark",
  "image": "/home/user/Pictures/Wallpapers/mountain.jpg",
  "palette": {
    "primary": "#d0bcff",
    "onPrimary": "#381e72",
    "surface": "#141218",
    "onSurface": "#e6e1e5",
    "background": "#141218",
    "onBackground": "#e6e1e5",
    "error": "#f2b8b5",
    "outline": "#938f99"
  },
  "surfaceVariants": {
    "surfaceVariant": "#49454f",
    "onSurfaceVariant": "#cac4d0"
  },
  "terminal": {
    "background": "#141218",
    "foreground": "#e6e1e5",
    "cursor": "#e6e1e5",
    "selectionBg": "#938f99"
  }
}
```

---

## 7. `colors_changed` Hook — Full Documentation

### When it fires
> "After the theme palette is resolved and terminal templates are updated."

From the enum in `config_types.h`:
```cpp
constexpr EnumOption<HookKind> kHookKinds[] = {
    // ...
    {HookKind::ColorsChanged, "colors_changed", ""},
    // ...
};
```

### Environment Variables available during `colors_changed`

Based on the hooks documentation, these env vars are set by Noctalia:

| Variable | Description | Source |
|----------|-------------|--------|
| `NOCTALIA_THEME_MODE` | `dark` or `light` | Set by `theme_mode_changed`, also available during `colors_changed` |
| `NOCTALIA_THEME_MODE_PREVIOUS` | Previous mode value | Set before `theme_mode_changed` fires |
| `NOCTALIA_THEME_MODE_CONFIGURED` | `dark`, `light`, or `auto` | The user-configured mode (not resolved) |

> Note: The hooks page does not explicitly list `colors_changed`-specific env vars
> like `NOCTALIA_COLORS_PATH`. The template output path is known to the hook author
> (it's the `output_path` in the template config). If you need the color file path in
> the hook, hardcode it or wrap in a script that knows the path.

### Hook Configuration

In `~/.config/noctalia/config.toml` (or any `*.toml` under config dir):

```toml
[hooks]
colors_changed = [
  "pkill -SIGUSR2 --full 'dynamic-island' || true",
]
```

Or as a single-string command:
```toml
[hooks]
colors_changed = "pkill -SIGUSR2 --full 'dynamic-island' || true"
```

### Timing & Order

1. Theme palette is resolved (wallpaper → Wu quantizer → M3 scheme)
2. Template engine renders all template files (including `dynamic-island/colors.json`)
3. Template `post_hook` runs (if configured on the template entry)
4. `colors_changed` hook fires ← **island reload happens here**

### Debounce Strategy

For wallpaper slideshow protection (2s debounce needed):

```toml
[hooks]
colors_changed = "bash ~/.config/noctalia/hooks/colors-changed.sh"
```

```bash
#!/usr/bin/env bash
# ~/.config/noctalia/hooks/colors-changed.sh
# Debounced SIGUSR2 sender for dynamic-island

LOCKFILE="/tmp/noctalia-color-change.lock"
DEBOUNCE_SEC=2

# Check if we're in a debounce window
if [[ -f "$LOCKFILE" ]]; then
  touch "$LOCKFILE"  # bump the timestamp
  exit 0
fi

# Set the lock
touch "$LOCKFILE"

# Wait for debounce window
sleep "$DEBOUNCE_SEC"

# Check if the lockfile was bumped during sleep
if [[ "$(stat -c %Y "$LOCKFILE" 2>/dev/null)" -gt "$(( $(date +%s) - DEBOUNCE_SEC ))" ]]; then
  # Debounce was bumped - wait again
  sleep "$DEBOUNCE_SEC"
fi

# Only fire if we are still the last in line
if [[ -f "$LOCKFILE" ]] && [[ "$(stat -c %Y "$LOCKFILE" 2>/dev/null)" -le "$(( $(date +%s) - DEBOUNCE_SEC + 1 ))" ]]; then
  rm -f "$LOCKFILE"
  pkill -SIGUSR2 --full 'dynamic-island' || true
fi
```

---

## 8. Integration Recipe

### Complete Noctalia Config Snippet

```toml
# ── Theme config ──
[theme]
mode   = "dark"
source = "wallpaper"
wallpaper_scheme = "m3-tonal-spot"

[theme.templates]
enable_builtin_templates = false

[theme.templates.user.island]
input_path  = "templates/dynamic-island/colors.json"
output_path = "$XDG_CONFIG_HOME/dynamic-island/colors.json"
post_hook   = ""   # handled by colors_changed hook instead

# ── Hooks ──
[hooks]
colors_changed = "bash ~/.config/noctalia/hooks/colors-changed.sh"
```

### File Layout

```
~/.config/noctalia/
├── config.toml                          # Contains [theme] and [hooks] above
├── templates/
│   └── dynamic-island/
│       └── colors.json                  # The template (Section 5)
├── hooks/
│   └── colors-changed.sh                # Debounced signal sender
```

```
~/.config/dynamic-island/
└── colors.json                          # Rendered output — island watches this file
```

### Manual Test

```bash
# Render with wallpaper
noctalia theme ~/Pictures/test.jpg \
  -c ~/.config/noctalia/templates/dynamic-island.toml

# Check output
cat ~/.config/dynamic-island/colors.json | jq .
```

---

## 9. Key Decisions & Rationale

| Decision | Rationale |
|----------|-----------|
| Use `surface` for `background` | Noctalia v5 has no separate `background` token; `surface` IS the shell background in M3. `on_surface` serves as `onBackground`. |
| Separate TOML config from main config | Keeps the dynamic-island template self-contained, can be tested with `-c` flag independently |
| Debounce in hook script, not template | `colors_changed` fires AFTER template rendering; `post_hook` fires BEFORE and only per-template-entry — hook-level debounce catches all |
| Use `$XDG_CONFIG_HOME` not `~/.config` | Preferred per Noctalia docs: resolves correctly when XDG vars are relocated |
| `hex` format (with `#`) | Standard CSS representation, easily parsed by any consumer |
| `post_hook` empty, signal in `colors_changed` | Keeps template export portable; the island reload is a system-level concern that belongs in hooks, not per-template post-processing |

---

## 10. Caveats & Open Questions

1. **`background`/`onBackground` tokens**: Not present in the documented 16-role palette. If v5 adds them before GA, update the template to use `{{ colors.background.default.hex }}` instead of surface. The defined `surfaceVariants` section is safe regardless.

2. **`output_path_dynamic`**: Could be used instead of static `output_path` to compute paths dynamically. Example from Emacs template: `output_path_dynamic = "bash '{{ config_dir }}/emacs/output-path.sh'"`. Not needed for dynamic-island since the path is fixed.

3. **`closest_color` in hooks**: The template `post_hook` has access to `{{ closest_color }}` when `compare_to`/`colors_to_compare` are configured. Not relevant for the basic color export.

4. **Light/dark dual output**: If the island needs both light and dark mode colors simultaneously, use `input_path_modes`:
   ```toml
   input_path_modes = { dark = "./island-colors-dark.json", light = "./island-colors-light.json" }
   ```
   Each renders separately with the respective mode's colors.

5. **`colors_changed` fires once per theme resolution**: Multiple rapid wallpaper changes still trigger one `colors_changed` per resolution, but a wallpaper slideshow at 5s intervals would trigger it 12x/min. The 2s debounce is essential.
