# Quickshell Packaging for NixOS — Research Findings

> **Date**: 2026-06-22
> **Status**: ✅ Complete
> **Quickshell version**: 0.3.0 (latest stable)

---

## TL;DR: Recommendation

**Use `pkgs.quickshell` from nixpkgs unstable.** It is version 0.3.0, maintained by the Quickshell author (`outfoxxed`), has binary cache via `cache.nixos.org`, and includes all needed features (PanelWindow, WlrLayershell, Qt6, SVG, Pipewire, PAM, Polkit).

For bleeding-edge development or custom build flags, use the official flake from `git+https://git.outfoxxed.me/quickshell/quickshell`.

---

## 1. nixpkgs Availability

### ✅ `pkgs.quickshell` EXISTS in nixpkgs unstable

- **Package path**: `pkgs/by-name/qu/quickshell/package.nix`
- **Version**: `0.3.0`
- **Maintainer**: `outfoxxed` (the Quickshell author)
- **Binary cache**: ✅ Available via `cache.nixos.org` (standard nixpkgs cache)
- **Source**: `git.outfoxxed.me/quickshell/quickshell` (tag `v0.3.0`)
- **License**: LGPL-3.0-only

### nixpkgs derivation key details

```nix
# pkgs/by-name/qu/quickshell/package.nix
stdenv.mkDerivation (finalAttrs: {
  pname = "quickshell";
  version = "0.3.0";
  src = fetchFromGitea {
    domain = "git.outfoxxed.me";
    owner = "quickshell";
    repo = "quickshell";
    tag = "v${finalAttrs.version}";
    hash = "sha256-gU+VGpwGJ2vvg0mtYqVvj5u+2LteuHlpokH6JSAtueY=";
  };

  nativeBuildInputs = [
    cmake ninja qt6.qtshadertools spirv-tools
    vulkan-headers wayland-scanner qt6.wrapQtAppsHook pkg-config
  ];

  buildInputs = [
    qt6.qtbase qt6.qtdeclarative qt6.qtwayland qt6.qtsvg
    cli11 wayland wayland-protocols libdrm libgbm
    cpptrace jemalloc libxcb pam pipewire glib polkit
  ];
})
```

**All features are enabled** by default in the nixpkgs build (Wayland, X11, Pipewire, PAM, Polkit, Hyprland, crash handler, jemalloc, SVG).

---

## 2. Official Flake

### Flake URLs

| Mirror | URL | Notes |
|--------|-----|-------|
| **Primary (Gitea)** | `git+https://git.outfoxxed.me/quickshell/quickshell` | Official source |
| **GitHub mirror** | `github:quickshell-mirror/quickshell` | Auto-synced mirror |

