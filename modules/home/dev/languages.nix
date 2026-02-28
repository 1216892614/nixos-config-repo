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
    gcc
    cmake
    gnumake
    pkg-config

    # Python
    python3
    pipx
    poetry

    # JavaScript / TypeScript
    nodejs_24
    pnpm
    deno
    bun
  ];

  home.sessionPath = [
    "$HOME/.cargo/bin"
    "$HOME/.deno/bin"
    "$HOME/.bun/bin"
  ];

  home.sessionVariables = {
    RUSTC_WRAPPER = "sccache";
    SCCACHE_CACHE_SIZE = "10G";
    RUSTUP_HOME = "$HOME/.rustup";
    CARGO_HOME = "$HOME/.cargo";
  };
}
