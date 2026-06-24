# Noctalia v4 → v5 IPC Command Mapping

> Research date: 2026-06-22
> Sources:
> - [Noctalia v5 IPC Overview](https://docs.noctalia.dev/v5/ipc/)
> - [Shell & UI Commands](https://docs.noctalia.dev/v5/ipc/shell-and-ui/)
> - [System Controls](https://docs.noctalia.dev/v5/ipc/system-controls/)
> - [v5 GitHub repo](https://github.com/noctalia-dev/noctalia) (README, `example.toml`)

## Critical Differences

| Aspect | v4 | v5 |
|--------|----|----|
| Binary | `noctalia-shell` | `noctalia` |
| IPC syntax | `noctalia-shell ipc call <target> <action>` | `noctalia msg <command>` |
| Discovery | (manual docs) | `noctalia msg --help` |
| In-config usage | `noctalia-shell ipc call ...` | `noctalia:...` (shorthand prefix) |

## Usage Forms

```
# Terminal / compositor keybinds:
noctalia msg <command>

# Inside Noctalia config (hooks, idle behaviors, widgets):
noctalia:<command>

# Example:
noctalia msg session lock          # from terminal / compositor
noctalia:session lock              # inside hooks / idle config
```

---

## Required v4 → v5 Mappings

These are the commands currently used in the NixOS config:

| # | v4 Command | v5 Equivalent | Category |
|---|-----------|---------------|----------|
| 1 | `noctalia-shell ipc call controlCenter toggle` | `noctalia msg panel-toggle control-center` | Panels |
| 2 | `noctalia-shell ipc call settings toggle` | `noctalia msg settings-toggle` | General |
| 3 | `noctalia-shell ipc call lockScreen lock` | `noctalia msg session lock` | Session |
| 4 | `noctalia-shell ipc call volume increase` | `noctalia msg volume-up` | Volume |
| 5 | `noctalia-shell ipc call volume decrease` | `noctalia msg volume-down` | Volume |
| 6 | `noctalia-shell ipc call volume muteOutput` | `noctalia msg volume-mute` | Volume |
| 7 | `noctalia-shell ipc call volume muteInput` | `noctalia msg mic-mute` | Microphone |
| 8 | `noctalia-shell ipc call lockScreen lock` (lock-on-start) | `noctalia msg session lock` | Session |

---

## Complete v5 IPC Command Reference

### General

| Action | Command |
|--------|---------|
| Print status | `noctalia msg status` |
| Reload config | `noctalia msg config-reload` |
| Toggle settings window | `noctalia msg settings-toggle` |

### Panels (Shell & UI)

| Action | Command |
|--------|---------|
| Toggle launcher | `noctalia msg panel-toggle launcher [query]` |
| Toggle session menu | `noctalia msg panel-toggle session` |
| Toggle clipboard | `noctalia msg panel-toggle clipboard` |
| Toggle wallpaper picker | `noctalia msg panel-toggle wallpaper` |
| Toggle control center | `noctalia msg panel-toggle control-center [tab]` |
| Open panel | `noctalia msg panel-open <id> [context]` |
| Close panel | `noctalia msg panel-close [id]` |

### Session

| Action | Command |
|--------|---------|
| Lock session | `noctalia msg session lock` |
| Suspend | `noctalia msg session suspend` |
| Lock + suspend | `noctalia msg session lock-and-suspend` |
| Log out | `noctalia msg session logout` |
| Reboot | `noctalia msg session reboot` |
| Shut down | `noctalia msg session shutdown` |

### Volume & Audio

| Action | Command |
|--------|---------|
| Set output volume | `noctalia msg volume-set 65` |
| Raise output volume | `noctalia msg volume-up [step]` |
| Lower output volume | `noctalia msg volume-down [step]` |
| Mute output toggle | `noctalia msg volume-mute` |
| Set mic volume | `noctalia msg mic-volume-set 0.5` |
| Raise mic volume | `noctalia msg mic-volume-up [step]` |
| Lower mic volume | `noctalia msg mic-volume-down [step]` |
| Mute mic toggle | `noctalia msg mic-mute` |

### Brightness

| Action | Command |
|--------|---------|
| Set brightness | `noctalia msg brightness-set [monitor] <value>` |
| Raise brightness | `noctalia msg brightness-up [monitor] [step]` |
| Lower brightness | `noctalia msg brightness-down [monitor] [step]` |
| Show brightness OSD | `noctalia msg brightness-osd <value>` |

### Media Controls

| Action | Command |
|--------|---------|
| Previous track | `noctalia msg media previous` |
| Play/pause toggle | `noctalia msg media toggle` |
| Stop playback | `noctalia msg media stop` |
| Next track | `noctalia msg media next` |

### Bar

| Action | Command |
|--------|---------|
| Show bar | `noctalia msg bar-show [name] [monitor]` |
| Hide bar | `noctalia msg bar-hide [name] [monitor]` |
| Toggle bar | `noctalia msg bar-toggle [name] [monitor]` |
| Set auto-hide | `noctalia msg bar-auto-hide-set <on|off> [name] [monitor]` |

### Dock

| Action | Command |
|--------|---------|
| Show dock | `noctalia msg dock-show` |
| Hide dock | `noctalia msg dock-hide` |
| Toggle dock | `noctalia msg dock-toggle` |
| Reload dock | `noctalia msg dock-reload` |

### Wallpaper

| Action | Command |
|--------|---------|
| Random wallpaper | `noctalia msg wallpaper-random [connector]` |
| Get wallpaper path | `noctalia msg wallpaper-get [connector]` |
| Set wallpaper | `noctalia msg wallpaper-set [connector] <path>` |

### Notifications & DND

| Action | Command |
|--------|---------|
| DND on | `noctalia msg notification-dnd-set on` |
| DND off | `noctalia msg notification-dnd-set off` |
| Toggle DND | `noctalia msg notification-dnd-toggle` |
| DND status | `noctalia msg notification-dnd-status` |
| Clear active notifications | `noctalia msg notification-clear-active` |
| Clear history | `noctalia msg notification-clear-history` |

### Theme

| Action | Command |
|--------|---------|
| Get theme mode | `noctalia msg theme-mode-get` |
| Toggle theme mode | `noctalia msg theme-mode-toggle` |
| Set theme mode | `noctalia msg theme-mode-set dark|light|auto` |
| Get color scheme | `noctalia msg color-scheme-get` |
| Set color scheme | `noctalia msg color-scheme-set <source> <name>` |

### System: Night Light, Wi-Fi, Bluetooth, Caffeine, Power

| Action | Command |
|--------|---------|
| Night light enable | `noctalia msg nightlight-enable` |
| Night light disable | `noctalia msg nightlight-disable` |
| Night light toggle | `noctalia msg nightlight-toggle` |
| Night light force | `noctalia msg nightlight-force-toggle` |
| Wi-Fi enable | `noctalia msg wifi-enable` |
| Wi-Fi disable | `noctalia msg wifi-disable` |
| Wi-Fi toggle | `noctalia msg wifi-toggle` |
| Wi-Fi status | `noctalia msg wifi-status` |
| Bluetooth enable | `noctalia msg bluetooth-enable` |
| Bluetooth disable | `noctalia msg bluetooth-disable` |
| Bluetooth toggle | `noctalia msg bluetooth-toggle` |
| Bluetooth status | `noctalia msg bluetooth-status` |
| Caffeine enable | `noctalia msg caffeine-enable` |
| Caffeine disable | `noctalia msg caffeine-disable` |
| Caffeine toggle | `noctalia msg caffeine-toggle` |
| Power profile set | `noctalia msg power-set <profile>` |
| Power profile cycle | `noctalia msg power-cycle` |
| DPMS on | `noctalia msg dpms-on` |
| DPMS off | `noctalia msg dpms-off` |

### Screenshots

| Action | Command |
|--------|---------|
| Region screenshot | `noctalia msg screenshot-region [widget]` |
| Fullscreen screenshot | `noctalia msg screenshot-fullscreen [pick|output|all]` |

### Window Switcher

| Action | Command |
|--------|---------|
| Open switcher | `noctalia msg window-switcher` |
| Close switcher | `noctalia msg window-switcher close` |

### Desktop & Lockscreen Widgets

| Action | Command |
|--------|---------|
| Enter edit mode | `noctalia msg desktop-widgets-edit` |
| Exit edit mode | `noctalia msg desktop-widgets-exit` |
| Toggle edit mode | `noctalia msg desktop-widgets-toggle-edit` |
| Show widgets | `noctalia msg desktop-widgets-show` |
| Hide widgets | `noctalia msg desktop-widgets-hide` |
| Toggle widgets | `noctalia msg desktop-widgets-toggle` |

### Clipboard

| Action | Command |
|--------|---------|
| Clear clipboard history | `noctalia msg clipboard-clear` |

### Plugins

| Action | Command |
|--------|---------|
| Send event to plugin | `noctalia msg plugin <author/plugin:entry> <target> <event> [payload]` |
| Manage plugins | `noctalia msg plugins <subcommand>` |

### Templates

| Action | Command |
|--------|---------|
| Apply templates | `noctalia msg templates-apply` |

---

## Notes for Migration

1. **Binary name change**: `noctalia-shell` → `noctalia`. Ensure the v5 binary is named `noctalia` in the Nix package.

2. **Lock on start**: The v4 `noctalia-shell ipc call lockScreen lock` in the lock-on-start service becomes `noctalia msg session lock`. The v5 `loginctl lock-session` also uses the same IPC path when Noctalia is running.

3. **Idle behaviors in config**: When used inside `[idle.behavior.*]` or `[hooks]` config blocks, use the `noctalia:` prefix instead:
   ```toml
   [idle.behavior.lock]
   timeout = 600
   command = "noctalia:session lock"
   ```

4. **Volume/mic commands**: The v5 `volume-mute` toggles output mute (replaces v4 `volume muteOutput`). The v5 `mic-mute` toggles microphone mute (replaces v4 `volume muteInput`). No `muteOutput`/`muteInput` distinction exists — each has its own dedicated command now.

5. **Niri compositor**: Niri keybinds use the normal `exec` syntax:
   ```
   // ~/.config/niri/config.kdl
   spawn-at-startup "noctalia"
   ```
   The v5 docs include a [Niri compositor settings page](https://docs.noctalia.dev/v5/compositor-settings/niri/).

6. **Discover all commands**: Run `noctalia msg --help` to see the complete, up-to-date list of all available IPC commands.

7. **CLI entry point changes**: The v5 binary serves as both the shell daemon and the IPC client:
   - `noctalia` — run the shell
   - `noctalia --daemon` — run as daemon (returns after init)
   - `noctalia msg <command>` — send IPC command to running shell
   - `noctalia config validate` — validate configuration
   - `noctalia config export` — export config
