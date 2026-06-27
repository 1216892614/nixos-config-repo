{ config, lib, pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    # Rust (self-managed via rustup)
    rustup
    sccache
    cargo-edit
    cargo-watch
    cargo-expand

    # C/C++ toolchain
    clang
    lld
    (lib.hiPrio gcc)
    cmake
    gnumake
    pkg-config
    openssl
    openssl.dev  # headers + .pc for openssl-sys (e.g. cargo install rust-docs-mcp)
    wayland  # lib + wayland-client.pc for wayland-sys (Rust Wayland crates)

    # Python
    python3
    pipx
    poetry

    # JavaScript / TypeScript
    nodejs_24
    pnpm
    deno
    bun

    # Java (e.g. for X Minecraft Launcher / modded Minecraft)
    jdk21
  ];

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/.deno/bin"
    "$HOME/.bun/bin"
  ];

  home.sessionVariables = {
    # RUSTC_WRAPPER / SCCACHE_* → managed by ./service-plane.nix
    RUSTUP_HOME = "$HOME/.rustup";
    CARGO_HOME = "$HOME/.cargo";
    JAVA_HOME = "${pkgs.jdk21}";
    # So pkg-config finds .pc files for cargo build scripts (openssl-sys, wayland-sys, etc.)
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.wayland.dev}/lib/pkgconfig";
  };

  # Limit parallel linker jobs to prevent rust-lld from exhausting memory
  home.file.".cargo/config.toml".text = ''
    [build]
    jobs = 4
  '';
}
