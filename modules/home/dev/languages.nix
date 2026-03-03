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
    (lib.hiPrio gcc)
    cmake
    gnumake
    pkg-config
    openssl
    openssl.dev  # headers + .pc for openssl-sys (e.g. cargo install rust-docs-mcp)

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
    RUSTC_WRAPPER = "sccache";
    SCCACHE_CACHE_SIZE = "10G";
    RUSTUP_HOME = "$HOME/.rustup";
    CARGO_HOME = "$HOME/.cargo";
    JAVA_HOME = "${pkgs.jdk21}";
    # So pkg-config finds openssl.pc (for openssl-sys in cargo builds)
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
  };
}