### Flake input declaration

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    quickshell = {
      # Option A: Track master (bleeding edge)
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";

      # Option B: Pin to a tagged release
      # url = "git+https://git.outfoxxed.me/quickshell/quickshell?ref=v0.3.0";

      # Option C: Use GitHub mirror
      # url = "github:quickshell-mirror/quickshell";

      # CRITICAL: Follow your nixpkgs to avoid Qt ABI mismatches
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

### Flake outputs

- **Package**: `quickshell.packages.${system}.default`
- **Overlay**: `quickshell.overlays.default`
- **DevShell**: `quickshell.devShells.${system}.default`

### Flake feature flags (default.nix)

```nix
quickshell.packages.x86_64-linux.default.override {
  withJemalloc = true;        # Mask heap fragmentation
  withQtSvg = true;           # SVG icon/image support
  withWayland = true;         # Wayland + wlr-layer-shell
  withX11 = true;             # X11 panel window support
  withPipewire = true;        # Pipewire audio integration
  withPam = true;             # PAM authentication
  withHyprland = true;        # Hyprland IPC/features
  withI3 = true;              # i3/Sway IPC
  withPolkit = true;          # Polkit auth agent
  withNetworkManager = true;  # NetworkManager integration
  withCrashReporter = true;   # Crash handler + restart
}
```

### `withModules` — add extra QML packages

The flake version has a `withModules` function for adding QML libraries to Quickshell's environment:

```nix
quickshell.packages.x86_64-linux.default.withModules [
  qt6.qtmultimedia
  qt6.qt5compat
]
```

---

## 3. Binary Cache (Cachix)

### ❌ No dedicated Quickshell Cachix

There is **no `quickshell.cachix.org` or equivalent**. However:

| Method | Cache | Build Required? |
|--------|-------|-----------------|
| **nixpkgs** (`pkgs.quickshell`) | `cache.nixos.org` | ❌ No (pre-built) |
| **Official flake** | None | ✅ Yes (local build) |

**Recommendation**: Use nixpkgs `pkgs.quickshell` to avoid building from source.

---

## 4. API Feature Verification (v0.3.0)

### ✅ PanelWindow
- **Import**: `import Quickshell`
- **Type**: Cross-platform decorationless window with screen-edge anchoring
- **Properties**: `anchors`, `margins`, `exclusiveZone`, `exclusionMode`, `aboveWindows`, `focusable`
- **Docs**: https://quickshell.org/docs/v0.3.0/types/Quickshell/PanelWindow/

### ✅ WlrLayershell (layer-shell overlay)
- **Import**: `import Quickshell.Wayland`
- **Type**: Attached object on `PanelWindow` — enables `zwlr_layer_shell_v1`
- **Layer values**: `WlrLayer.Background`, `WlrLayer.Bottom`, `WlrLayer.Top`, `WlrLayer.Overlay`
- **For Dynamic Island overlay**:

```qml
import Quickshell
import Quickshell.Wayland

PanelWindow {
  anchors {
    top: true
  }
  // Overlay layer renders above everything
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "dynamic-island"
}
```

### ✅ SpringAnimation
- **NOT a Quickshell type** — it's a **Qt Quick built-in**
- **Import**: `import QtQuick` (already available)
- **Usage**: Standard `Behavior on property { SpringAnimation { ... } }` or standalone
- **Properties**: `spring`, `damping`, `mass`, `velocity`, `epsilon`, `modulus`
- **Docs**: https://doc.qt.io/qt-6/qml-qtquick-springanimation.html

### ✅ Qt6 Dependencies
- **Minimum**: Qt 6.6+
- **Required packages**: qtbase, qtdeclarative, qtwayland, qtsvg
- **Build-time**: qtshadertools, spirv-tools, vulkan-headers, wayland-scanner
- **Runtime extras**: qtmultimedia (if using audio), qt5compat
- **Note**: Quickshell relies on private Qt APIs — MUST rebuild when Qt version changes

---

## 5. NixOS Module Support

### DMS (Display Manager Shell)

nixpkgs has a **dedicated NixOS module** for Quickshell-based DMS:

```nix
# Enable quickshell-based display manager shell
programs.dms-shell = {
  enable = true;
  quickshell.package = pkgs.quickshell;
};
```

### Other Quickshell-based packages in nixpkgs

| Package | Path | Description |
|---------|------|-------------|
| `noctalia-shell` | `pkgs/by-name/no/noctalia-shell/` | Full desktop shell built on Quickshell |
| `dms-shell` | `pkgs/by-name/dm/dms-shell/` | Display manager shell using Quickshell |

---

## 6. Comparison: nixpkgs vs Flake

| Criteria | nixpkgs (`pkgs.quickshell`) | Official Flake |
|----------|----------------------------|----------------|
| **Version** | 0.3.0 (tagged stable) | master or tagged |
| **Binary cache** | ✅ `cache.nixos.org` | ❌ Build from source |
| **Maintainer** | `outfoxxed` (author) | `outfoxxed` (author) |
| **Feature flags** | All defaults (enabled) | `.override { }` available |
| **`withModules`** | ❌ Not exposed | ✅ Yes |
| **DevShell** | ❌ | ✅ Available |
| **Update lag** | ~days behind master | Immediate |
| **Qt ABI safety** | ✅ Matches nixpkgs Qt | ✅ `inputs.nixpkgs.follows` |

---

## 7. Definitive Recommendation

### For Dynamic Island (standalone Quickshell project):

**Use nixpkgs `pkgs.quickshell`** — it's the simplest, fastest (pre-built), and officially maintained option. Version 0.3.0 has everything needed:

```nix
# In your flake.nix outputs:
environment.systemPackages = [ pkgs.quickshell ];
# or in home-manager:
home.packages = [ pkgs.quickshell ];
```

### If you need bleeding-edge features or `withModules`:

```nix
{
  inputs.quickshell = {
    url = "git+https://git.outfoxxed.me/quickshell/quickshell";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Then use outputs:
  # quickshell.packages.${system}.default
  # quickshell.overlays.default
}
```

### What NOT to use:
- ❌ `github:noctalia-dev/noctalia-qs` — dead code, obsolete fork
- ❌ `github:outfoxxed/quickshell` — old repo URL; the owner is now the `quickshell` org
- ❌ Arch AUR / Fedora COPR — not relevant for NixOS

---

## 8. Verified Sources

| Source | URL | Evidence |
|--------|-----|----------|
| nixpkgs package.nix (v0.3.0) | https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/qu/quickshell/package.nix | grepped + fetched |
| Official flake.nix | https://github.com/quickshell-mirror/quickshell/blob/master/flake.nix | web-fetched |
| Official default.nix (feature flags) | https://github.com/quickshell-mirror/quickshell/blob/master/default.nix | web-fetched |
| Official docs (install) | https://quickshell.org/docs/guide/install-setup | web-searched |
| PanelWindow API docs (v0.3.0) | https://quickshell.org/docs/v0.3.0/types/Quickshell/PanelWindow/ | web-fetched |
| WlrLayershell API docs (v0.3.0) | https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/WlrLayershell/ | web-fetched |
| WlrLayershell source | https://github.com/quickshell-mirror/quickshell/blob/783c9539/src/wayland/wlr_layershell/wlr_layershell.hpp | web-fetched |
| Qt SpringAnimation docs | https://doc.qt.io/qt-6/qml-qtquick-springanimation.html | web-searched |
| BUILD.md (all features) | https://github.com/quickshell-mirror/quickshell/blob/master/BUILD.md | web-fetched |
