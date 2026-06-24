# Noctalia v5 — Dynamic Island Color Export Learnings

> Session: 2026-06-22
> Topic: Template system for exporting color palette to external applications

## Key Discoveries

### 1. Template Engine
- Noctalia v5 has a full `TemplateEngine` with expressions `{{ }}`, blocks `<* *>`, loops, conditionals, filters, and pipe syntax
- Colors accessed as `{{ colors.<name>.<mode>.<format> }}` where format is `hex`, `rgb`, `hsl`, etc.
- 16 M3 color roles available: primary, on_primary, secondary, on_secondary, tertiary, on_tertiary, error, on_error, surface, on_surface, surface_variant, on_surface_variant, outline, shadow, hover, on_hover
- Terminal tokens also available: terminal_foreground, terminal_background, terminal_cursor, etc.
- No separate `background`/`onBackground` tokens — use `surface`/`on_surface` instead

### 2. Template Config Format
- TOML-driven batch processing: `[templates.<name>]` with `input_path`, `output_path`, `post_hook`
- `output_path` can be string or array (multiple outputs from one template)
- `output_path_dynamic` runs a shell command whose stdout lines become output paths
- `pre_hook`/`post_hook` run shell commands before/after rendering
- Template variables available: `{{ mode }}`, `{{ image }}`, `{{ config_dir }}`, `{{ config_file }}`, `{{ closest_color }}`
- XDG vars (`$XDG_CONFIG_HOME`, etc.) are auto-expanded per spec defaults

### 3. colors_changed Hook
- Defined in C++ as `HookKind::ColorsChanged` in `config_types.h`
- Fires "after the theme palette is resolved and terminal templates are updated"
- Configured in `[hooks]` section: string or array of strings
- Available env vars: `NOCTALIA_THEME_MODE`, `NOCTALIA_THEME_MODE_PREVIOUS`, `NOCTALIA_THEME_MODE_CONFIGURED`
- No colors_changed-specific env vars documented (e.g. no `NOCTALIA_COLORS_PATH`)
- Post-hooks on templates run BEFORE the global `colors_changed` hook

### 4. Execution Order
1. Wallpaper loaded → Wu quantizer → M3 scheme generation
2. Template engine renders ALL template files
3. Per-template `post_hook` runs
4. Global `colors_changed` hook fires

### 5. Debounce Strategy
- Use a file-based lock with timestamp comparison
- 2s debounce window protects against rapid wallpaper slideshow changes
- Implement in a shell script, called from `colors_changed` hook

### 6. Builtin Templates Reference
- Noctalia ships 24 built-in templates (alacritty, btop, cava, emacs, foot, ghostty, gtk3/4, helix, kcolorscheme, kitty, labwc, niri, hyprland, mango, qt, scroll, sway, starship, wezterm)
- All use `input_path` + `output_path` + `post_hook` pattern
- Some use `output_path_dynamic` for machine-dependent paths (emacs, niri, hyprland)

### 7. Output Format Decision
- JSON with camelCase keys (matches dynamic-island expectations)
- `hex` format with `#` prefix — standard CSS, universally parseable
- Include `surfaceVariants` and `terminal` objects for future use
- `mode` and `image` metadata included for consumer awareness

### 8. Files to Create
- `~/.config/noctalia/templates/dynamic-island/colors.json` — the template
- `~/.config/noctalia/hooks/colors-changed.sh` — debounced SIGUSR2 sender
- `~/.config/noctalia/config.toml` entry for `[theme.templates.user.island]` and `[hooks]`

## Sources Verified
- [x] Template Reference docs — complete syntax, filters, control flow
- [x] Palette docs — all 16 color roles, terminal tokens
- [x] Hooks docs — colors_changed timing, env vars, examples
- [x] GitHub config_types.h — HookKind enum confirmation
- [x] GitHub example.toml — hooks config format
- [x] GitHub builtin.toml — template entry patterns from 24 official templates
